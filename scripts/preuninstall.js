#!/usr/bin/env node
// ATLAS CLI — NPM preuninstall hook (P6.2, v5.28.0+)
// Runs before package removal. Preserves user data.

'use strict';

console.log('');
console.log('👋 Uninstalling @axoiq/atlas-cli');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');
console.log('User data preserved:');
console.log('  ~/.atlas/profiles/       — your launch profiles');
console.log('  ~/.atlas/mcp-profiles/   — your MCP bundles');
console.log('  ~/.atlas/config.json     — user config');
console.log('');
console.log('Installed bash files (atlas.sh + modules) will be removed by npm.');
console.log('');
console.log('To fully clean up (optional):');
console.log('  rm -rf ~/.atlas/{shell,profiles,mcp-profiles,runtime}');
console.log('');
console.log('To remove source line from shell config:');
console.log('  sed -i "/atlas.sh/d" ~/.zshrc ~/.bashrc 2>/dev/null');
console.log('');

// Exit 0 — never fail preuninstall
process.exit(0);
