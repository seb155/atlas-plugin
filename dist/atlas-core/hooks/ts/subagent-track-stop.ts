#!/usr/bin/env bun
/**
 * SubagentStop Hook — Subagent Track Stop (Phase 4 cleanup)
 *
 * SP-AGENT-VIS Layer 3: marks the agent as completed/failed in the runtime
 * registry and cleans up any tmux pane that was auto-spawned for it.
 *
 * Fires in parallel to existing `subagent-result-capture.ts` (which handles
 * research result correlation). This hook is ADDITIVE and focuses solely on
 * visibility state + pane cleanup.
 *
 * @event SubagentStop
 * @performance target <100ms (async, non-blocking)
 * @plan .blueprint/plans/keen-nibbling-umbrella.md Layer 3 cleanup
 */

import { execSync } from "node:child_process";

import { getByAgentId, markCompleted } from "./lib/agent-registry";

interface SubagentStopInput {
	session_id?: string;
	agent_id?: string;
	success?: boolean;
	duration_ms?: number;
	error?: string;
}

interface HookOutput {
	continue: boolean;
}

async function main(): Promise<void> {
	let raw = "";
	for await (const chunk of Bun.stdin.stream()) {
		raw += new TextDecoder().decode(chunk);
	}
	if (!raw.trim()) {
		console.log(JSON.stringify({ continue: true }));
		return;
	}

	let input: SubagentStopInput;
	try {
		input = JSON.parse(raw) as SubagentStopInput;
	} catch {
		console.log(JSON.stringify({ continue: true }));
		return;
	}

	const agentId = input.agent_id;
	if (!agentId) {
		console.log(JSON.stringify({ continue: true }));
		return;
	}

	// Read entry BEFORE marking complete (to get tmux_pane id)
	const entry = getByAgentId(agentId);

	// Mark completed (success defaults to true unless explicitly false)
	const success = input.success !== false;
	await markCompleted(agentId, {
		success,
		durationMs: input.duration_ms,
	});

	// Kill auto-spawned tmux pane (if any)
	if (entry?.tmux_pane) {
		try {
			execSync(`tmux kill-pane -t ${entry.tmux_pane} 2>/dev/null`, {
				timeout: 1000,
				stdio: "ignore",
			});
		} catch {
			// Pane already closed or tmux unreachable — ignore
		}
	}

	// WT tabs: user closes manually (no programmatic close API from parent)

	const output: HookOutput = { continue: true };
	console.log(JSON.stringify(output));
}

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
		console.error(`[subagent-track-stop] ${err instanceof Error ? err.message : String(err)}`);
		console.log(JSON.stringify({ continue: true }));
		process.exit(0);
	});
