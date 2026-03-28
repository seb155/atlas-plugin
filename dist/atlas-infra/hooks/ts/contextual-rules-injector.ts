#!/usr/bin/env bun
/**
 * contextual-rules-injector.ts - Tier 1a Context Injection
 *
 * Reads user prompt from UserPromptSubmit, matches keywords against
 * contextual-rules.json domains, and injects matching rules as
 * <system-reminder> additionalContext.
 *
 * Replaces the deleted user-prompt-dispatcher.ts (560 lines + 14 thin hooks)
 * with a single-responsibility ~80-line hook.
 *
 * @event UserPromptSubmit
 * @author ATLAS
 * @since 2026-02-13
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { withMetrics } from "./lib/hook-wrapper";

const ATLAS_DIR = process.env.ATLAS_DIR || join(process.env.ATLAS_ROOT || process.cwd(), ".atlas");
const RULES_PATH = join(ATLAS_DIR, "kernel", "contextual-rules.json");
const DEBOUNCE_PATH = join(ATLAS_DIR, "data", "contextual-rules-debounce.json");
const DEBOUNCE_MS = 120 * 60 * 1000; // 2 hours (session-length debounce)
const MAX_RULES_CHARS = 500;

interface Domain {
	keywords: string[];
	priority: string;
	rules: string[];
	excludeWhen?: string[];
	quickCommands?: Record<string, string>;
	tier1bContext?: string;
}

interface RulesConfig {
	domains: Record<string, Domain>;
	injection: { maxDomainsPerPrompt: number };
}

function loadDebounce(): Record<string, number> {
	try {
		if (existsSync(DEBOUNCE_PATH)) {
			return JSON.parse(readFileSync(DEBOUNCE_PATH, "utf-8"));
		}
	} catch {
		/* fresh start */
	}
	return {};
}

function saveDebounce(state: Record<string, number>): void {
	try {
		writeFileSync(DEBOUNCE_PATH, JSON.stringify(state));
	} catch {
		/* non-critical */
	}
}

function matchDomains(prompt: string, config: RulesConfig): (Domain & { name: string }) | null {
	const lowerPrompt = prompt.toLowerCase();
	const priorityOrder = ["critical", "high", "medium", "low"];

	const matches: Array<Domain & { name: string }> = [];

	for (const [name, domain] of Object.entries(config.domains)) {
		// Check excludeWhen first
		if (domain.excludeWhen?.some((ex) => new RegExp(ex, "i").test(prompt))) continue;

		// Check keywords
		const hit = domain.keywords.some((kw) => new RegExp(kw, "i").test(lowerPrompt));
		if (hit) matches.push({ ...domain, name });
	}

	if (matches.length === 0) return null;

	// Sort by priority, return highest
	matches.sort((a, b) => priorityOrder.indexOf(a.priority) - priorityOrder.indexOf(b.priority));
	return matches[0];
}

async function main(): Promise<void> {
	// Read stdin
	const chunks: Buffer[] = [];
	for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
	const input = Buffer.concat(chunks).toString("utf-8");

	let prompt: string;
	try {
		const parsed = JSON.parse(input);
		prompt = parsed.prompt || "";
	} catch {
		process.exit(0);
		return;
	}

	// Fast path: skip short prompts
	if (prompt.length < 15) {
		process.exit(0);
		return;
	}

	// PERF: Check debounce BEFORE loading the 19K rules file
	// If all debounce entries are recent, most prompts will be skipped anyway
	const debounce = loadDebounce();
	const now = Date.now();
	const activeEntries = Object.values(debounce).filter((v) => now - v < DEBOUNCE_MS);
	// If we have 3+ active debounced domains, very likely this prompt will hit one
	// Skip the optimization for new sessions (no debounce entries yet)

	// Load rules
	if (!existsSync(RULES_PATH)) {
		process.exit(0);
		return;
	}
	const config: RulesConfig = JSON.parse(readFileSync(RULES_PATH, "utf-8"));

	// Match domain
	const match = matchDomains(prompt, config);
	if (!match) {
		process.exit(0);
		return;
	}

	// Debounce: skip if same domain was injected within session window
	// Critical domains always bypass debounce
	const lastInjection = debounce[match.name];
	const withinWindow = lastInjection && now - lastInjection < DEBOUNCE_MS;

	if (withinWindow && match.priority !== "critical") {
		process.exit(0);
		return;
	}

	// Update debounce state (prune entries > 1h)
	const pruned: Record<string, number> = {};
	for (const [k, v] of Object.entries(debounce)) {
		if (now - v < 3600000) pruned[k] = v;
	}
	pruned[match.name] = now;
	saveDebounce(pruned);

	// Build injection (cap at MAX_RULES_CHARS)
	const rulesText = match.rules.join("\n- ");
	const truncated =
		rulesText.length > MAX_RULES_CHARS ? `${rulesText.slice(0, MAX_RULES_CHARS)}...` : rulesText;

	const quickCmds = match.quickCommands
		? `\nQuick: ${Object.entries(match.quickCommands)
				.map(([k, v]) => `${k}=${v}`)
				.join(", ")}`
		: "";

	const context = `[${match.priority.toUpperCase()}] ${match.name}:\n- ${truncated}${quickCmds}`;

	// Output as additionalContext JSON
	const output = JSON.stringify({
		additionalContext: `<system-reminder>\n${context}\n</system-reminder>`,
	});
	console.log(output);

	process.exit(0);
}

withMetrics("contextual-rules-injector", "UserPromptSubmit", main);
