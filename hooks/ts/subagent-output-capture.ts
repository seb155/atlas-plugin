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

import { registerSpawn } from "./lib/agent-registry";

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

	// Phase 4 will add: tmux/WT auto-tail spawn here (conditional on env).
	// For Phase 1, we stop at telemetry capture.

	const output: HookOutput = { continue: true };
	console.log(JSON.stringify(output));
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
