#!/usr/bin/env bats
# Composer-aware project version detection and constraint matching.

load test_helper

# Print the candidates that satisfy a constraint, space-separated
matching() {
    printf '%s\n' 7.4 8.0 8.1 8.2 8.3 8.4 9.0 | phpvm_filter_by_constraint "$1" | paste -s -d ' ' -
}

# Fail with the actual matches when they differ from the expected list
assert_matches() {
    local actual
    actual=$(matching "$1")
    if [ "$actual" != "$2" ]; then
        printf "constraint '%s': expected '%s', got '%s'\n" "$1" "$2" "$actual" >&2
        return 1
    fi
}

write_composer() {
    mkdir -p "$1"
    printf '%s\n' "$2" > "$1/composer.json"
}

# --- constraint matching ---

@test "caret and tilde constraints follow Composer semantics" {
    assert_matches '^8.1' "8.1 8.2 8.3 8.4"
    assert_matches '~8.2' "8.2 8.3 8.4"
    assert_matches '~8.2.0' "8.2"
}

@test "comparison constraints combine with spaces or commas" {
    assert_matches '>=8.1 <8.3' "8.1 8.2"
    assert_matches '>=8.1,<8.3' "8.1 8.2"
    assert_matches '>= 8.1, < 8.3' "8.1 8.2"
    assert_matches '<=8.1' "7.4 8.0 8.1"
    assert_matches '>=8.4' "8.4 9.0"
}

@test "wildcards, hyphen ranges and exact versions match whole minors" {
    assert_matches '8.2.*' "8.2"
    assert_matches '8.*' "8.0 8.1 8.2 8.3 8.4"
    assert_matches '8.1 - 8.2' "8.1 8.2"
    assert_matches '8.2.12' "8.2"
    assert_matches 'v8.2' "8.2"
}

@test "alternatives and stability flags are supported" {
    assert_matches '^7.4 || ^8.3' "7.4 8.3 8.4"
    assert_matches '^7.4|^8.3' "7.4 8.3 8.4"
    assert_matches '^8.3@dev' "8.3 8.4"
    assert_matches '^8.5' ""
}

@test "unusable constraints are reported" {
    run phpvm_filter_by_constraint "not-a-version" <<< "8.2"
    [ "$status" -eq 2 ]
    run phpvm_validate_constraint '$(id)'
    [ "$status" -ne 0 ]
    run phpvm_validate_constraint ">=8.1 <8.4 || ^9.0"
    [ "$status" -eq 0 ]
}

# --- composer.json parsing ---

@test "composer.json require.php is read and nested php keys are ignored" {
    cat > "$TEST_DIR/composer.json" << 'EOF'
{
    "description": "mentions \"php\": \"1.0\" in a string",
    "require-dev": {"php": "9.9"},
    "extra": {"require": {"php": "7.0"}},
    "authors": [{"name": "dev", "php": "5.6"}],
    "require": {
        "monolog/monolog": "^3.0",
        "php": ">=8.1 <8.4"
    }
}
EOF
    run phpvm_composer_php_requirement "$TEST_DIR/composer.json"
    [ "$status" -eq 0 ]
    [ "$output" = ">=8.1 <8.4" ]
}

@test "composer.json config.platform.php takes precedence over require.php" {
    write_composer "$TEST_DIR" '{"require":{"php":"^8.1"},"config":{"platform":{"php":"8.2.12"}}}'
    run phpvm_composer_php_requirement "$TEST_DIR/composer.json"
    [ "$status" -eq 0 ]
    [ "$output" = "8.2.12" ]
}

@test "composer.json without a PHP requirement is not a project pin" {
    write_composer "$TEST_DIR" '{"require":{"monolog/monolog":"^3.0"}}'
    run phpvm_composer_php_requirement "$TEST_DIR/composer.json"
    [ "$status" -eq 1 ]
}

# --- project pin resolution ---

@test "project version picks the newest installed version matching composer.json" {
    install_php 8.1
    install_php 8.2
    install_php 8.3
    write_composer "$TEST_DIR/app" '{"require":{"php":"^8.1 <8.3"}}'
    mkdir -p "$TEST_DIR/app/src"
    cd "$TEST_DIR/app/src"
    run phpvm_read_project_version installed
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "8.2" ]
    [[ "${lines[1]}" =~ "composer.json" ]]
}

@test "install candidates come from the repository version list" {
    write_composer "$TEST_DIR/app" '{"require":{"php":">=8.1 <8.4"}}'
    cd "$TEST_DIR/app"
    run phpvm_read_project_version remote
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "8.3" ]
}

@test ".phpvmrc wins over composer.json in the same directory" {
    install_php 8.1
    install_php 8.3
    write_composer "$TEST_DIR/app" '{"require":{"php":"^8.3"}}'
    printf '8.1\n' > "$TEST_DIR/app/.phpvmrc"
    cd "$TEST_DIR/app"
    run phpvm_read_project_version installed
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "8.1" ]
    [[ "${lines[1]}" =~ ".phpvmrc" ]]
}

@test "the nearest project file wins over a parent .phpvmrc" {
    install_php 8.1
    install_php 8.3
    printf '8.1\n' > "$TEST_DIR/.phpvmrc"
    write_composer "$TEST_DIR/app" '{"require":{"php":"^8.3"}}'
    cd "$TEST_DIR/app"
    run phpvm_read_project_version installed
    [ "${lines[0]}" = "8.3" ]
}

@test "composer.json without a PHP requirement defers to a parent .phpvmrc" {
    install_php 8.1
    printf '8.1\n' > "$TEST_DIR/.phpvmrc"
    write_composer "$TEST_DIR/app" '{"require":{"monolog/monolog":"^3.0"}}'
    cd "$TEST_DIR/app"
    run phpvm_read_project_version installed
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "8.1" ]
}

# --- commands ---

@test "use without arguments switches to the composer.json requirement" {
    install_php 8.1
    install_php 8.2
    write_composer "$TEST_DIR/app" '{"require":{"php":"~8.1.0"}}'
    run bash -c 'cd "$1" && bash "$2" use' _ "$TEST_DIR/app" "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found PHP requirement '~8.1.0' in composer.json; using 8.1" ]]
    [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.1" ]
}

@test "use without arguments fails when no installed version matches" {
    install_php 8.1
    write_composer "$TEST_DIR/app" '{"require":{"php":"^8.4"}}'
    run bash -c 'cd "$1" && bash "$2" use' _ "$TEST_DIR/app" "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 4 ]
    [[ "$output" =~ "No installed PHP version satisfies '^8.4'" ]]
}

@test "install without arguments installs the newest matching available version" {
    write_composer "$TEST_DIR/app" '{"require":{"php":"^8.1 <8.4"}}'
    run bash -c 'cd "$1" && bash "$2" install' _ "$TEST_DIR/app" "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PHP 8.3 installed." ]]
    phpvm_test_php_installed 8.3
}

@test "install without arguments fails when no available version matches" {
    write_composer "$TEST_DIR/app" '{"require":{"php":"^9.0"}}'
    run bash -c 'cd "$1" && bash "$2" install' _ "$TEST_DIR/app" "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 3 ]
    [[ "$output" =~ "No available PHP version satisfies '^9.0'" ]]
}

@test "resolve without arguments prints the project's installed version" {
    install_php 8.2
    install_php 8.3
    write_composer "$TEST_DIR/app" '{"config":{"platform":{"php":"8.2.10"}}}'
    cd "$TEST_DIR/app"
    run phpvm_resolve_to_installed
    [ "$status" -eq 0 ]
    [ "$output" = "8.2" ]
}

@test "an unsupported composer.json requirement falls back to the default alias" {
    install_php 8.2
    write_composer "$TEST_DIR/app" '{"require":{"php":"$(touch pwned)"}}'
    run bash -c 'cd "$1" && bash "$2" use' _ "$TEST_DIR/app" "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Ignoring unsupported PHP requirement" ]]
    [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.2" ]
    [ ! -e "$TEST_DIR/app/pwned" ]
}

@test "session mode use reads composer.json in Bash and Zsh" {
    install_php 8.1
    install_php 8.2
    write_composer "$TEST_DIR/app" '{"require":{"php":"^8.1 <8.2"}}'
    local shell
    for shell in bash zsh; do
        command -v "$shell" > /dev/null || continue
        run env PHPVM_SWITCH_MODE=session "$shell" -c 'cd "$1" && source "$2" --no-use && phpvm use >/dev/null && [[ "$(phpvm current)" = 8.1 ]]' \
            _ "$TEST_DIR/app" "$BATS_TEST_DIRNAME/../phpvm.sh"
        [ "$status" -eq 0 ]
    done
}

@test "latest resolves in Zsh without overwriting PATH" {
    if ! command -v zsh > /dev/null 2>&1; then
        skip "zsh is required for the native Zsh regression test"
    fi
    install_php 8.1
    install_php 8.3
    run env PHPVM_SWITCH_MODE=session zsh -c 'source "$1" --no-use && phpvm use latest >/dev/null && [[ "$(phpvm current)" = 8.3 ]]' \
        _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "command not found" ]]
}
