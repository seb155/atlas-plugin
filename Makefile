# ATLAS Plugin — Developer Makefile
# Usage: make [target]

.PHONY: build test install dev lint sync publish clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build all 3 tiers (admin/dev/user)
	./build.sh all

build-admin: ## Build admin tier only
	./build.sh admin

test: ## Run full test suite
	python3 -m pytest tests/ -x -q --tb=short

test-v: ## Run tests with verbose output
	python3 -m pytest tests/ -x --tb=short -v

install: ## Build admin + install to CC plugin cache
	./scripts/dev-install.sh

dev: build-admin install ## Build admin + install (alias for quick iteration)

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
