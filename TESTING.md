# Testing Guide for phpvm

This document describes the testing infrastructure for phpvm and how to run tests.

## Overview

phpvm uses a multi-layered testing approach:

1. **Built-in Tests** - Self-tests within phpvm.sh
2. **BATS Tests** - Comprehensive test suite using BATS framework
3. **ShellCheck** - Static analysis and linting
4. **shfmt** - Code formatting verification
5. **CI/CD** - Automated testing on multiple platforms

## Quick Start

### Install Testing Tools

```bash
# Install all development dependencies
make install

# Or install individually:
brew install shellcheck shfmt bats-core  # macOS
sudo apt-get install shellcheck bats    # Debian/Ubuntu
```

### Run Tests

```bash
# Run all checks (recommended)
make check

# Run individual test suites
make test           # Built-in tests
make test-bats      # BATS test suite
make lint           # ShellCheck analysis
make format-check   # Formatting verification

# Run all tests
make test-all
```

## Testing Infrastructure

### 1. Built-in Tests (`phpvm test`)

phpvm includes comprehensive self-tests that verify core functionality:

```bash
./phpvm.sh test
```

**What it tests:**
- Input sanitization
- Version validation
- Directory creation
- File operations
- PATH management
- Environment detection
- Package manager detection

**Advantages:**
- No external dependencies
- Runs in test mode (no system changes)
- Fast execution
- Built into the tool

### 2. BATS Test Suite

BATS (Bash Automated Testing System) provides comprehensive integration testing.

**Location:** `tests/` directory

**Test files:**
- `tests/test_helper.bash` - Setup, teardown, and helper functions
- `tests/01_core.bats` - Core functionality tests
- `tests/02_features.bats` - Placeholder feature tests
- `tests/03_error_handling.bats` - Error handling and edge cases

**Run BATS tests:**

```bash
# Run all BATS tests
make test-bats

# Or directly with BATS
bats tests/

# Run specific test file
bats tests/01_core.bats

# Run with verbose output
bats -t tests/
```

**Writing BATS tests:**

```bash
#!/usr/bin/env bats

load test_helper

@test "description of what you're testing" {
    run command_to_test
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected output" ]]
}
```

### 3. ShellCheck - Static Analysis

ShellCheck analyzes shell scripts for common issues, security problems, and style violations.

**Configuration:** `.shellcheckrc`

**Run linting:**

```bash
# Run ShellCheck
make lint

# Or directly
shellcheck phpvm.sh install.sh
```

**What it checks:**
- Syntax errors
- Semantic problems
- Security issues (command injection, etc.)
- Portability issues
- Style violations

### 4. shfmt - Code Formatting

shfmt formats shell scripts consistently.

**Configuration:** Follows `.editorconfig` (4-space indentation)

**Run formatting:**

```bash
# Format code
make format

# Check formatting (CI mode)
make format-check

# Or directly
shfmt -w -i 4 -sr phpvm.sh install.sh  # Format
shfmt -d -i 4 -sr phpvm.sh install.sh  # Check only
```

## Makefile Commands

The Makefile provides convenient shortcuts for all testing operations:

| Command              | Description                      |
| -------------------- | -------------------------------- |
| `make help`          | Display all available commands   |
| `make install`       | Install development dependencies |
| `make install-hooks` | Install git pre-commit hooks     |
| `make lint`          | Run ShellCheck linter            |
| `make format`        | Format code with shfmt           |
| `make format-check`  | Check formatting (CI)            |
| `make test`          | Run built-in tests               |
| `make test-bats`     | Run BATS test suite              |
| `make test-all`      | Run all tests                    |
| `make check`         | Run all checks                   |
| `make clean`         | Remove temporary files           |
| `make release`       | Prepare for release              |

## Git Pre-commit Hooks

Install pre-commit hooks to automatically run checks before each commit:

```bash
make install-hooks
```

**What the hook does:**
1. Checks code formatting
2. Runs linter (ShellCheck)
3. Prevents commit if checks fail

**Skip hooks temporarily:**

```bash
git commit --no-verify
```

## Continuous Integration

### GitHub Actions Workflows

phpvm uses GitHub Actions for automated testing:

**Workflows:**
- **test.yml** - Main test suite (syntax, core tests, multi-platform)
- **security-test.yml** - Security analysis
- **release.yml** - Release automation

**Platforms tested:**
- Ubuntu (latest)
- macOS (latest)
- Multiple Linux distributions (Debian, Fedora, Arch, Alpine, Rocky, Alma)

**Package managers tested:**
- Homebrew (macOS)
- apt (Debian/Ubuntu)
- dnf (Fedora/RHEL)
- yum (CentOS/RHEL)
- pacman (Arch)

### Run CI Locally

```bash
# Simulate CI checks
make check

# Or step by step
make lint
make format-check
make test
make test-bats
```

## Test Coverage

### Current Coverage

**Built-in tests:** 14+ test functions covering:
- ✅ Input validation and sanitization
- ✅ Version format validation
- ✅ Directory operations
- ✅ File operations (atomic writes)
- ✅ PATH management
- ✅ Version switching
- ✅ Deactivation
- ✅ .phpvmrc detection

**BATS tests:** 40+ test cases covering:
- ✅ Core functionality
- ✅ Command-line interface
- ✅ Error handling
- ✅ Edge cases
- ✅ Placeholder features
- ✅ Input validation
- ✅ File system operations

### Adding Tests

When adding new features, always add tests:

1. **Add built-in test** in `phpvm.sh` `run_tests()` function
2. **Add BATS test** in appropriate `tests/*.bats` file
3. **Update this document** with new test information

**Example - Adding a BATS test:**

```bash
# tests/01_core.bats

@test "new feature works correctly" {
    # Setup
    local test_input="8.1"

    # Execute
    run new_function "$test_input"

    # Assert
    [ "$status" -eq 0 ]
    [ "$output" = "expected result" ]
}
```

## Best Practices

### Test Writing

1. **Test one thing at a time** - Each test should verify a single behavior
2. **Use descriptive names** - Test names should clearly describe what's being tested
3. **Test error cases** - Don't just test the happy path
4. **Use setup/teardown** - Clean up after tests
5. **Make tests independent** - Tests shouldn't depend on each other

### Test Organization

1. **Group related tests** - Use separate files for different concerns
2. **Order logically** - Run fast tests first
3. **Use helpers** - Extract common setup into helper functions
4. **Document edge cases** - Add comments for non-obvious test cases

### Running Tests During Development

```bash
# Quick feedback loop
make lint && make test

# Before committing
make check

# Full test suite
make test-all
```

## Troubleshooting

### BATS not found

```bash
# Install BATS
./install-bats.sh

# Or via package manager
brew install bats-core  # macOS
sudo apt-get install bats  # Debian/Ubuntu
```

### ShellCheck not found

```bash
# Install ShellCheck
brew install shellcheck  # macOS
sudo apt-get install shellcheck  # Debian/Ubuntu
sudo dnf install ShellCheck  # Fedora/RHEL
```

### shfmt not found

```bash
# Install shfmt
brew install shfmt  # macOS

# Or with Go
GO111MODULE=on go install mvdan.cc/sh/v3/cmd/shfmt@latest
```

### Tests fail in CI but pass locally

1. Check that you're using the same environment
2. Verify all dependencies are installed
3. Check for platform-specific issues
4. Review CI logs for specific error messages

### Pre-commit hook fails

```bash
# Fix formatting
make format

# Fix linting issues
make lint

# Re-run checks
make check
```

## Performance

### Test Execution Times

Approximate execution times on modern hardware:

- **Built-in tests:** ~2-5 seconds
- **BATS tests:** ~5-10 seconds
- **ShellCheck:** ~1-2 seconds
- **Format check:** ~1 second
- **Full suite:** ~10-20 seconds

### Optimizing Tests

- Run fast tests first (linting, formatting)
- Use test mode to avoid system changes
- Mock external dependencies
- Parallelize when possible (BATS supports `-j` flag)

## Future Enhancements

Planned testing improvements:

- [ ] Code coverage reporting (using kcov)
- [ ] Performance benchmarking
- [ ] Mutation testing
- [ ] Fuzz testing for input validation
- [ ] Integration tests with real PHP installations
- [ ] Cross-platform compatibility matrix
- [ ] Stress testing (many versions, rapid switches)

## Contributing

When contributing to phpvm:

1. **Write tests first** (TDD approach)
2. **Ensure all tests pass** (`make check`)
3. **Add tests for bug fixes**
4. **Document test scenarios**
5. **Follow existing test patterns**

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [shfmt Documentation](https://github.com/mvdan/sh)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide/Practices)

---

**Last Updated:** January 15, 2026
**Test Suite Version:** 2.0
**Total Tests:** 50+ test cases
