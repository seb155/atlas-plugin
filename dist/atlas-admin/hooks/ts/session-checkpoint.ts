#!/usr/bin/env bun
/**
 * session-checkpoint.ts - Session Checkpoint System
 *
 * Stop hook that saves a comprehensive checkpoint for reliable session resume.
 * Solves: session name opacity, progress loss, TaskList state not preserved.
 *
 * @event Stop
 * @since 2026-02-07
 * @performance target <200ms
 */

import {
	appendFileSync,
	existsSync,
	mkdirSync,
	readFileSync,
	readdirSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import { join } from "node:path";

// =============================================================================
// Types
// =============================================================================

interface StopHookInput {
	session_id?: string;
	stop_reason?: string;
	response?: string;
	/** Last assistant message text (CC 2.1.19+) */
	last_assistant_message?: string;
	tool_uses?: Array<{
		name: string;
		input?: Record<string, unknown>;
	}>;
}

interface SessionCheckpoint {
	sessionId: string;
	timestamp: string;
	title: string;
	activePlan: string | null;
	activePlanFile: string | null;
	modifiedFiles: string[];
	keyActions: string[];
	resumeInstructions: string;
	/** Excerpt of last assistant message for resume context (CC 2.1.19+) */
	lastMessageExcerpt?: string;
}

// =============================================================================
// Constants
// =============================================================================

const ATLAS_ROOT = process.env.ATLAS_ROOT || process.cwd();
const CHECKPOINTS_DIR = join(ATLAS_ROOT, ".atlas/data/session-checkpoints");
const ACTIVE_SESSION_PATH = join(ATLAS_ROOT, ".atlas/data/active-session.json");
const ACTIVE_PLANS_DIR = join(ATLAS_ROOT, ".atlas/execution/active-plans");
const MAX_CHECKPOINTS = 20;

// =============================================================================
// Helpers
// =============================================================================

/**
 * Find the most recently modified active plan
 */
function findActivePlan(): { planId: string; planFile: string } | null {
	try {
		if (!existsSync(ACTIVE_PLANS_DIR)) return null;

		const files = readdirSync(ACTIVE_PLANS_DIR)
			.filter((f) => f.endsWith(".md") && !f.includes("-agent-"))
			.map((f) => ({
				name: f.replace(".md", ""),
				path: join(ACTIVE_PLANS_DIR, f),
				mtime: existsSync(join(ACTIVE_PLANS_DIR, f))
					? new Date(
							readFileSync(join(ACTIVE_PLANS_DIR, f), "utf-8").length > 0
								? require("node:fs").statSync(join(ACTIVE_PLANS_DIR, f)).mtime
								: 0,
						).getTime()
					: 0,
			}))
			.sort((a, b) => b.mtime - a.mtime);

		if (files.length === 0) return null;

		return { planId: files[0].name, planFile: files[0].path };
	} catch {
		return null;
	}
}

/**
 * Extract modified files from tool uses
 */
function extractModifiedFiles(toolUses: StopHookInput["tool_uses"]): string[] {
	const files = new Set<string>();

	for (const tool of toolUses || []) {
		if (tool.name === "Edit" || tool.name === "Write") {
			const filePath = (tool.input as { file_path?: string })?.file_path;
			if (filePath) {
				// Store relative path
				const relative = filePath.replace(ATLAS_ROOT + "/", "");
				files.add(relative);
			}
		}
	}

	return [...files];
}

/**
 * Extract key actions from tool uses
 */
function extractKeyActions(toolUses: StopHookInput["tool_uses"]): string[] {
	const actions: string[] = [];

	for (const tool of toolUses || []) {
		if (tool.name === "TaskCreate") {
			const subject = (tool.input as { subject?: string })?.subject;
			if (subject) actions.push(`Created task: ${subject}`);
		} else if (tool.name === "TaskUpdate") {
			const status = (tool.input as { status?: string })?.status;
			const taskId = (tool.input as { taskId?: string })?.taskId;
			if (status === "completed" && taskId) {
				actions.push(`Completed task #${taskId}`);
			}
		} else if (tool.name === "Bash") {
			const cmd = (tool.input as { command?: string })?.command || "";
			if (cmd.startsWith("git commit")) {
				actions.push("Git commit created");
			} else if (cmd.startsWith("git push")) {
				actions.push("Git push executed");
			} else if (cmd.includes("bun test")) {
				actions.push("Tests executed");
			}
		}
	}

	return actions.slice(0, 10); // Max 10 key actions
}

/**
 * Generate a human-readable title for the session
 */
function generateTitle(
	plan: { planId: string } | null,
	modifiedFiles: string[],
	actions: string[],
): string {
	const parts: string[] = [];

	if (plan) {
		parts.push(plan.planId);
	}

	// Infer topic from modified files
	if (modifiedFiles.length > 0) {
		const dirs = new Set(modifiedFiles.map((f) => f.split("/").slice(0, 2).join("/")));
		if (dirs.size <= 3) {
			parts.push([...dirs].join(", "));
		} else {
			parts.push(`${modifiedFiles.length} files modified`);
		}
	}

	// Add action summary
	const completedTasks = actions.filter((a) => a.startsWith("Completed")).length;
	if (completedTasks > 0) {
		parts.push(`${completedTasks} tasks done`);
	}

	return parts.join(" — ") || "Session without explicit plan";
}

/**
 * Generate resume instructions
 */
function generateResumeInstructions(
	plan: { planId: string; planFile: string } | null,
	modifiedFiles: string[],
	actions: string[],
): string {
	const lines: string[] = [];

	if (plan) {
		lines.push(`Continue plan: ${plan.planId}`);
		lines.push(`Plan file: ${plan.planFile}`);
	}

	if (modifiedFiles.length > 0) {
		lines.push(`Files modified this session: ${modifiedFiles.slice(0, 5).join(", ")}`);
	}

	if (actions.length > 0) {
		lines.push(`Last actions: ${actions.slice(-3).join("; ")}`);
	}

	return lines.join("\n");
}

/**
 * Rotate old checkpoints (keep max N)
 */
function rotateCheckpoints(): void {
	try {
		if (!existsSync(CHECKPOINTS_DIR)) return;

		const files = readdirSync(CHECKPOINTS_DIR)
			.filter((f) => f.endsWith(".json"))
			.map((f) => ({
				name: f,
				path: join(CHECKPOINTS_DIR, f),
				mtime: require("node:fs").statSync(join(CHECKPOINTS_DIR, f)).mtime.getTime(),
			}))
			.sort((a, b) => b.mtime - a.mtime);

		// Delete oldest beyond MAX_CHECKPOINTS
		for (const file of files.slice(MAX_CHECKPOINTS)) {
			rmSync(file.path, { force: true });
		}
	} catch {
		// Silent fail
	}
}

// =============================================================================
// Main
// =============================================================================

async function main() {
	// Skip if running as subagent
	if (process.env.CLAUDE_AGENT_ID || process.env.CLAUDE_AGENT_TYPE) {
		process.exit(0);
	}

	// Read input from stdin
	let input: StopHookInput;
	try {
		const stdin = await Bun.stdin.text();
		if (!stdin.trim()) process.exit(0);
		input = JSON.parse(stdin);
	} catch {
		process.exit(0);
	}

	const sessionId = input.session_id || "unknown";

	// Gather checkpoint data
	const plan = findActivePlan();
	const modifiedFiles = extractModifiedFiles(input.tool_uses);
	const actions = extractKeyActions(input.tool_uses);
	const title = generateTitle(plan, modifiedFiles, actions);

	// Build checkpoint
	const checkpoint: SessionCheckpoint = {
		sessionId,
		timestamp: new Date().toISOString(),
		title,
		activePlan: plan?.planId || null,
		activePlanFile: plan?.planFile || null,
		modifiedFiles,
		keyActions: actions,
		resumeInstructions: generateResumeInstructions(plan, modifiedFiles, actions),
		lastMessageExcerpt: input.last_assistant_message?.slice(0, 500),
	};

	// Save checkpoint
	if (!existsSync(CHECKPOINTS_DIR)) mkdirSync(CHECKPOINTS_DIR, { recursive: true });

	const date = new Date().toISOString().slice(0, 10);
	const time = new Date().toISOString().slice(11, 16).replace(":", "");
	const planSuffix = plan?.planId ? `-${plan.planId.slice(0, 30)}` : "";
	const filename = `${date}_${time}${planSuffix}.json`;

	writeFileSync(join(CHECKPOINTS_DIR, filename), JSON.stringify(checkpoint, null, 2));

	// Update active-session.json with human-readable title
	try {
		let activeSession: Record<string, unknown> = {};
		if (existsSync(ACTIVE_SESSION_PATH)) {
			activeSession = JSON.parse(readFileSync(ACTIVE_SESSION_PATH, "utf-8"));
		}
		activeSession.title = title;
		activeSession.lastCheckpoint = checkpoint.timestamp;
		writeFileSync(ACTIVE_SESSION_PATH, JSON.stringify(activeSession, null, 2));
	} catch {
		// Silent fail
	}

	// Rotate old checkpoints
	rotateCheckpoints();

	console.error(`[session-checkpoint] Saved: ${filename} — "${title}"`);
}

process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));

main().catch(() => process.exit(0));
