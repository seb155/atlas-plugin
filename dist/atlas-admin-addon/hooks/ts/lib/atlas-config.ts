#!/usr/bin/env bun
/**
 * atlas-config.ts
 *
 * Configuration loader for ATLAS hooks layer.
 * Reads profile.json and provides typed config to all ATLAS hooks.
 *
 * Usage:
 *   import { getAtlasConfig, ATLAS_DIR, PAI_DIR } from './lib/atlas-config';
 *   const config = getAtlasConfig();
 */

import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

// Path resolution
export const ATLAS_ROOT = process.env.ATLAS_ROOT || process.cwd();
const WORKSPACE_ROOT = process.env.ATLAS_WORKSPACE_ROOT || process.env.HOME || "";
export const PAI_DIR = process.env.PAI_DIR || `${WORKSPACE_ROOT}/.claude`;
export const ATLAS_DIR = process.env.ATLAS_DIR || `${WORKSPACE_ROOT}/.atlas`;

/** Get ATLAS workspace root directory */
export function getAtlasRoot(): string {
	return ATLAS_ROOT;
}

export type ContextMode = "minimal" | "lite" | "full";
export type EntityDetection = "smart" | "all" | "none";
export type AgentDiscovery = "cached" | "fresh";

export interface AtlasConfig {
	paiDir: string;
	userName: string;
	userEmail: string;
	assistantName: string;
	assistantColor: string;
	voicePort: number;
	voiceEnabled: boolean;
	createdAt: string;
	// Tiered context modes (Phase 3 DevEx Optimization)
	contextMode: ContextMode;
	entityDetection: EntityDetection;
	agentDiscovery: AgentDiscovery;
}

const DEFAULT_CONFIG: AtlasConfig = {
	paiDir: PAI_DIR,
	userName: "User",
	userEmail: "",
	assistantName: process.env.DA || "ATLAS",
	assistantColor: process.env.DA_COLOR || "blue",
	voicePort: 8888,
	voiceEnabled: false,
	createdAt: new Date().toISOString(),
	// Tiered context defaults (lite = balanced for most sessions)
	contextMode: "full", // Start with full for backward compatibility
	entityDetection: "smart",
	agentDiscovery: "cached",
};

let cachedConfig: AtlasConfig | null = null;

/**
 * Load ATLAS configuration from profile.json
 * Falls back to defaults if file doesn't exist or is invalid
 */
export function getAtlasConfig(): AtlasConfig {
	if (cachedConfig) return cachedConfig;

	const profilePath = join(PAI_DIR, "config/profile.json");

	try {
		if (existsSync(profilePath)) {
			const content = readFileSync(profilePath, "utf-8");
			const parsed = JSON.parse(content);
			cachedConfig = { ...DEFAULT_CONFIG, ...parsed };
		} else {
			cachedConfig = DEFAULT_CONFIG;
		}
	} catch (error) {
		console.error("Warning: Could not load profile.json, using defaults");
		cachedConfig = DEFAULT_CONFIG;
	}

	return cachedConfig!;
}

/**
 * Check if we're running as a subagent (should skip most hooks)
 */
export function isSubagent(): boolean {
	const claudeProjectDir = process.env.CLAUDE_PROJECT_DIR || "";
	return (
		claudeProjectDir.includes("/.claude/agents/") || process.env.CLAUDE_AGENT_TYPE !== undefined
	);
}

/**
 * Get the assistant name from config or environment
 */
export function getAssistantName(): string {
	const config = getAtlasConfig();
	return process.env.DA || config.assistantName || "ATLAS";
}

// ============================================================================
// SANDBOX MODE
// ============================================================================

/**
 * Check if we're running in sandbox mode
 * Sandbox mode isolates all writes to a temporary directory for safe testing
 */
export function isSandboxMode(): boolean {
	return (
		process.env.ATLAS_SANDBOX === "true" ||
		process.env.CLAUDE_PROJECT_DIR?.includes("/sandbox/") ||
		false
	);
}

/**
 * Get the sandbox directory path
 * All writes will be redirected here when in sandbox mode
 */
export function getSandboxDir(): string {
	return process.env.ATLAS_SANDBOX_DIR || "/tmp/atlas-sandbox";
}

/**
 * Get the effective path for a file operation
 * Returns sandbox path if in sandbox mode, original path otherwise
 */
export function getEffectivePath(originalPath: string): string {
	if (!isSandboxMode()) return originalPath;

	// Replace ATLAS_DIR with sandbox dir
	if (originalPath.startsWith(ATLAS_DIR)) {
		return originalPath.replace(ATLAS_DIR, getSandboxDir());
	}

	// Replace PAI_DIR with sandbox dir (for .claude files)
	if (originalPath.startsWith(PAI_DIR)) {
		return originalPath.replace(PAI_DIR, join(getSandboxDir(), ".claude"));
	}

	return originalPath;
}
