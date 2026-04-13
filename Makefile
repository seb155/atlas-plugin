# ATLAS Plugin — Developer Makefile (modular architecture)
# Usage: make [target]

.PHONY: build build-modular build-v5 test install dev dev-modular lint publish clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ── Modular Targets (PRIMARY — core + addons) ──────────────────────

build-modular: ## Build modular plugins (core + all addons)
	./build.sh modular

build-v5: build-modular ## DEPRECATED alias for build-modular

build-core: ## Build atlas-core only
	./build.sh modular-core

build-admin: ## Build atlas-admin addon only
	./build.sh modular-admin

build-dev-addon: ## Build atlas-dev addon only
	./build.sh modular-dev

dev: ## Build core + admin + install to CC cache (standard workflow)
	./build.sh modular
	@VERSION=$$(cat VERSION | tr -d '[:space:]'); \
	CACHE_DIR="$$HOME/.claude/plugins/cache/atlas-marketplace"; \
	echo ""; \
	echo "📦 Installing modular plugins to CC cache..."; \
	for plugin in atlas-core atlas-admin-addon; do \
		name=$$(echo $$plugin | sed 's/-addon//'); \
		dir="$$CACHE_DIR/$${name}/$$VERSION"; \
		mkdir -p "$$dir"; \
		cp -r "dist/$${plugin}/." "$$dir/" && \
		cp -r "dist/$${plugin}/.claude-plugin" "$$dir/" 2>/dev/null; \
		echo "  ✅ $${name} → $$dir"; \
	done; \
	if [ -f "scripts/atlas-cli.sh" ]; then \
		mkdir -p "$$HOME/.atlas/shell"; \
		cp scripts/atlas-cli.sh "$$HOME/.atlas/shell/atlas.sh"; \
		sed -i "s/^ATLAS_VERSION=.*/ATLAS_VERSION=\"$$VERSION\"/" "$$HOME/.atlas/shell/atlas.sh"; \
		chmod +x "$$HOME/.atlas/shell/atlas.sh"; \
		echo "  ✅ atlas-cli.sh → $$HOME/.atlas/shell/atlas.sh (v$$VERSION)"; \
	fi; \
	if [ -d "scripts/atlas-modules" ]; then \
		mkdir -p "$$HOME/.atlas/shell/modules"; \
		cp scripts/atlas-modules/*.sh "$$HOME/.atlas/shell/modules/"; \
		chmod +x "$$HOME/.atlas/shell/modules/"*.sh; \
		echo "  ✅ atlas-modules/ → $$HOME/.atlas/shell/modules/ ($$(ls scripts/atlas-modules/*.sh | wc -l) modules)"; \
	fi; \
	echo ""; \
	echo "✅ Installed modular plugins v$$VERSION"; \
	echo "   Cache: $$CACHE_DIR/"; \
	echo ""; \
	echo "⚠️  Restart Claude Code to apply changes."; \
	echo ""; \
	echo "📋 Next steps:"; \
	echo "   1. Restart Claude Code      (picks up plugin changes)"; \
	echo "   2. source ~/.zshrc          (reload shell with new atlas.sh)"

# ── Legacy Targets (backward compat) ─────────────────────────

build: ## Build legacy tiers (admin/dev/user) — DEPRECATED, use build-modular
	./build.sh all

install: ## Legacy install — DEPRECATED, use 'make dev'
	./scripts/dev-install.sh

# ── Testing ──────────────────────────────────────────────────

test: ## Run full test suite
	python3 -m pytest tests/ -x -q --tb=short

test-v: ## Run tests with verbose output
	python3 -m pytest tests/ -x --tb=short -v

test-l1: ## Run L1 structural tests only (<25s)
	python3 -m pytest tests/ -m "not build and not integration and not broken" -x -q --tb=short

lint: ## Validate plugin structure (frontmatter, refs)
	@echo "Running structural checks..."
	@python3 -m pytest tests/test_skill_frontmatter.py tests/test_skill_coverage.py -x -q --tb=short

# ── Release ──────────────────────────────────────────────────

publish-patch: ## Release patch version bump
	./scripts/publish.sh patch

publish-minor: ## Release minor version bump
	./scripts/publish.sh minor

# ── Utilities ────────────────────────────────────────────────

export-cursor: ## Export top 15 skills to Cursor .mdc rules format
	bash scripts/export-cursor.sh

clean: ## Remove build artifacts
	rm -rf dist/
	@echo "Cleaned dist/"
