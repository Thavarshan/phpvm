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

@test "phpvm self-update reports already latest version" {
    local remote_file="$TEST_DIR/phpvm-latest.sh"
    cat > "$remote_file" << 'EOF'
#!/bin/bash
PHPVM_VERSION="1.13.0"
EOF

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_SOURCE="$remote_file" PHPVM_SELF_UPDATE_DEST="$TEST_DIR/phpvm-self-update-target.sh" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -eq 0 ]
    [[ "$output" =~ "You are already on the latest version: v1.13.0." ]]
}

@test "phpvm self-update replaces script when newer version is available" {
    local remote_file="$TEST_DIR/phpvm-updated.sh"
    local target_file="$TEST_DIR/phpvm-self-update-target.sh"
    cat > "$remote_file" << 'EOF'
#!/bin/bash
PHPVM_VERSION="1.13.1"
EOF
    touch "$target_file"

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_SOURCE="$remote_file" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -eq 0 ]
    [[ "$output" =~ "phpvm successfully updated to the latest version: v1.13.1." ]]
    [ "$(grep -oE 'PHPVM_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$target_file")" = "PHPVM_VERSION=\"1.13.1\"" ]
}

@test "phpvm self-update downloads from remote URL and updates script" {
    if ! command -v python3 > /dev/null 2>&1; then
        skip "python3 is required for remote self-update integration test"
    fi

    local server_root="$TEST_DIR/http-server"
    local server_log="$TEST_DIR/http-server.log"
    local target_file="$TEST_DIR/phpvm-self-update-http-target.sh"
    mkdir -p "$server_root"

    cat > "$server_root/phpvm.sh" << 'EOF'
#!/bin/bash
PHPVM_VERSION="1.13.1"
EOF
    chmod +x "$server_root/phpvm.sh"

    python3 - "$server_root" << 'PY' > "$server_log" 2>&1 &
import http.server
import socketserver
import os
import sys

os.chdir(sys.argv[1])
with socketserver.TCPServer(("127.0.0.1", 0), http.server.SimpleHTTPRequestHandler) as httpd:
    print(httpd.server_address[1], flush=True)
    sys.stdout.flush()
    httpd.serve_forever()
PY
    local server_pid=$!
    sleep 1

    local port
    port=$(head -n 1 "$server_log" | tr -d '[:space:]')
    if [ -z "$port" ]; then
        kill "$server_pid" > /dev/null 2>&1 || true
        wait "$server_pid" 2> /dev/null || true
        echo "Failed to start local HTTP server" >&2
        return 1
    fi

    touch "$target_file"

    trap 'kill "$server_pid" > /dev/null 2>&1 || true; wait "$server_pid" 2>/dev/null || true' RETURN

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_URL="http://127.0.0.1:$port/phpvm.sh" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -eq 0 ]
    [[ "$output" =~ "phpvm successfully updated to the latest version: v1.13.1." ]]
    [ "$(grep -oE 'PHPVM_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$target_file")" = "PHPVM_VERSION=\"1.13.1\"" ]
}

@test "phpvm self-update installs a validated release bundle and completions" {
    local release_dir="$TEST_DIR/release"
    local bundle="$TEST_DIR/release.tar.gz"
    local target_file="$TEST_DIR/phpvm-self-update-target.sh"
    mkdir -p "$release_dir/completions" "$PHPVM_DIR/completions"
    cat > "$release_dir/phpvm.sh" << 'EOF'
#!/bin/bash
PHPVM_VERSION="1.13.1"
EOF
    printf 'complete -W "use install" phpvm\n' > "$release_dir/completions/phpvm.bash"
    tar -czf "$bundle" -C "$release_dir" phpvm.sh completions
    printf '#!/bin/bash\nPHPVM_VERSION="1.13.0"\n' > "$target_file"

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_BUNDLE="$bundle" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -eq 0 ]
    [[ "$output" =~ "updated to the latest version: v1.13.1" ]]
    grep -q '1.13.1' "$target_file"
    [ -s "$PHPVM_DIR/completions/phpvm.bash" ]
}

@test "phpvm self-update rejects a malformed bundle without replacing installed files" {
    local bundle="$TEST_DIR/invalid-release.tar.gz"
    local target_file="$TEST_DIR/phpvm-self-update-target.sh"
    mkdir -p "$PHPVM_DIR/completions"
    printf 'not a tar archive\n' > "$bundle"
    printf '#!/bin/bash\nPHPVM_VERSION="1.13.0"\n' > "$target_file"
    printf 'old completion\n' > "$PHPVM_DIR/completions/phpvm.bash"

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_BUNDLE="$bundle" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -ne 0 ]
    grep -q '1.13.0' "$target_file"
    grep -q 'old completion' "$PHPVM_DIR/completions/phpvm.bash"
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
    # Accept: 0 (managed PHP), 4 (none/not installed), or output "system"
    # Exit code 4 = PHPVM_EXIT_NOT_INSTALLED (when no PHP found)
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ]
    [[ "$output" = "none" ]] || [[ "$output" = "system" ]] || [[ "$output" =~ ^[0-9]+\.[0-9]+ ]]
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

@test "self-update stages protected destinations through the privilege helper" {
    [ "$(id -u)" -ne 0 ] || skip "permission checks require a non-root user"
    local protected_dir="$TEST_DIR/protected"
    mkdir -p "$protected_dir"
    printf '#!/bin/bash\nPHPVM_VERSION="99.0.0"\n' > "$TEST_DIR/new.sh"
    printf 'original\n' > "$protected_dir/phpvm.sh"
    export PHPVM_SELF_UPDATE_TEST_SOURCE="$TEST_DIR/new.sh"
    export PHPVM_SELF_UPDATE_DEST="$protected_dir/phpvm.sh"
    chmod 555 "$protected_dir"
    # Emulate elevation only inside the fixture, without invoking real sudo.
    run_with_sudo() {
        printf '%s\n' "$1" >> "$TEST_DIR/elevation.log"
        chmod 755 "$protected_dir"
        local result=0
        command "$@" || result=$?
        chmod 555 "$protected_dir"
        return "$result"
    }
    run phpvm_self_update
    chmod 755 "$protected_dir"
    [ "$status" -eq 0 ]
    grep -q '99.0.0' "$protected_dir/phpvm.sh"
    grep -qx mktemp "$TEST_DIR/elevation.log"
    grep -qx mv "$TEST_DIR/elevation.log"
    [ -x "$protected_dir/phpvm.sh" ]
    [ "$(find "$protected_dir" -name '*.tmp.*' | wc -l)" -eq 0 ]
}

@test "self-update restores the script if completion replacement fails" {
    local release_dir="$TEST_DIR/release"
    mkdir -p "$release_dir/completions" "$PHPVM_DIR/completions"
    printf '#!/bin/bash\nPHPVM_VERSION="99.0.0"\n' > "$release_dir/phpvm.sh"
    printf 'new completion\n' > "$release_dir/completions/phpvm.bash"
    tar -czf "$TEST_DIR/release.tar.gz" -C "$release_dir" phpvm.sh completions
    printf 'original script\n' > "$TEST_DIR/installed.sh"
    chmod 755 "$TEST_DIR/installed.sh"
    printf 'original completion\n' > "$PHPVM_DIR/completions/phpvm.bash"
    export PHPVM_SELF_UPDATE_TEST_BUNDLE="$TEST_DIR/release.tar.gz"
    export PHPVM_SELF_UPDATE_DEST="$TEST_DIR/installed.sh"
    phpvm_update_file_command() {
        local target="$1"
        shift
        if [ "$target" = "$PHPVM_DIR/completions/phpvm.bash" ] && [ "$1" = mv ]; then return 1; fi
        command "$@"
    }
    run phpvm_self_update
    [ "$status" -ne 0 ]
    [ "$(cat "$TEST_DIR/installed.sh")" = 'original script' ]
    [ -x "$TEST_DIR/installed.sh" ]
    [ "$(cat "$PHPVM_DIR/completions/phpvm.bash")" = 'original completion' ]
    [ "$(find "$TEST_DIR" -name '*.tmp.*' | wc -l)" -eq 0 ]
}

@test "denied update elevation leaves the installed script untouched" {
    [ "$(id -u)" -ne 0 ] || skip "permission checks require a non-root user"
    local protected_dir="$TEST_DIR/protected"
    mkdir -p "$protected_dir"
    printf '#!/bin/bash\nPHPVM_VERSION="99.0.0"\n' > "$TEST_DIR/new.sh"
    printf 'original\n' > "$protected_dir/phpvm.sh"
    export PHPVM_SELF_UPDATE_TEST_SOURCE="$TEST_DIR/new.sh"
    export PHPVM_SELF_UPDATE_DEST="$protected_dir/phpvm.sh"
    chmod 555 "$protected_dir"
    run_with_sudo() { return 1; }
    run phpvm_self_update
    chmod 755 "$protected_dir"
    [ "$status" -eq 5 ]
    [ "$(cat "$protected_dir/phpvm.sh")" = original ]
    [ "$(find "$protected_dir" -name '*.tmp.*' | wc -l)" -eq 0 ]
}
