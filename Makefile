# Makefile for phpvm - PHP Version Manager
# Provides convenient commands for development, testing, and quality assurance

.PHONY: help install test lint format check clean release

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

## help: Display this help message
help:
	@echo "$(BLUE)phpvm Development Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  make install        Install development dependencies"
	@echo "  make install-hooks  Install git pre-commit hooks"
	@echo ""
	@echo "$(GREEN)Quality Assurance:$(NC)"
	@echo "  make lint           Run shellcheck linter"
	@echo "  make format         Format code with shfmt"
	@echo "  make format-check   Check if code is formatted (CI)"
	@echo "  make check          Run all checks (lint + format-check + test)"
	@echo ""
	@echo "$(GREEN)Testing:$(NC)"
	@echo "  make test           Run BATS test suite"
	@echo "  make test-all       Run all tests"
	@echo "  make coverage       Run tests with coverage (if available)"
	@echo ""
	@echo "$(GREEN)Cleanup:$(NC)"
	@echo "  make clean          Remove temporary files and caches"
	@echo ""
	@echo "$(GREEN)Release:$(NC)"
	@echo "  make release        Prepare for release (check + test)"
	@echo ""

## install: Install development dependencies
install:
	@echo "$(BLUE)Installing development dependencies...$(NC)"
	@command -v shellcheck >/dev/null 2>&1 || { \
		echo "$(YELLOW)Installing shellcheck...$(NC)"; \
		if [ "$$(uname)" = "Darwin" ]; then \
			brew install shellcheck; \
		elif command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y shellcheck; \
		elif command -v dnf >/dev/null 2>&1; then \
			sudo dnf install -y ShellCheck; \
		else \
			echo "$(RED)Please install shellcheck manually$(NC)"; \
		fi; \
	}
	@command -v shfmt >/dev/null 2>&1 || { \
		echo "$(YELLOW)Installing shfmt...$(NC)"; \
		if [ "$$(uname)" = "Darwin" ]; then \
			brew install shfmt; \
		else \
			GO111MODULE=on go install mvdan.cc/sh/v3/cmd/shfmt@latest 2>/dev/null || \
			echo "$(RED)Please install shfmt manually: https://github.com/mvdan/sh$(NC)"; \
		fi; \
	}
	@command -v bats >/dev/null 2>&1 || { \
		echo "$(YELLOW)Installing BATS...$(NC)"; \
		./install-bats.sh; \
	}
	@echo "$(GREEN)Development dependencies installed!$(NC)"

## install-hooks: Install git pre-commit hooks
install-hooks:
	@echo "$(BLUE)Installing git pre-commit hooks...$(NC)"
	@mkdir -p .git/hooks
	@cat > .git/hooks/pre-commit << 'EOF'\n\
#!/bin/bash\n\
# phpvm pre-commit hook\n\
\n\
echo "Running pre-commit checks..."\n\
\n\
# Run format check\n\
if ! make format-check; then\n\
    echo "Error: Code formatting issues detected. Run 'make format' to fix."\n\
    exit 1\n\
fi\n\
\n\
# Run linter\n\
if ! make lint; then\n\
    echo "Error: Linting issues detected. Please fix before committing."\n\
    exit 1\n\
fi\n\
\n\
echo "Pre-commit checks passed!"\n\
exit 0\n\
EOF
	@chmod +x .git/hooks/pre-commit
	@echo "$(GREEN)Git hooks installed!$(NC)"

## lint: Run shellcheck linter
lint:
	@echo "$(BLUE)Running ShellCheck...$(NC)"
	@shellcheck phpvm.sh install.sh || { \
		echo "$(RED)Linting failed!$(NC)"; \
		exit 1; \
	}
	@echo "$(GREEN)Linting passed!$(NC)"

## format: Format code with shfmt
format:
	@echo "$(BLUE)Formatting shell scripts...$(NC)"
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -w -i 4 -sr phpvm.sh install.sh; \
		echo "$(GREEN)Formatting complete!$(NC)"; \
	else \
		echo "$(RED)shfmt not found. Run 'make install' first.$(NC)"; \
		exit 1; \
	fi

## format-check: Check if code is formatted (for CI)
format-check:
	@echo "$(BLUE)Checking code formatting...$(NC)"
	@if command -v shfmt >/dev/null 2>&1; then \
		if shfmt -d -i 4 -sr phpvm.sh install.sh | grep -q .; then \
			echo "$(RED)Code formatting issues detected. Run 'make format' to fix.$(NC)"; \
			shfmt -d -i 4 -sr phpvm.sh install.sh; \
			exit 1; \
		else \
			echo "$(GREEN)Code formatting is correct!$(NC)"; \
		fi; \
	else \
		echo "$(YELLOW)shfmt not found, skipping format check$(NC)"; \
	fi

## test: Run BATS test suite
test: test-bats

## test-bats: Run BATS test suite
test-bats:
	@echo "$(BLUE)Running BATS test suite...$(NC)"
	@if [ -d "tests" ]; then \
		if command -v bats >/dev/null 2>&1; then \
			bats tests/ || { \
				echo "$(RED)BATS tests failed!$(NC)"; \
				exit 1; \
			}; \
			echo "$(GREEN)BATS tests passed!$(NC)"; \
		else \
			echo "$(YELLOW)BATS not installed. Run 'make install' first.$(NC)"; \
		fi; \
	else \
		echo "$(YELLOW)No BATS tests found in tests/ directory$(NC)"; \
	fi

## test-all: Run all tests
test-all: test test-bats
	@echo "$(GREEN)All tests passed!$(NC)"

## coverage: Run tests with coverage (placeholder for future enhancement)
coverage:
	@echo "$(YELLOW)Code coverage for shell scripts requires additional tooling$(NC)"
	@echo "Consider using: https://github.com/SimonKagstrom/kcov"

## check: Run all quality checks
check: lint format-check test
	@echo "$(GREEN)All checks passed!$(NC)"

## clean: Remove temporary files and caches
clean:
	@echo "$(BLUE)Cleaning up...$(NC)"
	@find . -name "*.tmp" -delete
	@find . -name "*~" -delete
	@rm -rf .phpvm-test-*
	@rm -rf /tmp/phpvm-test-*
	@echo "$(GREEN)Cleanup complete!$(NC)"

## release: Prepare for release
release: check
	@echo "$(GREEN)Ready for release!$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Update CHANGELOG.md with release notes"
	@echo "  2. Update version in phpvm.sh (PHPVM_VERSION)"
	@echo "  3. Commit changes: git commit -am 'chore: prepare vX.Y.Z release'"
	@echo "  4. Create tag: git tag -a vX.Y.Z -m 'Release vX.Y.Z'"
	@echo "  5. Push: git push origin main --tags"

# Prevent make from treating files as targets
.NOTPARALLEL:
