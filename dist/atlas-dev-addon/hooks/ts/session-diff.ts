#!/usr/bin/env bun
/**
 * session-diff.ts - Git Change Detection Between Sessions
 *
 * Detects what changed in the repository since the last Claude session.
 * This enables AI awareness of file modifications made while "offline".
 *
 * Flow:
 * 1. Read last session state from .atlas/data/last-session-state.json
 * 2. Get current git state (HEAD, status, recent commits)
 * 3. Compare and generate change report
 * 4. Output as system-reminder for Claude's context
 *
 * @module session-diff
 * @since 2025-12-30
 * @parent PROG-001 ATLAS
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { ATLAS_DIR } from "./lib/atlas-config";

// =============================================================================
// TYPES
// =============================================================================

interface SessionState {
	sessionId: string;
	timestamp: string;
	gitHead: string;
	gitBranch: string;
	gitStatus: string[]; // Files with modifications
	focusFiles: string[]; // Files Claude worked on
	uncommittedCount: number;
}

interface ChangeReport {
	hasChanges: boolean;
	newCommits: CommitInfo[];
	modifiedFiles: string[];
	newFiles: string[];
	deletedFiles: string[];
	focusAreaChanges: string[]; // Changes in areas Claude was working on
	summary: string;
}

interface CommitInfo {
	hash: string;
	shortHash: string;
	subject: string;
	author: string;
	date: string;
}

// =============================================================================
// CONFIGURATION
// =============================================================================

const STATE_FILE = join(ATLAS_DIR, "data", "last-session-state.json");
const MAX_COMMITS_TO_SHOW = 10;
const MAX_STATE_AGE_MS = 24 * 60 * 60 * 1000; // 24h — skip diff if state is older (meaningless)
const IGNORE_PATTERNS = [
	"node_modules/",
	".git/",
	"*.log",
	".atlas/data/hook-performance.json",
	".atlas/data/learning-events.jsonl",
];

// =============================================================================
// GIT UTILITIES
// =============================================================================

/**
 * Execute git command safely using Bun.spawnSync (faster than Node execSync)
 */
function gitCmd(args: string[]): string {
	try {
		const result = Bun.spawnSync(["git", ...args], {
			cwd: process.cwd(),
		});
		return result.stdout.toString().trim();
	} catch {
		return "";
	}
}

/**
 * Get current git HEAD hash
 */
function getCurrentHead(): string {
	return gitCmd(["rev-parse", "HEAD"]);
}

/**
 * Get current branch name
 */
function getCurrentBranch(): string {
	return gitCmd(["rev-parse", "--abbrev-ref", "HEAD"]);
}

/**
 * Get git status (modified/untracked files)
 */
function getGitStatus(): string[] {
	const output = gitCmd(["status", "--porcelain"]);
	if (!output) return [];

	return output
		.split("\n")
		.filter((line) => line.trim())
		.map((line) => line.trim())
		.filter((line) => !IGNORE_PATTERNS.some((p) => line.includes(p)));
}

/**
 * Get commits between two refs
 */
function getCommitsBetween(fromRef: string, toRef = "HEAD"): CommitInfo[] {
	const output = gitCmd([
		"log",
		`${fromRef}..${toRef}`,
		`--format=%H|%h|%s|%an|%ai`,
		"-n",
		String(MAX_COMMITS_TO_SHOW),
	]);

	if (!output) return [];

	return output
		.split("\n")
		.filter((line) => line.trim())
		.map((line) => {
			const [hash, shortHash, subject, author, date] = line.split("|");
			return { hash, shortHash, subject, author, date };
		});
}

/**
 * Get files changed between two refs
 */
function getFilesBetween(
	fromRef: string,
	toRef = "HEAD",
): {
	modified: string[];
	added: string[];
	deleted: string[];
} {
	const output = gitCmd(["diff", "--name-status", `${fromRef}..${toRef}`]);

	if (!output) return { modified: [], added: [], deleted: [] };

	const modified: string[] = [];
	const added: string[] = [];
	const deleted: string[] = [];

	for (const line of output.split("\n")) {
		const [status, file] = line.split("\t");
		if (!file) continue;

		if (IGNORE_PATTERNS.some((p) => file.includes(p))) continue;

		switch (status) {
			case "M":
				modified.push(file);
				break;
			case "A":
				added.push(file);
				break;
			case "D":
				deleted.push(file);
				break;
		}
	}

	return { modified, added, deleted };
}

// =============================================================================
// STATE MANAGEMENT
// =============================================================================

/**
 * Load last session state
 */
function loadLastSessionState(): SessionState | null {
	if (!existsSync(STATE_FILE)) {
		return null;
	}

	try {
		const content = readFileSync(STATE_FILE, "utf-8");
		return JSON.parse(content);
	} catch (error) {
		console.error("⚠️ Could not load last session state:", error);
		return null;
	}
}

/**
 * Save current session state (called at session end)
 */
export function saveSessionState(sessionId: string, focusFiles: string[] = []): void {
	const status = getGitStatus();
	const state: SessionState = {
		sessionId,
		timestamp: new Date().toISOString(),
		gitHead: getCurrentHead(),
		gitBranch: getCurrentBranch(),
		gitStatus: status,
		focusFiles,
		uncommittedCount: status.length,
	};

	// Ensure directory exists
	const dir = dirname(STATE_FILE);
	if (!existsSync(dir)) {
		mkdirSync(dir, { recursive: true });
	}

	writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

// =============================================================================
// CHANGE DETECTION
// =============================================================================

/**
 * Detect changes since last session
 */
function detectChanges(lastState: SessionState): ChangeReport {
	const currentHead = getCurrentHead();
	const currentStatus = getGitStatus();

	// No changes if same HEAD and same status
	if (
		lastState.gitHead === currentHead &&
		JSON.stringify(lastState.gitStatus) === JSON.stringify(currentStatus)
	) {
		return {
			hasChanges: false,
			newCommits: [],
			modifiedFiles: [],
			newFiles: [],
			deletedFiles: [],
			focusAreaChanges: [],
			summary: "Aucun changement depuis la dernière session.",
		};
	}

	// Get commits since last session
	const newCommits = getCommitsBetween(lastState.gitHead);

	// Get file changes
	const { modified, added, deleted } = getFilesBetween(lastState.gitHead);

	// Check if any changes are in focus areas
	const focusAreaChanges = lastState.focusFiles.filter(
		(f) => modified.includes(f) || added.includes(f) || deleted.includes(f),
	);

	// Also check current uncommitted changes
	const uncommittedChanges = currentStatus.filter((s) => !lastState.gitStatus.includes(s));

	// Generate summary
	const summaryParts: string[] = [];

	if (newCommits.length > 0) {
		summaryParts.push(`${newCommits.length} nouveau(x) commit(s)`);
	}

	const totalFileChanges = modified.length + added.length + deleted.length;
	if (totalFileChanges > 0) {
		summaryParts.push(`${totalFileChanges} fichier(s) modifié(s)`);
	}

	if (uncommittedChanges.length > 0) {
		summaryParts.push(`${uncommittedChanges.length} changement(s) non commité(s)`);
	}

	if (focusAreaChanges.length > 0) {
		summaryParts.push(`⚠️ ${focusAreaChanges.length} fichier(s) que tu éditais ont changé`);
	}

	return {
		hasChanges: summaryParts.length > 0,
		newCommits,
		modifiedFiles: modified,
		newFiles: added,
		deletedFiles: deleted,
		focusAreaChanges,
		summary: summaryParts.length > 0 ? summaryParts.join(", ") : "Aucun changement significatif.",
	};
}

/**
 * Format change report for Claude's context
 */
function formatReport(lastState: SessionState, changes: ChangeReport): string {
	if (!changes.hasChanges) {
		return ""; // No need to inject anything
	}

	const lines: string[] = [];
	lines.push("🔄 **Changements Depuis Dernière Session**");
	lines.push(
		`Session précédente: ${lastState.timestamp.split("T")[0]} (${lastState.gitHead.slice(0, 7)})`,
	);
	lines.push("");

	// Summary
	lines.push(`**Résumé:** ${changes.summary}`);
	lines.push("");

	// New commits
	if (changes.newCommits.length > 0) {
		lines.push("**Commits:**");
		for (const commit of changes.newCommits.slice(0, 5)) {
			lines.push(`- \`${commit.shortHash}\` ${commit.subject}`);
		}
		if (changes.newCommits.length > 5) {
			lines.push(`- ... et ${changes.newCommits.length - 5} autres`);
		}
		lines.push("");
	}

	// File changes (grouped by directory)
	const allChanges = [
		...changes.modifiedFiles.map((f) => `M ${f}`),
		...changes.newFiles.map((f) => `A ${f}`),
		...changes.deletedFiles.map((f) => `D ${f}`),
	];

	if (allChanges.length > 0 && allChanges.length <= 10) {
		lines.push("**Fichiers:**");
		for (const change of allChanges) {
			lines.push(`- ${change}`);
		}
		lines.push("");
	} else if (allChanges.length > 15) {
		// Group by directory
		const dirs = new Map<string, number>();
		for (const change of allChanges) {
			const file = change.slice(2);
			const dir = dirname(file);
			dirs.set(dir, (dirs.get(dir) || 0) + 1);
		}

		lines.push("**Zones modifiées:**");
		const sortedDirs = [...dirs.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5);
		for (const [dir, count] of sortedDirs) {
			lines.push(`- \`${dir}/\` (${count} fichiers)`);
		}
		lines.push("");
	}

	// Focus area warning
	if (changes.focusAreaChanges.length > 0) {
		lines.push("⚠️ **Attention:** Ces fichiers que tu éditais ont été modifiés:");
		for (const file of changes.focusAreaChanges) {
			lines.push(`- ${file}`);
		}
		lines.push("");
	}

	return lines.join("\n");
}

// =============================================================================
// MAIN
// =============================================================================

async function main(): Promise<void> {
	const args = process.argv.slice(2);

	// Save mode (for session end)
	if (args.includes("--save")) {
		const sessionId = args[args.indexOf("--save") + 1] || `session-${Date.now()}`;
		const focusFiles = args
			.filter((a) => a.startsWith("--focus="))
			.map((a) => a.replace("--focus=", ""));

		saveSessionState(sessionId, focusFiles);
		console.error(`✅ Session state saved (${sessionId})`);
		return;
	}

	// Detect mode (for session start)
	const lastState = loadLastSessionState();

	if (!lastState) {
		// First run - save initial state silently
		saveSessionState("initial");
		console.error("📊 Session diff: première exécution, état initial sauvegardé");
		return;
	}

	// PERF: Staleness guard — if state is >24h old, diff is meaningless (too many changes)
	// Just save fresh state and skip the expensive git log/diff
	const stateAge = Date.now() - new Date(lastState.timestamp).getTime();
	if (stateAge > MAX_STATE_AGE_MS) {
		saveSessionState("stale-refresh");
		console.error(
			`📊 Session diff: état périmé (${Math.floor(stateAge / 3600000)}h), état rafraîchi`,
		);
		return;
	}

	// PERF: Quick HEAD check before expensive operations
	// If HEAD hasn't changed, only need to check working tree status
	const currentHead = getCurrentHead();
	if (lastState.gitHead === currentHead) {
		const currentStatus = getGitStatus();
		if (JSON.stringify(lastState.gitStatus) === JSON.stringify(currentStatus)) {
			console.error("📊 Session diff: aucun changement détecté");
			return;
		}
		// Only working tree changed — skip git log/diff (no new commits)
		const uncommittedChanges = currentStatus.filter((s) => !lastState.gitStatus.includes(s));
		console.error(`📊 Session diff: ${uncommittedChanges.length} changement(s) non commité(s)`);
		return;
	}

	const changes = detectChanges(lastState);

	if (changes.hasChanges) {
		// Output to stderr only — console.log system-reminders block /compact
		console.error(`📊 Session diff: ${changes.summary}`);
	} else {
		console.error("📊 Session diff: aucun changement détecté");
	}
}

process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
main()
	.then(() => process.exit(0))
	.catch(() => process.exit(0));

export { detectChanges, loadLastSessionState };
