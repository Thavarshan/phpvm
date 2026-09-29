#!/usr/bin/env bats
# Installer delivery checks against a local release mirror.

load test_helper

@test "installer downloads the pinned script and completions and configures the profile" {
    if ! command -v python3 > /dev/null 2>&1; then
        skip "python3 is required for the local installer mirror"
    fi

    local web_root="$TEST_DIR/web"
    local home_dir="$TEST_DIR/home"
    local install_dir="$TEST_DIR/install dir"
    local server_log="$TEST_DIR/install-http.log"
    mkdir -p "$web_root/1.13.0/completions" "$home_dir"
    touch "$home_dir/.bashrc"
    cp "$BATS_TEST_DIRNAME/../phpvm.sh" "$web_root/1.13.0/phpvm.sh"
    cp "$BATS_TEST_DIRNAME/../completions/phpvm.bash" "$web_root/1.13.0/completions/phpvm.bash"

    python3 - "$web_root" << 'PY' > "$server_log" 2>&1 &
import http.server
import os
import socketserver
import sys

os.chdir(sys.argv[1])
with socketserver.TCPServer(("127.0.0.1", 0), http.server.SimpleHTTPRequestHandler) as server:
    print(server.server_address[1], flush=True)
    server.serve_forever()
PY
    local server_pid=$!
    sleep 1
    local port
    port=$(head -n 1 "$server_log" | tr -d '[:space:]')
    if [ -z "$port" ]; then
        kill "$server_pid" > /dev/null 2>&1 || true
        wait "$server_pid" 2> /dev/null || true
        echo "Failed to start the local installer mirror" >&2
        return 1
    fi
    trap 'kill "$server_pid" >/dev/null 2>&1 || true; wait "$server_pid" 2>/dev/null || true' RETURN

    run env PHPVM_DIR="$install_dir" HOME="$home_dir" SHELL=/bin/bash PROFILE= PHPVM_INSTALL_SOURCE_BASE="http://127.0.0.1:$port/1.13.0" bash "$BATS_TEST_DIRNAME/../install.sh"
    [ "$status" -eq 0 ]
    [ -x "$install_dir/phpvm.sh" ]
    [ -L "$install_dir/bin/phpvm" ]
    [ -s "$install_dir/completions/phpvm.bash" ]
    grep -q 'PHPVM_DIR' "$home_dir/.bashrc"
}
