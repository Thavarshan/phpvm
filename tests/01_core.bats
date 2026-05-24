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
    cat > "$remote_file" <<'EOF'
#!/bin/bash
PHPVM_VERSION="1.12.1"
EOF

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_SOURCE="$remote_file" PHPVM_SELF_UPDATE_DEST="$TEST_DIR/phpvm-self-update-target.sh" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -eq 0 ]
    [[ "$output" =~ "You are already on the latest version: v1.12.1." ]]
}

@test "phpvm self-update replaces script when newer version is available" {
    local remote_file="$TEST_DIR/phpvm-updated.sh"
    local target_file="$TEST_DIR/phpvm-self-update-target.sh"
    cat > "$remote_file" <<'EOF'
#!/bin/bash
PHPVM_VERSION="1.12.2"
EOF
    touch "$target_file"

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_TEST_SOURCE="$remote_file" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -eq 0 ]
    [[ "$output" =~ "phpvm successfully updated to the latest version: v1.12.2." ]]
    [ "$(grep -oE 'PHPVM_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$target_file")" = "PHPVM_VERSION=\"1.12.2\"" ]
}

@test "phpvm self-update downloads from remote URL and updates script" {
    if ! command -v python3 > /dev/null 2>&1; then
        skip "python3 is required for remote self-update integration test"
    fi

    local server_root="$TEST_DIR/http-server"
    local server_log="$TEST_DIR/http-server.log"
    local target_file="$TEST_DIR/phpvm-self-update-http-target.sh"
    mkdir -p "$server_root"

    cat > "$server_root/phpvm.sh" <<'EOF'
#!/bin/bash
PHPVM_VERSION="1.12.3"
EOF
    chmod +x "$server_root/phpvm.sh"

    python3 - "$server_root" <<'PY' > "$server_log" 2>&1 &
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
        wait "$server_pid" 2>/dev/null || true
        echo "Failed to start local HTTP server" >&2
        return 1
    fi

    touch "$target_file"

    trap 'kill "$server_pid" > /dev/null 2>&1 || true; wait "$server_pid" 2>/dev/null || true' RETURN

    run env PHPVM_TEST_MODE=true PHPVM_SELF_UPDATE_URL="http://127.0.0.1:$port/phpvm.sh" PHPVM_SELF_UPDATE_DEST="$target_file" bash "$BATS_TEST_DIRNAME/../phpvm.sh" self-update
    [ "$status" -eq 0 ]
    [[ "$output" =~ "phpvm successfully updated to the latest version: v1.12.3." ]]
    [ "$(grep -oE 'PHPVM_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$target_file")" = "PHPVM_VERSION=\"1.12.3\"" ]
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
