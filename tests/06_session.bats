#!/usr/bin/env bats
# Per-shell switching and interpreter resolution tests.

load test_helper

@test "invalid session mode is rejected while sourcing" {
    run env PHPVM_SWITCH_MODE=invalid bash -c 'source "$1" --no-use' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Use 'global' or 'session'" ]]
}

@test "session mode switches only this shell and does not write global state" {
    install_php "8.1"
    install_php "8.2"
    export PHPVM_SWITCH_MODE=session
    printf '8.2\n' > "$PHPVM_ACTIVE_VERSION_FILE"

    phpvm use 8.1
    [ "$(phpvm current)" = "8.1" ]
    [ "$(phpvm which)" = "$PHPVM_SESSION_BIN/php" ]
    [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.2" ]
    [ ! -e "$PHPVM_CURRENT_SYMLINK" ]
    [[ "$PATH" = "$PHPVM_SESSION_BIN:"* ]]
}

@test "separate sourced shells can select different PHP versions" {
    install_php "8.1"
    install_php "8.2"
    export PHPVM_SWITCH_MODE=session
    phpvm use 8.1
    local parent_bin="$PHPVM_SESSION_BIN"

    run bash -c 'source "$1" --no-use; phpvm use 8.2 >/dev/null; phpvm current' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "8.2" ]
    [ "$PHPVM_SESSION_BIN" = "$parent_bin" ]
    [ "$(phpvm current)" = "8.1" ]
}

@test "Zsh sources phpvm as a shell function and unloads cleanly" {
    if ! command -v zsh > /dev/null 2>&1; then
        skip "zsh is required for the native Zsh session test"
    fi

    run env PHPVM_DIR="$PHPVM_DIR" PHPVM_SWITCH_MODE=session PHPVM_TEST_MODE=true TEST_PREFIX="$TEST_PREFIX" \
        zsh -c 'source "$1" --no-use; phpvm install 8.2 >/dev/null; phpvm use 8.2 >/dev/null; [[ "$(phpvm current)" = 8.2 ]]; phpvm unload >/dev/null; ! whence -w phpvm >/dev/null 2>&1; [[ -z "${PHPVM_DIR:-}" ]]' \
        _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
}

@test "session deactivation preserves PATH edits and unload clears the shell function" {
    install_php "8.1"
    export PHPVM_SWITCH_MODE=session
    phpvm use 8.1
    local extra_path="$TEST_DIR/extra path"
    mkdir -p "$extra_path"
    export PATH="$PATH:$extra_path"

    phpvm deactivate
    [[ ":$PATH:" = *":$extra_path:"* ]]
    [ -z "${PHPVM_SESSION_BIN:-}" ]
    phpvm use 8.1
    phpvm unload
    ! declare -F phpvm > /dev/null
}

@test "session mode rejects standalone switching and protects the active version" {
    install_php "8.1"
    export PHPVM_SWITCH_MODE=session
    phpvm use 8.1

    run env PHPVM_SWITCH_MODE=session PHPVM_TEST_MODE=true PHPVM_DIR="$PHPVM_DIR" bash "$BATS_TEST_DIRNAME/../phpvm.sh" use 8.1
    [ "$status" -eq 2 ]
    run phpvm uninstall 8.1
    [ "$status" -ne 0 ]
}

@test "exec runs the requested PHP binary in production resolution mode" {
    local php81="$TEST_DIR/php81"
    cat > "$php81" << 'EOF'
#!/bin/sh
if [ "$1" = "-r" ]; then printf '8.1\n'; else printf 'PHP 8.1.0\n'; fi
EOF
    chmod +x "$php81"
    get_php_binary_path() { printf '%s\n' "$php81"; }
    PHPVM_TEST_MODE=false

    run phpvm_exec 8.1 php -v
    [ "$status" -eq 0 ]
    [ "$output" = "PHP 8.1.0" ]
}

@test "production resolver rejects a mismatched binary" {
    local php82="$TEST_DIR/php82"
    cat > "$php82" << 'EOF'
#!/bin/sh
if [ "$1" = "-r" ]; then printf '8.2\n'; else printf 'PHP 8.2.0\n'; fi
EOF
    chmod +x "$php82"
    get_php_binary_path() { printf '%s\n' "$php82"; }
    PHPVM_TEST_MODE=false

    run phpvm_resolve_php_binary 8.1
    [ "$status" -eq 4 ]
    [[ "$output" =~ "version mismatch" ]]
}

@test "Linux resolver accepts the system PHP only when its version matches" {
    local system_bin="$TEST_DIR/system/php"
    mkdir -p "$(dirname "$system_bin")"
    cat > "$system_bin" << 'EOF'
#!/bin/sh
if [ "$1" = "-r" ]; then printf '8.2\n'; else printf 'PHP 8.2.0\n'; fi
EOF
    chmod +x "$system_bin"
    get_php_binary_path() { printf '%s\n' "$TEST_DIR/missing-php"; }
    export PATH="$(dirname "$system_bin"):$PATH"
    PKG_MANAGER=apt
    PHPVM_TEST_MODE=false

    [ "$(phpvm_resolve_php_binary 8.2)" = "$system_bin" ]
    run phpvm_resolve_php_binary 8.1
    [ "$status" -eq 4 ]
}

@test "Linux binary resolver finds a Remi parallel PHP installation" {
    local remi_binary="$TEST_DIR/remi/php82/root/usr/bin/php"
    mkdir -p "$(dirname "$remi_binary")"
    printf '#!/bin/sh\nexit 0\n' > "$remi_binary"
    chmod +x "$remi_binary"
    PHPVM_REMI_PREFIX="$TEST_DIR/remi"
    PKG_MANAGER=dnf

    [ "$(get_php_binary_path 8.2)" = "$remi_binary" ]
}

@test "Homebrew binary resolver selects the installed versioned formula" {
    local brew_binary="$TEST_DIR/homebrew/opt/php@8.2/bin/php"
    mkdir -p "$(dirname "$brew_binary")"
    touch "$brew_binary"
    HOMEBREW_PREFIX="$TEST_DIR/homebrew"
    PKG_MANAGER=brew
    brew_resolve_formula_for_version() { printf 'php@%s\n' "$1"; }

    [ "$(get_php_binary_path 8.2)" = "$brew_binary" ]
}

@test "session auto reads project pin and system removes only phpvm PATH entry" {
    install_php "8.2"
    export PHPVM_SWITCH_MODE=session
    printf '8.2\n' > "$TEST_DIR/.phpvmrc"
    cd "$TEST_DIR"
    phpvm auto
    [ "$(phpvm current)" = "8.2" ]
    local session_bin="$PHPVM_SESSION_BIN"
    local system_bin="$TEST_DIR/system-bin"
    mkdir -p "$system_bin"
    printf '#!/bin/sh\nprintf system\\n\n' > "$system_bin/php"
    chmod +x "$system_bin/php"
    export PATH="$PATH:$system_bin"

    phpvm system
    [ -z "${PHPVM_SESSION_BIN:-}" ]
    [[ ":$PATH:" = *":$system_bin:"* ]]
    [[ ":$PATH:" != *":$session_bin:"* ]]
    cd "$BATS_TEST_DIRNAME/.."
}

@test "failed version resolution returns failure from install use exec and uninstall" {
    phpvm_get_latest_installed_version() { return 4; }

    run install_php latest
    [ "$status" -eq 4 ]
    run use_php_version latest
    [ "$status" -eq 4 ]
    run phpvm_exec latest printf x
    [ "$status" -eq 4 ]
    run uninstall_php latest
    [ "$status" -eq 4 ]
}

@test "inherited initialization flag does not skip shell-local detection" {
    local shell
    for shell in bash zsh; do
        command -v "$shell" >/dev/null || continue
        run env -u PKG_MANAGER -u HOMEBREW_PREFIX PHPVM_INITIALIZED=true PHPVM_TEST_MODE=true \
            "$shell" -c 'source "$1" --no-use; [[ "$PKG_MANAGER" = brew && -n "$HOMEBREW_PREFIX" ]]' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
        [ "$status" -eq 0 ]
    done
}

@test "session which honors explicit versions aliases and system and rejects stale selections" {
    install_php 8.1
    install_php 8.2
    export PHPVM_SWITCH_MODE=session
    local system_php
    system_php=$(command -v php)
    phpvm use 8.1
    printf '8.2\n' > "$PHPVM_DIR/alias/project"
    [ "$(phpvm which 8.2)" = "$(phpvm_test_php_path 8.2)" ]
    [ "$(phpvm which project)" = "$(phpvm_test_php_path 8.2)" ]
    [ "$(phpvm which system)" = "$system_php" ]
    [ "$(phpvm which)" = "$PHPVM_SESSION_BIN/php" ]
    [ "$(phpvm_which '')" = "$PHPVM_SESSION_BIN/php" ]
    run phpvm which 8.1 extra
    [ "$status" -eq 2 ]
    rm "$(phpvm_test_php_path 8.1)"
    run phpvm which
    [ "$status" -eq 4 ]
    [ -z "$output" ]
}

@test "unversioned Homebrew formula ignores the globally linked interpreter" {
    HOMEBREW_PREFIX="$TEST_DIR/brew"
    PKG_MANAGER=brew
    PHPVM_TEST_MODE=false
    mkdir -p "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/opt/php/bin"
    printf '#!/bin/sh\nprintf "8.1\\n"\n' > "$HOMEBREW_PREFIX/bin/php"
    printf '#!/bin/sh\nprintf "8.2\\n"\n' > "$HOMEBREW_PREFIX/opt/php/bin/php"
    chmod +x "$HOMEBREW_PREFIX/bin/php" "$HOMEBREW_PREFIX/opt/php/bin/php"
    brew_resolve_formula_for_version() { printf 'php\n'; }
    [ "$(phpvm_resolve_php_binary 8.2)" = "$HOMEBREW_PREFIX/opt/php/bin/php" ]
    PHPVM_SWITCH_MODE=session
    phpvm use 8.2
    [ "$(php -v)" = 8.2 ]
}

@test "exec replaces inherited selection and metadata in Bash and Zsh children" {
    local version shell
    for version in 8.1 8.2; do
        printf '#!/bin/sh\nprintf "%s\\n"\n' "$version" > "$TEST_DIR/php$version"
        chmod +x "$TEST_DIR/php$version"
    done
    mkdir -p "$TEST_DIR/system"
    printf '#!/bin/sh\nprintf "system\\n"\n' > "$TEST_DIR/system/php"
    chmod +x "$TEST_DIR/system/php"
    export PATH="$TEST_DIR/system:$PATH"
    export PHPVM_SWITCH_MODE=session PHPVM_TEST_MODE=false
    get_php_binary_path() { printf '%s/php%s\n' "$TEST_DIR" "$1"; }
    phpvm use 8.1
    local parent_path="$PATH"
    for shell in bash zsh; do
        command -v "$shell" >/dev/null || continue
        run phpvm exec 8.2 "$shell" -c '
            set -e
            source "$1" --no-use
            [[ "$(php -v)" = 8.2 ]]
            [[ "$(phpvm current)" = 8.2 ]]
            [[ "$PHPVM_BIN" = "$PHPVM_SESSION_BIN" ]]
            phpvm system >/dev/null
            [[ "$(php -v)" = system ]]
            [[ -z "${PHPVM_SESSION_VERSION:-}" ]]
        ' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
        [ "$status" -eq 0 ]
        run phpvm exec system "$shell" -c '
            set -e
            source "$1" --no-use
            [[ "$(php -v)" = system ]]
            [[ "$(phpvm current)" = system ]]
            [[ -z "${PHPVM_SESSION_VERSION:-}" ]]
        ' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
        [ "$status" -eq 0 ]
    done
    [ "$PATH" = "$parent_path" ]
    [ "$(php -v)" = 8.1 ]
    [ "$(phpvm current)" = 8.1 ]
    run phpvm exec 8.2 sh -c 'printf "%s\n" "$1"; exit 23' _ 'argument with spaces'
    [ "$status" -eq 23 ]
    [ "$output" = 'argument with spaces' ]
}
