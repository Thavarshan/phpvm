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

    PHPVM_DIR="$temp_dir/.phpvm" bash "$BATS_TEST_DIRNAME/../phpvm.sh" alias default 8.1
    [ -f "$temp_dir/.phpvm/alias/default" ]

    run PHPVM_DIR="$temp_dir/.phpvm" bash "$BATS_TEST_DIRNAME/../phpvm.sh" alias
    [ "$status" -eq 0 ]
    [[ "$output" =~ "default" ]]

    run PHPVM_DIR="$temp_dir/.phpvm" bash "$BATS_TEST_DIRNAME/../phpvm.sh" alias def
    [ "$status" -eq 0 ]
    [[ "$output" =~ "default" ]]

    rm -rf "$temp_dir"
}

@test "phpvm unalias removes aliases" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-unalias.XXXXXX)

    PHPVM_DIR="$temp_dir/.phpvm" bash "$BATS_TEST_DIRNAME/../phpvm.sh" alias test 8.0
    [ -f "$temp_dir/.phpvm/alias/test" ]

    run PHPVM_DIR="$temp_dir/.phpvm" bash "$BATS_TEST_DIRNAME/../phpvm.sh" unalias test
    [ "$status" -eq 0 ]
    [ ! -f "$temp_dir/.phpvm/alias/test" ]

    rm -rf "$temp_dir"
}

@test "phpvm auto resolves alias in .phpvmrc" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-rcalias.XXXXXX)

    mkdir -p "$temp_dir/project"
    echo "default" > "$temp_dir/project/.phpvmrc"

    PHPVM_DIR="$temp_dir/.phpvm" bash "$BATS_TEST_DIRNAME/../phpvm.sh" alias default 8.1

    run bash -c "cd $temp_dir/project && PHPVM_DIR=$temp_dir/.phpvm PHPVM_TEST_MODE=true bash $BATS_TEST_DIRNAME/../phpvm.sh auto"
    [ "$status" -eq 0 ]

    rm -rf "$temp_dir"
}

@test "phpvm use without args uses default alias" {
    local temp_dir
    temp_dir=$(mktemp -d /tmp/phpvm-bats-default.XXXXXX)

    PHPVM_DIR="$temp_dir/.phpvm" bash "$BATS_TEST_DIRNAME/../phpvm.sh" alias default 8.1

    run PHPVM_DIR="$temp_dir/.phpvm" PHPVM_TEST_MODE=true bash "$BATS_TEST_DIRNAME/../phpvm.sh" use
    [ "$status" -eq 0 ]

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
