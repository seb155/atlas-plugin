#!/usr/bin/env bun
/**
 * statusline-sync.ts - Sync ATLAS state to /tmp for statusline display
 *
 * Writes a single JSON file with mode + hierarchy for tmux/terminal statuslines.
 * Runs on every UserPromptSubmit, skips subagents.
 *
 * @event UserPromptSubmit
 * @priority 90 (run late, after other hooks)
 */

import { existsSync, readFileSync, readdirSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "path";
import { withMetrics } from "./lib/hook-wrapper";

// Unref stdin immediately to prevent hanging
process.stdin.unref();

// Skip for subagents
if (process.env.CLAUDE_AGENT_ID) {
	process.exit(0);
}

const sessionId = process.env.CLAUDE_SESSION_ID || `pid-${process.pid}`;

// =============================================================================
// PATHS
// =============================================================================

function findAtlasRoot(): string {
	if (process.env.ATLAS_ROOT) return process.env.ATLAS_ROOT;
	let current = process.cwd();
	for (let i = 0; i < 10; i++) {
		if (existsSync(join(current, ".atlas"))) return current;
		const parent = dirname(current);
		if (parent === current) break;
		current = parent;
	}
	return process.cwd();
}

const ATLAS_ROOT = findAtlasRoot();
const ATLAS_DIR = join(ATLAS_ROOT, ".atlas");

const OUTPUT_FILE = "/tmp/atlas-global-state.json";

const SOURCE = {
	modeState: join(ATLAS_DIR, "data", "atlas-mode-state.json"),
	sharedState: join(ATLAS_DIR, "kernel", "shared-state.json"),
	activePlans: join(ATLAS_DIR, "data", "active-plans.json"),
	plansDir: join(ATLAS_DIR, "matrix", "components", "plans"),
};

// =============================================================================
// CLEANUP: Remove stale session-specific /tmp files (>1h old)
// =============================================================================

function cleanupOldFiles(): void {
	// PERF: Only run cleanup 1 in 10 times (probabilistic) — saves ~20ms of readdirSync+statSync
	if (Math.random() > 0.1) return;

	const MAX_AGE_MS = 60 * 60 * 1000;
	const now = Date.now();

	try {
		const files = readdirSync("/tmp").filter(
			(f: string) => f.startsWith("atlas-") && f.endsWith(".json") && !f.includes("-global"),
		);

		for (const file of files) {
			try {
				const stat = statSync(`/tmp/${file}`);
				if (now - stat.mtimeMs > MAX_AGE_MS) {
					unlinkSync(`/tmp/${file}`);
				}
			} catch {}
		}
	} catch {}
}

// =============================================================================
// MODE DETECTION
// =============================================================================

const MODE_EMOJIS: Record<string, string> = {
	LISTEN: "🎧",
	WORKING: "⚡",
	COACH: "🧘",
};

function safeReadJson(path: string): Record<string, unknown> | null {
	try {
		if (existsSync(path)) return JSON.parse(readFileSync(path, "utf-8"));
	} catch {}
	return null;
}

function detectMode(): { current: string; emoji: string } {
	// PERF: Try primary source first, skip fallback if found
	const modeData = safeReadJson(SOURCE.modeState);
	if (modeData) {
		const mode = (modeData.currentMode as string) || "LISTEN";
		return { current: mode, emoji: MODE_EMOJIS[mode] || "🎧" };
	}
	const sharedData = safeReadJson(SOURCE.sharedState);
	if (sharedData) {
		const session = sharedData.session as Record<string, unknown> | undefined;
		const mode = (session?.atlasMode as string) || "LISTEN";
		return { current: mode, emoji: MODE_EMOJIS[mode] || "🎧" };
	}
	return { current: "LISTEN", emoji: "🎧" };
}

// =============================================================================
// HIERARCHY DETECTION
// =============================================================================

interface PlanInfo {
	id: string;
	title: string;
	progress: number;
	parentId?: string;
	parentType?: string;
}

function extractFrontmatter(content: string): Record<string, string> {
	const result: Record<string, string> = {};
	const match = content.match(/^---\n([\s\S]*?)\n---/);
	if (!match) return result;
	for (const line of match[1].split("\n")) {
		const kv = line.match(/^(\w+):\s*(.+)/);
		if (kv) result[kv[1]] = kv[2].replace(/^["']|["']$/g, "").trim();
	}
	return result;
}

function readPlanFile(planId: string): PlanInfo | null {
	try {
		if (!existsSync(SOURCE.plansDir)) return null;
		const files = readdirSync(SOURCE.plansDir) as string[];
		const file = files.find((f: string) => f.includes(planId) && f.endsWith(".md"));
		if (!file) return null;

		const fm = extractFrontmatter(readFileSync(join(SOURCE.plansDir, file), "utf-8"));
		return {
			id: planId,
			title: fm.title || planId,
			progress: typeof fm.progress === "string" ? Number.parseInt(fm.progress, 10) || 0 : 0,
			parentId: fm.parent_id || fm.parent,
			parentType: fm.parent_type,
		};
	} catch {}
	return null;
}

function detectHierarchy(): {
	programme?: { id: string; name: string };
	epic?: { id: string; name: string };
	plan?: { id: string; title: string; progress: number };
	breadcrumb: string;
} {
	const hierarchy: {
		programme?: { id: string; name: string };
		epic?: { id: string; name: string };
		plan?: { id: string; title: string; progress: number };
		breadcrumb: string;
	} = { breadcrumb: "" };

	// Source 1: active-plans.json (primary)
	if (existsSync(SOURCE.activePlans)) {
		try {
			const data = JSON.parse(readFileSync(SOURCE.activePlans, "utf-8"));
			const plans = data.plans || [];
			if (plans.length > 0) {
				const top = plans[0];
				const planId = (top.id || "").replace(/^atls-/, "");
				const info = readPlanFile(planId);

				hierarchy.plan = {
					id: top.id || planId,
					title: info?.title || top.title || planId,
					progress: info?.progress ?? 0,
				};

				if (info?.parentId?.includes("EPIC")) {
					hierarchy.epic = { id: info.parentId, name: info.parentId };
				}
				hierarchy.programme = { id: "PROG-001", name: "ATLAS" };
			}
		} catch {}
	}

	// Source 2: Most recent in_progress plan file (fallback)
	// PERF: Only check 2 most recent files (was 5), skip statSync by sorting by filename
	// Plan filenames contain dates, so alphabetical sort ≈ chronological sort
	if (!hierarchy.plan) {
		try {
			if (existsSync(SOURCE.plansDir)) {
				const files = (readdirSync(SOURCE.plansDir) as string[])
					.filter((f: string) => f.includes("PLAN-") && f.endsWith(".md"))
					.sort((a, b) => b.localeCompare(a)) // Reverse alpha = newest first (date in name)
					.slice(0, 2); // Only check 2 most recent (was 5 with statSync each)

				for (const file of files) {
					const content = readFileSync(join(SOURCE.plansDir, file), "utf-8");
					const fm = extractFrontmatter(content);
					if (fm.status === "in_progress" || fm.status === "active") {
						const idMatch = file.match(/PLAN-(\d+)/);
						const planId = idMatch ? `PLAN-${idMatch[1]}` : file;
						hierarchy.programme = { id: "PROG-001", name: "ATLAS" };
						hierarchy.plan = {
							id: planId,
							title: fm.title || planId,
							progress: Number.parseInt(fm.progress || "0", 10) || 0,
						};
						if (fm.parent_id?.includes("EPIC")) {
							hierarchy.epic = { id: fm.parent_id, name: fm.parent_id };
						}
						break;
					}
				}
			}
		} catch {}
	}

	// Build breadcrumb
	const parts: string[] = [];
	if (hierarchy.programme?.name) parts.push(hierarchy.programme.name);
	if (hierarchy.epic?.id) parts.push(hierarchy.epic.id.replace(/^atls-/, ""));
	if (hierarchy.plan?.id) parts.push(hierarchy.plan.id.replace(/^atls-/, ""));
	hierarchy.breadcrumb = parts.join(" > ");

	return hierarchy;
}

// =============================================================================
// MAIN
// =============================================================================

async function main(): Promise<void> {
	cleanupOldFiles();

	const mode = detectMode();
	const hierarchy = detectHierarchy();

	writeFileSync(
		OUTPUT_FILE,
		JSON.stringify({
			mode,
			hierarchy,
			lastUpdate: new Date().toISOString(),
			lastSession: sessionId,
		}),
	);
}

withMetrics("statusline-sync", "SessionStart", main);
