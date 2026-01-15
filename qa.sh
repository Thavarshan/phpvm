#!/bin/bash
# Quality Assurance Script for phpvm
# Runs all quality checks: linting, formatting, and tests

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track failures
FAILED=0

# Banner
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   phpvm Quality Assurance Check        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Function to run check
run_check() {
    local name="$1"
    local command="$2"

    echo -e "${BLUE}▶ Running: ${name}${NC}"

    if eval "$command"; then
        echo -e "${GREEN}✓ ${name} passed${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ ${name} failed${NC}"
        echo ""
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Check if commands exist
check_dependencies() {
    local missing=()

    command -v shellcheck >/dev/null 2>&1 || missing+=("shellcheck")
    command -v shfmt >/dev/null 2>&1 || missing+=("shfmt")
    command -v bats >/dev/null 2>&1 || missing+=("bats")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: Missing dependencies: ${missing[*]}${NC}"
        echo -e "${YELLOW}Run 'make install' to install all dependencies${NC}"
        echo ""
        return 1
    fi

    return 0
}

# Step 1: Check dependencies
echo -e "${BLUE}Step 1/5: Checking dependencies${NC}"
if check_dependencies; then
    echo -e "${GREEN}✓ All dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠ Some dependencies missing (will skip those checks)${NC}"
fi
echo ""

# Step 2: ShellCheck (Linting)
if command -v shellcheck >/dev/null 2>&1; then
    run_check "ShellCheck Linting" "shellcheck phpvm.sh install.sh" || true
else
    echo -e "${YELLOW}⚠ Skipping ShellCheck (not installed)${NC}"
    echo ""
fi

# Step 3: Code Formatting Check
if command -v shfmt >/dev/null 2>&1; then
    run_check "Code Formatting Check" "shfmt -d -i 4 -sr phpvm.sh install.sh" || true
else
    echo -e "${YELLOW}⚠ Skipping format check (shfmt not installed)${NC}"
    echo ""
fi

# Step 4: Built-in Tests
run_check "Built-in Tests" "bash phpvm.sh test" || true

# Step 5: BATS Test Suite
if command -v bats >/dev/null 2>&1 && [ -d "tests" ]; then
    run_check "BATS Test Suite" "bats tests/" || true
else
    if [ ! -d "tests" ]; then
        echo -e "${YELLOW}⚠ Skipping BATS tests (tests/ directory not found)${NC}"
    else
        echo -e "${YELLOW}⚠ Skipping BATS tests (bats not installed)${NC}"
    fi
    echo ""
fi

# Summary
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}           Summary                      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! 🎉${NC}"
    echo ""
    echo "Your code is ready to commit!"
    exit 0
else
    echo -e "${RED}✗ ${FAILED} check(s) failed${NC}"
    echo ""
    echo "Please fix the issues above before committing."
    echo ""
    echo "Quick fixes:"
    echo "  • Run 'make format' to fix formatting issues"
    echo "  • Run 'make lint' to see detailed linting errors"
    echo "  • Run 'make test' to run tests individually"
    exit 1
fi
