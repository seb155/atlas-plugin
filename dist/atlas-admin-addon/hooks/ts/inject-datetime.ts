#!/usr/bin/env bun
/**
 * inject-datetime.ts - Inject current date/time into Claude's context
 *
 * This hook runs at SessionStart to ensure Claude always knows the
 * exact current date and time. This is critical for:
 * - Creating properly timestamped files
 * - Planning with accurate dates
 * - Avoiding confusion about "today" vs training data dates
 *
 * Output: system-reminder with current date/time in multiple formats
 *
 * @author Axoiq
 * @since 2025-12-12
 */

import { withMetrics } from "./lib/hook-wrapper";
import { NOW, getTimezoneDateTime } from "./lib/timestamp-utils";

/**
 * Generate the datetime context injection
 */
function generateDateTimeContext(): string {
	return `📅 ${NOW.weekday} ${NOW.date} ${getTimezoneDateTime()} | Files: ${NOW.datetime}_name.md | Frontmatter: ${NOW.datetime}`;
}

/**
 * Main entry point
 */
async function main(): Promise<void> {
	const eventType = process.argv[2] || "SessionStart";

	if (eventType === "SessionStart") {
		// Output to stderr only — console.log system-reminders block /compact
		const context = generateDateTimeContext();
		console.error(`📅 ${context}`);
	}

	process.exit(0);
}

withMetrics("inject-datetime", "SessionStart", main);
