#!/usr/bin/env bats
# BATS test suite for phpvm - Full lifecycle tests (install → use → current → which → uninstall)

bats_require_minimum_version 1.5.0

load test_helper

@test "lifecycle: install creates mock PHP directory" {
    run install_php "8.2"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Installing PHP 8.2" ]]
    [[ "$output" =~ "PHP 8.2 installed" ]]

    # Verify mock directory was created
    [ -d "$(phpvm_test_php_cellar_dir "8.2")" ]
    [ -x "$(phpvm_test_php_path "8.2")" ]
}

@test "lifecycle: use switches to installed version" {
    install_php "8.2"
    run use_php_version "8.2"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Switched to PHP 8.2" ]]

    # Active version file should be updated
    [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]
    [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.2" ]
}

@test "lifecycle: current shows active version after use" {
    install_php "8.2"
    use_php_version "8.2"
    run phpvm_current
    [ "$status" -eq 0 ]
    [ "$output" = "8.2" ]
}

@test "lifecycle: which returns binary path for installed version" {
    install_php "8.2"
    use_php_version "8.2"
    run phpvm_which "8.2"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "php@8.2" ]]
    [[ "$output" =~ "/bin/php" ]]
}

@test "lifecycle: use system sets active version to system" {
    install_php "8.2"
    use_php_version "8.2"
    run use_php_version "system"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Switched to system PHP" ]]

    [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "system" ]
}

@test "lifecycle: uninstall removes mock PHP directory" {
    install_php "8.1"
    run uninstall_php "8.1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PHP 8.1 uninstalled" ]]

    # Mock directory should be removed
    [ ! -d "$(phpvm_test_php_cellar_dir "8.1")" ]
}

@test "lifecycle: use fails for uninstalled version" {
    run use_php_version "7.4"
    [ "$status" -eq 4 ]
    [[ "$output" =~ "not installed" ]]
}

@test "lifecycle: install then use then install another then switch" {
    install_php "8.1"
    use_php_version "8.1"
    [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.1" ]

    install_php "8.2"
    use_php_version "8.2"
    [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.2" ]

    run phpvm_current
    [ "$output" = "8.2" ]
}

@test "lifecycle: install with X.Y.Z normalizes to X.Y" {
    run install_php "8.2.15"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Installing PHP 8.2" ]]
    [ -d "$(phpvm_test_php_cellar_dir "8.2")" ]
}

@test "lifecycle: list shows installed versions" {
    install_php "8.1"
    install_php "8.2"
    run list_installed_versions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "8.1" ]]
    [[ "$output" =~ "8.2" ]]
}
