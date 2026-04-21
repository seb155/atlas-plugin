# G Mining Pilot Onboarding Procedure (Phase B.6)

**Status**: DRAFT — pending NDA signature before activation
**Target go-live**: 2026-05-20
**Pilot scope**: ~10 users at G Mining (all ATLAS plugins: atlas-core + atlas-dev + atlas-admin)
**Plan reference**: `.blueprint/plans/aujourdhui-su-rmon-ordinateur-clever-blum.md` Phase B.6
**HITL Gate**: G5 (NDA signed + 2-user canary 48h, error rate < 5%)

## Prerequisite — NDA Coverage (BLOCKING)

Before issuing any access token to a G Mining pilot user, a signed Non-Disclosure
Agreement must be on file. The NDA MUST explicitly cover:

- **Methodology**: MSE 4-layer model, MBSE framework, CAGM (Capital Asset
  Governance Model) conventions, ISA 5.1 classification internals
- **Client references**: pilot data may include codenames THM-012 (Perama Hill),
  BRTZ, CAJB, FORAN, GYOW/oko-ref, and any client-specific adaptation patterns
- **Process**: ATLAS engineering chain (IMPORT → CLASSIFY → ENGINEER → SPEC GROUP
  → E-BOM → PROCURE → ESTIMATE → OUTPUTS), G-Part/E-Part/M-Part/I-Part/S-Part
  lifecycle, 3-tier rule inheritance (ISA → Company → Project)
- **Infrastructure**: internal URLs (forgejo.axoiq.com, synapse.axoiq.com, etc.),
  vault references, cognitive pattern framework (HID 5-layer), cost analytics
- **Distribution restriction**: G Mining may use ATLAS internally but may not
  redistribute plugin code, documentation, or workflow definitions to third
  parties without AXOIQ written consent

**Status as of 2026-04-20**: no NDA located on Seb's laptop or vaults.
Action required: Seb to confirm whether an NDA is in place (scan Vaultwarden /
Cloud Drive / Gmail archive for G Mining NDA dated 2026), or to draft + send
one via standard AXOIQ contract template before pilot activation.

**Cross-reference**: if NDA is signed but not tracked in vault, store the signed
PDF in `vault/AxoiQ/contracts/nda-gmining-<YYYY-MM-DD>.pdf` for future reference.

## Pilot user roster (template)

Populate this table AFTER NDA is signed, with the final list of G Mining
engineers who will receive plugin access:

| # | Name | Email | Role | Token issued | Token expiry | Notes |
|---|------|-------|------|---|---|---|
| 1 | (TBD) | (TBD)@[REDACTED] | (TBD) | YYYY-MM-DD | YYYY-MM-DD (+90d) | — |
| 2 | (TBD) | (TBD)@[REDACTED] | (TBD) | YYYY-MM-DD | YYYY-MM-DD (+90d) | — |
| … | … | … | … | … | … | … |

Constraints on the roster:
- Maximum 10 users for initial pilot (2026-05-20 → 2026-06-20, first month)
- Each user receives their own CF Access Service Token (1 token per identity,
  not a shared org token) — enables per-user audit trail + revocation
- Email must be `@[REDACTED]` or a G Mining-approved domain
- Must be listed in the signed NDA annexe or exhibit

## Per-user onboarding flow (once NDA signed + user in roster)

### Step 1 — Add user to Cloudflare Access policy P3

Navigate: Cloudflare dashboard → Zero Trust → Access → Applications →
plugins.axoiq.com → Edit policies → Policy P3 "Humans — G Mining pilot" →
Add email to the include list.

### Step 2 — Issue a per-user CF Access Service Token

Navigate: Cloudflare dashboard → Zero Trust → Access → Service Auth →
Service Tokens → Create Service Token.

- Name: `gmining-pilot-<firstname>-<lastname>-2026-05-20` (e.g.,
  `gmining-pilot-jdoe-2026-05-20`)
- Duration: 90 days
- Record Client ID + Client Secret in Vaultwarden collection
  `AXOIQ/Marketplace Tokens/G Mining Pilot`

### Step 3 — Send credentials via Bitwarden Send (expiration 7 days)

The credentials must NOT go via:
- Email plain text (persisted in server logs)
- Chat (Slack, Teams — log retention)
- SMS (SIM-swap risk)

The correct channel is Bitwarden Send (end-to-end encrypted, self-expiring):

1. Log into Vaultwarden
2. Create a Bitwarden Send with:
   - Name: `ATLAS Pilot Credentials — <username>`
   - Text content: the Client ID + Client Secret (labeled)
   - Expiration: 7 days
   - Max accesses: 1 (view-then-destroy)
   - Password: a one-time secret shared via signal channel
3. Share the Bitwarden Send URL via the user's verified email, labeled
   "One-time credentials; must be retrieved within 7 days"

### Step 4 — User runs the bootstrap script

User is instructed (in the onboarding email) to run:

```bash
# Set credentials from the Bitwarden Send one-time secret
export ATLAS_CF_CLIENT_ID="<paste from Bitwarden Send>"
export ATLAS_CF_CLIENT_SECRET="<paste from Bitwarden Send>"

# Optional — Atlas-managed alternative: use atlas-setup.sh with device flow
# (requires NDA signer's email provisioned in Authentik as G Mining external user)
curl -fsSL https://plugins.axoiq.com/atlas.sh | bash
```

Either path results in `~/.claude/settings.json` having the right marketplace
headers, and `claude plugin install atlas-core@atlas-axoiq` succeeds.

### Step 5 — Log onboarding in roster + vault

Update the roster table above with:
- `Token issued` date (today)
- `Token expiry` date (today + 90 days)
- `Notes` column with any relevant info (user's OS, installation method, issues)

Add an entry to `vault/AxoiQ/pilot-onboarding-log.md`:
```
2026-05-20 T14:30 EDT — gmining-pilot-jdoe-2026-05-20 issued to John Doe
  (john@[REDACTED]). Delivered via Bitwarden Send #abc123. Expiry 2026-08-18.
```

## Canary gate G5 criteria (BLOCKING for full pilot activation)

Before issuing tokens to ALL ~10 pilot users, run a 48h canary with 2 users:

- 2 initial users (technical lead + PM at G Mining) receive tokens first
- Monitor for 48h:
  - Caddy access_log `/var/log/caddy/plugins.log` (on LXC 103)
  - CF Access audit log (dashboard)
  - `~/.atlas/logs/` on the pilot users' machines (via screen-share if needed)
- Success criteria:
  - Install flow completes < 2 min end-to-end
  - `claude plugin install atlas-core` succeeds without errors
  - `/atlas` first session loads all 131 skills
  - Zero authentication errors in CF audit log
  - Error rate overall < 5% across the 48h period

If canary passes → Gate G5 APPROVED → issue tokens to remaining 8 pilot users.
If canary fails → investigate + fix + re-run 48h canary with 2 new users.

## Rollback (per-user or global)

Per-user revocation:
- Cloudflare dashboard → Zero Trust → Access → Service Auth → Service Tokens →
  find the user's token → Revoke. Instant effect (< 60s propagation).

Global rollback (all pilot users):
- Cloudflare dashboard → Access → Applications → plugins.axoiq.com → Policies →
  disable P3 "G Mining pilot" entirely.
- User's existing `claude` sessions still running continue until they restart;
  on next SessionStart, marketplace access returns 403 → graceful failure mode.

## Cross-references

- ADR-020: CF Access Service Tokens architecture
- ADR-021: Device flow OAuth bootstrap (atlas-setup.sh)
- ADR-022: HITL auto-update gate
- Plan: `.blueprint/plans/aujourdhui-su-rmon-ordinateur-clever-blum.md` Phase B.6
- Lesson reference: `lesson_2026-04-19_token_rotation_patterns.md`

---

*Document template | Created: 2026-04-20 21:42 EDT | Author: Seb Gagnon (with ATLAS) | Status: DRAFT pending NDA verification*
