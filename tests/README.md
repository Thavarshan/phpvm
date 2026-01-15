# phpvm Test Suite

This directory contains the BATS (Bash Automated Testing System) test suite for phpvm.

## Structure

```
tests/
├── README.md           # This file
├── test_helper.bash    # Setup, teardown, and helper functions
├── 01_core.bats        # Core functionality tests
├── 02_features.bats    # Feature and placeholder tests
└── 03_error_handling.bats  # Error handling and edge case tests
```

## Running Tests

### All tests

```bash
# From project root
make test-bats

# Or directly with BATS
bats tests/
```

### Specific test file

```bash
bats tests/01_core.bats
```

### With verbose output

```bash
bats -t tests/
```

### With tap output (for CI)

```bash
bats -t tests/ | tee test-results.tap
```

## Writing Tests

### Basic test structure

```bash
#!/usr/bin/env bats

load test_helper

@test "description of what you're testing" {
    # Arrange - Setup test conditions
    local test_input="8.1"

    # Act - Execute the code
    run command_to_test "$test_input"

    # Assert - Verify results
    [ "$status" -eq 0 ]
    [ "$output" = "expected output" ]
}
```

### Using test helper

The `test_helper.bash` file provides:

- `setup()` - Runs before each test
- `teardown()` - Runs after each test
- `create_mock_php()` - Helper to create mock PHP installations
- Environment variables for testing

### Test naming conventions

- Use descriptive names that explain what is being tested
- Start with the command or function name
- Describe the expected behavior
- Example: `phpvm current shows no active version initially`

### Testing commands

```bash
# Test command execution
@test "command succeeds" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" command arg
    [ "$status" -eq 0 ]
}

# Test command output
@test "command outputs expected text" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" command
    [[ "$output" =~ "expected text" ]]
}

# Test command failure
@test "command fails with invalid input" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" command invalid
    [ "$status" -ne 0 ]
}
```

### Testing functions

```bash
# Test internal function
@test "function returns correct value" {
    run function_name arg1 arg2
    [ "$status" -eq 0 ]
    [ "$output" = "expected" ]
}
```

## Test Categories

### Core Tests (01_core.bats)

Tests for fundamental functionality:
- Version validation
- Input sanitization
- Directory operations
- File operations
- Version resolution
- Help and version commands

### Feature Tests (02_features.bats)

Tests for features (including placeholders):
- exec, run commands
- ls-remote command
- alias management
- cache management
- Help text content

### Error Handling Tests (03_error_handling.bats)

Tests for error conditions:
- Missing arguments
- Invalid input
- Edge cases
- Security validation
- Graceful degradation

## Best Practices

1. **Test one thing at a time** - Each test should verify a single behavior
2. **Use setup/teardown** - Keep tests independent
3. **Make tests readable** - Clear names and comments
4. **Test error cases** - Don't just test happy paths
5. **Use helpers** - Reduce duplication
6. **Keep tests fast** - Use mocks when possible

## Debugging Tests

### Run specific test

```bash
bats tests/01_core.bats -f "test name pattern"
```

### Print output during test

```bash
@test "debug test" {
    run command
    echo "Status: $status" >&3
    echo "Output: $output" >&3
    [ "$status" -eq 0 ]
}
```

### Run with verbose output

```bash
bats -t tests/
```

## Common Patterns

### Testing exit codes

```bash
run command
[ "$status" -eq 0 ]     # Success
[ "$status" -eq 1 ]     # General error
[ "$status" -eq 2 ]     # Invalid argument
[ "$status" -ne 0 ]     # Any error
```

### Testing output

```bash
run command
[ "$output" = "exact match" ]
[[ "$output" =~ "pattern" ]]
[[ "$output" =~ ^prefix ]]
```

### Testing file operations

```bash
[ -f "$file" ]          # File exists
[ -d "$dir" ]           # Directory exists
[ -x "$file" ]          # File is executable
[ ! -f "$file" ]        # File doesn't exist
```

## Adding New Tests

When adding new functionality:

1. Create test first (TDD approach)
2. Add test to appropriate file
3. Run test to see it fail
4. Implement feature
5. Run test to see it pass
6. Refactor if needed

## Integration with CI

These tests run automatically in GitHub Actions on:
- Every push to main/development branches
- Every pull request
- Weekly scheduled runs

See `.github/workflows/quality.yml` for CI configuration.

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [BATS GitHub](https://github.com/bats-core/bats-core)
- [Testing Best Practices](../TESTING.md)

---

**Test Coverage:** 50+ test cases
**Last Updated:** January 15, 2026
