#!/usr/bin/env bun
/**
 * keyword-aware-calibration.ts - SP-DAIMON P2 Keyword-Aware Calibration
 *
 * Reads user prompt from UserPromptSubmit, loads DAIMON calibration rules
 * from vault/daimon/calibration-rules.md (path resolved via
 * ~/.atlas/runtime/session-calibration.json), matches patterns case-insensitive,
 * and injects top N matches as <system-reminder> additionalContext.
 *
 * Pattern source: contextual-rules-injector.ts (Tier 1a Context Injection).
 * Differs: rules are user-editable markdown (not JSON), per-user (not global),
 * DAIMON-profile-driven (not contextual domain-based).
 *
 * @event UserPromptSubmit
 * @author ATLAS
 * @since 2026-04-15 (SP-DAIMON P2)
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { withMetrics } from "./lib/hook-wrapper";

const CALIBRATION_CACHE = join(homedir(), ".atlas", "runtime", "session-calibration.json");
const DEBOUNCE_PATH = join(
	process.env.ATLAS_DIR || join(homedir(), ".atlas"),
	"data",
	"calibration-rules-debounce.json",
);
const DEBOUNCE_MS = 120 * 60 * 1000; // 2 hours per-rule debounce
const MAX_RULES_PER_PROMPT = 3;
const MAX_INJECTION_CHARS = 500;

interface CalibrationRule {
	name: string;
	match: "keyword" | "phrase" | "regex";
	patterns: string[];
	interpretation: string;
	actions: string[];
}

function loadDebounce(path: string): Record<string, number> {
	try {
		if (existsSync(path)) {
			return JSON.parse(readFileSync(path, "utf-8"));
		}
	} catch {
		/* fresh start */
	}
	return {};
}

function saveDebounce(path: string, state: Record<string, number>): void {
	try {
		writeFileSync(path, JSON.stringify(state));
	} catch {
		/* non-critical */
	}
}

/**
 * Parse calibration-rules.md into rules list.
 * Expected format per rule:
 *   ### Rule N — name
 *   **match**: keyword|phrase|regex
 *   **patterns**: p1, p2, p3
 *   **interpretation**: text
 *   **action**:
 *   - bullet 1
 *   - bullet 2
 */
function parseRulesMarkdown(md: string): CalibrationRule[] {
	const rules: CalibrationRule[] = [];
	// Split by "### Rule" headers (greedy match preserves sections)
	const sections = md.split(/^### Rule \d+ — /m).slice(1);

	for (const section of sections) {
		const nameMatch = section.match(/^([^\n]+)/);
		const matchTypeMatch = section.match(/\*\*match\*\*:\s*(keyword|phrase|regex)/i);
		const patternsMatch = section.match(/\*\*patterns\*\*:\s*([^\n]+)/i);
		const interpMatch = section.match(/\*\*interpretation\*\*:\s*([^\n]+)/i);
		const actionsBlock = section.match(/\*\*action\*\*:\s*\n((?:[-*]\s+[^\n]+\n?)+)/i);

		if (!nameMatch || !matchTypeMatch || !patternsMatch || !actionsBlock) continue;

		const patterns = patternsMatch[1]
			.split(",")
			.map((p) => p.trim())
			.filter((p) => p.length > 0);

		const actions = actionsBlock[1]
			.split("\n")
			.filter((l) => /^[-*]\s/.test(l))
			.map((l) => l.replace(/^[-*]\s+/, "").trim());

		if (patterns.length === 0 || actions.length === 0) continue;

		rules.push({
			name: nameMatch[1].trim(),
			match: matchTypeMatch[1].toLowerCase() as CalibrationRule["match"],
			patterns,
			interpretation: interpMatch?.[1].trim() || "",
			actions,
		});
	}

	return rules;
}

function matchRules(prompt: string, rules: CalibrationRule[]): CalibrationRule[] {
	const lowerPrompt = prompt.toLowerCase();
	const hits: CalibrationRule[] = [];

	for (const rule of rules) {
		for (const pat of rule.patterns) {
			const lowerPat = pat.toLowerCase();
			// All match types use substring check (case-insensitive); regex support via pattern text
			if (rule.match === "regex") {
				try {
					if (new RegExp(pat, "i").test(prompt)) {
						hits.push(rule);
						break;
					}
				} catch {
					continue; // invalid regex, skip silently
				}
			} else if (lowerPrompt.includes(lowerPat)) {
				hits.push(rule);
				break;
			}
		}
	}

	return hits;
}

function resolveVaultPath(): string | null {
	if (!existsSync(CALIBRATION_CACHE)) return null;
	try {
		const calib = JSON.parse(readFileSync(CALIBRATION_CACHE, "utf-8"));
		return calib.vault_path || null;
	} catch {
		return null;
	}
}

function buildInjection(rules: CalibrationRule[]): string {
	const parts = rules.slice(0, MAX_RULES_PER_PROMPT).map((r) => {
		const actionList = r.actions.map((a) => `  - ${a}`).join("\n");
		return `[${r.name}]\n${r.interpretation}\n${actionList}`;
	});
	const body = parts.join("\n\n");
	return body.length > MAX_INJECTION_CHARS
		? `${body.slice(0, MAX_INJECTION_CHARS)}...`
		: body;
}

async function main(): Promise<void> {
	// Read stdin (UserPromptSubmit hook contract)
	const chunks: Buffer[] = [];
	for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
	const input = Buffer.concat(chunks).toString("utf-8");

	let prompt: string;
	try {
		prompt = JSON.parse(input).prompt || "";
	} catch {
		process.exit(0);
	}

	// Fast path: skip short prompts
	if (prompt.length < 15) process.exit(0);

	// Resolve vault + rules file
	const vaultPath = resolveVaultPath();
	if (!vaultPath) process.exit(0);

	const rulesPath = join(vaultPath, "daimon", "calibration-rules.md");
	if (!existsSync(rulesPath)) process.exit(0);

	// Parse rules
	let rules: CalibrationRule[];
	try {
		rules = parseRulesMarkdown(readFileSync(rulesPath, "utf-8"));
	} catch {
		process.exit(0);
	}
	if (rules.length === 0) process.exit(0);

	// Match
	const hits = matchRules(prompt, rules);
	if (hits.length === 0) process.exit(0);

	// Debounce per-rule
	const debounce = loadDebounce(DEBOUNCE_PATH);

	const now = Date.now();
	const fresh = hits.filter((r) => {
		const last = debounce[r.name];
		return !last || now - last >= DEBOUNCE_MS;
	});
	if (fresh.length === 0) process.exit(0);

	// Update debounce (prune > 1h old, mark fresh hits)
	const pruned: Record<string, number> = {};
	for (const [k, v] of Object.entries(debounce)) {
		if (now - v < 3600000) pruned[k] = v;
	}
	for (const r of fresh) pruned[r.name] = now;
	saveDebounce(DEBOUNCE_PATH, pruned);


	// Build + emit
	const context = `DAIMON calibration match (${fresh.length} rule${fresh.length > 1 ? "s" : ""}):\n\n${buildInjection(fresh)}`;
	console.log(
		JSON.stringify({
			additionalContext: `<system-reminder>\n${context}\n</system-reminder>`,
		}),
	);

	process.exit(0);
}

withMetrics("keyword-aware-calibration", "UserPromptSubmit", main);
