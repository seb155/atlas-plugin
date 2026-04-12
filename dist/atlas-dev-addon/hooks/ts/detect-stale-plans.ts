#!/usr/bin/env bun
/**
 * detect-stale-plans.ts - SessionStart Plan Freshness Hook
 *
 * Scans active-plans/ for stale execution plans and warns at session start.
 * Plans are categorized by age since last modification:
 *
 * - < 7 days: ✅ Active (no output)
 * - 7-30 days: ⚠️ Stale (suggest review)
 * - 30-60 days: 🔴 Expired (suggest archive)
 * - > 60 days: 💀 Zombie (suggest git rm)
 *
 * Target: < 5ms execution time (Rule #14)
 *
 * @author ATLAS
 * @since 2026-02-04
 */

import { existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const ATLAS_ROOT = process.env.ATLAS_ROOT || process.cwd();
const PLANS_DIR = join(ATLAS_ROOT, ".atlas/execution/active-plans");
const DAY_MS = 86_400_000;

interface PlanStatus {
	name: string;
	ageDays: number;
	level: "stale" | "expired" | "zombie";
	icon: string;
}

function main(): void {
	if (!existsSync(PLANS_DIR)) {
		process.exit(0);
	}

	const files = readdirSync(PLANS_DIR).filter((f) => f.endsWith(".md"));
	if (files.length === 0) {
		process.exit(0);
	}

	const now = Date.now();
	const flagged: PlanStatus[] = [];

	for (const file of files) {
		try {
			const stat = statSync(join(PLANS_DIR, file));
			const ageDays = Math.floor((now - stat.mtimeMs) / DAY_MS);

			if (ageDays >= 60) {
				flagged.push({ name: file, ageDays, level: "zombie", icon: "💀" });
			} else if (ageDays >= 30) {
				flagged.push({ name: file, ageDays, level: "expired", icon: "🔴" });
			} else if (ageDays >= 7) {
				flagged.push({ name: file, ageDays, level: "stale", icon: "⚠️" });
			}
		} catch {
			// Skip unreadable files
		}
	}

	if (flagged.length === 0) {
		process.exit(0);
	}

	// Sort by age descending (worst first)
	flagged.sort((a, b) => b.ageDays - a.ageDays);

	const zombies = flagged.filter((p) => p.level === "zombie");
	const expired = flagged.filter((p) => p.level === "expired");
	const stale = flagged.filter((p) => p.level === "stale");
	const activeCount = files.length - flagged.length;

	const lines = flagged.map(
		(p) => `| ${p.icon} | ${p.name.replace(".md", "")} | ${p.ageDays}d | ${p.level} |`,
	);

	const suggestions: string[] = [];
	if (zombies.length > 0) {
		suggestions.push(
			`- 💀 ${zombies.length} zombie plan(s) (>60d) — suggest \`git rm\` after review`,
		);
	}
	if (expired.length > 0) {
		suggestions.push(
			`- 🔴 ${expired.length} expired plan(s) (>30d) — suggest archiving to MATRIX summary`,
		);
	}
	if (stale.length > 0) {
		suggestions.push(`- ⚠️ ${stale.length} stale plan(s) (>7d) — consider reviewing or closing`);
	}

	// Output to stderr only — never inject into context (prevents /compact failures)
	const summary = `${flagged.length} plan(s) need attention: ${zombies.length} zombie, ${expired.length} expired, ${stale.length} stale (of ${files.length} total)`;
	console.error(`[detect-stale-plans] ${summary}`);
}

main();
