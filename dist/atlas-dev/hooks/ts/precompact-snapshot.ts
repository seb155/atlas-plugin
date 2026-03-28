#!/usr/bin/env bun
/**
 * precompact-snapshot.ts - PreCompact Checkpoint (File-Only)
 *
 * Saves a checkpoint BEFORE context compaction so /a-pickup can find it.
 * Checkpoint-only: NO system_message injection to avoid compaction loops.
 *
 * What it does:
 * 1. Creates a checkpoint in session-checkpoints/
 * 2. Adds navigation links (plan → checkpoint → hierarchy)
 * 3. Logs compaction event to history file
 * 4. Outputs { result: "continue" } — no context inflation
 *
 * @event PreCompact
 * @since 2026-02-07
 * @performance target <200ms
 */

import {
	appendFileSync,
	existsSync,
	mkdirSync,
	readFileSync,
	readdirSync,
	statSync,
	unlinkSync,
	writeFileSync,
} from "node:fs";
import { join } from "node:path";

// =============================================================================
// Types
// =============================================================================

interface PreCompactInput {
	session_id?: string;
	transcript_path?: string;
	context_tokens?: number;
	// CC may use different field names — capture all for debugging
	[key: string]: unknown;
}

interface CompactionCheckpoint {
	sessionId: string;
	timestamp: string;
	source: "compaction";
	contextTokens: number;
	title: string;
	activePlan: string | null;
	activePlanFile: string | null;
	modifiedFiles: string[];
	keyActions: string[];
	resumeInstructions: string;
	links: {
		plan: string | null;
		checkpoint: string;
		hierarchy: string;
	};
	progress: {
		completed: number;
		total: number;
	};
}

// =============================================================================
// Constants
// =============================================================================

const ATLAS_ROOT = process.env.ATLAS_ROOT || process.cwd();
const CHECKPOINTS_DIR = join(ATLAS_ROOT, ".atlas/data/session-checkpoints");
const ACTIVE_PLANS_DIR = join(ATLAS_ROOT, ".atlas/execution/active-plans");
const COMPACTION_HISTORY_PATH = join(ATLAS_ROOT, ".atlas/data/compaction-history.jsonl");

/** Max lines to keep in compaction-history.jsonl (Rule #12: auto-rotation) */
const MAX_HISTORY_LINES = 200;
/** Max age for checkpoint files before cleanup */
const MAX_CHECKPOINT_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

// =============================================================================
// Helpers
// =============================================================================

/**
 * Find the most recently modified active plan
 */
function findActivePlan(): { planId: string; planFile: string } | null {
	try {
		if (!existsSync(ACTIVE_PLANS_DIR)) return null;

		const files = readdirSync(ACTIVE_PLANS_DIR)
			.filter((f) => f.endsWith(".md") && !f.includes("-agent-"))
			.map((f) => ({
				name: f.replace(".md", ""),
				path: join(ACTIVE_PLANS_DIR, f),
				mtime: statSync(join(ACTIVE_PLANS_DIR, f)).mtime.getTime(),
			}))
			.sort((a, b) => b.mtime - a.mtime);

		if (files.length === 0) return null;
		return { planId: files[0].name, planFile: files[0].path };
	} catch {
		return null;
	}
}

/**
 * Get modified files via git diff
 */
async function getModifiedFiles(): Promise<string[]> {
	try {
		const proc = Bun.spawn(["git", "diff", "--name-only", "HEAD"], {
			cwd: ATLAS_ROOT,
			stdout: "pipe",
			stderr: "pipe",
		});
		const output = await new Response(proc.stdout).text();
		return output.trim().split("\n").filter(Boolean).slice(0, 15);
	} catch {
		return [];
	}
}

/**
 * Extract progress from plan file (count checked/unchecked items)
 */
function extractPlanProgress(planFile: string): { completed: number; total: number } {
	try {
		const content = readFileSync(planFile, "utf-8");
		const checked = (content.match(/- \[x\]/gi) || []).length;
		const unchecked = (content.match(/- \[ \]/g) || []).length;
		return { completed: checked, total: checked + unchecked };
	} catch {
		return { completed: 0, total: 0 };
	}
}

/**
 * Read recent key actions from the latest checkpoint (if any)
 */
function getRecentActions(): string[] {
	try {
		if (!existsSync(CHECKPOINTS_DIR)) return [];

		const files = readdirSync(CHECKPOINTS_DIR)
			.filter((f) => f.endsWith(".json"))
			.map((f) => ({
				path: join(CHECKPOINTS_DIR, f),
				mtime: statSync(join(CHECKPOINTS_DIR, f)).mtime.getTime(),
			}))
			.sort((a, b) => b.mtime - a.mtime);

		if (files.length === 0) return [];

		const latest = JSON.parse(readFileSync(files[0].path, "utf-8"));
		return latest.keyActions || [];
	} catch {
		return [];
	}
}

/**
 * Build hierarchy string from plan file content
 */
function buildHierarchy(planFile: string | null): string {
	if (!planFile) return "PROG-001 → ATLAS";

	try {
		const content = readFileSync(planFile, "utf-8");
		// Look for EPIC, PROJ references
		const epicMatch = content.match(/EPIC-(\d+)/);
		const projMatch = content.match(/PROJ-(\d+)/);
		const planMatch = content.match(/PLAN-(\d+)/);

		const parts = ["PROG-001"];
		if (projMatch) parts.push(`PROJ-${projMatch[1]}`);
		if (epicMatch) parts.push(`EPIC-${epicMatch[1]}`);
		if (planMatch) parts.push(`PLAN-${planMatch[1]}`);

		return parts.join(" → ");
	} catch {
		return "PROG-001 → ATLAS";
	}
}

/**
 * Log compaction event to history
 */
function logCompaction(sessionId: string, contextTokens: number, planId: string | null): void {
	try {
		const entry = {
			timestamp: new Date().toISOString(),
			sessionId,
			event: "pre_compact",
			contextTokens,
			activePlan: planId,
		};
		appendFileSync(COMPACTION_HISTORY_PATH, JSON.stringify(entry) + "\n");
	} catch {
		// Silent
	}
}

/**
 * Rotate compaction-history.jsonl to keep only recent entries (Rule #12)
 */
function rotateHistoryIfNeeded(): void {
	try {
		if (!existsSync(COMPACTION_HISTORY_PATH)) return;

		const content = readFileSync(COMPACTION_HISTORY_PATH, "utf-8");
		const lines = content.trim().split("\n").filter(Boolean);

		if (lines.length <= MAX_HISTORY_LINES) return;

		// Keep only the most recent entries
		const trimmed = lines.slice(-MAX_HISTORY_LINES).join("\n") + "\n";
		writeFileSync(COMPACTION_HISTORY_PATH, trimmed);
		console.error(`[precompact] Rotated history: ${lines.length} → ${MAX_HISTORY_LINES} lines`);
	} catch {
		// Silent — never block compaction for log rotation
	}
}

/**
 * Clean up checkpoint files older than MAX_CHECKPOINT_AGE_MS
 */
function cleanupOldCheckpoints(): void {
	try {
		if (!existsSync(CHECKPOINTS_DIR)) return;

		const now = Date.now();
		const files = readdirSync(CHECKPOINTS_DIR).filter((f) => f.endsWith(".json"));
		let deleted = 0;

		for (const file of files) {
			const filePath = join(CHECKPOINTS_DIR, file);
			const mtime = statSync(filePath).mtime.getTime();
			if (now - mtime > MAX_CHECKPOINT_AGE_MS) {
				unlinkSync(filePath);
				deleted++;
			}
		}

		if (deleted > 0) {
			console.error(`[precompact] Cleaned ${deleted} old checkpoint(s)`);
		}
	} catch {
		// Silent
	}
}

// =============================================================================
// Main
// =============================================================================

async function main() {
	// Skip subagents
	if (process.env.CLAUDE_AGENT_ID || process.env.CLAUDE_AGENT_TYPE) {
		process.exit(0);
	}

	// Read input from stdin
	let input: PreCompactInput = {};
	try {
		const stdin = await Bun.stdin.text();
		if (stdin.trim()) {
			input = JSON.parse(stdin);
		}
	} catch {
		// No stdin or invalid JSON
	}

	const sessionId = input.session_id || `session-${Date.now()}`;
	const contextTokens = input.context_tokens || 0;

	// Debug: log ALL actual stdin fields to discover CC's real schema
	const allFields = Object.entries(input)
		.map(([k, v]) => `${k}=${typeof v === "object" ? JSON.stringify(v) : v}`)
		.join(", ");
	console.error(`[precompact] stdin: {${allFields || "empty"}}`);
	console.error(`[precompact] contextTokens resolved to: ${contextTokens}`);

	// Housekeeping: rotate logs and clean old checkpoints
	rotateHistoryIfNeeded();
	cleanupOldCheckpoints();

	// Gather state
	const plan = findActivePlan();
	const modifiedFiles = await getModifiedFiles();
	const recentActions = getRecentActions();
	const progress = plan ? extractPlanProgress(plan.planFile) : { completed: 0, total: 0 };
	const hierarchy = buildHierarchy(plan?.planFile || null);

	// Build title
	const titleParts: string[] = [];
	if (plan) titleParts.push(plan.planId);
	if (modifiedFiles.length > 0) titleParts.push(`${modifiedFiles.length} files`);
	if (progress.total > 0) titleParts.push(`${progress.completed}/${progress.total} done`);
	const title = titleParts.join(" — ") || "Session without plan";

	// Build checkpoint
	const date = new Date().toISOString().slice(0, 10);
	const time = new Date().toISOString().slice(11, 16).replace(":", "");
	const planSuffix = plan?.planId ? `-${plan.planId.slice(0, 30)}` : "";
	const filename = `${date}_${time}-compact${planSuffix}.json`;
	const checkpointPath = join(CHECKPOINTS_DIR, filename);

	const checkpoint: CompactionCheckpoint = {
		sessionId,
		timestamp: new Date().toISOString(),
		source: "compaction",
		contextTokens,
		title,
		activePlan: plan?.planId || null,
		activePlanFile: plan ? plan.planFile.replace(ATLAS_ROOT + "/", "") : null,
		modifiedFiles,
		keyActions: recentActions,
		resumeInstructions: plan
			? `Continue plan: ${plan.planId}. Read: ${plan.planFile.replace(ATLAS_ROOT + "/", "")}`
			: "No active plan. Check /a-pickup for recent sessions.",
		links: {
			plan: plan ? plan.planFile.replace(ATLAS_ROOT + "/", "") : null,
			checkpoint: checkpointPath.replace(ATLAS_ROOT + "/", ""),
			hierarchy,
		},
		progress,
	};

	// Save checkpoint
	if (!existsSync(CHECKPOINTS_DIR)) mkdirSync(CHECKPOINTS_DIR, { recursive: true });
	writeFileSync(checkpointPath, JSON.stringify(checkpoint, null, 2));

	// Log event (file-only, no context injection)
	logCompaction(sessionId, contextTokens, plan?.planId || null);

	// Output continue — NO system_message to avoid compaction loop
	console.log(JSON.stringify({ result: "continue" }));
	console.error(`[precompact] Saved: ${filename} — "${title}"`);
}

process.on("uncaughtException", () => {
	console.log(JSON.stringify({ result: "continue" }));
	process.exit(0);
});
process.on("unhandledRejection", () => {
	console.log(JSON.stringify({ result: "continue" }));
	process.exit(0);
});

main().catch(() => {
	console.log(JSON.stringify({ result: "continue" }));
	process.exit(0);
});
