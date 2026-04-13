#!/usr/bin/env bats
# BATS test suite for phpvm - Feature tests

load test_helper

# --- exec command ---

@test "phpvm exec runs command with specified PHP version" {
    install_php "8.1"
    run phpvm_exec "8.1" php -v
    [ "$status" -eq 0 ]
    # Mock PHP binary runs successfully — verifies the correct bin dir was prepended to PATH
    [[ "$output" =~ "PHP" ]]
}

@test "phpvm exec fails for uninstalled version" {
    run phpvm_exec "7.0" php -v
    [ "$status" -ne 0 ]
    [[ "$output" =~ "not installed" ]]
}

@test "phpvm exec with no args shows error" {
    run phpvm_exec
    [ "$status" -ne 0 ]
}

# --- run command ---

@test "phpvm run delegates to exec with php" {
    install_php "8.2"
    run phpvm_run "8.2" -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ "8.2" ]]
}

# --- ls-remote command ---

@test "phpvm ls-remote returns available versions in test mode" {
    run phpvm_ls_remote
    [ "$status" -eq 0 ]
    [[ "$output" =~ "8.2" ]]
    [[ "$output" =~ "8.3" ]]
}

@test "phpvm ls-remote filters by pattern" {
    run phpvm_ls_remote "8.2"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "8.2" ]]
    [[ ! "$output" =~ "7.4" ]]
}

# --- resolve command ---

@test "phpvm resolve returns installed version" {
    install_php "8.2"
    run phpvm_resolve_to_installed "8.2"
    [ "$status" -eq 0 ]
    [ "$output" = "8.2" ]
}

@test "phpvm resolve passes through system keyword" {
    run phpvm_resolve_to_installed "system"
    [ "$status" -eq 0 ]
    [ "$output" = "system" ]
}

@test "phpvm resolve fails for uninstalled version" {
    run phpvm_resolve_to_installed "7.0"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "not installed" ]]
}

@test "phpvm resolve with no args shows error" {
    run phpvm_resolve_to_installed
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Missing version argument" ]]
}

@test "phpvm resolve resolves alias to version" {
    phpvm_alias "default" "8.1"
    install_php "8.1"
    run phpvm_resolve_to_installed "default"
    [ "$status" -eq 0 ]
    [ "$output" = "8.1" ]
}

# --- cache command ---

@test "phpvm cache dir shows cache path" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" cache dir
    [ "$status" -eq 0 ]
    [[ "$output" =~ "/cache" ]]
}

@test "phpvm cache clear removes cached files" {
    mkdir -p "$PHPVM_DIR/cache"
    printf 'test' > "$PHPVM_DIR/cache/testfile"
    [ -f "$PHPVM_DIR/cache/testfile" ]

    run phpvm_cache clear
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cache cleared" ]]
    [ ! -f "$PHPVM_DIR/cache/testfile" ]
}

@test "phpvm cache with invalid subcommand shows error" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" cache invalid
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Unknown cache subcommand" ]]
}

# --- alias/unalias ---

@test "phpvm alias creates and lists aliases" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-alias.XXXXXX)

    bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias default 8.1"
    [ -f "$temp_dir/.phpvm/alias/default" ]

    run bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "default" ]]

    run bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias def"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "default" ]]

    rm -rf "$temp_dir"
}

@test "phpvm unalias removes aliases" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-unalias.XXXXXX)

    bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias test 8.0"
    [ -f "$temp_dir/.phpvm/alias/test" ]

    run bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" unalias test"
    [ "$status" -eq 0 ]
    [ ! -f "$temp_dir/.phpvm/alias/test" ]

    rm -rf "$temp_dir"
}

@test "phpvm auto resolves alias in .phpvmrc" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-rcalias.XXXXXX)

    mkdir -p "$temp_dir/project"
    echo "default" > "$temp_dir/project/.phpvmrc"

    bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias default 8.1"

    run bash -c "cd \"$temp_dir/project\" && PHPVM_DIR=\"$temp_dir/.phpvm\" PHPVM_TEST_MODE=true bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" auto"
    # Test passes if alias is resolved to 8.1 (even if version not installed)
    [[ "$output" =~ "8.1" ]]

    rm -rf "$temp_dir"
}

@test "phpvm alias prevents self-reference" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-alias.XXXXXX)

    # Try to create alias that points to itself
    run bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias foo foo"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "cannot refer to itself" ]]

    rm -rf "$temp_dir"
}

@test "phpvm alias prevents alias chains" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-alias.XXXXXX)

    # Create first alias
    bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias foo 8.1"

    # Try to create alias that points to another alias
    run bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias bar foo"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "itself an alias" ]]

    rm -rf "$temp_dir"
}

# --- use with .phpvmrc / default ---

@test "phpvm use without args uses default alias" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-default.XXXXXX)

    bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias default 8.1"

    run bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" PHPVM_TEST_MODE=true bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" use"
    # Test passes if default alias is resolved to 8.1 (even if version not installed)
    [[ "$output" =~ "8.1" ]]

    rm -rf "$temp_dir"
}

@test "phpvm use without args reads .phpvmrc" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-phpvmrc-use.XXXXXX)
    mkdir -p "$temp_dir/.phpvm"

    printf '8.2\n' > "$temp_dir/.phpvmrc"

    run bash -c "cd \"$temp_dir\" && PHPVM_DIR=\"$temp_dir/.phpvm\" PHPVM_TEST_MODE=true bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" use"
    [[ "$output" =~ "8.2" ]]
    [[ "$output" =~ ".phpvmrc" ]]

    rm -rf "$temp_dir"
}

@test "phpvm use prefers .phpvmrc over default alias" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-phpvmrc-pref.XXXXXX)

    bash -c "PHPVM_DIR=\"$temp_dir/.phpvm\" bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" alias default 8.1"
    printf '8.3\n' > "$temp_dir/.phpvmrc"

    run bash -c "cd \"$temp_dir\" && PHPVM_DIR=\"$temp_dir/.phpvm\" PHPVM_TEST_MODE=true bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" use"
    [[ "$output" =~ "8.3" ]]
    [[ "$output" =~ ".phpvmrc" ]]

    rm -rf "$temp_dir"
}

@test "phpvm install without args reads .phpvmrc" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-phpvmrc-inst.XXXXXX)
    mkdir -p "$temp_dir/.phpvm"

    printf '8.2\n' > "$temp_dir/.phpvmrc"

    run bash -c "cd \"$temp_dir\" && PHPVM_DIR=\"$temp_dir/.phpvm\" PHPVM_TEST_MODE=true bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" install"
    [[ "$output" =~ "8.2" ]]
    [[ "$output" =~ ".phpvmrc" ]]

    rm -rf "$temp_dir"
}

@test "phpvm use without args and no .phpvmrc or default shows error" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-phpvmrc-none.XXXXXX)
    mkdir -p "$temp_dir/.phpvm"

    run bash -c "cd \"$temp_dir\" && PHPVM_DIR=\"$temp_dir/.phpvm\" PHPVM_TEST_MODE=true bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" use"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "No .phpvmrc found" ]]

    rm -rf "$temp_dir"
}

@test "phpvm install without args and no .phpvmrc shows error" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-phpvmrc-noinst.XXXXXX)
    mkdir -p "$temp_dir/.phpvm"

    run bash -c "cd \"$temp_dir\" && PHPVM_DIR=\"$temp_dir/.phpvm\" PHPVM_TEST_MODE=true bash \"$BATS_TEST_DIRNAME/../phpvm.sh\" install"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "No .phpvmrc found" ]]

    rm -rf "$temp_dir"
}

# --- list output formatting ---

@test "phpvm list shows arrow for active version" {
    install_php "8.1"
    install_php "8.2"
    use_php_version "8.2"
    run list_installed_versions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "8.2" ]]
    [[ "$output" =~ "->" ]]
}

@test "phpvm list shows default annotation" {
    install_php "8.1"
    phpvm_alias "default" "8.1"
    run list_installed_versions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "default" ]]
}

# --- auto-default alias on first install ---

@test "first install auto-sets default alias" {
    [ ! -f "$PHPVM_DIR/alias/default" ]
    install_php "8.2"
    [ -f "$PHPVM_DIR/alias/default" ]
    [ "$(cat "$PHPVM_DIR/alias/default")" = "8.2" ]
}

@test "second install does not change default alias" {
    install_php "8.1"
    [ "$(cat "$PHPVM_DIR/alias/default")" = "8.1" ]
    install_php "8.2"
    [ "$(cat "$PHPVM_DIR/alias/default")" = "8.1" ]
}

# --- help text ---

@test "help text shows all implemented commands" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "phpvm exec" ]]
    [[ "$output" =~ "phpvm run" ]]
    [[ "$output" =~ "phpvm ls-remote" ]]
    [[ "$output" =~ "phpvm alias" ]]
    [[ "$output" =~ "phpvm unalias" ]]
    [[ "$output" =~ "phpvm cache" ]]
    [[ "$output" =~ "phpvm resolve" ]]
    [[ "$output" =~ "phpvm unload" ]]
}
