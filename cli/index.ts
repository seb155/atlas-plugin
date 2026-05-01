#!/usr/bin/env bun
/**
 * cli/index.ts — ATLAS CLI TypeScript Entrypoint
 *
 * Dispatches TypeScript-based atlas subcommands.
 * Run directly:   bun cli/index.ts portal --help
 * After compile:  node cli/index.js portal --help
 *
 * Build: bun build cli/index.ts --outfile cli/index.js --target node
 *
 * SP-DEVHUB-COCKPIT Wave 2 — T10
 * @author AXOIQ
 * @since 2026-04-26
 */

import { portalCmd } from "./commands/portal";

const [, , cmd, ...args] = process.argv;

if (!cmd || cmd === "--help" || cmd === "-h") {
	console.log(`atlas CLI (TypeScript commands)

Usage: atlas <command> [args]

Commands:
  portal     DevHub cockpit sync/status/diff (--help for details)

Examples:
  atlas portal --help
  atlas portal status
  atlas portal sync
  atlas portal diff --since-last-week`);
	process.exit(0);
}

switch (cmd) {
	case "portal":
		await portalCmd(args);
		break;
	default:
		console.error(`Unknown command: ${cmd}`);
		console.error("Run 'atlas --help' to see available commands.");
		process.exit(1);
}
