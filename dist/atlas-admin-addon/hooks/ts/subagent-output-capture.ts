#!/usr/bin/env bun
/**
 * PostToolUse:Agent Hook — Subagent Output Capture
 *
 * SP-AGENT-VIS Layer 1: captures the `output_file` symlink path returned by
 * `Agent({run_in_background: true})` so downstream layers (statusline, CLI, tmux
 * auto-tail) can surface subagent visibility.
 *
 * When an Agent tool call resolves, this hook:
 * 1. Parses the tool result for `agent_id` and `output_file`
 * 2. Writes an entry to `~/.atlas/runtime/agents.json` via lib/agent-registry
 * 3. (Phase 4) will trigger tmux/WT auto-tail spawn if capable env detected
 *
 * Fail-open: on any error, emit `{continue: true}` so CC never blocks.
 * Non-background agents (no `output_file`) are silently ignored.
 *
 * @event PostToolUse
 * @matcher Agent
 * @performance target <100ms (async, non-blocking)
 * @plan .blueprint/plans/keen-nibbling-umbrella.md Layer 1
 */

import { execSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";

import { registerSpawn, updateVisibility } from "./lib/agent-registry";

// ─── Types ─────────────────────────────────────────────────────────

/**
 * PostToolUse hook stdin payload. CC schema is permissive; we defensively
 * probe multiple possible shapes and fall back to no-op on mismatch.
 */
interface PostToolUseInput {
	session_id?: string;
	hook_event_name?: string;
	tool_name?: string;
	tool_input?: Record<string, unknown>;
	tool_response?: Record<string, unknown>;
	// Alternate schema some CC versions use:
	toolUseResult?: Record<string, unknown>;
}

interface HookOutput {
	continue: boolean;
}

// ─── Extraction helpers ────────────────────────────────────────────

/**
 * Extract agent_id from multiple possible tool result shapes.
 * Claude Code Agent tool typically returns fields like:
 *   { agent_id, output_file, task_id, ... }
 * We probe both `tool_response` and `toolUseResult` keys.
 */
function extractAgentId(input: PostToolUseInput): string | null {
	const candidates: Array<Record<string, unknown> | undefined> = [
		input.tool_response,
		input.toolUseResult,
	];
	for (const c of candidates) {
		if (!c) continue;
		const id = (c.agent_id ?? c.agentId ?? c.task_id ?? c.taskId) as string | undefined;
		if (typeof id === "string" && id.length > 0) return id;
	}
	return null;
}

/**
 * Extract output_file symlink path from tool result.
 * Pattern: `/tmp/claude-${UID}/.../tasks/{agent_id}.output`
 */
function extractOutputFile(input: PostToolUseInput): string | null {
	const candidates: Array<Record<string, unknown> | undefined> = [
		input.tool_response,
		input.toolUseResult,
	];
	for (const c of candidates) {
		if (!c) continue;
		const path = (c.output_file ?? c.outputFile) as string | undefined;
		if (typeof path === "string" && path.length > 0) return path;
	}
	return null;
}

/**
 * Extract subagent_type from tool_input for early type tagging.
 * (Final agent_type arrives on SubagentStart; this is a best-effort placeholder.)
 */
function extractAgentType(input: PostToolUseInput): string {
	const t = input.tool_input?.subagent_type;
	if (typeof t === "string" && t.length > 0) return t;
	return "unknown";
}

// ─── Main ──────────────────────────────────────────────────────────

async function main(): Promise<void> {
	// Read stdin
	let raw = "";
	for await (const chunk of Bun.stdin.stream()) {
		raw += new TextDecoder().decode(chunk);
	}
	if (!raw.trim()) {
		// No input — skip silently
		console.log(JSON.stringify({ continue: true }));
		return;
	}

	let input: PostToolUseInput;
	try {
		input = JSON.parse(raw) as PostToolUseInput;
	} catch {
		console.log(JSON.stringify({ continue: true }));
		return;
	}

	// Only handle Agent tool (defensive: hook matcher is already "Agent",
	// but double-check in case of schema drift)
	const toolName = input.tool_name ?? "";
	if (toolName !== "Agent") {
		console.log(JSON.stringify({ continue: true }));
		return;
	}

	const agentId = extractAgentId(input);
	const outputFile = extractOutputFile(input);
	const sessionId = input.session_id ?? "";
	const agentType = extractAgentType(input);

	// No agent_id → foreground agent or schema mismatch; nothing to track
	if (!agentId) {
		console.log(JSON.stringify({ continue: true }));
		return;
	}

	// Register in runtime state — outputFile may be null for foreground agents
	// (SubagentStart will upgrade status when it fires)
	await registerSpawn(agentId, outputFile, agentType, sessionId);

	// ─── Layer 3: Cross-platform auto-tail (always-on default, opt-out via env) ──
	// Only spawn visibility surface if we have an output_file (background agent)
	if (outputFile) {
		await spawnVisibility(agentId);
	}

	const output: HookOutput = { continue: true };
	console.log(JSON.stringify(output));
}

// ─── Layer 3 helpers ───────────────────────────────────────────────

function getScriptsDir(): string {
	// hooks/ts/subagent-output-capture.ts → ../scripts
	const self = import.meta.url.replace(/^file:\/\//, "");
	return resolve(dirname(self), "..", "..", "scripts");
}

function detectEnv(): "tmux" | "wt" | "fallback" | "none" {
	try {
		const scriptsDir = getScriptsDir();
		const out = execSync(`bash "${scriptsDir}/lib/detect-visibility-env.sh"`, {
			encoding: "utf-8",
			timeout: 1500,
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
		if (out === "tmux" || out === "wt" || out === "fallback" || out === "none") return out;
	} catch {
		// fall through
	}
	return "fallback";
}

function getTmuxPaneCount(): number {
	try {
		const out = execSync("tmux list-panes 2>/dev/null | wc -l", {
			encoding: "utf-8",
			timeout: 1000,
			stdio: ["ignore", "pipe", "ignore"],
		}).trim();
		return parseInt(out, 10) || 0;
	} catch {
		return 0;
	}
}

async function spawnVisibility(agentId: string): Promise<void> {
	const env = detectEnv();
	const scriptsDir = getScriptsDir();

	if (env === "none") return; // user opt-out

	if (env === "tmux") {
		const maxPanes = parseInt(process.env.ATLAS_MAX_TAIL_PANES || "2", 10);
		const currentPanes = getTmuxPaneCount();
		// Cap auto-spawn: allow up to maxPanes tails (in addition to main pane)
		if (currentPanes > maxPanes) return;
		try {
			const tailScript = join(scriptsDir, "atlas-agent-tail.sh");
			const paneId = execSync(
				`tmux split-window -h -p 35 -d -P -F '#{pane_id}' "${tailScript} ${agentId}" 2>/dev/null`,
				{ encoding: "utf-8", timeout: 1500, stdio: ["ignore", "pipe", "ignore"] },
			).trim();
			if (paneId) {
				// Keep pane visible after agent completes so user can review output
				try {
					execSync(`tmux set-option -p -t ${paneId} remain-on-exit on 2>/dev/null`, {
						timeout: 500,
						stdio: "ignore",
					});
				} catch {
					// Non-critical — visibility still registered, pane will just auto-close
				}
				await updateVisibility(agentId, { tmux_pane: paneId, visibility_mode: "tmux" });
			}
		} catch {
			// Tmux command failed (maybe pane limit) — fallback silently
		}
		return;
	}

	if (env === "wt") {
		try {
			const tailScript = join(scriptsDir, "atlas-agent-tail.sh");
			// Use wt.exe new-tab; Windows Terminal doesn't return tab id from CLI
			execSync(
				`wt.exe new-tab --title "agent:${agentId}" bash -c "${tailScript} ${agentId}"`,
				{ timeout: 1500, stdio: "ignore" },
			);
			await updateVisibility(agentId, { visibility_mode: "wt" });
		} catch {
			// wt.exe failed — fall through to hint
		}
		return;
	}

	if (env === "fallback") {
		try {
			execSync(`bash "${scriptsDir}/lib/show-hint.sh"`, {
				timeout: 500,
				stdio: "ignore",
			});
		} catch {
			// hint failed — silent
		}
		await updateVisibility(agentId, { visibility_mode: "none" });
	}
}

// Fail-open error handlers — visibility is best-effort, must not block CC.
process.on("uncaughtException", () => {
	console.log(JSON.stringify({ continue: true }));
	process.exit(0);
});
process.on("unhandledRejection", () => {
	console.log(JSON.stringify({ continue: true }));
	process.exit(0);
});

main()
	.then(() => process.exit(0))
	.catch((err) => {
		console.error(`[subagent-output-capture] ${err instanceof Error ? err.message : String(err)}`);
		console.log(JSON.stringify({ continue: true }));
		process.exit(0);
	});
