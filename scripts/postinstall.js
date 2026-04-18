#!/usr/bin/env node
// ATLAS CLI — NPM postinstall hook (P6.2, v5.28.0+)
// Copies bash launcher + modules + seed profiles to ~/.atlas/
// Idempotent: safe to re-run; preserves user-customized profiles

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const ATLAS_SHELL = path.join(HOME, '.atlas', 'shell');
const ATLAS_MODULES = path.join(ATLAS_SHELL, 'modules');
const ATLAS_PROFILES = path.join(HOME, '.atlas', 'profiles');
const ATLAS_MCP_PROFILES = path.join(HOME, '.atlas', 'mcp-profiles');

const PKG_ROOT = path.join(__dirname, '..');

function mkdirp(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function copyFile(src, dest) {
  fs.copyFileSync(src, dest);
  try { fs.chmodSync(dest, 0o755); } catch (_) { /* ignore */ }
}

function copyDir(src, dest, ext) {
  if (!fs.existsSync(src)) return 0;
  mkdirp(dest);
  const entries = fs.readdirSync(src, { withFileTypes: true });
  let count = 0;
  for (const entry of entries) {
    if (entry.isFile() && (!ext || entry.name.endsWith(ext))) {
      copyFile(path.join(src, entry.name), path.join(dest, entry.name));
      count++;
    }
  }
  return count;
}

function main() {
  console.log('');
  console.log('📦 Installing ATLAS CLI');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    mkdirp(ATLAS_SHELL);
    mkdirp(ATLAS_MODULES);

    // Copy main launcher
    const srcCli = path.join(PKG_ROOT, 'scripts', 'atlas-cli.sh');
    const destCli = path.join(ATLAS_SHELL, 'atlas.sh');
    copyFile(srcCli, destCli);
    console.log(`  ✅ atlas.sh → ${destCli}`);

    // Update ATLAS_VERSION in atlas.sh to match package version
    try {
      const pkg = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, 'package.json'), 'utf8'));
      let content = fs.readFileSync(destCli, 'utf8');
      content = content.replace(/^ATLAS_VERSION=.*/m, `ATLAS_VERSION="${pkg.version}"`);
      fs.writeFileSync(destCli, content);
      console.log(`  ✅ ATLAS_VERSION set to ${pkg.version}`);
    } catch (e) {
      console.log(`  ⚠️  Version sync skipped: ${e.message}`);
    }

    // Copy modules
    const srcModules = path.join(PKG_ROOT, 'scripts', 'atlas-modules');
    const modCount = copyDir(srcModules, ATLAS_MODULES, '.sh');
    console.log(`  ✅ modules/ → ${ATLAS_MODULES} (${modCount} modules)`);

    // Seed profiles (don't overwrite if user has customizations)
    if (!fs.existsSync(ATLAS_PROFILES) || fs.readdirSync(ATLAS_PROFILES).length === 0) {
      const n = copyDir(path.join(PKG_ROOT, 'templates', 'profiles'), ATLAS_PROFILES, '.yaml');
      if (n > 0) console.log(`  ✅ profiles/ → ${ATLAS_PROFILES} (${n} seeded)`);
    } else {
      console.log(`  ℹ️  profiles/ exists — user customizations preserved`);
    }

    // Seed MCP profiles
    if (!fs.existsSync(ATLAS_MCP_PROFILES) || fs.readdirSync(ATLAS_MCP_PROFILES).length === 0) {
      const n = copyDir(path.join(PKG_ROOT, 'templates', 'mcp-profiles'), ATLAS_MCP_PROFILES, '.yaml');
      if (n > 0) console.log(`  ✅ mcp-profiles/ → ${ATLAS_MCP_PROFILES} (${n} seeded)`);
    } else {
      console.log(`  ℹ️  mcp-profiles/ exists — preserved`);
    }

    console.log('');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✨ ATLAS CLI installed successfully!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');
    console.log('Next steps:');
    console.log('  1. Add to ~/.zshrc (or ~/.bashrc):');
    console.log('       [ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"');
    console.log('');
    console.log('  2. Optional — enable auto-detect profile from cwd:');
    console.log('       export ATLAS_AUTO_DETECT_PROFILE=true');
    console.log('');
    console.log('  3. Reload shell:');
    console.log('       source ~/.zshrc');
    console.log('');
    console.log('  4. Test installation:');
    console.log('       atlas profile list');
    console.log('       atlas --detect-only');
    console.log('');
    console.log('Docs: https://forgejo.axoiq.com/axoiq/atlas-plugin/src/branch/main/docs/');
    console.log('');
  } catch (err) {
    console.error('');
    console.error('❌ ATLAS CLI install failed:');
    console.error(`   ${err.message}`);
    console.error('');
    console.error('Non-fatal: npm install will continue.');
    console.error('You can manually install by running:');
    console.error('   cd <package-dir> && bash scripts/install-manual.sh');
    console.error('');
    // Non-fatal: don't break npm install
    process.exit(0);
  }
}

main();
