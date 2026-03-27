/**
 * timestamp-utils.ts - ATLAS Timestamp Utilities
 *
 * Provides standardized timestamp formatting for all ATLAS operations.
 * Enforces consistent date/time format across the system.
 *
 * Standard Formats:
 * - Date only: YYYY-MM-DD (e.g., 2025-12-12)
 * - DateTime: YYYY-MM-DD_HH-mm (e.g., 2025-12-12_23-45)
 * - Full: YYYY-MM-DD_HH-mm-ss (e.g., 2025-12-12_23-45-30)
 *
 * @author Axoiq
 * @since 2025-12-12
 */

/**
 * Get day of week in French
 */
export function getDayOfWeek(): string {
	const days = ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"];
	return days[new Date().getDay()];
}

/**
 * Get current date in YYYY-MM-DD format
 */
export function getDate(): string {
	return new Date().toISOString().split("T")[0];
}

/**
 * Get current datetime in YYYY-MM-DD_HH-mm format
 * Uses underscore as separator (safe for filenames)
 */
export function getDateTime(): string {
	const now = new Date();
	const date = now.toISOString().split("T")[0];
	const time = now.toTimeString().split(" ")[0].slice(0, 5).replace(":", "-");
	return `${date}_${time}`;
}

/**
 * Get current datetime with seconds in YYYY-MM-DD_HH-mm-ss format
 */
export function getFullDateTime(): string {
	const now = new Date();
	const date = now.toISOString().split("T")[0];
	const time = now.toTimeString().split(" ")[0].replace(/:/g, "-");
	return `${date}_${time}`;
}

/**
 * Get current datetime for display (human readable)
 * Format: YYYY-MM-DD HH:mm
 */
export function getDisplayDateTime(): string {
	const now = new Date();
	const date = now.toISOString().split("T")[0];
	const time = now.toTimeString().split(" ")[0].slice(0, 5);
	return `${date} ${time}`;
}

/**
 * Get current datetime in ISO format
 */
export function getISODateTime(): string {
	return new Date().toISOString();
}

/**
 * Get timezone-aware datetime string
 * Includes timezone offset (e.g., 2025-12-12_23-45 PST)
 */
export function getTimezoneDateTime(): string {
	const now = new Date();
	const date = now.toISOString().split("T")[0];
	const time = now.toTimeString().split(" ")[0].slice(0, 5).replace(":", "-");
	const tz = now.toTimeString().split(" ")[1] || "UTC";
	return `${date}_${time} ${tz}`;
}

/**
 * Parse a timestamp string to Date object
 * Supports multiple formats:
 * - YYYY-MM-DD
 * - YYYY-MM-DD_HH-mm
 * - YYYY-MM-DD_HH-mm-ss
 * - ISO 8601
 */
export function parseTimestamp(timestamp: string): Date | null {
	// ISO format
	if (timestamp.includes("T")) {
		const date = new Date(timestamp);
		return Number.isNaN(date.getTime()) ? null : date;
	}

	// Our format with underscore
	if (timestamp.includes("_")) {
		const [datePart, timePart] = timestamp.split("_");
		const time = timePart?.replace(/-/g, ":") || "00:00:00";
		const date = new Date(`${datePart}T${time}`);
		return Number.isNaN(date.getTime()) ? null : date;
	}

	// Just date
	const date = new Date(timestamp);
	return Number.isNaN(date.getTime()) ? null : date;
}

/**
 * Validate timestamp format
 * Returns true if the timestamp matches expected format
 */
export function isValidTimestamp(
	timestamp: string,
	format: "date" | "datetime" | "full" = "datetime",
): boolean {
	const patterns = {
		date: /^\d{4}-\d{2}-\d{2}$/,
		datetime: /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}$/,
		full: /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/,
	};

	return patterns[format].test(timestamp);
}

/**
 * Generate a unique filename with timestamp prefix
 * Example: 2025-12-12_23-45_my-file.md
 */
export function timestampedFilename(basename: string): string {
	return `${getDateTime()}_${basename}`;
}

/**
 * Get timestamp for YAML frontmatter
 * Returns object with created/updated fields
 */
export function getFrontmatterTimestamps(existingCreated?: string): {
	created: string;
	updated: string;
} {
	const now = getDateTime();
	return {
		created: existingCreated || now,
		updated: now,
	};
}

/**
 * Format a Date object to our standard format
 */
export function formatDate(date: Date, format: "date" | "datetime" | "full" = "datetime"): string {
	const datePart = date.toISOString().split("T")[0];

	if (format === "date") {
		return datePart;
	}

	const timePart = date.toTimeString().split(" ")[0];
	const timeFormatted =
		format === "full" ? timePart.replace(/:/g, "-") : timePart.slice(0, 5).replace(":", "-");

	return `${datePart}_${timeFormatted}`;
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMPORAL AWARENESS - INS-024
// Functions for human-contextual time awareness
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Get temporal greeting in French based on current hour
 * Implements INS-024 temporal awareness pattern
 */
export function getTemporalGreeting(): string {
	const hour = new Date().getHours();
	if (hour < 12) return "Bon matin";
	if (hour < 17) return "Bon après-midi";
	return "Bonsoir";
}

/**
 * Get human state context based on time of day
 * Used to acknowledge human energy/focus patterns
 */
export function getHumanStateContext(): string {
	const hour = new Date().getHours();
	const day = new Date().getDay();

	// Energy patterns
	if (hour >= 14 && hour <= 16) return "afternoon-dip";
	if (hour >= 22 || hour < 6) return "late-night";

	// Work context
	if (day === 5 && hour > 15) return "friday-pm";
	if (day === 1 && hour < 12) return "monday-am";
	if (day === 0 || day === 6) return "weekend";

	return "normal";
}

/**
 * Get compact temporal string for response headers
 * Format: "Dimanche 14:35"
 */
export function getCompactTemporal(): string {
	const weekday = getDayOfWeek();
	const time = new Date().toTimeString().slice(0, 5);
	return `${weekday} ${time}`;
}

// Export current timestamp constants for quick access
export const NOW = {
	date: getDate(),
	datetime: getDateTime(),
	full: getFullDateTime(),
	display: getDisplayDateTime(),
	iso: getISODateTime(),
	tz: getTimezoneDateTime(),
	weekday: getDayOfWeek(),
};
