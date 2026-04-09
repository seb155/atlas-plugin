#!/usr/bin/env bun
/**
 * Setup Hook: ATLAS Workspace Validator
 * PLAN-1111 Phase 6: Validate ATLAS workspace on CLI initialization
 *
 * @event Setup
 * @performance target <200ms (blocking on first run)
 *
 * Purpose: Ensure ATLAS workspace is properly configured
 * - Verify critical directories exist
 * - Check kernel configuration
 * - Validate hooks registry
 * - Report workspace health
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "path";

interface SetupInput {
	workspace_path: string;
	is_first_run: boolean;
}

interface SetupOutput {
	result: "continue" | "block";
	system_message?: string;
	errors?: string[];
}

interface ValidationResult {
	valid: boolean;
	errors: string[];
	warnings: string[];
	created: string[];
}

const ATLAS_ROOT = process.cwd();

// Critical directories that must exist
const REQUIRED_DIRS = [
	".atlas/kernel",
	".atlas/data",
	".atlas/matrix/components",
	".atlas/execution/active-plans",
	".atlas/context/domains",
	".atlas/knowledge",
];

// Critical files that must exist
const REQUIRED_FILES = [
	".atlas/kernel/contextual-rules.json",
	".atlas/kernel/projects-registry.json",
	"packages/core/entity-types.ts",
];

// Optional but recommended files
const RECOMMENDED_FILES = [
	".atlas/kernel/hooks-index.json",
	".atlas/kernel/agents-registry.json",
	".atlas/data/active-mode.json",
];

async function main() {
	try {
		// Read input from stdin
		let inputData = "";
		for await (const chunk of Bun.stdin.stream()) {
			inputData += new TextDecoder().decode(chunk);
		}

		const input: SetupInput = JSON.parse(inputData);

		// Run validation
		const result = await validateWorkspace(input);

		// Build output
		const output: SetupOutput = {
			result: result.valid ? "continue" : "block",
		};

		if (!result.valid) {
			output.errors = result.errors;
			output.system_message = `❌ ATLAS workspace validation failed:\n${result.errors.join("\n")}`;
		} else if (result.created.length > 0 || result.warnings.length > 0) {
			const messages: string[] = [];

			if (result.created.length > 0) {
				messages.push(`Created: ${result.created.join(", ")}`);
			}
			if (result.warnings.length > 0) {
				messages.push(`Warnings: ${result.warnings.join(", ")}`);
			}

			output.system_message = `🔧 ATLAS workspace initialized. ${messages.join(" | ")}`;
		}

		// Log setup event
		logSetupEvent(input, result);

		console.log(JSON.stringify(output));
	} catch (error) {
		// Allow continuation on error but warn
		console.log(
			JSON.stringify({
				result: "continue",
				system_message: "⚠️ ATLAS setup validation skipped due to error",
			}),
		);
	}
}

async function validateWorkspace(input: SetupInput): Promise<ValidationResult> {
	const result: ValidationResult = {
		valid: true,
		errors: [],
		warnings: [],
		created: [],
	};

	// Check and create required directories
	for (const dir of REQUIRED_DIRS) {
		const fullPath = join(ATLAS_ROOT, dir);
		if (!existsSync(fullPath)) {
			try {
				mkdirSync(fullPath, { recursive: true });
				result.created.push(dir);
			} catch (e) {
				result.errors.push(`Failed to create ${dir}`);
				result.valid = false;
			}
		}
	}

	// Check required files
	for (const file of REQUIRED_FILES) {
		const fullPath = join(ATLAS_ROOT, file);
		if (!existsSync(fullPath)) {
			result.errors.push(`Missing required file: ${file}`);
			result.valid = false;
		}
	}

	// Check recommended files
	for (const file of RECOMMENDED_FILES) {
		const fullPath = join(ATLAS_ROOT, file);
		if (!existsSync(fullPath)) {
			result.warnings.push(`Missing recommended: ${file}`);
		}
	}

	// Validate kernel configuration
	try {
		const rulesPath = join(ATLAS_ROOT, ".atlas/kernel/contextual-rules.json");
		if (existsSync(rulesPath)) {
			JSON.parse(readFileSync(rulesPath, "utf-8"));
		}
	} catch (e) {
		result.errors.push("Invalid contextual-rules.json");
		result.valid = false;
	}

	// Check git repository
	if (!existsSync(join(ATLAS_ROOT, ".git"))) {
		result.warnings.push("Not a git repository");
	}

	// Initialize setup state if first run
	if (input.is_first_run) {
		await initializeFirstRun();
	}

	return result;
}

async function initializeFirstRun(): Promise<void> {
	try {
		// Create default active-mode.json if missing
		const modePath = join(ATLAS_ROOT, ".atlas/data/active-mode.json");
		if (!existsSync(modePath)) {
			const defaultMode = {
				mode: "LISTEN",
				updatedAt: new Date().toISOString(),
				source: "setup-validator",
			};
			writeFileSync(modePath, JSON.stringify(defaultMode, null, 2));
		}

		// Create empty session activity log if missing
		const activityPath = join(ATLAS_ROOT, ".atlas/data/session-activity.jsonl");
		if (!existsSync(activityPath)) {
			writeFileSync(activityPath, "");
		}

		// Auto-deploy ATLAS CLI if missing
		await deployCliIfMissing();
	} catch {}
}

async function deployCliIfMissing(): Promise<void> {
	const home = process.env.HOME || process.env.USERPROFILE || "";
	if (!home) return;

	const cliTarget = join(home, ".atlas", "shell", "atlas.sh");
	const modulesTarget = join(home, ".atlas", "shell", "modules");
	const pluginRoot =
		process.env.CLAUDE_PLUGIN_ROOT ||
		join(home, ".claude", "plugins", "cache", "atlas-admin-marketplace", "atlas-admin");

	// Find the plugin scripts directory
	let scriptsDir = "";
	const directScripts = join(pluginRoot, "scripts");
	if (existsSync(join(directScripts, "atlas-cli.sh"))) {
		scriptsDir = directScripts;
	} else {
		// Try versioned directories (plugin cache structure: atlas-admin/4.32.1/scripts/)
		const { readdirSync } = require("node:fs");
		try {
			const versions = readdirSync(pluginRoot).filter((d: string) =>
				/^\d+\.\d+\.\d+$/.test(d),
			);
			if (versions.length > 0) {
				versions.sort();
				const latest = versions[versions.length - 1];
				const candidate = join(pluginRoot, latest, "scripts");
				if (existsSync(join(candidate, "atlas-cli.sh"))) {
					scriptsDir = candidate;
				}
			}
		} catch {}
	}

	if (!scriptsDir) return;

	// Deploy atlas.sh if missing
	if (!existsSync(cliTarget)) {
		const { mkdirSync, copyFileSync } = require("node:fs");
		try {
			mkdirSync(join(home, ".atlas", "shell"), { recursive: true });
			copyFileSync(join(scriptsDir, "atlas-cli.sh"), cliTarget);
			// Make executable
			const { chmodSync } = require("node:fs");
			chmodSync(cliTarget, 0o755);
		} catch {}
	}

	// Deploy modules if directory is missing or empty
	if (!existsSync(modulesTarget) || readdirEmpty(modulesTarget)) {
		const sourceModules = join(scriptsDir, "atlas-modules");
		if (existsSync(sourceModules)) {
			const { mkdirSync, copyFileSync, readdirSync } = require("node:fs");
			try {
				mkdirSync(modulesTarget, { recursive: true });
				for (const file of readdirSync(sourceModules)) {
					if (file.endsWith(".sh")) {
						copyFileSync(
							join(sourceModules, file),
							join(modulesTarget, file),
						);
					}
				}
			} catch {}
		}
	}
}

function readdirEmpty(dir: string): boolean {
	try {
		const { readdirSync } = require("node:fs");
		return readdirSync(dir).length === 0;
	} catch {
		return true;
	}
}

function logSetupEvent(input: SetupInput, result: ValidationResult): void {
	try {
		const logPath = join(ATLAS_ROOT, ".atlas/data/setup-history.jsonl");
		const event = {
			timestamp: new Date().toISOString(),
			workspacePath: input.workspace_path,
			isFirstRun: input.is_first_run,
			valid: result.valid,
			errorsCount: result.errors.length,
			warningsCount: result.warnings.length,
			createdCount: result.created.length,
		};

		const { appendFileSync } = require("node:fs");
		appendFileSync(logPath, JSON.stringify(event) + "\n");
	} catch {}
}

process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
main()
	.then(() => process.exit(0))
	.catch(() => process.exit(0));
