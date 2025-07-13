#!/bin/sh

# phpvm - A PHP Version Manager for macOS and Linux
# Author: Jerome Thayananthajothy (tjthavarshan@gmail.com)

# Define a debug mode for testing
if [ "${BATS_TEST_FILENAME:-}" != "" ]; then
    # Script is being tested
    # Don't execute main automatically
    PHPVM_TEST_MODE=true
    echo "TEST MODE ACTIVE" >&2
else
    PHPVM_TEST_MODE=false
fi

# Fix to prevent shell crash when sourced
(return 0 2>/dev/null) && return 0 || true # Allow sourcing without execution

PHPVM_DIR="${PHPVM_DIR:-$HOME/.phpvm}"
PHPVM_VERSIONS_DIR="$PHPVM_DIR/versions"
PHPVM_ACTIVE_VERSION_FILE="$PHPVM_DIR/active_version"
PHPVM_CURRENT_SYMLINK="$PHPVM_DIR/current"
DEBUG=false # Set to true to enable debug logs

# Helper function to run commands with sudo if needed
run_with_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

# Helper function to log messages with timestamps
log_with_timestamp() {
    local level="$1"
    shift
    printf "%s [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
}

# ANSI color codes
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
RESET=$(printf '\033[0m')

# Output functions
phpvm_echo() { log_with_timestamp "INFO" "$*"; }
phpvm_err() { log_with_timestamp "ERROR" "$*" >&2; }
phpvm_warn() { log_with_timestamp "WARNING" "$*" >&2; }
phpvm_debug() { [ "$DEBUG" = "true" ] && log_with_timestamp "DEBUG" "$*"; }

# Create the required directory structure
create_directories() {
    mkdir -p "$PHPVM_VERSIONS_DIR" || {
        phpvm_err "Failed to create directory $PHPVM_VERSIONS_DIR"
        return 1
    }
}

# Detect the system's package manager and OS
detect_system() {
    if [ "$(uname)" = "Darwin" ]; then
        PKG_MANAGER="brew"
        if ! command -v brew >/dev/null 2>&1; then
            phpvm_err "Homebrew is not installed. Please install Homebrew first."
            return 1
        fi
        HOMEBREW_PREFIX=$(brew --prefix)
        PHP_BIN_PATH="$HOMEBREW_PREFIX/bin"
        return 0
    fi

    # Detect Linux package manager
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PHP_BIN_PATH="/usr/bin"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PHP_BIN_PATH="/usr/bin"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PHP_BIN_PATH="/usr/bin"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        PHP_BIN_PATH="/usr/bin"
    elif command -v brew >/dev/null 2>&1; then
        PKG_MANAGER="brew"
        # Detect Linuxbrew path
        if [ -d "/home/linuxbrew/.linuxbrew" ]; then
            HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
        elif [ -d "$HOME/.linuxbrew" ]; then
            HOMEBREW_PREFIX="$HOME/.linuxbrew"
        else
            HOMEBREW_PREFIX=$(brew --prefix)
        fi
        PHP_BIN_PATH="$HOMEBREW_PREFIX/bin"
    else
        phpvm_err "No supported package manager found (apt, dnf, yum, pacman, or brew)."
        return 1
    fi
}

# Install PHP using the detected package manager
install_php() {
    version="$1"
    [ -z "$version" ] && {
        phpvm_err "No PHP version specified for installation."
        return 1
    }

    phpvm_echo "Installing PHP $version..."

    # If in test mode, just create a mock directory
    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        mkdir -p "${TEST_PREFIX:-/tmp}/opt/homebrew/Cellar/php@$version/bin"
        phpvm_echo "PHP $version installed."
        return 0
    fi

    case "$PKG_MANAGER" in
    brew)
        if ! brew install php@"$version"; then
            phpvm_warn "php@$version is not available in Homebrew. Trying latest version..."
            if ! brew install php; then
                phpvm_err "Failed to install PHP. Please check if the version is available."
                return 1
            fi
        fi
        ;;
    apt)
        run_with_sudo apt-get update
        if ! run_with_sudo apt-get install -y php"$version"; then
            phpvm_err "Failed to install PHP $version. Package php$version may not exist."
            return 1
        fi
        ;;
    dnf | yum)
        run_with_sudo $PKG_MANAGER install -y php"$version" || {
            phpvm_err "Failed to install PHP $version. Package php$version may not exist."
            return 1
        }
        ;;
    pacman)
        run_with_sudo pacman -Sy
        if ! run_with_sudo pacman -S --noconfirm php"$version"; then
            phpvm_err "Failed to install PHP $version. Package php$version may not exist."
            return 1
        fi
        ;;
    esac

    phpvm_echo "PHP $version installed."
    return 0
}

# Helper function to get the installed PHP version
get_installed_php_version() {
    phpvm_debug "Getting installed PHP version..."

    # If in test mode, return a mock version
    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        echo "8.0.0"
        return 0
    fi

    if command -v php-config >/dev/null 2>&1; then
        php-config --version
    else
        php -v | awk '/^PHP/ {print $2}'
    fi
}

# Switch to a specific PHP version
use_php_version() {
    version="$1"
    [ -z "$version" ] && {
        phpvm_err "No PHP version specified to switch."
        return 1
    }

    phpvm_echo "Switching to PHP $version..."

    # Handle test mode specifically
    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        if [ "$version" = "system" ]; then
            echo "system" >"$PHPVM_ACTIVE_VERSION_FILE"
            phpvm_echo "Switched to system PHP."
            return 0
        fi

        if [ -d "${TEST_PREFIX:-/tmp}/opt/homebrew/Cellar/php@$version" ]; then
            echo "$version" >"$PHPVM_ACTIVE_VERSION_FILE"
            phpvm_echo "Switched to PHP $version."
            return 0
        else
            phpvm_err "PHP version $version is not installed."
            return 1
        fi
    fi

    case "$PKG_MANAGER" in
    brew)
        phpvm_debug "Unlinking any existing PHP version..."
        brew unlink php >/dev/null 2>&1 || true
        brew unlink php@*.* >/dev/null 2>&1 || true

        if [ "$version" = "system" ]; then
            # Special case for switching to system PHP
            echo "system" >"$PHPVM_ACTIVE_VERSION_FILE"
            phpvm_echo "Switched to system PHP."
            return 0
        fi

        if [ -d "$HOMEBREW_PREFIX/Cellar/php@$version" ]; then
            phpvm_debug "Linking PHP $version..."
            brew link php@"$version" --force --overwrite || {
                phpvm_err "Failed to link PHP $version."
                return 1
            }
        elif [ -d "$HOMEBREW_PREFIX/Cellar/php" ]; then
            installed_version=$(get_installed_php_version)
            if [ "$installed_version" = "$version" ]; then
                brew link php --force --overwrite
                phpvm_echo "Using PHP $version installed as 'php'."
            else
                phpvm_err "PHP version $version is not installed. Installed version: $installed_version"
                return 1
            fi
        else
            phpvm_err "PHP version $version is not installed."
            return 1
        fi
        ;;
    apt | dnf | yum | pacman)
        # For Linux package managers, we use update-alternatives if available
        if command -v update-alternatives >/dev/null 2>&1; then
            if [ "$version" = "system" ]; then
                # Use auto option for system default
                run_with_sudo update-alternatives --auto php || {
                    phpvm_err "Failed to switch to system PHP version."
                    return 1
                }
                echo "system" >"$PHPVM_ACTIVE_VERSION_FILE"
                phpvm_echo "Switched to system PHP."
                return 0
            fi

            if [ -f "/usr/bin/php$version" ]; then
                run_with_sudo update-alternatives --set php "/usr/bin/php$version" || {
                    phpvm_err "Failed to switch to PHP $version using update-alternatives."
                    return 1
                }
            else
                phpvm_err "PHP binary for version $version not found at /usr/bin/php$version"
                return 1
            fi
        else
            phpvm_err "update-alternatives command not found. Cannot switch PHP versions on this system."
            return 1
        fi
        ;;
    esac

    phpvm_debug "Updating symlink to PHP $version..."
    rm -f "$PHPVM_CURRENT_SYMLINK"
    ln -s "$PHP_BIN_PATH/php" "$PHPVM_CURRENT_SYMLINK" || {
        phpvm_err "Failed to update symlink."
        return 1
    }

    echo "$version" >"$PHPVM_ACTIVE_VERSION_FILE" || {
        phpvm_err "Failed to write active version."
        return 1
    }

    phpvm_echo "Switched to PHP $version."
    return 0
}

# Switch to the system PHP version
system_php_version() {
    phpvm_echo "Switching to system PHP version..."
    use_php_version "system"
    return $?
}

# Auto-switch PHP version based on .phpvmrc file
auto_switch_php_version() {
    current_dir="$PWD"
    found=0
    depth=0
    max_depth=5

    while [ "$current_dir" != "/" ] && [ $depth -lt $max_depth ]; do
        if [ -f "$current_dir/.phpvmrc" ]; then
            if ! version=$(tr -d '[:space:]' <"$current_dir/.phpvmrc"); then
                phpvm_err "Failed to read $current_dir/.phpvmrc"
                return 1
            fi
            if [ -n "$version" ]; then
                phpvm_echo "Auto-switching to PHP $version (from $current_dir/.phpvmrc)"
                if ! use_php_version "$version"; then
                    phpvm_err "Failed to switch to PHP $version from $current_dir/.phpvmrc"
                    return 1
                fi
            else
                phpvm_warn "No valid PHP version found in $current_dir/.phpvmrc."
                return 1
            fi
            found=1
            break
        fi
        current_dir=$(dirname "$current_dir")
        depth=$((depth + 1))
    done

    if [ $found -eq 0 ]; then
        phpvm_warn "No .phpvmrc file found in the current or parent directories."
        return 1
    fi
    return 0
}

# List installed PHP versions
list_installed_versions() {
    phpvm_echo "Installed PHP versions:"

    # Handle test mode specifically
    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        for dir in "${TEST_PREFIX:-/tmp}/opt/homebrew/Cellar/php"*; do
            if [ -d "$dir" ]; then
                base_name=$(basename "$dir")
                if [ "$base_name" = "php" ]; then
                    echo "  8.0.0 (latest)"
                else
                    # Extract version from php@X.Y format
                    version=${base_name#php@}
                    echo "  $version"
                fi
            fi
        done
        echo "  system (macOS built-in PHP)"
        echo ""
        if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
            active_version=$(cat "$PHPVM_ACTIVE_VERSION_FILE")
            phpvm_echo "Active version: $active_version"
        else
            phpvm_warn "No active PHP version set."
        fi
        return 0
    fi

    case "$PKG_MANAGER" in
    brew)
        if [ -d "$HOMEBREW_PREFIX/Cellar" ]; then
            for dir in "$HOMEBREW_PREFIX/Cellar/php"*; do
                if [ -d "$dir" ]; then
                    base_name=$(basename "$dir")
                    if [ "$base_name" = "php" ]; then
                        version=$(get_installed_php_version)
                        echo "  $version (latest)"
                    else
                        # Extract version from php@X.Y format
                        version=${base_name#php@}
                        echo "  $version"
                    fi
                fi
            done
        fi
        echo "  system (macOS built-in PHP)"
        ;;
    apt)
        dpkg -l | grep -E '^ii +php[0-9]+\.[0-9]+' | awk '{print "  " $2}' | sed 's/^  php//'
        echo "  system (default system PHP)"
        ;;
    dnf | yum)
        $PKG_MANAGER list installed | grep -E 'php[0-9]+\.' | awk '{print "  " $1}' | sed 's/^  php//'
        echo "  system (default system PHP)"
        ;;
    pacman)
        pacman -Q | grep '^php' | awk '{print "  " $1}' | sed 's/^  php//'
        echo "  system (default system PHP)"
        ;;
    esac

    echo ""
    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
        active_version=$(cat "$PHPVM_ACTIVE_VERSION_FILE")
        phpvm_echo "Active version: $active_version"
    else
        phpvm_warn "No active PHP version set."
    fi
}

# Print help message
print_help() {
    cat <<EOF
phpvm - PHP Version Manager

Usage:
  phpvm install <version>  Install specified PHP version
  phpvm use <version>      Switch to specified PHP version
  phpvm system             Switch to system PHP version
  phpvm auto               Auto-switch based on .phpvmrc file
  phpvm list               List installed PHP versions
  phpvm help               Show this help message
  phpvm test               Run self-tests to verify functionality

Examples:
  phpvm install 8.1        Install PHP 8.1
  phpvm use 7.4            Switch to PHP 7.4
  phpvm system             Switch to system PHP version
  phpvm auto               Auto-switch based on current directory
EOF
}

# Self-tests for phpvm functionality
run_tests() {
    # Set up test environment
    echo "${GREEN}Setting up test environment...${RESET}"

    # Create a temporary directory for tests
    TEST_DIR=$(mktemp -d)

    # Set test-specific environment variables
    export PHPVM_TEST_MODE=true
    export HOME="$TEST_DIR"
    export PHPVM_DIR="$HOME/.phpvm"
    export PHPVM_VERSIONS_DIR="$PHPVM_DIR/versions"
    export PHPVM_ACTIVE_VERSION_FILE="$PHPVM_DIR/active_version"
    export PHPVM_CURRENT_SYMLINK="$PHPVM_DIR/current"
    export TEST_PREFIX="$TEST_DIR"

    # Create mock commands for testing
    MOCK_BIN_DIR="$TEST_DIR/bin"
    mkdir -p "$MOCK_BIN_DIR"
    PATH="$MOCK_BIN_DIR:$PATH"

    # Mock brew command
    cat >"$MOCK_BIN_DIR/brew" <<'EOF'
#!/bin/sh
if [ "$1" = "--prefix" ]; then
    echo "/opt/homebrew"
    exit 0
fi

if [ "$1" = "install" ]; then
    mkdir -p "$TEST_PREFIX/opt/homebrew/Cellar/php"
    mkdir -p "$TEST_PREFIX/opt/homebrew/Cellar/php@$2"
    echo "Installed PHP $2"
    exit 0
elif [ "$1" = "unlink" ]; then
    echo "Unlinked PHP"
    exit 0
elif [ "$1" = "link" ]; then
    echo "Linked PHP"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/brew"

    # Mock uname command
    cat >"$MOCK_BIN_DIR/uname" <<'EOF'
#!/bin/sh
echo "Darwin"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/uname"

    # Mock php and php-config commands
    cat >"$MOCK_BIN_DIR/php" <<'EOF'
#!/bin/sh
if [ "$1" = "-v" ]; then
    echo "PHP 8.0.0 (cli)"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/php"

    cat >"$MOCK_BIN_DIR/php-config" <<'EOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
    echo "8.0.0"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/php-config"

    # Mock sudo command
    cat >"$MOCK_BIN_DIR/sudo" <<'EOF'
#!/bin/sh
# Just execute the command without actual sudo
"$@"
exit $?
EOF
    chmod +x "$MOCK_BIN_DIR/sudo"

    # Mock id command
    cat >"$MOCK_BIN_DIR/id" <<'EOF'
#!/bin/sh
if [ "$1" = "-u" ]; then
    echo "1000"  # Non-root user
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/id"

    # Create test directories
    mkdir -p "$PHPVM_DIR"
    mkdir -p "$TEST_DIR/opt/homebrew/Cellar/php@7.4/bin"

    test_function() {
        local name="$1"
        local status=0

        shift
        echo -n "${GREEN}Testing $name... ${RESET}"

        if "$@"; then
            echo "${GREEN}✓ PASSED${RESET}"
            return 0
        else
            echo "${RED}✗ FAILED${RESET}"
            return 1
        fi
    }

    # Check the results of a function
    assert_success() {
        "$@"
        local status=$?
        return $status
    }

    # Check output contains expected text
    assert_output_contains() {
        local expected="$1"
        shift

        # Create a temporary file to capture both stdout and stderr
        output_file=$(mktemp)

        # Run the command, redirecting both stdout and stderr to the temporary file
        "$@" >"$output_file" 2>&1

        # Check if the output contains the expected text
        if grep -q "$expected" "$output_file"; then
            rm "$output_file"
            return 0
        else
            echo "   Expected output to contain: $expected"
            echo "   Actual output: $(cat "$output_file")"
            rm "$output_file"
            return 1
        fi
    }

    # Check that a command creates a directory
    assert_dir_exists() {
        local dir="$1"
        shift

        "$@" >/dev/null 2>&1
        if [ -d "$dir" ]; then
            return 0
        else
            echo "   Directory $dir does not exist"
            return 1
        fi
    }

    # Test create_directories function
    test_create_directories() {
        rm -rf "$PHPVM_DIR"
        assert_dir_exists "$PHPVM_VERSIONS_DIR" create_directories
    }

    # Test output functions with timestamps
    test_output_functions() {
        # Check that output contains timestamp format [YYYY-MM-DD HH:MM:SS]
        assert_output_contains "[INFO]" phpvm_echo "Test message" &&
            assert_output_contains "[ERROR]" phpvm_err "Test error" &&
            assert_output_contains "[WARNING]" phpvm_warn "Test warning"
    }

    # Test timestamp format in logs
    test_timestamp_format() {
        # Extract just the timestamp portion from the output
        output=$(phpvm_echo "Test message")
        timestamp=$(echo "$output" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}')

        # Check that it's a valid timestamp format
        if [ -n "$timestamp" ]; then
            return 0
        else
            echo "   Expected output to contain timestamp in YYYY-MM-DD HH:MM:SS format"
            echo "   Actual output: $output"
            return 1
        fi
    }

    # Test the run_with_sudo function
    test_run_with_sudo() {
        # Create a test command that outputs its arguments
        cat >"$MOCK_BIN_DIR/testcmd" <<'EOF'
#!/bin/sh
echo "Command executed with args: $@"
exit 0
EOF
        chmod +x "$MOCK_BIN_DIR/testcmd"

        # Run the command through run_with_sudo
        output=$(run_with_sudo testcmd arg1 arg2)

        # Check that the command was executed with the correct arguments
        if echo "$output" | grep -q "Command executed with args: arg1 arg2"; then
            return 0
        else
            echo "   Expected command to be executed with args"
            echo "   Actual output: $output"
            return 1
        fi
    }

    # Test detect_system function
    test_detect_system() {
        detect_system
        [ "$PKG_MANAGER" = "brew" ] && [ -n "$PHP_BIN_PATH" ]
    }

    # Test get_installed_php_version
    test_get_installed_php_version() {
        result=$(get_installed_php_version)
        [ "$result" = "8.0.0" ]
    }

    # Test install_php
    test_install_php() {
        install_php "7.4" >/dev/null
        local status=$?

        # Check for success and file existence
        [ $status -eq 0 ] && [ -d "$TEST_DIR/opt/homebrew/Cellar/php@7.4/bin" ]
    }

    # Test use_php_version
    test_use_php_version() {
        # Create mock installation
        mkdir -p "$TEST_DIR/opt/homebrew/Cellar/php@7.4/bin"

        # Test switching
        use_php_version "7.4" >/dev/null
        local status=$?

        # Check for success and correct active version
        [ $status -eq 0 ] && [ "$(cat $PHPVM_ACTIVE_VERSION_FILE)" = "7.4" ]
    }

    # Test system_php_version
    test_system_php_version() {
        system_php_version >/dev/null
        local status=$?

        # Check for success and correct active version
        [ $status -eq 0 ] && [ "$(cat $PHPVM_ACTIVE_VERSION_FILE)" = "system" ]
    }

    # Test auto_switch_php_version
    test_auto_switch() {
        # Create mock installation
        mkdir -p "$TEST_DIR/opt/homebrew/Cellar/php@7.4/bin"

        # Create a project with .phpvmrc
        mkdir -p "$HOME/project"
        echo "7.4" >"$HOME/project/.phpvmrc"

        # Change to the project directory
        cd "$HOME/project"

        # Test auto-switching
        auto_switch_php_version >/dev/null
        local status=$?

        # Check for success and correct active version
        [ $status -eq 0 ] && [ "$(cat $PHPVM_ACTIVE_VERSION_FILE)" = "7.4" ]
    }

    # Test handling of corrupted .phpvmrc file
    test_corrupted_phpvmrc() {
        # Create an invalid .phpvmrc file (empty)
        mkdir -p "$HOME/bad_project"
        touch "$HOME/bad_project/.phpvmrc"

        # Change to the project directory
        cd "$HOME/bad_project"

        # Test auto-switching with empty .phpvmrc
        output=$(auto_switch_php_version 2>&1)
        status=$?

        # Should fail with an appropriate warning
        [ $status -eq 1 ] && echo "$output" | grep -q "No valid PHP version found"
    }

    # Run all tests
    echo "${GREEN}Running phpvm self-tests...${RESET}"

    failed=0
    total=0

    total=$((total + 1))
    test_function "create_directories" test_create_directories || failed=$((failed + 1))

    total=$((total + 1))
    test_function "output functions" test_output_functions || failed=$((failed + 1))

    total=$((total + 1))
    test_function "timestamp format" test_timestamp_format || failed=$((failed + 1))

    total=$((total + 1))
    test_function "run_with_sudo" test_run_with_sudo || failed=$((failed + 1))

    total=$((total + 1))
    test_function "detect_system" test_detect_system || failed=$((failed + 1))

    total=$((total + 1))
    test_function "get_installed_php_version" test_get_installed_php_version || failed=$((failed + 1))

    total=$((total + 1))
    test_function "install_php" test_install_php || failed=$((failed + 1))

    total=$((total + 1))
    test_function "use_php_version" test_use_php_version || failed=$((failed + 1))

    total=$((total + 1))
    test_function "system_php_version" test_system_php_version || failed=$((failed + 1))

    total=$((total + 1))
    test_function "auto_switch_php_version" test_auto_switch || failed=$((failed + 1))

    total=$((total + 1))
    test_function "corrupted .phpvmrc handling" test_corrupted_phpvmrc || failed=$((failed + 1))

    # Clean up
    rm -rf "$TEST_DIR"

    # Print results
    passed=$((total - failed))
    echo ""
    echo "${GREEN}Test Results: $passed/$total tests passed${RESET}"

    if [ $failed -eq 0 ]; then
        echo "${GREEN}All tests passed!${RESET}"
        return 0
    else
        echo "${RED}$failed tests failed.${RESET}"
        return 1
    fi
}

# Uninstall a specific PHP version
uninstall_php() {
    version="$1"
    [ -z "$version" ] && {
        phpvm_err "No PHP version specified for uninstallation."
        return 1
    }

    phpvm_echo "Uninstalling PHP $version..."

    # If in test mode, just remove the mock directory
    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        case "$PKG_MANAGER" in
        brew)
            mock_dir="${TEST_PREFIX:-/tmp}/opt/homebrew/Cellar/php@$version"
            ;;
        apt)
            mock_dir="${TEST_PREFIX:-/tmp}/var/lib/dpkg/info/php$version"
            ;;
        dnf | yum)
            mock_dir="${TEST_PREFIX:-/tmp}/var/lib/rpm/php$version"
            ;;
        pacman)
            mock_dir="${TEST_PREFIX:-/tmp}/var/lib/pacman/local/php$version"
            ;;
        *)
            phpvm_err "Test mode not supported for this package manager."
            return 1
            ;;
        esac
        rm -rf "$mock_dir"
        phpvm_echo "PHP $version uninstalled."
        return 0
    fi

    case "$PKG_MANAGER" in
    brew)
        if brew list --versions php@"$version" >/dev/null 2>&1; then
            brew uninstall php@"$version" || {
                phpvm_err "Failed to uninstall PHP $version with Homebrew."
                return 1
            }
            phpvm_echo "PHP $version uninstalled."
        else
            phpvm_warn "PHP $version is not installed via Homebrew."
            return 1
        fi
        ;;
    apt)
        if dpkg -l | grep -q "^ii\s*php$version\s"; then
            run_with_sudo apt-get remove -y php"$version" || {
                phpvm_err "Failed to uninstall PHP $version with apt."
                return 1
            }
            phpvm_echo "PHP $version uninstalled."
        else
            phpvm_warn "PHP $version is not installed via apt."
            return 1
        fi
        ;;
    dnf | yum)
        if $PKG_MANAGER list installed | grep -q "^php$version$"; then
            run_with_sudo $PKG_MANAGER remove -y php"$version" || {
                phpvm_err "Failed to uninstall PHP $version with $PKG_MANAGER."
                return 1
            }
            phpvm_echo "PHP $version uninstalled."
        else
            phpvm_warn "PHP $version is not installed via $PKG_MANAGER."
            return 1
        fi
        ;;
    pacman)
        if pacman -Qi php"$version" > /dev/null 2>&1; then
            run_with_sudo pacman -R --noconfirm php"$version" || {
                phpvm_err "Failed to uninstall PHP $version with pacman."
                return 1
            }
            phpvm_echo "PHP $version uninstalled."
        else
            phpvm_warn "PHP $version is not installed via pacman."
            return 1
        fi
        ;;
    *)
        phpvm_err "Uninstall not supported for this package manager."
        return 1
        ;;
    esac

    # Clean up symlink and active version if needed
    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ] && [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "$version" ]; then
        rm -f "$PHPVM_CURRENT_SYMLINK"
        rm -f "$PHPVM_ACTIVE_VERSION_FILE"
        phpvm_warn "Active PHP version was uninstalled. Please select another version."
    fi

    return 0
}

# Main function to handle commands
main() {
    # Only run if not being sourced
    create_directories
    detect_system

    if [ "$#" -eq 0 ]; then
        phpvm_err "No command provided."
        print_help
        exit 1
    fi

    command="$1"
    shift

    case "$command" in
    use)
        if [ "$#" -eq 0 ]; then
            phpvm_err "Missing PHP version argument for 'use' command."
            exit 1
        fi
        use_php_version "$@"
        ;;
    install)
        if [ "$#" -eq 0 ]; then
            phpvm_err "Missing PHP version argument for 'install' command."
            exit 1
        fi
        install_php "$@"
        ;;
    uninstall)
        if [ "$#" -eq 0 ]; then
            phpvm_err "Missing PHP version argument for 'uninstall' command."
            exit 1
        fi
        uninstall_php "$@"
        ;;
    system)
        system_php_version
        ;;
    auto)
        auto_switch_php_version
        ;;
    list)
        list_installed_versions
        ;;
    help)
        print_help
        ;;
    test)
        run_tests
        ;;
    *)
        phpvm_err "Unknown command: $command"
        print_help
        exit 1
        ;;
    esac
}

# Robust execution detection with multiple fallbacks
phpvm_should_execute_main() {
    # Layer 1: Explicit override (highest priority)
    case "${PHPVM_SOURCED:-auto}" in
    true | 1 | yes) return 1 ;; # Don't execute
    false | 0 | no) return 0 ;; # Execute
    esac

    # Layer 2: Test mode
    [ "$PHPVM_TEST_MODE" = "true" ] && return 1

    # Layer 3: Check if script has arguments (most reliable indicator)
    # If script is called with arguments, it's likely being executed
    if [ $# -gt 0 ]; then
        return 0 # Execute
    fi

    # Layer 4: Return test (fallback for POSIX shells)
    if (return 0 2>/dev/null); then
        return 1 # Sourced
    else
        return 0 # Executed
    fi
}

# Safe main execution with error handling
if phpvm_should_execute_main "$@"; then
    phpvm_debug "Executing main with $# arguments"

    # Verify main function exists
    if command -v main >/dev/null 2>&1; then
        main "$@"
    else
        phpvm_err "main function not found - script may be corrupted"
        exit 1
    fi
else
    phpvm_debug "Script sourced for function loading"

    # Set environment for shell integration
    PHPVM_FUNCTIONS_LOADED=true
    export PHPVM_FUNCTIONS_LOADED

    # Auto-use .phpvmrc if enabled and present
    if [ "${PHPVM_AUTO_USE:-true}" = "true" ] && [ -f ".phpvmrc" ]; then
        command -v auto_switch_php_version >/dev/null 2>&1 &&
            auto_switch_php_version 2>/dev/null || true
    fi
fi
