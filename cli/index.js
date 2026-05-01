#!/usr/bin/env bun
// @bun
import{createRequire}from"node:module";var __require=createRequire(import.meta.url);function baseUrl(){return process.env.DEVHUB_URL??"http://localhost:8001"}async function resolveToken(){if(process.env.ATLAS_HOOK_TOKEN)return process.env.ATLAS_HOOK_TOKEN;const envPath=`${process.env.HOME??"/root"}/.env`;try{const{readFileSync}=await import("node:fs");const content=readFileSync(envPath,"utf-8");const match=content.match(/^ATLAS_HOOK_TOKEN=["']?([^"'\n]+)["']?/m);if(match?.[1])return match[1]}catch{}return null}function col(value,width){if(value.length>=width)return value.slice(0,width);return value.padEnd(width)}function pp(data){console.log(JSON.stringify(data,null,2))}async function authHeaders(){const token=await resolveToken();const base={Accept:"application/json"};if(token)return{...base,Authorization:`Bearer ${token}`};return base}async function apiGet(path){const url=`${baseUrl()}/api/v1${path}`;try{const res=await fetch(url,{headers:await authHeaders(),signal:AbortSignal.timeout(1e4)});if(!res.ok)return null;return await res.json()}catch{return null}}async function apiPost(path,body){const url=`${baseUrl()}/api/v1${path}`;try{const res=await fetch(url,{method:"POST",headers:{...await authHeaders(),"Content-Type":"application/json"},body:JSON.stringify(body),signal:AbortSignal.timeout(1e4)});if(!res.ok)return null;return await res.json()}catch{return null}}async function cmdSync(args){let featureId="";let autoMode=false;let jsonMode=false;for(let i=0;i<args.length;i++){const arg=args[i];if(arg==="--feature"||arg==="-f"){featureId=args[++i]??""}else if(arg?.startsWith("--feature=")){featureId=arg.slice("--feature=".length)}else if(arg==="--auto"){autoMode=true}else if(arg==="--json"){jsonMode=true}else if(arg==="--help"||arg==="-h"||arg==="help"){printSyncHelp();return}}const payload={session_id:process.env.CLAUDE_SESSION_ID??"cli",source:"atlas-cli",auto:autoMode};if(featureId)payload.feature_id=featureId;if(!jsonMode){console.log(`
  \x1B[1mPortal Sync\x1B[0m`);if(featureId)console.log(`  Feature:   \x1B[36m${featureId}\x1B[0m`);if(autoMode)console.log("  Mode:      \x1B[36mauto\x1B[0m");console.log(`  Endpoint:  ${baseUrl()}/api/v1/devhub/sync/auto`);console.log(`  ──────────────────────────────────────────
`)}const data=await apiPost("/devhub/sync/auto",payload);if(!data){console.error("  ⚠️  Sync endpoint unreachable — DevHub may not be running");console.error("  Hint: Start backend with `docker compose up -d`\n");process.exit(1)}if(jsonMode){pp(data);return}const ok=["queued","ok","accepted","synced","success"].includes(data.status??"");const icon=ok?"✅":"⚠️ ";console.log(`  ${icon} ${data.status??"?"}`);if(data.sync_id??data.id)console.log(`  ID:       ${data.sync_id??data.id}`);if(data.triggered_at??data.timestamp)console.log(`  Time:     ${data.triggered_at??data.timestamp}`);const files=data.files_synced??data.files;if(Array.isArray(files)&&files.length)console.log(`  Files:    ${files.length} synced`);else if(files)console.log(`  Files:    ${files}`);console.log()}function printSyncHelp(){console.log(`atlas portal sync [flags] — trigger DevHub portal sync

POST /api/v1/devhub/sync/auto

Flags:
  --feature <id>    Sync a specific feature by ID
  --auto            Auto-sync mode (uses last known state)
  --json            Raw JSON output

Auth:
  ATLAS_HOOK_TOKEN  Bearer token (scoped to portal:sync-only)
  DEVHUB_URL        Override base URL (default: http://localhost:8001)

Examples:
  atlas portal sync
  atlas portal sync --feature FE-42
  atlas portal sync --auto
  atlas portal sync --json`)}async function cmdStatus(args){const jsonMode=args.includes("--json");if(!jsonMode){console.log(`
  \x1B[1mPortal Status\x1B[0m`);console.log(`  ────────────────────────────────────────────────────────────────────
`)}const health=await apiGet("/devhub/health");if(!health){console.error(`  ❌ DevHub unreachable at ${baseUrl()}`);console.error("  Hint: Set DEVHUB_URL or start backend with `docker compose up -d`\n");process.exit(1)}const eco=await apiGet("/devhub/ecosystem");if(jsonMode){console.log("=== /devhub/health ===");pp(health);if(eco){console.log(`
=== /devhub/ecosystem ===`);pp(eco)}return}const status=health.status??"?";const lastSync=health.last_sync_at??health.last_sync??"N/A";const syncCount=health.sync_count??"?";const pending=health.pending_changes??0;const version=health.version??"?";const hIcon=["healthy","ok"].includes(status)?"✅":status==="degraded"?"⚠️ ":"❌";console.log(`  ${hIcon} ${status.toUpperCase().padEnd(12)}  v${version}`);console.log(`  Last sync:   ${lastSync}`);console.log(`  Total syncs: ${syncCount}`);if(pending)console.log(`  Pending:     ${pending} change(s) awaiting sync`);const apps=Array.isArray(eco)?eco:eco?.apps??eco?.services??eco?.data??[];if(apps.length>0){console.log(`
  \x1B[1mApplications\x1B[0m`);console.log(`  ${col("",3)}${col("App",22)} ${col("Health",12)} ${col("Last Sync",26)} ${col("URL",22)}`);console.log("  ────────────────────────────────────────────────────────────────────");for(const app of apps){const name=col(app.name??app.app??"",22);const healthVal=col(app.health??app.status??"?",12);const ls=col(app.last_sync_at??app.last_sync??"—",26);const url=col(app.url??"",22);const aIcon=["healthy","ok","green"].includes(app.health??app.status??"")?"✅":["degraded","warn"].includes(app.health??app.status??"")?"⚠️ ":"❌";console.log(`  ${aIcon}  ${name} ${healthVal} ${ls} ${url}`)}}else{console.log(`
  \x1B[2m(ecosystem endpoint not available)\x1B[0m`)}console.log(`
  \x1B[2mBase: ${baseUrl()}\x1B[0m
`)}async function cmdDiff(args){let since="";let jsonMode=false;for(let i=0;i<args.length;i++){const arg=args[i];if(arg==="--since-last-week"){const d=new Date(Date.now()-604800000);since=d.toISOString().replace(/\.\d+Z$/,"Z")}else if(arg?.startsWith("--since=")){since=arg.slice("--since=".length)}else if(arg==="--since"){since=args[++i]??""}else if(arg==="--json"){jsonMode=true}else if(arg==="--help"||arg==="-h"||arg==="help"){printDiffHelp();return}}const qs=since?`?since=${encodeURIComponent(since)}`:"";if(!jsonMode){console.log(`
  \x1B[1mPortal Drift Report\x1B[0m`);if(since)console.log(`  Since:  \x1B[36m${since}\x1B[0m`);console.log(`  ──────────────────────────────────────────────────────
`)}const data=await apiGet(`/devhub/health${qs}`);if(!data){console.error(`  ❌ DevHub unreachable at ${baseUrl()}
`);process.exit(1)}if(jsonMode){pp(data);return}const status=data.status??"?";const lastSync=data.last_sync_at??data.last_sync??"N/A";let driftItems=[];if(Array.isArray(data.drift)){driftItems=data.drift}else if(data.drift&&typeof data.drift==="object"){driftItems=data.drift.items??data.drift.changes??[]}else if(Array.isArray(data.changes)){driftItems=data.changes}const driftCount=data.drift_count??driftItems.length;const icon=["healthy","ok"].includes(status)?"✅":"⚠️ ";console.log(`  ${icon} Status:    ${status}`);console.log(`  Last sync: ${lastSync}`);console.log(`  Drift:     ${driftCount} item(s)`);if(driftItems.length>0){console.log();console.log(`  ${col("File",42)} ${col("Type",18)} Severity`);console.log(`  ${"─".repeat(42)} ${"─".repeat(18)} ${"─".repeat(10)}`);const shown=driftItems.slice(0,20);for(const item of shown){const path=col(item.path??item.file??"",42);const kind=col(item.type??item.kind??"change",18);const severity=item.severity??"medium";const sevIcon=["critical","high"].includes(severity)?"\uD83D\uDD34":severity==="medium"?"\uD83D\uDFE1":"\uD83D\uDFE2";console.log(`  ${path} ${kind} ${sevIcon} ${severity}`)}if(driftItems.length>20){console.log(`  ... and ${driftItems.length-20} more item(s)`)}}else{console.log(`
  ✅ No drift detected — portal is in sync`)}console.log()}function printDiffHelp(){console.log(`atlas portal diff [flags] — show DevHub portal drift report

GET /api/v1/devhub/health

Flags:
  --since-last-week     Show drift from the past 7 days
  --since <ISO8601>     Show drift since a specific timestamp
  --json                Raw JSON output

Auth:
  ATLAS_HOOK_TOKEN  Bearer token
  DEVHUB_URL        Override base URL (default: http://localhost:8001)

Examples:
  atlas portal diff
  atlas portal diff --since-last-week
  atlas portal diff --since 2026-04-19T00:00:00Z
  atlas portal diff --json`)}async function portalCmd(args){const sub=args[0]??"help";const rest=args.slice(1);switch(sub){case"sync":case"s":await cmdSync(rest);break;case"status":case"st":await cmdStatus(rest);break;case"diff":case"d":await cmdDiff(rest);break;case"help":case"--help":case"-h":case"":printPortalHelp();break;default:console.error(`Unknown portal subcommand: '${sub}'. Run 'atlas portal help'.`);process.exit(1)}}function printPortalHelp(){console.log(`atlas portal — DevHub cockpit sync/status/diff commands

Subcommands:
  sync [--feature <id>] [--auto]   Trigger portal sync (POST /devhub/sync/auto)
  status                           App health + last sync table (5+ apps)
  diff [--since-last-week]         Drift report (GET /devhub/health)

Aliases: s=sync, st=status, d=diff

Global flags:
  --json      Raw JSON output (all commands)
  --help, -h  Show command help

Auth (in order of precedence):
  ATLAS_HOOK_TOKEN   Bearer token scoped to portal:sync-only
  DEVHUB_URL         Override base URL (default: http://localhost:8001)

Examples:
  atlas portal sync
  atlas portal sync --feature FE-42 --json
  atlas portal status
  atlas portal diff --since-last-week
  atlas portal diff --json`)}var[,,cmd,...args]=process.argv;if(!cmd||cmd==="--help"||cmd==="-h"){console.log(`atlas CLI (TypeScript commands)

Usage: atlas <command> [args]

Commands:
  portal     DevHub cockpit sync/status/diff (--help for details)

Examples:
  atlas portal --help
  atlas portal status
  atlas portal sync
  atlas portal diff --since-last-week`);process.exit(0)}switch(cmd){case"portal":await portalCmd(args);break;default:console.error(`Unknown command: ${cmd}`);console.error("Run 'atlas --help' to see available commands.");process.exit(1)}
