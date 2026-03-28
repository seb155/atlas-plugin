#!/usr/bin/env bun
/**
 * git-worktree.ts - Git Worktree Foundation Library
 *
 * Provides a TypeScript wrapper around git worktree commands for parallel agent execution.
 * Part of Phase 3: Swarm Mode Integration.
 *
 * @author ATLAS
 * @since 2026-02-05
 */

import { existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { $ } from "bun";

// =============================================================================
// Types
// =============================================================================

export interface WorktreeInfo {
	path: string;
	branch: string;
	head: string; // commit SHA
	prunable: boolean;
	createdAt: Date;
}

export interface MergeResult {
	success: boolean;
	conflicts: string[];
	mergedFiles: number;
}

// =============================================================================
// Constants
// =============================================================================

const WORKTREE_DIR = ".worktrees";
const ATLAS_ROOT = process.env.ATLAS_ROOT || process.cwd();

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Get the git root directory
 */
async function getGitRoot(): Promise<string | null> {
	try {
		const result = await $`git rev-parse --show-toplevel`.text();
		return result.trim();
	} catch {
		return null;
	}
}

/**
 * Parse git worktree list --porcelain output
 */
async function parseWorktreeList(): Promise<WorktreeInfo[]> {
	try {
		const output = await $`git worktree list --porcelain`.text();
		const worktrees: WorktreeInfo[] = [];
		const lines = output.trim().split("\n");

		let currentWorktree: Partial<WorktreeInfo> = {};

		for (const line of lines) {
			if (line.startsWith("worktree ")) {
				if (currentWorktree.path) {
					worktrees.push(currentWorktree as WorktreeInfo);
				}
				currentWorktree = {
					path: line.slice(9),
					prunable: false,
					createdAt: new Date(),
				};
			} else if (line.startsWith("HEAD ")) {
				currentWorktree.head = line.slice(5);
			} else if (line.startsWith("branch ")) {
				const branchRef = line.slice(7);
				currentWorktree.branch = branchRef.replace("refs/heads/", "");
			} else if (line === "prunable") {
				currentWorktree.prunable = true;
			} else if (line === "") {
				if (currentWorktree.path) {
					worktrees.push(currentWorktree as WorktreeInfo);
					currentWorktree = {};
				}
			}
		}

		// Add last worktree if exists
		if (currentWorktree.path) {
			worktrees.push(currentWorktree as WorktreeInfo);
		}

		// Get creation dates for each branch
		for (const wt of worktrees) {
			if (wt.branch) {
				try {
					const timestamp = await $`git log -1 --format=%ct ${wt.branch}`.text();
					wt.createdAt = new Date(Number.parseInt(timestamp.trim()) * 1000);
				} catch {
					// Keep default date if we can't get commit date
				}
			}
		}

		return worktrees;
	} catch {
		return [];
	}
}

/**
 * Generate a random short ID (6 characters)
 */
function generateShortId(): string {
	return Math.random().toString(36).substring(2, 8);
}

// =============================================================================
// Public API
// =============================================================================

/**
 * Create a new worktree in .worktrees/ directory
 *
 * @param agentType - The agent type (e.g., "engineer", "architect")
 * @param baseBranch - Optional base branch to branch from (defaults to current branch)
 * @returns WorktreeInfo on success, null on failure
 */
export async function createWorktree(
	agentType: string,
	baseBranch?: string,
): Promise<WorktreeInfo | null> {
	try {
		const gitRoot = await getGitRoot();
		if (!gitRoot) return null;

		const shortId = generateShortId();
		const branchName = `swarm/${agentType}/${shortId}`;
		const worktreePath = join(gitRoot, WORKTREE_DIR, shortId);

		// Create worktree with new branch
		const args = ["worktree", "add", worktreePath, "-b", branchName];
		if (baseBranch) {
			args.push(baseBranch);
		}

		await $`git ${args}`.quiet();

		// Get HEAD commit
		const head = await $`git -C ${worktreePath} rev-parse HEAD`.text();

		return {
			path: worktreePath,
			branch: branchName,
			head: head.trim(),
			prunable: false,
			createdAt: new Date(),
		};
	} catch (error) {
		console.error(`[git-worktree] Failed to create worktree: ${error}`);
		return null;
	}
}

/**
 * Remove a worktree and prune
 *
 * @param path - Absolute path to the worktree
 */
export async function removeWorktree(path: string): Promise<void> {
	try {
		// Remove worktree
		await $`git worktree remove ${path} --force`.quiet();

		// Prune stale worktree references
		await $`git worktree prune`.quiet();
	} catch (error) {
		console.error(`[git-worktree] Failed to remove worktree ${path}: ${error}`);
	}
}

/**
 * List all active worktrees
 *
 * @returns Array of WorktreeInfo objects
 */
export async function listWorktrees(): Promise<WorktreeInfo[]> {
	return parseWorktreeList();
}

/**
 * Merge worktree changes back to current branch
 *
 * @param worktreePath - Path to the worktree to merge
 * @param strategy - Merge strategy: "merge" (default) or "squash"
 * @returns MergeResult with success status and details
 */
export async function mergeWorktree(
	worktreePath: string,
	strategy: "merge" | "squash" = "merge",
): Promise<MergeResult> {
	try {
		const worktrees = await listWorktrees();
		const worktree = worktrees.find((wt) => wt.path === worktreePath);

		if (!worktree) {
			return {
				success: false,
				conflicts: ["Worktree not found"],
				mergedFiles: 0,
			};
		}

		// Perform merge
		const mergeFlag = strategy === "squash" ? "--squash" : "--no-ff";
		const result = await $`git merge ${mergeFlag} ${worktree.branch}`.nothrow();

		if (result.exitCode !== 0) {
			// Check for conflicts
			const statusOutput = await $`git status --porcelain`.text();
			const conflicts = statusOutput
				.split("\n")
				.filter((line) => line.startsWith("UU ") || line.startsWith("AA "))
				.map((line) => line.slice(3).trim());

			return {
				success: false,
				conflicts,
				mergedFiles: 0,
			};
		}

		// Count merged files
		const diffStat = await $`git diff --stat HEAD^..HEAD`.text();
		const fileCount = diffStat.split("\n").filter((line) => line.includes("|")).length;

		return {
			success: true,
			conflicts: [],
			mergedFiles: fileCount,
		};
	} catch (error) {
		return {
			success: false,
			conflicts: [String(error)],
			mergedFiles: 0,
		};
	}
}

/**
 * Cleanup worktrees older than maxAgeHours
 *
 * @param maxAgeHours - Maximum age in hours before cleanup (default: 24)
 * @returns Number of worktrees cleaned up
 */
export async function cleanupStaleWorktrees(maxAgeHours = 24): Promise<number> {
	try {
		const gitRoot = await getGitRoot();
		if (!gitRoot) return 0;

		const worktrees = await listWorktrees();
		const maxAgeMs = maxAgeHours * 60 * 60 * 1000;
		const now = Date.now();

		let cleanedCount = 0;

		for (const wt of worktrees) {
			// Skip main worktree (git root)
			if (wt.path === gitRoot) continue;

			// Skip if not in .worktrees/ directory
			if (!wt.path.includes(WORKTREE_DIR)) continue;

			const age = now - wt.createdAt.getTime();

			if (age > maxAgeMs || wt.prunable) {
				await removeWorktree(wt.path);
				cleanedCount++;
			}
		}

		return cleanedCount;
	} catch (error) {
		console.error(`[git-worktree] Failed to cleanup stale worktrees: ${error}`);
		return 0;
	}
}
