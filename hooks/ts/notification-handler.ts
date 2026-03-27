#!/usr/bin/env bun
/**
 * Notification Hook: Custom Notification Handler
 * PLAN-1111 Phase 6: Handle Claude notifications with ATLAS branding
 * PLAN-1120: Handle background research completion notifications
 *
 * @event Notification
 * @performance target <50ms (non-blocking)
 *
 * Purpose: Customize how notifications are presented to the user
 * - Add ATLAS branding
 * - Log important notifications
 * - Filter noise
 * - Handle background research completion (PLAN-1120)
 */

import { appendFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "path";

interface NotificationInput {
	message: string;
	type: "info" | "warning" | "error" | "success";
	source?: string;
}

interface NotificationOutput {
	result: "continue" | "block";
	message?: string;
}

const ATLAS_ROOT = process.cwd();
const NOTIFICATIONS_LOG = join(ATLAS_ROOT, ".atlas/data/notifications.jsonl");

// Notification type icons
const ICONS: Record<string, string> = {
	info: "ℹ️",
	warning: "⚠️",
	error: "❌",
	success: "✅",
};

// Patterns to suppress (noise reduction)
const SUPPRESS_PATTERNS = [/^Searching\.\.\./i, /^Loading\.\.\./i, /^Processing\.\.\./i];

// Patterns that indicate important notifications
const IMPORTANT_PATTERNS = [/error/i, /fail/i, /complete/i, /success/i, /warning/i];

// PLAN-1120: Patterns for background research notifications
const RESEARCH_COMPLETE_PATTERNS = [
	/background.*research.*complete/i,
	/gemini-researcher.*finish/i,
	/research.*task.*done/i,
	/background.*agent.*complete/i,
];

async function main() {
	try {
		// Read input from stdin
		let inputData = "";
		for await (const chunk of Bun.stdin.stream()) {
			inputData += new TextDecoder().decode(chunk);
		}

		const input: NotificationInput = JSON.parse(inputData);

		// Check if should suppress
		const shouldSuppress = SUPPRESS_PATTERNS.some((p) => p.test(input.message));
		if (shouldSuppress) {
			console.log(JSON.stringify({ result: "block" }));
			return;
		}

		// PLAN-1120: Check for background research completion
		const isResearchComplete = RESEARCH_COMPLETE_PATTERNS.some((p) => p.test(input.message));
		if (isResearchComplete) {
			// Log research completion
			logNotification({ ...input, type: "success" });

			// Format with research-specific branding
			const formattedMessage = `🔬 ATLAS Research: ${input.message}\n\n💡 **Tip**: Use \`TaskOutput\` to retrieve the full research results.`;

			const output: NotificationOutput = {
				result: "continue",
				message: formattedMessage,
			};
			console.log(JSON.stringify(output));
			return;
		}

		// Log important notifications
		const isImportant = IMPORTANT_PATTERNS.some((p) => p.test(input.message));
		if (isImportant) {
			logNotification(input);
		}

		// Format with ATLAS branding
		const icon = ICONS[input.type] || "ℹ️";
		const formattedMessage = `${icon} ATLAS: ${input.message}`;

		const output: NotificationOutput = {
			result: "continue",
			message: formattedMessage,
		};

		console.log(JSON.stringify(output));
	} catch (error) {
		// Pass through on error
		console.log(JSON.stringify({ result: "continue" }));
	}
}

function logNotification(input: NotificationInput): void {
	try {
		const dir = join(ATLAS_ROOT, ".atlas/data");
		if (!existsSync(dir)) {
			mkdirSync(dir, { recursive: true });
		}

		const entry = {
			timestamp: new Date().toISOString(),
			type: input.type,
			message: input.message,
			source: input.source || "unknown",
		};

		appendFileSync(NOTIFICATIONS_LOG, JSON.stringify(entry) + "\n");
	} catch {}
}

process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
main()
	.then(() => process.exit(0))
	.catch(() => process.exit(0));
