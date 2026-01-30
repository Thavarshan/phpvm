#!/usr/bin/env bats
# BATS test suite for phpvm - Error handling and edge cases

load test_helper

@test "phpvm with no arguments shows error" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "No command provided" ]]
}

@test "phpvm install with no version shows error" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" install
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Missing PHP version argument" ]]
}

@test "phpvm use with no version shows error" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" use
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Missing PHP version argument" ]]
}

@test "phpvm uninstall with no version shows error" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" uninstall
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Missing PHP version argument" ]]
}

@test "sanitize_input rejects empty input" {
    run sanitize_input ""
    [ "$status" -eq 1 ]
}

@test "sanitize_input rejects input that is too long" {
    run sanitize_input "8.1.0.0.0.0.0.0.0.0.0.0"
    [ "$status" -eq 1 ]
}

@test "sanitize_input rejects semicolon" {
    run sanitize_input "8.1;"
    [ "$status" -eq 1 ]
}

@test "sanitize_input rejects pipe" {
    run sanitize_input "8.1|"
    [ "$status" -eq 1 ]
}

@test "sanitize_input rejects dollar sign" {
    run sanitize_input "8.1\$"
    [ "$status" -eq 1 ]
}

@test "sanitize_input rejects backticks" {
    run sanitize_input "8.1\`"
    [ "$status" -eq 1 ]
}

@test "validate_php_version rejects empty string" {
    run validate_php_version ""
    [ "$status" -eq 2 ]
}

@test "validate_php_version rejects version with letters" {
    run validate_php_version "8.1.abc"
    [ "$status" -eq 2 ]
}

@test "validate_php_version accepts 8.1 format" {
    run validate_php_version "8.1"
    [ "$status" -eq 0 ]
}

@test "validate_php_version accepts 8.1.0 format" {
    run validate_php_version "8.1.0"
    [ "$status" -eq 0 ]
}

@test "phpvm_atomic_write handles directory creation" {
    local test_file="$TEST_DIR/subdir/test.txt"
    mkdir -p "$(dirname "$test_file")"
    run phpvm_atomic_write "$test_file" "content"
    [ "$status" -eq 0 ]
    [ -f "$test_file" ]
}

@test "auto_switch_php_version fails gracefully with invalid .phpvmrc" {
    cd "$TEST_DIR"
    echo "invalid-version!" > .phpvmrc
    run auto_switch_php_version
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid PHP version format" ]]
}

@test "auto_switch_php_version fails gracefully with empty .phpvmrc" {
    cd "$TEST_DIR"
    touch .phpvmrc
    run auto_switch_php_version
    [ "$status" -eq 1 ]
}

@test "phpvm_deactivate is idempotent" {
    run phpvm_deactivate true
    [ "$status" -eq 0 ]
    run phpvm_deactivate true
    [ "$status" -eq 0 ]
}

# Security tests for path traversal protection
@test "phpvm alias rejects path traversal in name" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" alias "../../../etc/passwd" "8.2"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Invalid alias name" ]]
}

@test "phpvm alias rejects slash in name" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" alias "foo/bar" "8.2"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Invalid alias name" ]]
}

@test "phpvm_validate_alias_name rejects path traversal" {
    run phpvm_validate_alias_name "../../../etc/passwd"
    [ "$status" -eq 1 ]
}

@test "phpvm_validate_alias_name accepts valid names" {
    run phpvm_validate_alias_name "default"
    [ "$status" -eq 0 ]
    run phpvm_validate_alias_name "my-alias_123"
    [ "$status" -eq 0 ]
}
