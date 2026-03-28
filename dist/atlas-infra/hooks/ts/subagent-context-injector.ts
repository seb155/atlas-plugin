#!/usr/bin/env bun
/**
 * SubagentStart Hook: Context Injector
 *
 * PLAN-1111 Phase 1: Inject ATLAS context into subagents
 *
 * Injects:
 * - Active EPIC/PLAN context
 * - Relevant MATRIX entities for the query
 * - User preferences from routing rules
 *
 * @event SubagentStart
 * @performance target <50ms (non-blocking)
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "path";

interface SubagentStartInput {
	session_id: string;
	agent_id: string;
	agent_type: string;
	prompt?: string;
}

interface HookOutput {
	continue: boolean;
	additionalContext?: string;
}

const ATLAS_ROOT = process.cwd();
const ACTIVE_AGENTS_PATH = join(ATLAS_ROOT, ".atlas/data/subagent-active.json");

/**
 * Record agent start for SubagentStop correlation.
 * Stores agent_id → {agent_type, start_timestamp} mapping.
 */
function recordAgentStart(agentId: string, agentType: string): void {
	try {
		const dir = dirname(ACTIVE_AGENTS_PATH);
		if (!existsSync(dir)) mkdirSync(dir, { recursive: true });

		let store: Record<string, { agent_type: string; started_at: string }> = {};
		if (existsSync(ACTIVE_AGENTS_PATH)) {
			try {
				store = JSON.parse(readFileSync(ACTIVE_AGENTS_PATH, "utf-8"));
			} catch {
				store = {};
			}
		}

		store[agentId] = {
			agent_type: agentType,
			started_at: new Date().toISOString(),
		};

		// Prune entries older than 1 hour (stale agents)
		const oneHourAgo = Date.now() - 3600_000;
		for (const [id, entry] of Object.entries(store)) {
			if (new Date(entry.started_at).getTime() < oneHourAgo) {
				delete store[id];
			}
		}

		writeFileSync(ACTIVE_AGENTS_PATH, JSON.stringify(store, null, 2));
	} catch {
		// Silent fail — metrics are non-critical
	}
}

/**
 * Get active EPIC and PLAN from ecosystem status
 */
function getActiveContext(): { epic?: string; plan?: string; project?: string } {
	try {
		const statusPath = join(ATLAS_ROOT, ".atlas/kernel/ecosystem-status.json");
		if (!existsSync(statusPath)) return {};

		const status = JSON.parse(readFileSync(statusPath, "utf-8"));
		return {
			epic: status.activeChain?.epic,
			plan: status.activeChain?.plan,
			project: status.activeChain?.project,
		};
	} catch {
		return {};
	}
}

interface CheckpointSummary {
	planId: string | null;
	planFile: string | null;
	progress: string;
	hierarchy: string;
	modifiedFiles: string[];
}

/**
 * Get latest checkpoint for plan/progress context
 */
function getLatestCheckpoint(): CheckpointSummary | null {
	try {
		const checkpointsDir = join(ATLAS_ROOT, ".atlas/data/session-checkpoints");
		if (!existsSync(checkpointsDir)) return null;

		const { readdirSync, statSync: fstatSync } = require("node:fs");
		const files = readdirSync(checkpointsDir)
			.filter((f: string) => f.endsWith(".json"))
			.map((f: string) => ({
				path: join(checkpointsDir, f),
				mtime: fstatSync(join(checkpointsDir, f)).mtime.getTime(),
			}))
			.sort((a: { mtime: number }, b: { mtime: number }) => b.mtime - a.mtime);

		if (files.length === 0) return null;

		// Only use if < 4 hours old
		if (Date.now() - files[0].mtime > 4 * 60 * 60 * 1000) return null;

		const cp = JSON.parse(readFileSync(files[0].path, "utf-8"));
		const planFile = (cp.activePlanFile || "").replace(ATLAS_ROOT + "/", "");
		return {
			planId: cp.activePlan || null,
			planFile: planFile || null,
			progress:
				cp.progress && cp.progress.total > 0 ? `${cp.progress.completed}/${cp.progress.total}` : "",
			hierarchy: cp.links?.hierarchy || "",
			modifiedFiles: (cp.modifiedFiles || []).slice(0, 5),
		};
	} catch {
		return null;
	}
}

/**
 * Get relevant INS for the agent type
 */
function getRelevantInsights(agentType: string): string[] {
	const insightsByAgent: Record<string, string[]> = {
		"gemini-researcher": ["INS-509", "INS-268"], // Audit methodology, hooks best practices
		"claude-researcher": ["INS-509", "INS-268"],
		"perplexity-researcher": ["INS-509"],
		architect: ["INS-487", "INS-469"], // AI Software Factory, Vercel patterns
		engineer: ["INS-487", "INS-366"], // AI Software Factory, Docker patterns
		designer: ["INS-462"], // Visual validation
		pentester: [],
		delphi: [], // DELPHI has its own context
	};

	return insightsByAgent[agentType] || [];
}

/**
 * Get routing preferences for the agent
 */
function getRoutingPreferences(agentType: string): string | null {
	try {
		const prefsPath = join(ATLAS_ROOT, ".atlas/data/routing-preferences.json");
		if (!existsSync(prefsPath)) return null;

		const prefs = JSON.parse(readFileSync(prefsPath, "utf-8"));
		const agentPrefs = prefs.agents?.[agentType];

		if (agentPrefs) {
			return `Routing: ${agentPrefs.preferredFor?.join(", ") || "general"}`;
		}
		return null;
	} catch {
		return null;
	}
}

/**
 * Build context injection for the subagent
 */
function buildContextInjection(input: SubagentStartInput): string {
	const lines: string[] = [];
	const activeContext = getActiveContext();
	const checkpoint = getLatestCheckpoint();

	// Header
	lines.push("## ATLAS Context (auto-injected)");
	lines.push("");

	// Active plan from checkpoint (more reliable than ecosystem-status)
	if (checkpoint?.planId) {
		lines.push("### Current Session");
		lines.push(
			`- **Plan**: ${checkpoint.planId}${checkpoint.progress ? ` (${checkpoint.progress} done)` : ""}`,
		);
		if (checkpoint.planFile) lines.push(`- **Plan file**: \`${checkpoint.planFile}\``);
		if (checkpoint.hierarchy) lines.push(`- **Hierarchy**: ${checkpoint.hierarchy}`);
		if (checkpoint.modifiedFiles.length > 0) {
			lines.push(`- **Recent files**: ${checkpoint.modifiedFiles.slice(0, 3).join(", ")}`);
		}
		lines.push("");
	} else if (activeContext.epic || activeContext.plan) {
		// Fallback to ecosystem status
		lines.push("### Active Work Context");
		if (activeContext.project) lines.push(`- **Project**: ${activeContext.project}`);
		if (activeContext.epic) lines.push(`- **EPIC**: ${activeContext.epic}`);
		if (activeContext.plan) lines.push(`- **PLAN**: ${activeContext.plan}`);
		lines.push("");
	}

	// Agent-specific insights
	const insights = getRelevantInsights(input.agent_type);
	if (insights.length > 0) {
		lines.push("### Relevant Methodology");
		lines.push(`Reference these insights if applicable: ${insights.join(", ")}`);
		lines.push("");
	}

	// Routing preferences
	const routing = getRoutingPreferences(input.agent_type);
	if (routing) {
		lines.push(`### ${routing}`);
		lines.push("");
	}

	// ATLAS-specific instructions
	lines.push("### ATLAS Integration");
	lines.push("- Results may be captured to Knowledge Library");
	lines.push("- Valuable insights may become INS entities");
	lines.push("- Reference MATRIX entities when relevant (INS-XXX, PLAN-XXX)");
	if (checkpoint?.planFile) {
		lines.push(`- When completing plan items, update checkboxes in \`${checkpoint.planFile}\``);
	}

	return lines.join("\n");
}

async function main() {
	// Read input from stdin
	let inputData = "";
	for await (const chunk of Bun.stdin.stream()) {
		inputData += new TextDecoder().decode(chunk);
	}

	const input: SubagentStartInput = JSON.parse(inputData);

	// Always record start for SubagentStop correlation (even for skipped agents)
	recordAgentStart(input.agent_id, input.agent_type);

	// Skip injection for certain agent types
	const skipAgents = ["statusline-setup", "Bash"];
	if (skipAgents.includes(input.agent_type)) {
		const output: HookOutput = { continue: true };
		console.log(JSON.stringify(output));
		return;
	}

	// Build and output context injection
	const contextInjection = buildContextInjection(input);

	const output: HookOutput = {
		continue: true,
		additionalContext: contextInjection,
	};

	console.log(JSON.stringify(output));
}

process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
main()
	.then(() => process.exit(0))
	.catch((err) => {
		// Fail-open: allow subagent to start without injection
		console.error(`[SubagentContextInjector] Error: ${err.message}`);
		console.log(JSON.stringify({ continue: true }));
		process.exit(0);
	});
