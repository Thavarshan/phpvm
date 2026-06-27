#!/usr/bin/env bats
# BATS test suite for phpvm - DNF module stream helpers (issue #20)
# These tests use a PATH-based dnf stub to simulate "dnf module list php" output
# without requiring a real Fedora/RHEL system.

load test_helper

# ── helpers ──────────────────────────────────────────────────────────────────

# Write a stub script that emulates "dnf module list php" for Remi streams.
# The stub is placed first on PATH so phpvm.sh's dnf calls hit it.
setup_dnf_stub_remi() {
    local stub_dir="$TEST_DIR/stub-remi"
    mkdir -p "$stub_dir"
    cat > "$stub_dir/dnf" <<'STUB'
#!/bin/bash
# Minimal dnf stub — only handles the subcommands phpvm uses
case "$*" in
  "--version")
    echo "5.2.0"
    ;;
  "module list php"|"module list php 2>/dev/null")
    cat <<'TABLE'
php   remi-7.4   common [d], devel, minimal   PHP scripting language
php   remi-8.0   common [d], devel, minimal   PHP scripting language
php   remi-8.1   common [d], devel, minimal   PHP scripting language
php   remi-8.2   common [d], devel, minimal   PHP scripting language
php   remi-8.3   common [d], devel, minimal   PHP scripting language
php   remi-8.4   common [d], devel, minimal   PHP scripting language
php   remi-8.5   common [d], devel, minimal   PHP scripting language
TABLE
    ;;
  *)
    exit 1
    ;;
esac
STUB
    chmod +x "$stub_dir/dnf"
    export PATH="$stub_dir:$PATH"
}

# Remi stub with remi-8.2 already enabled ([e] in profile column)
setup_dnf_stub_remi_enabled() {
    local stub_dir="$TEST_DIR/stub-remi-enabled"
    mkdir -p "$stub_dir"
    cat > "$stub_dir/dnf" <<'STUB'
#!/bin/bash
case "$*" in
  "--version")
    echo "5.2.0"
    ;;
  "module list php"|"module list php 2>/dev/null")
    cat <<'TABLE'
php   remi-8.1   common [d], devel, minimal   PHP scripting language
php   remi-8.2 [e]   common [d], devel, minimal   PHP scripting language
php   remi-8.3   common [d], devel, minimal   PHP scripting language
TABLE
    ;;
  *)
    exit 1
    ;;
esac
STUB
    chmod +x "$stub_dir/dnf"
    export PATH="$stub_dir:$PATH"
}

# AppStream stub (plain X.Y stream names, DNF4)
setup_dnf_stub_appstream() {
    local stub_dir="$TEST_DIR/stub-appstream"
    mkdir -p "$stub_dir"
    cat > "$stub_dir/dnf" <<'STUB'
#!/bin/bash
case "$*" in
  "--version")
    echo "4.14.0"
    ;;
  "module list php"|"module list php 2>/dev/null")
    cat <<'TABLE'
php   8.0   common [d], devel, minimal   PHP scripting language
php   8.1   common [d], devel, minimal   PHP scripting language
php   8.2   common [d], devel, minimal   PHP scripting language
TABLE
    ;;
  *)
    exit 1
    ;;
esac
STUB
    chmod +x "$stub_dir/dnf"
    export PATH="$stub_dir:$PATH"
}

# ── dnf_resolve_php_stream ────────────────────────────────────────────────────

@test "dnf_resolve_php_stream returns remi-8.2 for version 8.2 on Remi Fedora" {
    setup_dnf_stub_remi
    source "$BATS_TEST_DIRNAME/../phpvm.sh"
    result=$(dnf_resolve_php_stream "8.2")
    [ "$result" = "remi-8.2" ]
}

@test "dnf_resolve_php_stream returns remi-8.1 for version 8.1 on Remi Fedora" {
    setup_dnf_stub_remi
    source "$BATS_TEST_DIRNAME/../phpvm.sh"
    result=$(dnf_resolve_php_stream "8.1")
    [ "$result" = "remi-8.1" ]
}

@test "dnf_resolve_php_stream returns empty string for unknown version on Remi" {
    setup_dnf_stub_remi
    source "$BATS_TEST_DIRNAME/../phpvm.sh"
    result=$(dnf_resolve_php_stream "9.9")
    [ -z "$result" ]
}

@test "dnf_resolve_php_stream returns 8.2 for version 8.2 on AppStream (DNF4)" {
    setup_dnf_stub_appstream
    source "$BATS_TEST_DIRNAME/../phpvm.sh"
    result=$(dnf_resolve_php_stream "8.2")
    [ "$result" = "8.2" ]
}

# ── dnf_stream_enabled ────────────────────────────────────────────────────────

@test "dnf_stream_enabled returns true when remi-8.2 is enabled" {
    setup_dnf_stub_remi_enabled
    source "$BATS_TEST_DIRNAME/../phpvm.sh"
    run dnf_stream_enabled "remi-8.2"
    [ "$status" -eq 0 ]
}

@test "dnf_stream_enabled returns false for non-enabled stream remi-8.1" {
    setup_dnf_stub_remi_enabled
    source "$BATS_TEST_DIRNAME/../phpvm.sh"
    run dnf_stream_enabled "remi-8.1"
    [ "$status" -ne 0 ]
}

# ── dnf_major_version ─────────────────────────────────────────────────────────

@test "dnf_major_version returns 5 for DNF5 stub" {
    setup_dnf_stub_remi
    source "$BATS_TEST_DIRNAME/../phpvm.sh"
    result=$(dnf_major_version)
    [ "$result" = "5" ]
}

@test "dnf_major_version returns 4 for DNF4 stub" {
    setup_dnf_stub_appstream
    source "$BATS_TEST_DIRNAME/../phpvm.sh"
    result=$(dnf_major_version)
    [ "$result" = "4" ]
}
