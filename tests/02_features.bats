#!/usr/bin/env bats
# BATS test suite for phpvm - Placeholder feature tests

load test_helper

@test "phpvm exec shows helpful error message" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" exec 8.1 php -v
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not yet implemented" ]]
    [[ "$output" =~ "Phase 1" ]]
}

@test "phpvm run shows helpful error message" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" run 8.1 script.php
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not yet implemented" ]]
    [[ "$output" =~ "Phase 1" ]]
}

@test "phpvm ls-remote shows helpful error message" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" ls-remote
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not yet implemented" ]]
    [[ "$output" =~ "Phase 2" ]]
}

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

@test "phpvm cache dir works" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" cache dir
    [ "$status" -eq 0 ]
    [[ "$output" =~ "/cache" ]]
}

@test "phpvm cache clear shows helpful error message" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" cache clear
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not yet implemented" ]]
}

@test "phpvm cache with invalid subcommand shows error" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" cache invalid
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Unknown cache subcommand" ]]
}

@test "help text includes planned features" {
    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Planned Features" ]]
    [[ "$output" =~ "phpvm exec" ]]
    [[ "$output" =~ "phpvm run" ]]
    [[ "$output" =~ "phpvm ls-remote" ]]
    [[ "$output" =~ "phpvm alias" ]]
    [[ "$output" =~ "phpvm unalias" ]]
    [[ "$output" =~ "phpvm cache" ]]
}
