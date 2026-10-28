#!/usr/bin/env bats
# Regression tests for issues #25-#34.

load test_helper

# Put fake package-manager commands first on PATH
stub_command() {
    local name="$1"
    local body="$2"
    mkdir -p "$TEST_DIR/stub"
    printf '#!/bin/sh\n%s\n' "$body" > "$TEST_DIR/stub/$name"
    chmod +x "$TEST_DIR/stub/$name"
    case ":$PATH:" in
    *":$TEST_DIR/stub:"*) ;;
    *) export PATH="$TEST_DIR/stub:$PATH" ;;
    esac
}

# --- #25: prompt hook ---

@test "cd hook leaves a manual use alone until the directory changes (#25)" {
    install_php 8.1
    install_php 8.2
    export PHPVM_SWITCH_MODE=session
    mkdir -p "$TEST_DIR/project"
    printf '8.2\n' > "$TEST_DIR/project/.phpvmrc"
    cd "$TEST_DIR/project"
    phpvm_cd_hook > /dev/null
    [ "$(phpvm current)" = "8.2" ]

    phpvm use 8.1 > /dev/null
    phpvm_cd_hook > /dev/null
    [ "$(phpvm current)" = "8.1" ]

    cd "$TEST_DIR"
    phpvm_cd_hook > /dev/null
    cd "$TEST_DIR/project"
    phpvm_cd_hook > /dev/null
    [ "$(phpvm current)" = "8.2" ]
}

# --- #26: unload in Zsh ---

@test "unload removes every phpvm helper function in Zsh and Bash (#26)" {
    run bash -c 'source "$1" --no-use; phpvm unload >/dev/null 2>&1; declare -F | awk "{print \$3}" | grep -E "^(phpvm|main$|install_php|use_php_version|dnf_|brew_|linux_)"' \
        _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ -z "$output" ]

    if ! command -v zsh > /dev/null 2>&1; then
        skip "zsh is required for the Zsh unload check"
    fi
    run zsh -c 'source "$1" --no-use; phpvm unload >/dev/null 2>&1; print -rl -- ${(k)functions} | grep -E "^(phpvm|main$|install_php|use_php_version|dnf_|brew_|linux_)"' \
        _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ -z "$output" ]
}

# --- #27: exec and run without a version ---

@test "run and exec use the project pin when no version is given (#27)" {
    install_php 8.2
    mkdir -p "$TEST_DIR/project"
    printf '8.2\n' > "$TEST_DIR/project/.phpvmrc"
    cd "$TEST_DIR/project"

    run phpvm_run -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found '8.2' in .phpvmrc" ]]
    [[ "$output" =~ "PHP " ]]

    # The source message goes to stderr so the command's output stays clean
    [[ "$(phpvm_exec php -v 2> /dev/null)" == "PHP 8.2.0 (cli)"* ]]

    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" run -v
    [ "$status" -eq 0 ]
}

@test "run without a version or project pin reports usage (#27)" {
    cd "$TEST_DIR"
    run phpvm_run
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Missing version argument" ]]
    run phpvm_exec composer install
    [ "$status" -eq 2 ]
}

# --- #28: PHPVM_BIN in global mode ---

@test "global use through the shell function exports PHPVM_BIN (#28)" {
    install_php 8.2
    cp "$BATS_TEST_DIRNAME/../phpvm.sh" "$TEST_DIR/phpvm.sh"
    chmod +x "$TEST_DIR/phpvm.sh"
    PHPVM_SCRIPT_PATH="$TEST_DIR/phpvm.sh"
    unset PHPVM_BIN

    phpvm use 8.2 > /dev/null
    [ "$PHPVM_BIN" = "$(dirname "$(phpvm_test_php_path 8.2)")" ]
}

# --- #29: Fedora/RHEL module streams ---

@test "dnf with alternatives switches module streams when no versioned binary exists (#29)" {
    export DNF_LOG="$TEST_DIR/dnf.log"
    stub_command alternatives 'exit 0'
    stub_command dnf 'printf "%s\n" "$*" >> "$DNF_LOG"
case "$*" in
"module list php") printf "php   remi-8.2   common [d]   PHP\nphp   remi-8.3   common [d]   PHP\n" ;;
esac
exit 0'
    PHPVM_TEST_MODE=false
    PKG_MANAGER=dnf
    get_php_binary_path() { printf '%s\n' "$TEST_DIR/missing/php"; }
    run_with_sudo() { "$@"; }
    update_current_symlink() { return 0; }
    # The interpreter only reports 8.3 once packages were synced to the stream
    phpvm_resolve_php_binary() { grep -q '^distro-sync' "$DNF_LOG" 2> /dev/null && printf '/usr/bin/php\n'; }

    run switch_to_version_php 8.3
    [ "$status" -eq 0 ]
    grep -qx 'module enable php:remi-8.3 -y' "$DNF_LOG"
    grep -q '^distro-sync -y php-\*' "$DNF_LOG"
    [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.3" ]
}

# --- #30: Homebrew unversioned formula ---

@test "Homebrew list labels the unversioned php formula from its own binary (#30)" {
    HOMEBREW_PREFIX="$TEST_DIR/brew"
    PKG_MANAGER=brew
    PHPVM_TEST_MODE=false
    mkdir -p "$HOMEBREW_PREFIX/Cellar/php" "$HOMEBREW_PREFIX/Cellar/php@8.2" "$HOMEBREW_PREFIX/opt/php/bin"
    printf '#!/bin/sh\nprintf "8.4"\n' > "$HOMEBREW_PREFIX/opt/php/bin/php"
    chmod +x "$HOMEBREW_PREFIX/opt/php/bin/php"
    # The PHP linked on PATH is a different formula
    stub_command php-config 'echo 8.2.20'
    stub_command php 'echo "PHP 8.2.20 (cli)"'
    printf '8.4\n' > "$PHPVM_ACTIVE_VERSION_FILE"

    run list_installed_versions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "-> 8.4" ]]
    [[ ! "$output" =~ "8.2.20" ]]
    [ "$(phpvm_installed_versions | sort | paste -s -d ' ' -)" = "8.2 8.4" ]
}

# --- #31: apt install ---

setup_apt_stubs() {
    export APT_LOG="$TEST_DIR/apt.log"
    stub_command apt-cache 'printf "%s:\n  Installed: (none)\n  Candidate: %s\n" "$3" "$APT_CANDIDATE"'
    stub_command apt-get 'printf "%s\n" "$*" >> "$APT_LOG"
if [ "$1" = install ] && [ -n "$APT_FAIL" ]; then
    echo "E: Could not get lock /var/lib/dpkg/lock-frontend" >&2
    exit 100
fi
exit 0'
    PKG_MANAGER=apt
    run_with_sudo() { "$@"; }
}

@test "apt install reports a missing package without attempting the install (#31)" {
    setup_apt_stubs
    export APT_CANDIDATE="(none)"
    run install_php_apt 8.3
    [ "$status" -eq 3 ]
    [[ "$output" =~ "not available from your apt sources" ]]
    ! grep -q '^install' "$APT_LOG"
}

@test "apt install shows apt errors and installs FPM only on request (#31)" {
    setup_apt_stubs
    export APT_CANDIDATE="8.3.6-1"

    export APT_FAIL=1
    run install_php_apt 8.3
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Could not get lock" ]]
    [[ ! "$output" =~ "ppa:ondrej/php" ]]

    unset APT_FAIL
    run install_php_apt 8.3
    [ "$status" -eq 0 ]
    grep -qx 'install -y php8.3-cli php8.3-common' "$APT_LOG"

    export PHPVM_APT_INSTALL_FPM=true
    run install_php_apt 8.3
    [ "$status" -eq 0 ]
    grep -qx 'install -y php8.3-cli php8.3-common php8.3-fpm' "$APT_LOG"
}

# --- #33: self-update integrity ---

@test "self-update rejects a bundle whose checksum does not match (#33)" {
    local release_dir="$TEST_DIR/release"
    local bundle="$TEST_DIR/release.tar.gz"
    local target_file="$TEST_DIR/installed.sh"
    mkdir -p "$release_dir/completions"
    printf '#!/bin/bash\nPHPVM_VERSION="99.0.0"\n' > "$release_dir/phpvm.sh"
    printf 'complete -W "use" phpvm\n' > "$release_dir/completions/phpvm.bash"
    tar -czf "$bundle" -C "$release_dir" phpvm.sh completions
    printf '%064d  release.tar.gz\n' 0 > "$bundle.sha256"
    printf 'original\n' > "$target_file"

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_BUNDLE="$bundle" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Checksum mismatch" ]]
    [ "$(cat "$target_file")" = original ]
}

@test "self-update refuses to downgrade unless forced (#33)" {
    local remote_file="$TEST_DIR/older.sh"
    local target_file="$TEST_DIR/installed.sh"
    printf '#!/bin/bash\nPHPVM_VERSION="1.0.0"\n' > "$remote_file"
    printf 'original\n' > "$target_file"

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_SOURCE="$remote_file" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -eq 0 ]
    [[ "$output" =~ "newer than the latest release v1.0.0" ]]
    [ "$(cat "$target_file")" = original ]

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_SOURCE="$remote_file" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update --force
    [ "$status" -eq 0 ]
    grep -q 'PHPVM_VERSION="1.0.0"' "$target_file"

    run env PHPVM_TEST_MODE=true bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update --bogus
    [ "$status" -eq 2 ]
}

# --- #34: PATH entries with glob characters ---

@test "session PATH stripping keeps glob characters literal (#34)" {
    install_php 8.1
    export PHPVM_SWITCH_MODE=session
    mkdir -p "$TEST_DIR/glob"
    touch "$TEST_DIR/glob/a1" "$TEST_DIR/glob/a2"
    cd "$TEST_DIR/glob"
    export PATH="$PATH:a*"

    phpvm use 8.1 > /dev/null
    phpvm deactivate > /dev/null
    [[ "$PATH" == *":a*" ]]
    [[ "$PATH" != *"a1"* ]]
}
