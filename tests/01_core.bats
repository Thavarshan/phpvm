#!/usr/bin/env bats
# BATS test suite for phpvm - Core functionality tests

bats_require_minimum_version 1.5.0

load test_helper

@test "phpvm version command works" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "phpvm version" ]]
}

@test "phpvm help command displays help" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "phpvm - PHP Version Manager" ]]
    [[ "$output" =~ "Usage:" ]]
}

@test "sanitize_input rejects dangerous characters" {
    run sanitize_input "8.1; rm -rf /"
    [ "$status" -ne 0 ]
}

@test "sanitize_input accepts valid version" {
    run sanitize_input "8.1"
    [ "$status" -eq 0 ]
    [ "$output" = "8.1" ]
}

@test "validate_php_version accepts valid version format" {
    run validate_php_version "8.1"
    [ "$status" -eq 0 ]
}

@test "validate_php_version accepts system" {
    run validate_php_version "system"
    [ "$status" -eq 0 ]
}

@test "validate_php_version rejects invalid format" {
    run validate_php_version "abc"
    [ "$status" -ne 0 ]
}

@test "create_directories creates required structure" {
    [ -d "$PHPVM_VERSIONS_DIR" ]
    [ -d "$PHPVM_DIR/alias" ]
    [ -d "$PHPVM_DIR/cache" ]
}

@test "phpvm_resolve_version returns input when no alias exists" {
    run phpvm_resolve_version "8.1"
    [ "$status" -eq 0 ]
    [ "$output" = "8.1" ]
}

@test "phpvm_atomic_write creates file safely" {
    local test_file="$TEST_DIR/test.txt"
    run phpvm_atomic_write "$test_file" "test content"
    [ "$status" -eq 0 ]
    [ -f "$test_file" ]
    [ "$(cat "$test_file")" = "test content" ]
}

@test "phpvm_has_colors detects color support" {
    # This should work in most environments
    run phpvm_has_colors
    # Status should be 0 (colors supported) or 1 (not supported)
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "unknown command returns correct exit code" {
    run -127 bash "$BATS_TEST_DIRNAME/../phpvm.sh" unknown-command
    [ "$status" -eq 127 ]
}

@test "phpvm current shows no active version initially" {
    run phpvm_current
    # Accept either "none" (no PHP) or "system" (system PHP exists)
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    [[ "$output" = "none" ]] || [[ "$output" = "system" ]]
}

@test "find_phpvmrc returns error when no file exists" {
    cd "$TEST_DIR"
    run find_phpvmrc
    [ "$status" -eq 1 ]
}

@test "find_phpvmrc finds file in current directory" {
    cd "$TEST_DIR"
    echo "8.1" > .phpvmrc
    run find_phpvmrc
    [ "$status" -eq 0 ]
    [[ "$output" =~ ".phpvmrc" ]]
}

@test "find_phpvmrc finds file in parent directory" {
    cd "$TEST_DIR"
    echo "8.1" > .phpvmrc
    mkdir -p subdir
    cd subdir
    run find_phpvmrc
    [ "$status" -eq 0 ]
    [[ "$output" =~ ".phpvmrc" ]]
}
