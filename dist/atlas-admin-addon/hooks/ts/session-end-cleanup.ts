#!/usr/bin/env bun
/**
 * session-end-cleanup.ts - Session Cleanup Hook
 *
 * Performs cleanup tasks when a Claude Code session ends.
 * Part of PLAN-1054 Phase 4: Feature Adoption.
 *
 * Event: SessionEnd
 * Priority: Low (runs after other hooks)
 *
 * Tasks:
 * 1. Clean up temporary files (/tmp/atlas-*)
 * 2. Save session summary to activity log
 * 3. Release any session locks
 * 4. Compact debounce state files
 *
 * @author ATLAS
 * @since 2026-01-18
 * @plan PLAN-1054
 */

import { existsSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { cleanupStaleWorktrees } from "./lib/git-worktree";

// =============================================================================
// Types
// =============================================================================

interface SessionEndInput {
	session_id: string;
	transcript_path?: string;
	cwd?: string;
}

interface SessionSummary {
	sessionId: string;
	endTime: string;
	duration?: number;
	filesCleanedUp: number;
	debounceCompacted: boolean;
	worktreesCleanedUp: number;
}

// =============================================================================
// Constants
// =============================================================================

const ATLAS_ROOT = process.env.ATLAS_ROOT || process.cwd();
const TEMP_PREFIX = "atlas-";
const MAX_TEMP_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

// Debounce state files to compact
const DEBOUNCE_FILES = [
	".atlas/data/bash-guard-debounce.json",
	".atlas/data/post-bash-debounce.json",
	".atlas/data/post-edit-debounce.json",
	".atlas/data/user-prompt-dispatcher-state.json",
];

// =============================================================================
// Cleanup Functions
// =============================================================================

/**
 * Clean up old temporary files from /tmp
 */
function cleanupTempFiles(sessionId: string): number {
	let cleaned = 0;

	try {
		const tmpDir = "/tmp";
		const files = readdirSync(tmpDir);
		const now = Date.now();

		for (const file of files) {
			if (!file.startsWith(TEMP_PREFIX)) continue;

			const filePath = join(tmpDir, file);
			try {
				const stats = statSync(filePath);
				const age = now - stats.mtimeMs;

				// Clean files older than MAX_TEMP_AGE_MS or matching current session
				if (age > MAX_TEMP_AGE_MS || file.includes(sessionId)) {
					rmSync(filePath, { recursive: true, force: true });
					cleaned++;
				}
			} catch {
				// Ignore individual file errors
			}
		}
	} catch {
		// Ignore temp directory access errors
	}

	return cleaned;
}

/**
 * Compact debounce state files (remove old entries)
 */
function compactDebounceFiles(): boolean {
	let compacted = false;
	const maxAge = 24 * 60 * 60 * 1000; // 24 hours
	const now = Date.now();

	for (const relativePath of DEBOUNCE_FILES) {
		const filePath = join(ATLAS_ROOT, relativePath);

		try {
			if (!existsSync(filePath)) continue;

			const content = readFileSync(filePath, "utf-8");
			const state = JSON.parse(content);

			// Filter out old entries
			let changed = false;
			for (const [key, value] of Object.entries(state)) {
				if (typeof value === "number" && now - value > maxAge) {
					delete state[key];
					changed = true;
				} else if (typeof value === "object" && value !== null) {
					// Handle nested objects (like perFile debounce)
					for (const [subKey, subValue] of Object.entries(value as Record<string, number>)) {
						if (typeof subValue === "number" && now - subValue > maxAge) {
							delete (state[key] as Record<string, number>)[subKey];
							changed = true;
						}
					}
				}
			}

			if (changed) {
				writeFileSync(filePath, JSON.stringify(state, null, 2));
				compacted = true;
			}
		} catch {
			// Ignore individual file errors
		}
	}

	return compacted;
}

/**
 * Release session lock if exists
 */
function releaseSessionLock(sessionId: string): void {
	const lockFile = join(ATLAS_ROOT, ".atlas/data/session.lock");

	try {
		if (existsSync(lockFile)) {
			const content = readFileSync(lockFile, "utf-8");
			const lock = JSON.parse(content);

			// Only release if it's our session
			if (lock.sessionId === sessionId) {
				rmSync(lockFile, { force: true });
			}
		}
	} catch {
		// Ignore lock release errors
	}
}

/**
 * Log session summary to activity log
 */
function logSessionSummary(summary: SessionSummary): void {
	const logFile = join(ATLAS_ROOT, ".atlas/data/session-activity.jsonl");

	try {
		const entry = JSON.stringify({
			type: "session_end",
			...summary,
			timestamp: new Date().toISOString(),
		});

		writeFileSync(logFile, `${entry}\n`, { flag: "a" });
	} catch {
		// Ignore logging errors
	}
}

// =============================================================================
// Main Entry Point
// =============================================================================

async function main() {
	const startTime = Date.now();

	// Read input from stdin
	let input: SessionEndInput;
	try {
		const reader = Bun.stdin.stream().getReader();
		const decoder = new TextDecoder();
		let data = "";

		while (true) {
			const { done, value } = await reader.read();
			if (done) break;
			data += decoder.decode(value, { stream: true });
		}

		input = JSON.parse(data || "{}");
	} catch {
		// No input, use defaults
		input = { session_id: "unknown" };
	}

	const sessionId = input.session_id || "unknown";

	// Run cleanup tasks
	const filesCleanedUp = cleanupTempFiles(sessionId);
	const debounceCompacted = compactDebounceFiles();
	const worktreesCleanedUp = await cleanupStaleWorktrees(24);
	releaseSessionLock(sessionId);

	// Clean up subagent correlation store (ephemeral, session-scoped)
	const activeAgentsPath = join(ATLAS_ROOT, ".atlas/data/subagent-active.json");
	try {
		if (existsSync(activeAgentsPath)) rmSync(activeAgentsPath, { force: true });
	} catch {
		// Ignore
	}

	// Log summary
	const summary: SessionSummary = {
		sessionId,
		endTime: new Date().toISOString(),
		duration: Date.now() - startTime,
		filesCleanedUp,
		debounceCompacted,
		worktreesCleanedUp,
	};

	logSessionSummary(summary);

	// Debug output
	if (process.env.DEBUG_HOOKS) {
		console.error(
			`[session-end-cleanup] Session ${sessionId}: cleaned ${filesCleanedUp} temp files, ` +
				`${worktreesCleanedUp} worktrees, debounce ${debounceCompacted ? "compacted" : "unchanged"} (${summary.duration}ms)`,
		);
	}
}

// Suppress unhandled errors - cleanup should never break anything
process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));

main().catch(() => process.exit(0));
