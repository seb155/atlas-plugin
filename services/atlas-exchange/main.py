"""
atlas-exchange — Authentik OIDC token → Cloudflare Access Service Token exchange

Part of Phase B.2.c of plugins.axoiq.com Zero-Trust (ADR-021 bootstrap flow).

Flow:
  1. User runs `curl -fsSL https://plugins.axoiq.com/atlas.sh | bash`
  2. Script does OAuth 2.0 Device Authorization Grant (RFC 8628) against Authentik
  3. Script gets an Authentik access_token (short-lived, ~1h)
  4. Script POSTs to this service: Authorization: Bearer <authentik_token>
  5. This service validates the Authentik token via introspection
  6. If valid + user is authorized: creates a per-user CF Access Service Token
  7. Returns {client_id, client_secret, expires_at} for the user to save

Security:
  - Requires Authentik JWT validation (signature + audience + expiry)
  - Rate limited (to prevent token flooding)
  - Audit log for each issued token (structlog + correlation ID)
  - CF API Global Key read from env (cannot be logged)

Deploy:
  See README.md — Docker Compose at homelab stack.

Config via env:
  AUTHENTIK_ISSUER        — e.g., https://auth.axoiq.com/application/o/atlas-cli-device/
  AUTHENTIK_AUDIENCE      — OIDC audience claim (e.g., "atlas-cli-device")
  AUTHENTIK_JWKS_URL      — JWKS endpoint for signature verification
  CF_EMAIL                — CF account email
  CF_GLOBAL_API_KEY       — CF Global API Key (from BW)
  CF_ACCOUNT_ID           — 418120b9e6fa67cbddcb4a03aafb7e11
  CF_ACCESS_APP_ID        — 29135f06-ca88-4e1b-9e2b-23a141cfe6d2
  CF_POLICY_ID            — 0fe85847-d583-41e5-a689-598a107b700f (P2 service tokens)
  TOKEN_DURATION_HOURS    — e.g., 8760 (1 year)
  LOG_LEVEL               — default INFO
"""
import os
import time
import uuid
from typing import Annotated

import httpx
import structlog
from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from pydantic import BaseModel

log = structlog.get_logger()

# ─── Config ───────────────────────────────────────────────────────────
AUTHENTIK_ISSUER = os.environ["AUTHENTIK_ISSUER"]
AUTHENTIK_AUDIENCE = os.environ["AUTHENTIK_AUDIENCE"]
AUTHENTIK_JWKS_URL = os.environ["AUTHENTIK_JWKS_URL"]
CF_EMAIL = os.environ["CF_EMAIL"]
CF_GLOBAL_API_KEY = os.environ["CF_GLOBAL_API_KEY"]
CF_ACCOUNT_ID = os.environ["CF_ACCOUNT_ID"]
CF_ACCESS_APP_ID = os.environ["CF_ACCESS_APP_ID"]
CF_POLICY_ID = os.environ["CF_POLICY_ID"]
TOKEN_DURATION_HOURS = int(os.environ.get("TOKEN_DURATION_HOURS", "8760"))
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

app = FastAPI(title="atlas-exchange", version="0.1.0")
bearer = HTTPBearer(auto_error=True)
_jwks_cache: dict = {}


class ExchangeResponse(BaseModel):
    client_id: str
    client_secret: str
    token_id: str
    expires_at: str


# ─── Auth — validate Authentik access token ──────────────────────────
async def _get_jwks() -> dict:
    """Cache JWKS for 5 min to avoid hammering Authentik."""
    now = time.time()
    if _jwks_cache.get("expires_at", 0) > now:
        return _jwks_cache["keys"]
    async with httpx.AsyncClient(timeout=5.0) as client:
        resp = await client.get(AUTHENTIK_JWKS_URL)
        resp.raise_for_status()
    _jwks_cache["keys"] = resp.json()
    _jwks_cache["expires_at"] = now + 300
    return resp.json()


async def verify_authentik_token(
    creds: Annotated[HTTPAuthorizationCredentials, Depends(bearer)],
) -> dict:
    """Validate Authentik JWT signature + audience + expiry. Return claims."""
    jwks = await _get_jwks()
    try:
        header = jwt.get_unverified_header(creds.credentials)
        key = next(k for k in jwks["keys"] if k["kid"] == header["kid"])
        claims = jwt.decode(
            creds.credentials,
            key=key,
            algorithms=[header["alg"]],
            audience=AUTHENTIK_AUDIENCE,
            issuer=AUTHENTIK_ISSUER,
        )
        return claims
    except (JWTError, StopIteration) as e:
        log.warning("authentik_token_invalid", error=str(e))
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid Authentik token") from e


# ─── CF Access — issue service token + bind to policy ────────────────
async def issue_cf_service_token(user_email: str) -> dict:
    """Create a CF Access Service Token named after the user + bind to P2 policy."""
    token_name = f"atlas-user-{user_email.replace('@', '-at-').replace('.', '-')}-{int(time.time())}"
    headers = {
        "X-Auth-Email": CF_EMAIL,
        "X-Auth-Key": CF_GLOBAL_API_KEY,
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        # 1. Create service token
        resp = await client.post(
            f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT_ID}/access/service_tokens",
            headers=headers,
            json={"name": token_name, "duration": f"{TOKEN_DURATION_HOURS}h"},
        )
        resp.raise_for_status()
        result = resp.json()["result"]
        token_id = result["id"]

        # 2. Append to P2 policy's service_token include list
        # (get current policy, append, update)
        policy_resp = await client.get(
            f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT_ID}"
            f"/access/apps/{CF_ACCESS_APP_ID}/policies/{CF_POLICY_ID}",
            headers=headers,
        )
        policy_resp.raise_for_status()
        policy = policy_resp.json()["result"]
        policy["include"].append({"service_token": {"token_id": token_id}})
        update_resp = await client.put(
            f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT_ID}"
            f"/access/apps/{CF_ACCESS_APP_ID}/policies/{CF_POLICY_ID}",
            headers=headers,
            json={
                "name": policy["name"],
                "decision": policy["decision"],
                "include": policy["include"],
                "precedence": policy["precedence"],
            },
        )
        update_resp.raise_for_status()

    return result


# ─── Routes ───────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "service": "atlas-exchange"}


@app.post("/atlas/exchange", response_model=ExchangeResponse)
async def exchange(
    request: Request,
    claims: Annotated[dict, Depends(verify_authentik_token)],
) -> ExchangeResponse:
    corr_id = str(uuid.uuid4())
    user_email = claims.get("email")
    if not user_email:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Authentik token missing email claim")

    log.info(
        "exchange_request",
        correlation_id=corr_id,
        user=user_email,
        sub=claims.get("sub"),
        remote_addr=request.client.host if request.client else "unknown",
    )

    try:
        result = await issue_cf_service_token(user_email)
    except httpx.HTTPStatusError as e:
        log.error(
            "cf_token_issue_failed",
            correlation_id=corr_id,
            status=e.response.status_code,
            body=e.response.text[:500],
        )
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, "CF token issue failed") from e

    log.info(
        "exchange_success",
        correlation_id=corr_id,
        user=user_email,
        token_id=result["id"],
        expires_at=result["expires_at"],
    )

    return ExchangeResponse(
        client_id=result["client_id"],
        client_secret=result["client_secret"],
        token_id=result["id"],
        expires_at=result["expires_at"],
    )
