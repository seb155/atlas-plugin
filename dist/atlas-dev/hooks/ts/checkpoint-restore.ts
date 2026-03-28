#!/usr/bin/env bun
/**
 * checkpoint-restore.ts - Session Checkpoint Hint Table
 *
 * SessionStart hook that shows available checkpoints on session start.
 * User can then use /a-pickup for interactive restore.
 *
 * Note: SessionStart does NOT fire after internal compaction —
 * breadcrumb injection is handled by PreCompact saving to disk only.
 *
 * @event SessionStart
 * @since 2026-02-07
 * @performance target <50ms
 */

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

// =============================================================================
// Types
// =============================================================================

interface SessionCheckpoint {
	title: string;
	timestamp: string;
	source?: string;
	activePlan: string | null;
	activePlanFile?: string | null;
	modifiedFiles?: string[];
	keyActions?: string[];
	resumeInstructions?: string;
	links?: {
		plan: string | null;
		checkpoint: string;
		hierarchy: string;
	};
	progress?: {
		completed: number;
		total: number;
	};
	contextTokens?: number;
}

// =============================================================================
// Constants
// =============================================================================

const ATLAS_ROOT = process.env.ATLAS_ROOT || process.cwd();
const CHECKPOINTS_DIR = join(ATLAS_ROOT, ".atlas/data/session-checkpoints");
const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

// =============================================================================
// Helpers
// =============================================================================

function timeAgo(timestamp: string): string {
	const ms = Date.now() - new Date(timestamp).getTime();
	const minutes = Math.floor(ms / 60000);
	const hours = Math.floor(minutes / 60);
	const days = Math.floor(hours / 24);

	if (days > 0) return `${days}d`;
	if (hours > 0) return `${hours}h`;
	if (minutes > 0) return `${minutes}m`;
	return "now";
}

/**
 * Parse timestamp from checkpoint filename (e.g. "2026-02-19_2144-name.json" → epoch ms)
 * Falls back to 0 if format doesn't match.
 */
function parseFilenameTimestamp(filename: string): number {
	const match = filename.match(/^(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})/);
	if (!match) return 0;
	const [, year, month, day, hour, min] = match;
	return new Date(`${year}-${month}-${day}T${hour}:${min}:00`).getTime();
}

/**
 * Load sorted checkpoint files (newest first), filtered by max age
 * PERF: Uses filename timestamp instead of statSync per file
 */
function loadCheckpointFiles(): Array<{ path: string; mtime: number }> {
	if (!existsSync(CHECKPOINTS_DIR)) return [];

	const now = Date.now();
	return readdirSync(CHECKPOINTS_DIR)
		.filter((f) => f.endsWith(".json"))
		.map((f) => ({
			path: join(CHECKPOINTS_DIR, f),
			mtime: parseFilenameTimestamp(f),
		}))
		.filter((f) => f.mtime > 0 && now - f.mtime < MAX_AGE_MS)
		.sort((a, b) => b.mtime - a.mtime);
}

// =============================================================================
// Output Generators
// =============================================================================

/**
 * Hint table of recent checkpoints for session start
 */
function generateHintTable(files: Array<{ path: string; mtime: number }>): string {
	const top = files.slice(0, 3).map((f) => {
		const cp: SessionCheckpoint = JSON.parse(readFileSync(f.path, "utf-8"));
		return cp;
	});

	const lines: string[] = [];
	lines.push(`## 💾 ${files.length} Checkpoint(s) available`);
	lines.push("");
	lines.push("| # | Age | Session |");
	lines.push("|---|-----|---------|");
	for (let i = 0; i < top.length; i++) {
		const cp = top[i];
		const age = timeAgo(cp.timestamp);
		const title = cp.title.length > 60 ? cp.title.slice(0, 57) + "..." : cp.title;
		lines.push(`| ${i + 1} | ${age} | ${title} |`);
	}
	if (files.length > 3) {
		lines.push(`| ... | | +${files.length - 3} more |`);
	}
	lines.push("");
	lines.push("→ `/a-pickup` to restore a session with full context");

	return lines.join("\n");
}

// =============================================================================
// Main
// =============================================================================

async function main() {
	// Skip subagents
	if (process.env.CLAUDE_AGENT_ID || process.env.CLAUDE_AGENT_TYPE) {
		process.exit(0);
	}

	try {
		const files = loadCheckpointFiles();
		if (files.length === 0) process.exit(0);

		// Log checkpoint availability to stderr only (no context injection)
		// User can use /a-pickup to see full checkpoint details
		console.error(
			`[checkpoint-restore] ${files.length} checkpoint(s) available. Use /a-pickup to restore.`,
		);
	} catch {
		// Silent fail — never block session start
	}
}

process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));

main().catch(() => process.exit(0));
