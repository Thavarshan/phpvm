#!/usr/bin/env bats
# BATS test suite for phpvm - Setup and helper functions

# Setup function runs before each test
setup() {
    # Set test mode
    export PHPVM_TEST_MODE=true

    # Create temporary test directory
    export TEST_DIR="$(mktemp -d /tmp/phpvm-bats-test.XXXXXX)"
    export PHPVM_DIR="$TEST_DIR/.phpvm"
    export PHPVM_VERSIONS_DIR="$PHPVM_DIR/versions"
    export PHPVM_ACTIVE_VERSION_FILE="$PHPVM_DIR/active_version"
    export PHPVM_CURRENT_SYMLINK="$PHPVM_DIR/current"

    # Source phpvm
    source "$BATS_TEST_DIRNAME/../phpvm.sh"

    # Create directory structure
    create_directories
}

# Teardown function runs after each test
teardown() {
    # Clean up test directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Helper function to create mock PHP installation
create_mock_php() {
    local version="$1"
    local mock_dir="$TEST_DIR/php-$version"
    mkdir -p "$mock_dir/bin"

    cat > "$mock_dir/bin/php" <<EOF
#!/bin/bash
if [ "\$1" = "-v" ]; then
    echo "PHP $version (cli) (built: $(date))"
fi
exit 0
EOF
    chmod +x "$mock_dir/bin/php"
    echo "$mock_dir/bin/php"
}
