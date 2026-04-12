/**
 * hook-wrapper.ts - Hook Instrumentation Wrapper
 *
 * Wraps hook execution with timeout protection, error tracing,
 * and clean process exit. Simplified from PLAN-842 (push stack removed).
 *
 * Usage:
 * ```typescript
 * import { withMetrics } from '@atlas/core/metrics/hook-wrapper';
 * async function main(): Promise<void> { ... }
 * withMetrics('my-hook', 'UserPromptSubmit', main);
 * ```
 *
 * @author ATLAS
 * @since 2026-01-03
 */

import { appendFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
// Activity tracking removed — statusline-sync handles this directly

// Trace files for observability
const TRACES_DIR = join(process.env.ATLAS_DIR || process.cwd(), ".atlas/data/traces");
const TIMEOUT_TRACE_PATH = join(TRACES_DIR, "hook-timeouts.jsonl");
const ERROR_TRACE_PATH = join(TRACES_DIR, "hook-errors.jsonl");

function logTimeout(hookName: string, hookType: string, durationMs: number): void {
	try {
		mkdirSync(TRACES_DIR, { recursive: true });
		const entry = {
			timestamp: new Date().toISOString(),
			hookName,
			hookType,
			durationMs: Math.round(durationMs),
			sessionId: process.env.CLAUDE_SESSION_ID || `pid-${process.pid}`,
		};
		appendFileSync(TIMEOUT_TRACE_PATH, JSON.stringify(entry) + "\n");
	} catch {
		// Silent - don't block on logging
	}
}

function logError(
	hookName: string,
	hookType: string,
	error: Error | string,
	durationMs: number,
): void {
	try {
		mkdirSync(TRACES_DIR, { recursive: true });
		const entry = {
			timestamp: new Date().toISOString(),
			hookName,
			hookType,
			error: error instanceof Error ? error.message : String(error),
			stack: error instanceof Error ? error.stack?.split("\n").slice(0, 5).join("\n") : undefined,
			durationMs: Math.round(durationMs),
			sessionId: process.env.CLAUDE_SESSION_ID || `pid-${process.pid}`,
		};
		appendFileSync(ERROR_TRACE_PATH, JSON.stringify(entry) + "\n");
	} catch {
		// Silent - don't block on logging
	}
}

// Hook types for metrics categorization (Claude Code hook events + ATLAS custom)
export type HookType =
	| "PreToolUse"
	| "PostToolUse"
	| "PostToolUseFailure"
	| "UserPromptSubmit"
	| "SessionStart"
	| "SessionEnd"
	| "Stop"
	| "SubagentStop"
	| "Notification"
	| "CronJob";

// Default timeout for hooks (prevents lock-out)
const DEFAULT_HOOK_TIMEOUT_MS = Number(process.env.ATLAS_HOOK_TIMEOUT_MS) || 2500;

export async function withMetrics<T>(
	hookName: string,
	hookType: HookType,
	fn: () => Promise<T>,
	timeoutMs: number = DEFAULT_HOOK_TIMEOUT_MS,
): Promise<T> {
	const start = performance.now();

	try {
		// Race between function execution and timeout
		const result = await Promise.race([
			fn(),
			new Promise<never>((_, reject) =>
				setTimeout(() => reject(new Error(`Hook timeout after ${timeoutMs}ms`)), timeoutMs),
			),
		]);

		// Ensure clean process exit
		process.exit(0);
	} catch (error) {
		const duration = performance.now() - start;
		const isTimeout = error instanceof Error && error.message.includes("Hook timeout");

		if (isTimeout) {
			console.error(`[${hookName}] ⏱️ Timeout after ${duration.toFixed(0)}ms - exiting cleanly`);
			logTimeout(hookName, hookType, duration);
		} else if (error instanceof Error) {
			logError(hookName, hookType, error, duration);
		}

		// Fail-open: exit cleanly even on errors — hooks must never block Claude Code
		process.exit(0);
	}
}

/**
 * Quick hook runner for simple cases.
 */
export function runHook<T>(hookName: string, hookType: HookType, fn: () => Promise<T>): Promise<T> {
	return withMetrics(hookName, hookType, fn);
}
