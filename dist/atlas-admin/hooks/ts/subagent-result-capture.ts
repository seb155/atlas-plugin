#!/usr/bin/env bun
/**
 * SubagentStop Hook: Result Capture
 *
 * PLAN-1111 Phase 1: Capture subagent results for ATLAS
 *
 * Captures:
 * - Research findings → Knowledge Library
 * - Metrics (duration, tokens, success)
 * - Suggests INS creation for valuable insights
 *
 * @event SubagentStop
 * @performance target <100ms (non-blocking)
 */

import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "path";

interface SubagentStopInput {
	session_id: string;
	agent_id: string;
	agent_type: string;
	transcript_path?: string;
	/** Subagent-specific transcript (CC 2.1.19+) */
	agent_transcript_path?: string;
	/** Last assistant message text (CC 2.1.19+) — more reliable than transcript parsing */
	last_assistant_message?: string;
	duration_ms?: number;
	success?: boolean;
	/** Confidence score from agent response (0-1), supports cascade routing (CC 2.1.19) */
	confidence?: number;
	/** Model used for this agent run */
	model_used?: string;
	/** Whether this was an escalated run (fallback model) */
	was_escalated?: boolean;
}

interface HookOutput {
	continue: boolean;
	additionalContext?: string;
}

interface SubagentMetric {
	timestamp: string;
	session_id: string;
	agent_id: string;
	agent_type: string;
	duration_ms: number;
	success: boolean;
	captured: boolean;
	/** Confidence score from agent response (0-1), supports cascade routing */
	confidence?: number;
	/** Whether escalation was triggered due to low confidence */
	escalated?: boolean;
}

const ATLAS_ROOT = process.cwd();
const METRICS_PATH = join(ATLAS_ROOT, ".atlas/data/subagent-metrics.jsonl");
const RESEARCH_PATH = join(ATLAS_ROOT, ".atlas/knowledge/research");
const ACTIVE_AGENTS_PATH = join(ATLAS_ROOT, ".atlas/data/subagent-active.json");

interface AgentStartRecord {
	agent_type: string;
	started_at: string;
}

/**
 * Correlate with SubagentStart store to recover agent_type and calculate duration.
 * The SubagentStart hook records agent_id → {agent_type, started_at} mappings.
 */
function correlateWithStart(input: SubagentStopInput): { agent_type: string; duration_ms: number } {
	let agent_type = input.agent_type || "";
	let duration_ms = input.duration_ms || 0;

	try {
		if (!existsSync(ACTIVE_AGENTS_PATH)) {
			return { agent_type, duration_ms };
		}

		const store: Record<string, AgentStartRecord> = JSON.parse(
			readFileSync(ACTIVE_AGENTS_PATH, "utf-8"),
		);
		const startRecord = store[input.agent_id];

		if (startRecord) {
			// Recover agent_type if missing from SubagentStop event
			if (!agent_type) {
				agent_type = startRecord.agent_type;
			}

			// Calculate duration from timestamps if not provided by Claude Code
			if (!duration_ms && startRecord.started_at) {
				const startTime = new Date(startRecord.started_at).getTime();
				const endTime = Date.now();
				duration_ms = endTime - startTime;
			}

			// Clean up: remove consumed entry
			delete store[input.agent_id];
			writeFileSync(ACTIVE_AGENTS_PATH, JSON.stringify(store, null, 2));
		}
	} catch {
		// Silent fail — correlation is best-effort
	}

	return { agent_type, duration_ms };
}

/**
 * Extract confidence score from transcript
 * Looks for confidence indicators in agent output (CC 2.1.19 cascade routing)
 */
function extractConfidence(transcriptPath: string): number | undefined {
	try {
		if (!existsSync(transcriptPath)) return undefined;

		const content = readFileSync(transcriptPath, "utf-8");

		// Look for explicit confidence markers
		const confidencePatterns = [
			/confidence[:\s]+(\d+(?:\.\d+)?)/i,
			/certainty[:\s]+(\d+(?:\.\d+)?)/i,
			/"confidence"[:\s]+(\d+(?:\.\d+)?)/,
		];

		for (const pattern of confidencePatterns) {
			const match = content.match(pattern);
			if (match) {
				const value = Number.parseFloat(match[1]);
				// Normalize to 0-1 range
				return value > 1 ? value / 100 : value;
			}
		}

		// Infer confidence from language patterns
		const lowConfidencePatterns = [
			/i'm not (sure|certain)/i,
			/might be/i,
			/could be/i,
			/unclear/i,
			/uncertain/i,
		];
		const highConfidencePatterns = [/definitely/i, /certainly/i, /clearly/i, /confirmed/i];

		const lowCount = lowConfidencePatterns.filter((p) => p.test(content)).length;
		const highCount = highConfidencePatterns.filter((p) => p.test(content)).length;

		if (lowCount > highCount) return 0.6;
		if (highCount > lowCount) return 0.9;

		return undefined; // No confidence signal
	} catch {
		return undefined;
	}
}

/**
 * Log metrics for analytics.
 * Uses correlated agent_type and duration_ms from SubagentStart store.
 */
function logMetrics(
	input: SubagentStopInput,
	captured: boolean,
	correlated: { agent_type: string; duration_ms: number },
): void {
	try {
		const dir = dirname(METRICS_PATH);
		if (!existsSync(dir)) mkdirSync(dir, { recursive: true });

		// Use agent_transcript_path first, then transcript_path for confidence extraction
		const transcriptForConfidence = input.agent_transcript_path || input.transcript_path;

		// Extract confidence: explicit field > transcript parsing (fallback)
		const confidence =
			input.confidence ??
			(transcriptForConfidence ? extractConfidence(transcriptForConfidence) : undefined);

		const metric: SubagentMetric = {
			timestamp: new Date().toISOString(),
			session_id: input.session_id,
			agent_id: input.agent_id,
			agent_type: correlated.agent_type,
			duration_ms: correlated.duration_ms,
			success: input.success !== false,
			captured,
			confidence,
			escalated: input.was_escalated,
		};

		appendFileSync(METRICS_PATH, JSON.stringify(metric) + "\n");
	} catch {
		// Silent fail for metrics
	}
}

/**
 * Extract research summary from transcript
 */
function extractResearchSummary(transcriptPath: string): string | null {
	try {
		if (!existsSync(transcriptPath)) return null;

		const content = readFileSync(transcriptPath, "utf-8");

		// Look for research-like content patterns
		const researchPatterns = [
			/## (?:Summary|Findings|Results|Conclusion)([\s\S]*?)(?=##|$)/i,
			/### (?:Key (?:Findings|Points|Insights))([\s\S]*?)(?=###|##|$)/i,
			/(?:Found|Discovered|Research shows)([\s\S]{100,500})/i,
		];

		for (const pattern of researchPatterns) {
			const match = content.match(pattern);
			if (match && match[1]?.trim().length > 50) {
				return match[1].trim().slice(0, 1000); // Limit to 1000 chars
			}
		}

		return null;
	} catch {
		return null;
	}
}

/**
 * Check if result is valuable enough to suggest INS creation
 */
function shouldSuggestINS(agentType: string, summary: string | null): boolean {
	if (!summary) return false;

	// Research agents with substantial findings
	const researchAgents = ["gemini-researcher", "claude-researcher", "perplexity-researcher"];
	if (!researchAgents.includes(agentType)) return false;

	// Check for substantial content
	if (summary.length < 200) return false;

	// Check for insight-worthy patterns
	const insightPatterns = [
		/pattern|methodology|best practice|key (finding|insight|learning)/i,
		/discovered|found that|important|significant/i,
		/should|must|always|never|recommend/i,
	];

	return insightPatterns.some((p) => p.test(summary));
}

/**
 * Save research to Knowledge Library
 */
function saveResearch(agentType: string, summary: string): string | null {
	try {
		if (!existsSync(RESEARCH_PATH)) mkdirSync(RESEARCH_PATH, { recursive: true });

		const date = new Date().toISOString().split("T")[0];
		const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 16);
		const filename = `${date}-${agentType}-research.md`;
		const filepath = join(RESEARCH_PATH, filename);

		// Check if file exists and append, or create new
		let content = "";
		if (existsSync(filepath)) {
			content = readFileSync(filepath, "utf-8");
			content += `\n\n---\n\n## ${timestamp}\n\n${summary}`;
		} else {
			content = `# ${agentType} Research - ${date}\n\n## ${timestamp}\n\n${summary}`;
		}

		writeFileSync(filepath, content);
		return filepath;
	} catch {
		return null;
	}
}

async function main() {
	// Read input from stdin
	let inputData = "";
	for await (const chunk of Bun.stdin.stream()) {
		inputData += new TextDecoder().decode(chunk);
	}

	const input: SubagentStopInput = JSON.parse(inputData);

	// Correlate with SubagentStart store to recover agent_type and calculate duration
	const correlated = correlateWithStart(input);

	// Skip capture for utility agents
	const skipAgents = ["statusline-setup", "Bash", "Explore"];
	if (skipAgents.includes(correlated.agent_type)) {
		logMetrics(input, false, correlated);
		console.log(JSON.stringify({ continue: true }));
		return;
	}

	// Try to extract and save research
	// Priority: last_assistant_message (CC 2.1.19+) > transcript parsing (fallback)
	let captured = false;
	let savedPath: string | null = null;
	let summary: string | null = null;

	if (input.last_assistant_message && input.last_assistant_message.length > 50) {
		// Use last_assistant_message directly — more reliable than transcript parsing
		summary = input.last_assistant_message.slice(0, 1000);
	} else {
		// Fallback to transcript parsing for older CC versions
		const transcriptPath = input.agent_transcript_path || input.transcript_path;
		if (transcriptPath) {
			summary = extractResearchSummary(transcriptPath);
		}
	}

	if (summary) {
		savedPath = saveResearch(correlated.agent_type, summary);
		captured = savedPath !== null;
	}

	// Log metrics with correlated values
	logMetrics(input, captured, correlated);

	// Build response
	const output: HookOutput = { continue: true };

	// Add context if valuable result captured
	if (captured && shouldSuggestINS(correlated.agent_type, summary)) {
		const durationStr =
			correlated.duration_ms > 0 ? `${(correlated.duration_ms / 1000).toFixed(1)}s` : "unknown";
		output.additionalContext = `## Subagent Research Captured

**Agent**: ${correlated.agent_type}
**Duration**: ${durationStr}
**Saved to**: ${savedPath}

💡 **Consider**: This research may be valuable enough for an INS entity. Use \`/a-learn\` to capture key insights.`;
	}

	console.log(JSON.stringify(output));
}

process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));
main()
	.then(() => process.exit(0))
	.catch((err) => {
		// Fail-open: allow completion without capture
		console.error(`[SubagentResultCapture] Error: ${err.message}`);
		console.log(JSON.stringify({ continue: true }));
		process.exit(0);
	});
