#!/usr/bin/env bun
/**
 * lib/agent-registry.ts
 *
 * SP-AGENT-VIS Layer 1 — Shared state management for subagent visibility.
 *
 * Atomic read/write ~/.atlas/runtime/agents.json.
 * Used by subagent-output-capture (PostToolUse:Agent), subagent-context-injector
 * (SubagentStart), subagent-result-capture (SubagentStop), and the `atlas agents` CLI.
 *
 * Plan: .blueprint/plans/keen-nibbling-umbrella.md Layer 1.
 * Invariant: single source of truth for currently-running + recently-completed agents.
 *
 * @module hooks/ts/lib/agent-registry
 */

import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

import { ATLAS_DIR } from "./atlas-config";

// ─── Paths ─────────────────────────────────────────────────────────

export const AGENTS_REGISTRY_PATH = `${ATLAS_DIR}/runtime/agents.json`;
export const AGENTS_LOCK_PATH = `${AGENTS_REGISTRY_PATH}.lock`;

// ─── Types ─────────────────────────────────────────────────────────

export type AgentStatus = "spawning" | "running" | "completed" | "failed";
export type VisibilityMode = "tmux" | "wt" | "none";

export interface AgentEntry {
	agent_id: string;
	agent_type: string;
	output_file: string | null;
	started_at: string;
	finished_at: string | null;
	status: AgentStatus;
	duration_ms: number | null;
	success: boolean | null;
	tmux_pane: string | null;
	wt_tab: string | null;
	visibility_mode: VisibilityMode;
	session_id: string;
}

type AgentsStore = Record<string, AgentEntry>;

const STALE_AGE_MS = 2 * 60 * 60 * 1000; // 2 hours
const LOCK_TIMEOUT_MS = 500;
const LOCK_POLL_MS = 10;

// ─── Lockfile (best-effort concurrency control) ────────────────────

async function acquireLock(): Promise<boolean> {
	const start = Date.now();
	while (Date.now() - start < LOCK_TIMEOUT_MS) {
		try {
			// O_CREAT + O_EXCL via writeFileSync with flag 'wx' (fails if exists)
			writeFileSync(AGENTS_LOCK_PATH, String(process.pid), { flag: "wx" });
			return true;
		} catch {
			// Check if lockfile is stale (> 2s old = dead process)
			try {
				const fs = require("node:fs");
				const stat = fs.statSync(AGENTS_LOCK_PATH);
				if (Date.now() - stat.mtimeMs > 2000) {
					// Stale lock, reclaim
					fs.unlinkSync(AGENTS_LOCK_PATH);
					continue;
				}
			} catch {
				// Lock disappeared between check and now, retry
			}
			await new Promise((r) => setTimeout(r, LOCK_POLL_MS));
		}
	}
	return false;
}

function releaseLock(): void {
	try {
		const fs = require("node:fs");
		fs.unlinkSync(AGENTS_LOCK_PATH);
	} catch {
		// Already released or never acquired
	}
}

// ─── Atomic I/O ────────────────────────────────────────────────────

function ensureDir(): void {
	const dir = dirname(AGENTS_REGISTRY_PATH);
	if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
}

function readStore(): AgentsStore {
	if (!existsSync(AGENTS_REGISTRY_PATH)) return {};
	try {
		return JSON.parse(readFileSync(AGENTS_REGISTRY_PATH, "utf-8")) as AgentsStore;
	} catch {
		// Corrupt file — treat as empty (will be overwritten on next write)
		return {};
	}
}

function writeStore(store: AgentsStore): void {
	ensureDir();
	const tmpPath = `${AGENTS_REGISTRY_PATH}.tmp.${process.pid}`;
	writeFileSync(tmpPath, JSON.stringify(store, null, 2));
	renameSync(tmpPath, AGENTS_REGISTRY_PATH);
}

async function updateStore(mutator: (store: AgentsStore) => void): Promise<void> {
	const locked = await acquireLock();
	try {
		const store = readStore();
		mutator(store);
		if (locked) {
			writeStore(store);
		}
		// If lock not acquired, we still attempted to mutate — best-effort degradation.
		// Another hook process may overwrite, but data loss is bounded (single agent event).
	} finally {
		if (locked) releaseLock();
	}
}

// ─── Public API ────────────────────────────────────────────────────

/**
 * Create or update an agent entry when its Agent() tool call resolves.
 * Called from PostToolUse:Agent hook (subagent-output-capture).
 *
 * @param agentId - From Agent tool result (e.g., "abc123def456")
 * @param outputFile - Symlink path to JSONL transcript (e.g., "/tmp/claude-UID/.../tasks/ID.output")
 * @param agentType - Optional, may be known at spawn time (e.g., "team-engineer")
 * @param sessionId - Parent CC session id
 */
export async function registerSpawn(
	agentId: string,
	outputFile: string | null,
	agentType: string = "unknown",
	sessionId: string = "",
): Promise<void> {
	await updateStore((store) => {
		const now = new Date().toISOString();
		const existing = store[agentId];
		store[agentId] = {
			agent_id: agentId,
			agent_type: existing?.agent_type ?? agentType,
			output_file: outputFile ?? existing?.output_file ?? null,
			started_at: existing?.started_at ?? now,
			finished_at: null,
			status: existing?.status === "completed" || existing?.status === "failed"
				? existing.status
				: "spawning",
			duration_ms: null,
			success: null,
			tmux_pane: existing?.tmux_pane ?? null,
			wt_tab: existing?.wt_tab ?? null,
			visibility_mode: existing?.visibility_mode ?? "none",
			session_id: existing?.session_id || sessionId,
		};
		pruneStaleInPlace(store);
	});
}

/**
 * Upgrade an agent entry to "running" once SubagentStart fires.
 * Called from SubagentStart hook (subagent-context-injector or subagent-track-start).
 */
export async function registerStart(
	agentId: string,
	agentType: string,
	sessionId: string = "",
): Promise<void> {
	await updateStore((store) => {
		const now = new Date().toISOString();
		const existing = store[agentId];
		if (existing) {
			existing.agent_type = agentType; // More reliable than PostToolUse
			existing.status = existing.status === "spawning" ? "running" : existing.status;
			existing.started_at = existing.started_at || now;
			if (sessionId && !existing.session_id) existing.session_id = sessionId;
		} else {
			// PostToolUse didn't fire first (race) — create minimal entry
			store[agentId] = {
				agent_id: agentId,
				agent_type: agentType,
				output_file: null,
				started_at: now,
				finished_at: null,
				status: "running",
				duration_ms: null,
				success: null,
				tmux_pane: null,
				wt_tab: null,
				visibility_mode: "none",
				session_id: sessionId,
			};
		}
		pruneStaleInPlace(store);
	});
}

/**
 * Mark an agent as completed/failed. Called from SubagentStop hook.
 */
export async function markCompleted(
	agentId: string,
	opts: { success: boolean; durationMs?: number },
): Promise<AgentEntry | null> {
	let result: AgentEntry | null = null;
	await updateStore((store) => {
		const existing = store[agentId];
		if (!existing) return;
		const now = new Date().toISOString();
		existing.finished_at = now;
		existing.status = opts.success ? "completed" : "failed";
		existing.success = opts.success;
		if (opts.durationMs !== undefined) {
			existing.duration_ms = opts.durationMs;
		} else if (existing.started_at) {
			existing.duration_ms = Date.now() - new Date(existing.started_at).getTime();
		}
		result = { ...existing };
	});
	return result;
}

/**
 * Update visibility metadata (tmux pane id, wt tab id, mode).
 */
export async function updateVisibility(
	agentId: string,
	patch: Partial<Pick<AgentEntry, "tmux_pane" | "wt_tab" | "visibility_mode">>,
): Promise<void> {
	await updateStore((store) => {
		const existing = store[agentId];
		if (!existing) return;
		if (patch.tmux_pane !== undefined) existing.tmux_pane = patch.tmux_pane;
		if (patch.wt_tab !== undefined) existing.wt_tab = patch.wt_tab;
		if (patch.visibility_mode !== undefined) existing.visibility_mode = patch.visibility_mode;
	});
}

/**
 * Read a single agent entry (no mutation, no lock).
 */
export function getByAgentId(agentId: string): AgentEntry | null {
	const store = readStore();
	return store[agentId] ?? null;
}

/**
 * Read all agents with status in ["spawning", "running"].
 */
export function getActive(): AgentEntry[] {
	const store = readStore();
	return Object.values(store).filter((a) => a.status === "spawning" || a.status === "running");
}

/**
 * Read all agents (running + recently completed within retention window).
 */
export function getAll(): AgentEntry[] {
	return Object.values(readStore());
}

/**
 * Prune entries older than `maxAgeMs` (default 2h).
 * Called opportunistically on writes to bound file size.
 */
function pruneStaleInPlace(store: AgentsStore, maxAgeMs: number = STALE_AGE_MS): void {
	const cutoff = Date.now() - maxAgeMs;
	for (const [id, entry] of Object.entries(store)) {
		const ts = entry.finished_at ?? entry.started_at;
		if (!ts) continue;
		if (new Date(ts).getTime() < cutoff) {
			delete store[id];
		}
	}
}

/**
 * Explicit prune (for CLI `atlas agents clean` or manual maintenance).
 */
export async function pruneStale(maxAgeMs: number = STALE_AGE_MS): Promise<number> {
	let removed = 0;
	await updateStore((store) => {
		const before = Object.keys(store).length;
		pruneStaleInPlace(store, maxAgeMs);
		removed = before - Object.keys(store).length;
	});
	return removed;
}
