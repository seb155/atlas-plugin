# ATLAS Plugin — Developer Makefile
# Usage: make [target]

.PHONY: build test install dev dev-domains lint sync publish clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build all 4 tiers (admin/dev/user/worker)
	./build.sh all

build-admin: ## Build admin tier only
	./build.sh admin

test: ## Run full test suite
	python3 -m pytest tests/ -x -q --tb=short

test-v: ## Run tests with verbose output
	python3 -m pytest tests/ -x --tb=short -v

install: ## Build all 4 + install to CC plugin cache
	./scripts/dev-install.sh

dev: install ## Build all 4 + install (standard workflow)

dev-admin: ## Quick admin-only build + install
	./scripts/dev-install.sh --admin-only

dev-domains: ## Build all 6 domain plugins + install to CC cache
	./build.sh domains
	@VERSION=$$(cat VERSION | tr -d '[:space:]'); \
	CACHE_DIR="$$HOME/.claude/plugins/cache"; \
	echo ""; \
	echo "📦 Installing domain plugins to CC cache..."; \
	for name in core dev frontend infra enterprise experiential; do \
		dir="$$CACHE_DIR/atlas-$${name}-marketplace/atlas-$${name}/$$VERSION"; \
		mkdir -p "$$dir"; \
		cp -r "dist/atlas-$${name}/." "$$dir/"; \
		echo "  ✅ atlas-$${name} → $$dir"; \
	done; \
	echo ""; \
	echo "✅ Installed 6 domain plugins v$$VERSION"

lint: ## Validate plugin structure (frontmatter, refs, profiles)
	@echo "Running structural checks..."
	@python3 -m pytest tests/test_skill_frontmatter.py tests/test_skill_coverage.py -x -q --tb=short 2>/dev/null || python3 -m pytest tests/ -k "frontmatter or coverage" -x -q --tb=short

sync: ## Show diff between synapse and dev-plugin repos
	./scripts/sync-repos.sh --status

sync-both: ## Sync both directions
	./scripts/sync-repos.sh --both

publish-patch: ## Release patch version bump
	./scripts/publish.sh patch

publish-minor: ## Release minor version bump
	./scripts/publish.sh minor

clean: ## Remove build artifacts
	rm -rf dist/
	@echo "Cleaned dist/"
