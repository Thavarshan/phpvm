#!/bin/bash

# phpvm - A PHP Version Manager for macOS and Linux
# Author: Jerome Thayananthajothy (tjthavarshan@gmail.com)
# Version: 1.10.0
#
# IMPORTANT: This script is written for bash and uses bashisms (arrays, process substitution, etc.)
# For sourcing into your shell, use bash only. Zsh users should run phpvm via:
#   bash -c 'source ~/.phpvm/phpvm.sh && phpvm <command>'
# Or consider creating a zsh wrapper function that delegates to bash.

# shellcheck disable=SC2155  # Allow declare and assign on same line for better readability

PHPVM_VERSION="1.10.0"

# Test mode flag
PHPVM_TEST_MODE="${PHPVM_TEST_MODE:-false}"

PHPVM_DIR="${PHPVM_DIR:-$HOME/.phpvm}"
PHPVM_VERSIONS_DIR="$PHPVM_DIR/versions"
PHPVM_ACTIVE_VERSION_FILE="$PHPVM_DIR/active_version"
PHPVM_CURRENT_SYMLINK="$PHPVM_DIR/current"
DEBUG=false # Set to true to enable debug logs
PHPVM_LOG_TIMESTAMPS="${PHPVM_LOG_TIMESTAMPS:-false}"
PHPVM_PATCH_VERSION_WARNING_SHOWN="${PHPVM_PATCH_VERSION_WARNING_SHOWN:-false}"

# Exit codes for consistent error handling
# These follow common Unix conventions and provide specific error information
PHPVM_EXIT_SUCCESS=0       # Operation completed successfully
PHPVM_EXIT_ERROR=1         # General error
PHPVM_EXIT_INVALID_ARG=2   # Invalid argument or usage error
PHPVM_EXIT_NOT_FOUND=3     # Version not found (not available)
PHPVM_EXIT_NOT_INSTALLED=4 # Version not installed locally
PHPVM_EXIT_FILE_ERROR=5    # File or permission error
PHPVM_EXIT_UNKNOWN_CMD=127 # Unknown command

# Cache for command availability checks
PHPVM_CACHE_PHP_CONFIG=""
PHPVM_CACHE_PHP=""

# Helper to check if a command exists (DRY for 'command -v X > /dev/null 2>&1')
# Usage: command_exists <command_name>
# Returns: 0 if command exists, 1 otherwise
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Test mode helpers
phpvm_is_test_mode() {
    [ "${PHPVM_TEST_MODE}" = "true" ]
}

phpvm_test_prefix() {
    echo "${TEST_PREFIX:-/tmp}"
}

phpvm_test_cellar_root() {
    echo "$(phpvm_test_prefix)/opt/homebrew/Cellar"
}

phpvm_test_php_cellar_dir() {
    local version="$1"
    echo "$(phpvm_test_cellar_root)/php@${version}"
}

phpvm_test_php_bin_dir() {
    local version="$1"
    echo "$(phpvm_test_php_cellar_dir "$version")/bin"
}

phpvm_test_php_installed() {
    local version="$1"
    [ -d "$(phpvm_test_php_cellar_dir "$version")" ]
}

phpvm_test_install_php() {
    local version="$1"
    local bin_dir
    local php_binary
    bin_dir="$(phpvm_test_php_bin_dir "$version")"
    mkdir -p "$bin_dir"

    # Create a mock PHP binary that behaves like real php for basic operations
    php_binary="$bin_dir/php"
    cat > "$php_binary" << 'EOF'
#!/bin/sh
# Mock PHP binary for phpvm tests
version="${PHP_TEST_VERSION:-8.2.0}"

if [ "$1" = "-v" ]; then
    echo "PHP ${version} (cli) (built: Jan 1 2024 00:00:00) (NTS)"
    exit 0
elif [ "$1" = "-r" ]; then
    # Handle php -r 'code' for version extraction
    shift
    code="$1"
    case "$code" in
        *PHP_MAJOR_VERSION*PHP_MINOR_VERSION*)
            # Extract major.minor from our version
            echo "${version}" | cut -d. -f1-2
            ;;
        *)
            # Simple eval-like behavior for other code
            echo "${version}"
            ;;
    esac
    exit 0
fi

echo "PHP ${version}"
exit 0
EOF
    chmod +x "$php_binary"
}

phpvm_test_php_path() {
    local version="$1"
    echo "$(phpvm_test_php_cellar_dir "$version")/bin/php"
}

# State helpers
set_active_version() {
    local version="$1"
    if ! phpvm_atomic_write "$PHPVM_ACTIVE_VERSION_FILE" "$version"; then
        phpvm_err "Failed to write active version file"
        return 1
    fi
    return 0
}

# Update the current symlink to point to the active PHP binary
# This links to whatever `command -v php` resolves to, ensuring the symlink
# points to the actual php binary that the shell would execute.
# SAFETY: Verifies target exists before creating symlink to prevent broken symlinks.
update_current_symlink() {
    local target

    # In test mode, use the test prefix path
    if phpvm_is_test_mode; then
        target="$PHP_BIN_PATH/php"
    else
        # Use command -v to get the actual resolved php path
        target=$(command -v php 2> /dev/null) || true
    fi

    # Verify we have a target and it exists
    if [ -z "$target" ]; then
        phpvm_warn "No php binary found in PATH (skipping symlink update)"
        return 0 # Non-fatal - symlink is convenience, not critical
    fi

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        phpvm_warn "Symlink target does not exist: $target (skipping symlink update)"
        return 0 # Non-fatal - symlink is convenience, not critical
    fi

    rm -f "$PHPVM_CURRENT_SYMLINK"
    ln -s "$target" "$PHPVM_CURRENT_SYMLINK" || {
        phpvm_err "Failed to update symlink."
        return 1
    }
    return 0
}

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

# Check if terminal supports colors
phpvm_has_colors() {
    # Check if stdout is a terminal
    if [ ! -t 1 ]; then
        return 1
    fi

    # Check TERM variable
    case "${TERM:-}" in
    dumb | '') return 1 ;;
    esac

    # Check for NO_COLOR environment variable (https://no-color.org/)
    if [ -n "${NO_COLOR:-}" ]; then
        return 1
    fi

    # Check tput for color support
    if command_exists tput; then
        local colors
        colors=$(tput colors 2> /dev/null || echo 0)
        [ "$colors" -ge 8 ] && return 0
    fi

    # Fallback: assume colors are supported for common terminals
    return 0
}

# Initialize ANSI color codes based on terminal support
phpvm_init_colors() {
    if phpvm_has_colors; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m')
        RESET=$(printf '\033[0m')
    else
        RED=''
        GREEN=''
        YELLOW=''
        RESET=''
    fi
}

# Initialize colors on load
phpvm_init_colors

# Output functions
phpvm_log() {
    local level="$1"
    shift
    local color_prefix=""
    local color_suffix=""

    if [ -n "${RESET:-}" ]; then
        case "$level" in
        ERROR) color_prefix="${RED}" ;;
        WARNING) color_prefix="${YELLOW}" ;;
        INFO) color_prefix="${GREEN}" ;;
        esac
        color_suffix="${RESET}"
    fi

    if [ "$DEBUG" = "true" ] || [ "$PHPVM_LOG_TIMESTAMPS" = "true" ]; then
        log_with_timestamp "$level" "${color_prefix}$*${color_suffix}"
    else
        printf "%s\n" "${color_prefix}$*${color_suffix}"
    fi
}

phpvm_echo() { phpvm_log "INFO" "$*"; }
phpvm_err() { phpvm_log "ERROR" "$*" >&2; }
phpvm_warn() { phpvm_log "WARNING" "$*" >&2; }
phpvm_debug() { if [ "$DEBUG" = "true" ]; then log_with_timestamp "DEBUG" "$*"; fi; }

# Atomic file write - writes to temp file then moves to target
# This prevents race conditions and partial writes
phpvm_atomic_write() {
    local target_file="$1"
    local content="$2"
    local temp_file
    local target_dir

    # Get directory of target file
    target_dir="$(dirname "$target_file")"

    # Create secure temp file using mktemp (more secure than predictable filename)
    temp_file=$(mktemp "${target_dir}/.phpvm_tmp.XXXXXXXXXX") || {
        phpvm_debug "Failed to create temp file with mktemp"
        return 1
    }

    # Set safe permissions
    chmod 0644 "$temp_file" 2> /dev/null || {
        rm -f "$temp_file" 2> /dev/null
        return 1
    }

    # Write content to temp file
    if ! printf '%s\n' "$content" > "$temp_file" 2> /dev/null; then
        rm -f "$temp_file" 2> /dev/null
        return 1
    fi

    # Atomically move temp file to target
    if ! mv -f "$temp_file" "$target_file" 2> /dev/null; then
        rm -f "$temp_file" 2> /dev/null
        return 1
    fi

    return 0
}

# Ensure all required phpvm directories exist (DRY for repeated mkdir -p calls)
# Usage: ensure_phpvm_dirs
# Returns: 0 on success, 1 on failure
ensure_phpvm_dirs() {
    # Core phpvm directory
    if [ ! -d "$PHPVM_DIR" ]; then
        mkdir -p "$PHPVM_DIR" || {
            phpvm_err "Failed to create directory $PHPVM_DIR"
            return 1
        }
    fi

    # Versions directory - critical for phpvm operation
    if [ ! -d "$PHPVM_VERSIONS_DIR" ]; then
        mkdir -p "$PHPVM_VERSIONS_DIR" || {
            phpvm_err "Failed to create directory $PHPVM_VERSIONS_DIR"
            return 1
        }
    fi

    # Alias directory for version aliases (e.g., default -> 8.2) - required for alias commands
    if [ ! -d "$PHPVM_DIR/alias" ]; then
        mkdir -p "$PHPVM_DIR/alias" || {
            phpvm_err "Failed to create alias directory $PHPVM_DIR/alias"
            return 1
        }
    fi

    # Cache directory for metadata and downloads
    mkdir -p "$PHPVM_DIR/cache" 2> /dev/null || true

    return 0
}

# Create the required directory structure (wrapper for compatibility)
create_directories() {
    ensure_phpvm_dirs
}

# Locking mechanism to prevent concurrent operations
# Uses mkdir for atomic lock creation (POSIX-compliant)
phpvm_lock() {
    local lockdir="$PHPVM_DIR/.lock"
    local max_wait=30
    local waited=0
    local lock_pid

    while ! mkdir "$lockdir" 2> /dev/null; do
        # Reset lock_pid at top of each iteration to avoid staleness
        lock_pid=""

        # Check if lock is stale (process no longer exists)
        if [ -f "$lockdir/pid" ]; then
            lock_pid=$(cat "$lockdir/pid" 2> /dev/null || echo "")
            if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2> /dev/null; then
                phpvm_warn "Removing stale lock from process $lock_pid"
                rm -rf "$lockdir" 2> /dev/null || true
                continue
            fi
        fi

        if [ "$waited" -ge "$max_wait" ]; then
            phpvm_err "Failed to acquire lock after ${max_wait}s. Another phpvm operation may be running."
            if [ -n "$lock_pid" ]; then
                phpvm_warn "Lock held by process: $lock_pid"
            fi
            phpvm_warn "If no other phpvm process is running, remove: $lockdir"
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done

    # Store PID in lock directory for debugging
    echo "$$" > "$lockdir/pid" 2> /dev/null || true
    return 0
}

phpvm_unlock() {
    local lockdir="$PHPVM_DIR/.lock"

    # Belt-and-suspenders safety checks before rm -rf
    [ -n "${PHPVM_DIR:-}" ] || return 0
    [ "$PHPVM_DIR" != "/" ] || return 0

    # Verify lockdir is actually under PHPVM_DIR before removal
    case "$lockdir" in
    "$PHPVM_DIR"/.lock)
        rm -rf "$lockdir" 2> /dev/null || true
        ;;
    *)
        phpvm_warn "Lock directory path looks suspicious, skipping removal: $lockdir"
        return 1
        ;;
    esac
}

# Execute a command with lock protection
# Usage: phpvm_with_lock <function_name> [args...]
phpvm_with_lock() {
    local func="$1"
    shift

    if ! phpvm_lock; then
        return "$PHPVM_EXIT_ERROR"
    fi

    # Save existing traps to restore them after lock release
    # This is critical for shell integration - don't clobber user's traps
    local saved_exit_trap saved_int_trap saved_term_trap saved_hup_trap
    saved_exit_trap=$(trap -p EXIT)
    saved_int_trap=$(trap -p INT)
    saved_term_trap=$(trap -p TERM)
    saved_hup_trap=$(trap -p HUP)

    # Set our cleanup traps
    trap 'phpvm_unlock' EXIT INT TERM HUP

    local result
    "$func" "$@"
    result=$?

    # Unlock BEFORE restoring traps to prevent lock leaks if interrupted
    # between trap restoration and unlock
    phpvm_unlock

    # Restore original traps (or explicitly clear if user had none)
    # Critical: if saved_*_trap is empty, user had no trap, so clear ours with 'trap -'
    if [ -n "$saved_exit_trap" ]; then
        eval "$saved_exit_trap"
    else
        trap - EXIT
    fi
    if [ -n "$saved_int_trap" ]; then
        eval "$saved_int_trap"
    else
        trap - INT
    fi
    if [ -n "$saved_term_trap" ]; then
        eval "$saved_term_trap"
    else
        trap - TERM
    fi
    if [ -n "$saved_hup_trap" ]; then
        eval "$saved_hup_trap"
    else
        trap - HUP
    fi

    return "$result"
}

# Get OS information
get_os_info() {
    PHPVM_OS_TYPE="$(command uname -s)"
    PHPVM_OS_ARCH="$(command uname -m)"

    # Detect macOS version
    if [ "$PHPVM_OS_TYPE" = "Darwin" ]; then
        if command_exists sw_vers; then
            PHPVM_MACOS_VERSION="$(sw_vers -productVersion)"
            PHPVM_MACOS_MAJOR="$(echo "$PHPVM_MACOS_VERSION" | command cut -d. -f1)"
            PHPVM_MACOS_MINOR="$(echo "$PHPVM_MACOS_VERSION" | command cut -d. -f2)"
        fi
    fi

    # Detect Linux distribution and WSL
    if [ "$PHPVM_OS_TYPE" = "Linux" ]; then
        # Check for WSL (Windows Subsystem for Linux)
        if [ -f "/proc/version" ] && command grep -qi "microsoft\|WSL" /proc/version 2> /dev/null; then
            PHPVM_IS_WSL=true
            if command grep -qi "wsl2" /proc/version 2> /dev/null; then
                PHPVM_WSL_VERSION="2"
            else
                PHPVM_WSL_VERSION="1"
            fi
            phpvm_debug "Detected WSL $PHPVM_WSL_VERSION environment"
        else
            PHPVM_IS_WSL=false
        fi

        # Try modern method first
        if [ -f "/etc/os-release" ]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            PHPVM_LINUX_DISTRO="$ID"
            PHPVM_LINUX_VERSION="$VERSION_ID"
        elif [ -f "/etc/lsb-release" ]; then
            # shellcheck disable=SC1091
            . /etc/lsb-release
            PHPVM_LINUX_DISTRO="$(echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]')"
            PHPVM_LINUX_VERSION="$DISTRIB_RELEASE"
        elif [ -f "/etc/redhat-release" ]; then
            PHPVM_LINUX_DISTRO="rhel"
            PHPVM_LINUX_VERSION="$(command grep -o '[0-9]' /etc/redhat-release | command head -1)"
        elif [ -f "/etc/debian_version" ]; then
            PHPVM_LINUX_DISTRO="debian"
            PHPVM_LINUX_VERSION="$(command cat /etc/debian_version)"
        fi

        # WSL-specific adjustments
        if [ "$PHPVM_IS_WSL" = "true" ]; then
            phpvm_debug "WSL detected - applying WSL-specific configurations"
            # WSL may have different PATH requirements
            if [ "$PHPVM_WSL_VERSION" = "1" ]; then
                phpvm_warn "WSL 1 detected. Some features may not work as expected."
            fi
        fi
    fi
}

# Detect the system's package manager and OS
detect_system() {
    # Get detailed OS information
    get_os_info

    # In test mode, use sandbox defaults without requiring real package managers
    if phpvm_is_test_mode; then
        PKG_MANAGER="brew"
        HOMEBREW_PREFIX=$(phpvm_test_prefix)
        PHP_BIN_PATH="$HOMEBREW_PREFIX/bin"
        phpvm_debug "Test mode: using brew-style sandbox at $HOMEBREW_PREFIX"
        return 0
    fi

    if [ "$PHPVM_OS_TYPE" = "Darwin" ]; then
        PKG_MANAGER="brew"
        if ! command_exists brew; then
            phpvm_err "Homebrew is not installed. Please install Homebrew first."
            phpvm_warn "Visit https://brew.sh to install Homebrew."
            return 1
        fi

        # Use brew --prefix directly (simpler and more reliable)
        if command_exists brew; then
            HOMEBREW_PREFIX=$(brew --prefix 2> /dev/null)
        fi

        # Fallback for different macOS versions
        if [ -z "$HOMEBREW_PREFIX" ]; then
            if [ "$PHPVM_OS_ARCH" = "arm64" ] && [ -d "/opt/homebrew" ]; then
                HOMEBREW_PREFIX="/opt/homebrew"
            elif [ -d "/usr/local" ]; then
                HOMEBREW_PREFIX="/usr/local"
            fi
        fi

        PHP_BIN_PATH="$HOMEBREW_PREFIX/bin"
        phpvm_debug "Detected macOS $PHPVM_MACOS_VERSION on $PHPVM_OS_ARCH, Homebrew prefix: $HOMEBREW_PREFIX"
        return 0
    fi

    # Enhanced Linux package manager detection with distribution-specific logic
    if [ "$PHPVM_OS_TYPE" = "Linux" ]; then
        phpvm_debug "Detected Linux distribution: $PHPVM_LINUX_DISTRO $PHPVM_LINUX_VERSION"

        # Debian/Ubuntu family
        if command_exists apt-get; then
            PKG_MANAGER="apt"
            PHP_BIN_PATH="/usr/bin"

            # Check for specific Ubuntu/Debian PHP package patterns
            if [ "$PHPVM_LINUX_DISTRO" = "ubuntu" ] || [ "$PHPVM_LINUX_DISTRO" = "debian" ]; then
                # Modern Ubuntu/Debian uses ondrej/sury PPA for multiple PHP versions
                # No additional adjustments needed - handled by package abstraction layer
                :
            fi

        # RHEL/Fedora/CentOS family
        elif command_exists dnf; then
            PKG_MANAGER="dnf"
            PHP_BIN_PATH="/usr/bin"

        elif command_exists yum; then
            PKG_MANAGER="yum"
            PHP_BIN_PATH="/usr/bin"

            # RHEL/CentOS specific adjustments
            if [ "$PHPVM_LINUX_DISTRO" = "rhel" ] || [ "$PHPVM_LINUX_DISTRO" = "centos" ]; then
                # May need EPEL repository for modern PHP versions
                if [ -n "$PHPVM_LINUX_VERSION" ] && [ "$PHPVM_LINUX_VERSION" -lt 8 ]; then
                    phpvm_warn "RHEL/CentOS $PHPVM_LINUX_VERSION may require EPEL repository for modern PHP versions"
                fi
            fi

        # Arch Linux family
        elif command_exists pacman; then
            PKG_MANAGER="pacman"
            PHP_BIN_PATH="/usr/bin"

        # Linuxbrew as fallback
        elif command_exists brew; then
            PKG_MANAGER="brew"

            # Enhanced Linuxbrew detection
            if [ -n "$HOMEBREW_PREFIX" ]; then
                # Use existing prefix
                :
            elif [ -d "/home/linuxbrew/.linuxbrew" ]; then
                HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
            elif [ -d "$HOME/.linuxbrew" ]; then
                HOMEBREW_PREFIX="$HOME/.linuxbrew"
            elif command_exists brew; then
                HOMEBREW_PREFIX=$(brew --prefix 2> /dev/null || echo "/usr/local")
            else
                HOMEBREW_PREFIX="/usr/local"
            fi

            PHP_BIN_PATH="$HOMEBREW_PREFIX/bin"
            phpvm_debug "Using Linuxbrew at $HOMEBREW_PREFIX"

        else
            phpvm_err "No supported package manager found (apt, dnf, yum, pacman, or brew)."
            phpvm_warn "Detected: $PHPVM_LINUX_DISTRO $PHPVM_LINUX_VERSION"
            phpvm_warn "Consider installing one of the supported package managers or Linuxbrew."
            return 1
        fi
    else
        phpvm_err "Unsupported operating system: $PHPVM_OS_TYPE"
        return 1
    fi

    return 0
}

# Sanitize user input to prevent command injection
# Returns sanitized string via stdout, returns 1 if input contains dangerous characters
sanitize_input() {
    local input="$1"
    local max_length="${2:-20}"

    # Check for empty input
    if [ -z "$input" ]; then
        return 1
    fi

    # Check length (prevent buffer overflow style attacks)
    if [ ${#input} -gt "$max_length" ]; then
        phpvm_err "Input too long (max $max_length characters)"
        return 1
    fi

    # Allowlist only: letters, digits, dot, hyphen, underscore (for versions and aliases)
    # Use printf to avoid echo interpretation of strings like -n, -e, backslash escapes
    if ! printf '%s\n' "$input" | command grep -Eq '^[a-zA-Z0-9._-]+$'; then
        phpvm_err "Input contains invalid characters"
        return 1
    fi

    # Prevent values starting with '-' (defensive against option parsing issues)
    case "$input" in
    -*)
        phpvm_err "Input cannot start with '-'"
        return 1
        ;;
    esac

    printf '%s\n' "$input"
    return 0
}

# Normalize PHP version for package operations (X.Y.Z -> X.Y)
# Usage: phpvm_normalize_version <version>
# Outputs normalized version or nothing on failure
phpvm_normalize_version() {
    local version="$1"

    if is_valid_version_format "$version"; then
        printf '%s\n' "$version" | command awk -F. '{print $1 "." $2}'
        return 0
    fi

    return 1
}

# Check if string matches valid PHP version format (X.Y or X.Y.Z)
# Usage: is_valid_version_format <version>
# Returns: 0 if valid, 1 if invalid
is_valid_version_format() {
    local version="$1"
    printf '%s\n' "$version" | command grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'
}

phpvm_warn_patch_version_once() {
    local input_version="$1"
    local normalized_version="$2"

    if [ -n "$input_version" ] && [ -n "$normalized_version" ] && [ "$input_version" != "$normalized_version" ]; then
        if [ "${PHPVM_PATCH_VERSION_WARNING_SHOWN:-false}" != "true" ]; then
            phpvm_warn "Using $normalized_version for package operations."
            PHPVM_PATCH_VERSION_WARNING_SHOWN=true
            export PHPVM_PATCH_VERSION_WARNING_SHOWN
        fi
    fi
}

# Portable version sorter (works on BSD and GNU sort)
# Reads versions on stdin, outputs latest X.Y[.Z]
phpvm_latest_from_list() {
    command awk -F. '
      NF==2 { printf "%d.%d.%d %s\n",$1,$2,0,$0; next }
      NF>=3 { printf "%d.%d.%d %s\n",$1,$2,$3,$0; next }
    ' |
        command sort -k1,1n -k2,2n -k3,3n |
        command tail -1 |
        command awk '{print $2}'
}

# ============================================================================
# PACKAGE MANAGER ABSTRACTION LAYER
# Helper functions to reduce code duplication across package managers
# ============================================================================

# Get the package name format for a given PHP version
# Usage: get_php_package_name <version>
# Returns: Formatted package name (e.g., "php@8.2", "php8.2-cli", "php-cli")
get_php_package_name() {
    local version="$1"
    local normalized_version
    local formula

    normalized_version=$(phpvm_normalize_version "$version") || return 1
    case "$PKG_MANAGER" in
    brew)
        # Use helper to resolve actual installed formula
        if formula=$(brew_resolve_formula_for_version "$normalized_version"); then
            echo "$formula"
        else
            # Fallback to versioned format if not installed yet
            echo "php@${normalized_version}"
        fi
        ;;
    apt)
        # Ubuntu/Debian use phpX.Y-cli as the main package
        # This works with ondrej/sury PPA which is the standard way to get multiple PHP versions
        echo "php${normalized_version}-cli"
        ;;
    dnf | yum)
        # Fedora/RHEL: Use base php package + module streams
        # Note: Version switching on RHEL/Fedora typically requires:
        # 1. dnf module enable php:X.Y
        # 2. dnf install php-cli
        # We install the base package; module management happens in install function
        echo "php-cli"
        ;;
    pacman)
        # Arch typically uses unversioned 'php' package
        echo "php"
        ;;
    *)
        echo "php${normalized_version}"
        ;;
    esac
}

# Get the binary path for a PHP version
# Usage: get_php_binary_path <version>
# Returns: Full path to PHP binary
get_php_binary_path() {
    local version="$1"
    local normalized_version
    local formula

    normalized_version=$(phpvm_normalize_version "$version") || return 1
    case "$PKG_MANAGER" in
    brew)
        if [ -n "${HOMEBREW_PREFIX:-}" ]; then
            # Try to resolve actual formula first
            if formula=$(brew_resolve_formula_for_version "$normalized_version"); then
                if [ "$formula" = "php" ]; then
                    # Unversioned php can be in bin or opt/php/bin
                    if [ -x "${HOMEBREW_PREFIX}/bin/php" ]; then
                        echo "${HOMEBREW_PREFIX}/bin/php"
                    else
                        echo "${HOMEBREW_PREFIX}/opt/php/bin/php"
                    fi
                else
                    echo "${HOMEBREW_PREFIX}/opt/${formula}/bin/php"
                fi
            else
                # Fallback to versioned path
                echo "${HOMEBREW_PREFIX}/opt/php@${normalized_version}/bin/php"
            fi
        else
            echo "/opt/homebrew/opt/php@${normalized_version}/bin/php"
        fi
        ;;
    apt | dnf | yum | pacman)
        # Use linux_find_php_binary for reliable path resolution
        # Capture output to prevent any stdout side-effects from mixing with fallback
        local found_binary
        if found_binary=$(linux_find_php_binary "$normalized_version"); then
            echo "$found_binary"
        else
            echo "/usr/bin/php${normalized_version}"
        fi
        ;;
    *)
        echo "/usr/bin/php${normalized_version}"
        ;;
    esac
}

# Check if a PHP package is installed
# Usage: is_php_package_installed <version>
# Returns: 0 if installed, 1 if not
is_php_package_installed() {
    local version="$1"
    local package_name
    local php_binary
    local actual_version

    package_name=$(get_php_package_name "$version") || return 1

    case "$PKG_MANAGER" in
    brew)
        brew list --versions "$package_name" > /dev/null 2>&1
        ;;
    apt)
        # Use dpkg-query for exact package status check
        dpkg-query -W -f='${Status}' "$package_name" 2> /dev/null | command grep -Fq "install ok installed"
        ;;
    dnf | yum)
        # For dnf/yum, verify the actual binary resolves to the requested version
        # since these package managers use modules/streams and generic package names
        php_binary=$(linux_find_php_binary "$version" 2> /dev/null) || return 1

        # Verify binary exists and reports correct major.minor version
        if [ -x "$php_binary" ]; then
            actual_version=$("$php_binary" -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;' 2> /dev/null || true)
            [ "$actual_version" = "$version" ]
        else
            return 1
        fi
        ;;
    pacman)
        pacman -Qi "$package_name" > /dev/null 2>&1
        ;;
    *)
        return 1
        ;;
    esac
}

# Install PHP package using the appropriate package manager
# Usage: pkg_install_php <version>
# Returns: 0 on success, 1 on failure
pkg_install_php() {
    local version="$1"
    local package_name

    package_name=$(get_php_package_name "$version") || return 1

    case "$PKG_MANAGER" in
    brew)
        brew install "$package_name"
        ;;
    apt)
        run_with_sudo apt-get install -y "$package_name"
        ;;
    dnf)
        run_with_sudo dnf install -y "$package_name"
        ;;
    yum)
        run_with_sudo yum install -y "$package_name"
        ;;
    pacman)
        run_with_sudo pacman -S --noconfirm "$package_name"
        ;;
    *)
        return 1
        ;;
    esac
}

# Uninstall PHP package using the appropriate package manager
# Usage: pkg_uninstall_php <version>
# Returns: 0 on success, 1 on failure
pkg_uninstall_php() {
    local version="$1"
    local package_name
    local normalized_version

    package_name=$(get_php_package_name "$version") || return 1
    normalized_version=$(phpvm_normalize_version "$version") || return 1

    case "$PKG_MANAGER" in
    brew)
        brew uninstall "$package_name"
        ;;
    apt)
        # Symmetrical with install: remove cli+common+fpm packages
        run_with_sudo apt-get remove -y \
            "php${normalized_version}-cli" \
            "php${normalized_version}-common" \
            "php${normalized_version}-fpm" 2> /dev/null ||
            run_with_sudo apt-get remove -y "$package_name"
        ;;
    dnf)
        run_with_sudo dnf remove -y "$package_name"
        ;;
    yum)
        run_with_sudo yum remove -y "$package_name"
        ;;
    pacman)
        run_with_sudo pacman -R --noconfirm "$package_name"
        ;;
    *)
        return 1
        ;;
    esac
}

# Search for PHP packages in repositories
# Usage: pkg_search_php <version>
# Returns: 0 if found, 1 if not found, 2 if some PHP packages exist but not requested version
pkg_search_php() {
    local version="$1"
    local package_name
    local mm

    package_name=$(get_php_package_name "$version") || return 1

    case "$PKG_MANAGER" in
    brew)
        # Use brew info for reliable formula existence check (more stable than search)
        brew info "$package_name" > /dev/null 2>&1
        ;;
    apt)
        # Use apt-cache policy for exact package check
        # Explicitly fail if candidate is "(none)" to avoid false positives
        local policy_output
        policy_output=$(apt-cache policy "$package_name" 2> /dev/null)
        if echo "$policy_output" | command grep -Fq "Candidate:"; then
            # Check that candidate is not "(none)"
            ! echo "$policy_output" | command grep -Eq "Candidate:.*\(none\)"
        else
            return 1
        fi
        ;;
    dnf)
        # Check for module stream availability (preferred for versioned PHP)
        if dnf module list php 2> /dev/null | command grep -Eq "php[[:space:]]+${version}[[:space:]]|${version}[[:space:]]+\["; then
            return 0
        fi
        # If any php module exists, signal "some versions exist"
        if dnf module list php 2> /dev/null | command grep -q "^php"; then
            return 2
        fi
        # Fallback: check generic package
        if dnf info "$package_name" > /dev/null 2>&1; then
            return 0
        fi
        return 1
        ;;
    yum)
        # If Remi enabled, check for remi-style packages (e.g., php82-php-cli for 8.2)
        if check_remi_repository; then
            mm="${version/./}" # 8.2 -> 82
            if yum info "php${mm}-php-cli" > /dev/null 2>&1; then
                return 0
            fi
        fi
        # Check if any php packages exist
        if yum search php 2> /dev/null | command grep -q "php"; then
            return 2
        fi
        return 1
        ;;
    pacman)
        pacman -Si "$package_name" > /dev/null 2>&1
        ;;
    *)
        return 1
        ;;
    esac
}

# ============================================================================
# END PACKAGE MANAGER ABSTRACTION LAYER
# ============================================================================

# Validate PHP version format
validate_php_version() {
    local version="$1"

    # Allow 'system' as a special case
    [ "$version" = "system" ] && return "$PHPVM_EXIT_SUCCESS"

    # First sanitize the input
    if ! sanitize_input "$version" 10 > /dev/null 2>&1; then
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    # Check for basic PHP version format (X.Y or X.Y.Z)
    if is_valid_version_format "$version"; then
        return "$PHPVM_EXIT_SUCCESS"
    fi

    return "$PHPVM_EXIT_INVALID_ARG"
}

# Resolve version alias to actual version number
# Returns the resolved version or the input if no alias is found
phpvm_resolve_version() {
    local input="$1"
    local resolved=""

    # Return early for empty input
    if [ -z "$input" ]; then
        return 1
    fi

    # Resolve special keywords
    if [ "$input" = "latest" ] || [ "$input" = "stable" ]; then
        if resolved=$(phpvm_get_latest_installed_version); then
            echo "$resolved"
            return 0
        else
            # No installed versions found - provide clear guidance
            phpvm_err "No installed PHP versions found."
            phpvm_warn "Install a version first: phpvm install 8.2"
            return "$PHPVM_EXIT_NOT_INSTALLED"
        fi
    fi

    # SECURITY: Only check alias file if input passes alias name validation
    # This prevents path traversal attacks like "../../../etc/passwd"
    if phpvm_validate_alias_name "$input" && [ -f "$PHPVM_DIR/alias/$input" ]; then
        resolved=$(command cat "$PHPVM_DIR/alias/$input" 2> /dev/null | command tr -d '[:space:]')
        if [ -n "$resolved" ]; then
            phpvm_debug "Resolved alias '$input' to version '$resolved'"
            echo "$resolved"
            return 0
        fi
    fi

    # No alias found, return input as-is
    echo "$input"
    return 0
}

# Get latest installed PHP version (best-effort)
phpvm_get_latest_installed_version() {
    local versions=()
    local version
    local latest

    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        # Test mode: use test prefix paths
        for path in "${TEST_PREFIX:-/tmp}/opt/homebrew/Cellar/php"*; do
            if [ -d "$path" ]; then
                version=$(basename "$path")
                version=${version#php@}
                [ "$version" = "php" ] && continue
                versions+=("$version")
            fi
        done
    else
        case "$PKG_MANAGER" in
        brew)
            if [ -d "$HOMEBREW_PREFIX/Cellar" ]; then
                for path in "$HOMEBREW_PREFIX/Cellar/php"*; do
                    if [ -d "$path" ]; then
                        version=$(basename "$path")
                        if [ "$version" = "php" ]; then
                            version=$(get_installed_php_version)
                        else
                            version=${version#php@}
                        fi
                        [ -n "$version" ] && versions+=("$version")
                    fi
                done
            fi
            ;;
        apt)
            while read -r version; do
                versions+=("$version")
            done < <(dpkg-query -W -f='${Package}\n' 2> /dev/null | grep -E '^php[0-9]+\.[0-9]+' | sed -E 's/^php([0-9]+\.[0-9]+).*/\1/' | sort -u)
            ;;
        dnf | yum | pacman)
            # Use binary-based detection for more reliable version detection
            while read -r version; do
                versions+=("$version")
            done < <(phpvm_linux_installed_versions)
            ;;
        esac
    fi

    if [ ${#versions[@]} -eq 0 ]; then
        return 1
    fi

    latest=$(printf '%s\n' "${versions[@]}" | phpvm_latest_from_list)
    if [ -n "$latest" ]; then
        echo "$latest"
        return 0
    fi

    return 1
}

# Check if Remi repository is available/enabled for RHEL/Fedora systems
check_remi_repository() {
    # Check if Remi repository is installed
    if command_exists dnf; then
        dnf repolist enabled 2> /dev/null | grep -q remi
    elif command_exists yum; then
        yum repolist enabled 2> /dev/null | grep -q remi
    else
        return 1
    fi
}

# Detect if PHP packages are available in current repositories
detect_php_availability() {
    local version="$1"

    # Use the unified package search abstraction
    pkg_search_php "$version"
    return $?
}

# Provide repository setup suggestions for RHEL/Fedora systems
suggest_repository_setup() {
    local version="$1"
    local major_minor
    local major_version

    if [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        if [ "$PHPVM_LINUX_DISTRO" = "fedora" ]; then
            phpvm_echo ""
            phpvm_echo "PHP packages not found in default Fedora repositories."
            phpvm_echo "To install PHP $version, you need to enable Remi's repository:"
            phpvm_echo ""
            phpvm_echo "  # Install Remi's repository"
            if [ -n "$PHPVM_LINUX_VERSION" ]; then
                phpvm_echo "  sudo dnf install https://rpms.remirepo.net/fedora/remi-release-$PHPVM_LINUX_VERSION.rpm"
            else
                phpvm_echo "  sudo dnf install https://rpms.remirepo.net/fedora/remi-release-42.rpm"
            fi
            phpvm_echo ""
            phpvm_echo "  # Enable the repository"
            phpvm_echo "  sudo dnf config-manager --set-enabled remi"
            phpvm_echo ""
            phpvm_echo "  # Enable specific PHP version repository"
            major_minor=$(echo "$version" | cut -d. -f1,2 | tr -d '.')
            phpvm_echo "  sudo dnf config-manager --set-enabled remi-php$major_minor"
            phpvm_echo ""
            phpvm_echo "After setting up the repositories, try: phpvm install $version"

        elif [ "$PHPVM_LINUX_DISTRO" = "rhel" ] || [ "$PHPVM_LINUX_DISTRO" = "rocky" ] || [ "$PHPVM_LINUX_DISTRO" = "almalinux" ] || [ "$PHPVM_LINUX_DISTRO" = "centos" ]; then
            phpvm_echo ""
            phpvm_echo "PHP packages not found in default RHEL/CentOS repositories."
            phpvm_echo "To install PHP $version, you need to enable EPEL and Remi repositories:"
            phpvm_echo ""
            phpvm_echo "  # Install EPEL repository"
            phpvm_echo "  sudo dnf install epel-release"
            phpvm_echo ""
            phpvm_echo "  # Install Remi's repository"
            if [ -n "$PHPVM_LINUX_VERSION" ]; then
                major_version=$(echo "$PHPVM_LINUX_VERSION" | cut -d. -f1)
                phpvm_echo "  sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-$major_version.rpm"
            else
                phpvm_echo "  sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-9.rpm"
            fi
            phpvm_echo ""
            phpvm_echo "  # Enable the repositories"
            phpvm_echo "  sudo dnf config-manager --set-enabled remi"
            major_minor=$(echo "$version" | cut -d. -f1,2 | tr -d '.')
            phpvm_echo "  sudo dnf config-manager --set-enabled remi-php$major_minor"
            phpvm_echo ""
            phpvm_echo "After setting up the repositories, try: phpvm install $version"
        fi
    fi
}

# Brew helpers
# Get major.minor version of unversioned "php" formula from its opt binary
# Never uses PATH-based php to avoid conflicts with system PHP
brew_php_major_minor() {
    local bin="${HOMEBREW_PREFIX}/opt/php/bin/php"
    [ -x "$bin" ] || return 1
    "$bin" -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;' 2> /dev/null
}

# Resolve which brew formula provides a given PHP version
# This MUST be called before any unlinking operations to ensure accurate detection
# Returns "php@X.Y" if versioned formula exists, "php" if unversioned matches, or fails
brew_resolve_formula_for_version() {
    local version="$1" # X.Y format
    local current_version

    # Prefer versioned formula if it exists
    if brew list --versions "php@${version}" > /dev/null 2>&1; then
        echo "php@${version}"
        return 0
    fi

    # Check if unversioned "php" formula is installed and matches the version
    # Use brew metadata, NOT PATH-based php which may be system PHP
    if brew list --versions php > /dev/null 2>&1; then
        # Extract version from formula's opt binary
        current_version=$(brew_php_major_minor 2> /dev/null || true)
        if [ "$current_version" = "$version" ]; then
            echo "php"
            return 0
        fi
    fi

    return 1
}

brew_unlink_all_php() {
    local formula_list
    local php_formula

    brew unlink php > /dev/null 2>&1 || true

    if formula_list=$(brew list --formula 2> /dev/null); then
        printf '%s\n' "$formula_list" | command grep -E '^php@[0-9]+\.[0-9]+$' | while IFS= read -r php_formula; do
            phpvm_debug "Unlinking $php_formula..."
            brew unlink "$php_formula" > /dev/null 2>&1 || true
        done
    fi
}

brew_link_php() {
    local version="$1"
    local link_output
    local link_status

    phpvm_debug "Linking PHP $version..."
    link_output=$(brew link php@"$version" --force --overwrite 2>&1)
    link_status=$?
    if [ "$link_status" -ne 0 ]; then
        phpvm_err "Failed to link PHP $version:"
        printf "%s\n" "$link_output" >&2
        return "$PHPVM_EXIT_ERROR"
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

# Link unversioned PHP formula (DRY for repeated 'brew link php --force --overwrite' calls)
# Usage: brew_link_php_unversioned
# Returns: 0 on success, 1 on failure
brew_link_php_unversioned() {
    local link_output
    local link_status

    phpvm_debug "Linking unversioned PHP formula..."
    link_output=$(brew link php --force --overwrite 2>&1)
    link_status=$?
    if [ "$link_status" -ne 0 ]; then
        phpvm_err "Failed to link unversioned PHP formula:"
        printf "%s\n" "$link_output" >&2
        return "$PHPVM_EXIT_ERROR"
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

# Linux helpers
linux_find_php_binary() {
    local version="$1"
    local normalized_version
    local php_binary

    normalized_version=$(phpvm_normalize_version "$version") || return 1
    php_binary="/usr/bin/php$normalized_version"

    if [ ! -f "$php_binary" ]; then
        if [ -f "/usr/bin/php-$normalized_version" ]; then
            php_binary="/usr/bin/php-$normalized_version"
        elif [ -f "/usr/bin/php${normalized_version/./}" ]; then
            php_binary="/usr/bin/php${normalized_version/./}"
        fi
    fi

    if [ -f "$php_binary" ]; then
        echo "$php_binary"
        return 0
    fi

    return 1
}

# Get installed PHP versions on Linux by checking actual binaries
# Returns list of major.minor versions (e.g., "8.1", "8.2")
phpvm_linux_installed_versions() {
    local bin version basename_bin

    for bin in /usr/bin/php /usr/bin/php[0-9]* /usr/bin/php-[0-9]*; do
        [ -x "$bin" ] || continue

        # Skip helper binaries - use broader patterns to catch versioned variants
        # like php8.2-fpm, php8.2-cgi, php8.2dbg, phpize8.2, php-config8.2
        basename_bin=$(basename "$bin")
        case "$basename_bin" in
        # Exact matches
        phpize | php-config | phpdbg | php-cgi | php-fpm) continue ;;
        # Pattern matches for versioned helpers
        *fpm* | *cgi* | *dbg* | *ize* | *config*) continue ;;
        esac

        # Extract major.minor version from binary
        version=$("$bin" -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;' 2> /dev/null || true)
        [ -n "$version" ] && printf '%s\n' "$version"
    done | sort -u
}

linux_set_php_alternative() {
    local php_binary="$1"
    local version="$2"
    local alternatives_cmd=""
    local priority=10

    # Derive priority from version if provided (e.g., 8.2 => 802)
    if [ -n "$version" ]; then
        local major minor
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)
        if [ -n "$major" ] && [ -n "$minor" ]; then
            priority=$((major * 100 + minor))
        fi
    fi

    # Detect which alternatives command is available
    if command_exists update-alternatives; then
        alternatives_cmd="update-alternatives"
    elif command_exists alternatives; then
        alternatives_cmd="alternatives"
    else
        phpvm_err "Neither update-alternatives nor alternatives command found."
        return "$PHPVM_EXIT_ERROR"
    fi

    if ! "$alternatives_cmd" --list php 2> /dev/null | grep -q "$php_binary"; then
        phpvm_debug "Installing alternative for PHP $php_binary with priority $priority using $alternatives_cmd"
        run_with_sudo "$alternatives_cmd" --install /usr/bin/php php "$php_binary" "$priority" || {
            phpvm_warn "Failed to install alternative, trying direct switch..."
        }
    fi

    run_with_sudo "$alternatives_cmd" --set php "$php_binary" || {
        phpvm_err "Failed to switch to PHP $php_binary using $alternatives_cmd."
        return "$PHPVM_EXIT_ERROR"
    }

    return "$PHPVM_EXIT_SUCCESS"
}

# Install PHP using the detected package manager
install_php() {
    local version="$1"
    local normalized_version

    [ -z "$version" ] && {
        phpvm_err "No PHP version specified for installation."
        return "$PHPVM_EXIT_INVALID_ARG"
    }

    # Resolve aliases to actual versions - propagate failure
    if ! version=$(phpvm_resolve_version "$version"); then
        return $?
    fi

    # Validate version format
    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format: $version. Expected format: X.Y or X.Y.Z"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    if [ "$version" = "system" ]; then
        phpvm_err "Cannot install the 'system' PHP."
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    normalized_version=$(phpvm_normalize_version "$version") || {
        phpvm_err "Invalid PHP version format: $version. Expected format: X.Y or X.Y.Z"
        return "$PHPVM_EXIT_INVALID_ARG"
    }
    phpvm_warn_patch_version_once "$version" "$normalized_version"

    phpvm_echo "Installing PHP $normalized_version..."

    # If in test mode, just create a mock directory
    if phpvm_is_test_mode; then
        phpvm_test_install_php "$normalized_version"
        phpvm_echo "PHP $normalized_version installed."
        return "$PHPVM_EXIT_SUCCESS"
    fi

    case "$PKG_MANAGER" in
    brew)
        install_php_brew "$normalized_version" || return $?
        ;;
    apt)
        install_php_apt "$normalized_version" || return $?
        ;;
    dnf)
        install_php_dnf "$normalized_version" || return $?
        ;;
    yum)
        install_php_yum "$normalized_version" || return $?
        ;;
    pacman)
        local package_name
        package_name=$(get_php_package_name "$normalized_version") || return "$PHPVM_EXIT_ERROR"
        install_php_pacman "$normalized_version" "$package_name" || return $?
        ;;
    *)
        phpvm_err "Unsupported package manager."
        return "$PHPVM_EXIT_ERROR"
        ;;
    esac

    phpvm_echo "PHP $normalized_version installed."
    return "$PHPVM_EXIT_SUCCESS"
}

install_php_brew() {
    local version="$1"
    if ! pkg_search_php "$version"; then
        phpvm_err "php@$version is not available in Homebrew."
        phpvm_warn ""
        phpvm_warn "To see available versions, run:"
        phpvm_warn "  brew search php"
        phpvm_warn ""
        phpvm_warn "To install the latest version explicitly, use:"
        phpvm_warn "  brew install php"
        phpvm_warn "  phpvm use system"
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    if ! pkg_install_php "$version"; then
        phpvm_err "Failed to install PHP $version."
        return "$PHPVM_EXIT_ERROR"
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

install_php_apt() {
    local version="$1"
    local normalized_version

    normalized_version=$(phpvm_normalize_version "$version") || return "$PHPVM_EXIT_INVALID_ARG"

    run_with_sudo apt-get update || {
        phpvm_warn "Failed to update package list, continuing anyway..."
    }

    # Ubuntu/Debian with ondrej/sury PPA is the standard approach
    # Install both CLI and common extensions
    phpvm_echo "Installing PHP ${normalized_version} (cli + common extensions)..."
    if ! run_with_sudo apt-get install -y \
        "php${normalized_version}-cli" \
        "php${normalized_version}-common" \
        "php${normalized_version}-fpm" 2> /dev/null; then

        phpvm_err "Failed to install PHP ${normalized_version}."
        phpvm_warn ""
        phpvm_warn "You likely need to add the ondrej/php PPA:"
        phpvm_warn "  sudo add-apt-repository ppa:ondrej/php"
        phpvm_warn "  sudo apt-get update"
        phpvm_warn "  phpvm install ${normalized_version}"
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

install_php_dnf() {
    local version="$1"
    local normalized_version
    local availability_status

    normalized_version=$(phpvm_normalize_version "$version") || return "$PHPVM_EXIT_INVALID_ARG"

    detect_php_availability "$version"
    availability_status=$?

    if [ $availability_status -eq 1 ]; then
        phpvm_err "PHP packages not found in current repositories."
        suggest_repository_setup "$version"
        return "$PHPVM_EXIT_NOT_FOUND"
    elif [ $availability_status -eq 2 ]; then
        phpvm_warn "PHP $version not found, but other PHP versions are available."
        phpvm_echo "Available PHP packages:"
        dnf search php 2> /dev/null | grep "^php[0-9]" | head -5
        phpvm_echo ""
        if ! check_remi_repository; then
            phpvm_echo "For more PHP versions, consider enabling Remi's repository:"
            suggest_repository_setup "$version"
        fi
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    # Fedora/RHEL use module streams for version management
    phpvm_echo "Installing PHP ${normalized_version} via dnf module..."
    phpvm_warn "Note: Fedora/RHEL manage PHP versions via module streams."

    # Try to enable the module stream first
    if command_exists dnf && dnf module list php > /dev/null 2>&1; then
        phpvm_echo "Enabling PHP:${normalized_version} module stream..."
        if ! run_with_sudo dnf module reset php -y 2> /dev/null; then
            phpvm_warn "Failed to reset PHP module"
        fi
        if ! run_with_sudo dnf module enable php:"${normalized_version}" -y; then
            phpvm_warn "Failed to enable PHP:${normalized_version} module stream"
            phpvm_warn "You may need Remi repository for this PHP version"
            suggest_repository_setup "$version"
            return "$PHPVM_EXIT_ERROR"
        fi
    fi

    # Install the base PHP package
    if ! run_with_sudo dnf install -y php-cli php-common; then
        phpvm_err "Failed to install PHP ${normalized_version}."
        if ! check_remi_repository; then
            phpvm_echo ""
            phpvm_echo "You may need to enable Remi's repository:"
            suggest_repository_setup "$version"
        fi
        return "$PHPVM_EXIT_ERROR"
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

install_php_yum() {
    local version="$1"
    local normalized_version
    local availability_status

    normalized_version=$(phpvm_normalize_version "$version") || {
        phpvm_err "Invalid PHP version format: $version"
        return "$PHPVM_EXIT_INVALID_ARG"
    }

    phpvm_warn_patch_version_once "$version" "$normalized_version"

    if [ "$PHPVM_LINUX_DISTRO" = "rhel" ] || [ "$PHPVM_LINUX_DISTRO" = "centos" ]; then
        if [ -n "$PHPVM_LINUX_VERSION" ] && [ "$PHPVM_LINUX_VERSION" -lt 8 ]; then
            phpvm_warn "Installing PHP $normalized_version on RHEL/CentOS $PHPVM_LINUX_VERSION"
            phpvm_warn "You may need EPEL and Remi repositories for modern PHP versions"
        fi
    fi

    detect_php_availability "$normalized_version"
    availability_status=$?

    if [ $availability_status -eq 1 ]; then
        phpvm_err "PHP packages not found in current repositories."
        suggest_repository_setup "$version"
        return "$PHPVM_EXIT_NOT_FOUND"
    elif [ $availability_status -eq 2 ]; then
        phpvm_warn "PHP $normalized_version not found, but other PHP versions are available."
        if ! check_remi_repository; then
            phpvm_echo "For more PHP versions, consider enabling Remi's repository:"
            suggest_repository_setup "$version"
        fi
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    # YUM doesn't have module streams like DNF - recommend Remi for versioned PHP
    phpvm_echo "Installing PHP ${normalized_version}..."
    phpvm_warn "Note: yum doesn't support module streams. This may install via Remi naming (php${normalized_version/./}-*)"

    if check_remi_repository; then
        # Remi uses naming like php82-php-cli, php81-php-cli, etc.
        local remi_base="php${normalized_version/./}" # Convert 8.2 to php82
        phpvm_echo "Detected Remi repository, using ${remi_base} package naming..."
        if ! run_with_sudo yum install -y "${remi_base}-php-cli" "${remi_base}-php-common"; then
            phpvm_err "Failed to install PHP ${normalized_version} via Remi naming."
            return "$PHPVM_EXIT_ERROR"
        fi
    else
        # Try generic php-cli install (older RHEL/CentOS may have basic php package)
        phpvm_warn "Remi repository not detected. Attempting generic php-cli install..."
        if ! run_with_sudo yum install -y php-cli php-common; then
            phpvm_err "Failed to install PHP $version."
            phpvm_echo ""
            phpvm_echo "You may need to enable Remi repository for versioned PHP:"
            suggest_repository_setup "$version"
            return "$PHPVM_EXIT_ERROR"
        fi
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

install_php_pacman() {
    local version="$1"
    local package_name="$2"
    local arch_php_version

    run_with_sudo pacman -Sy || {
        phpvm_warn "Failed to sync package databases, continuing anyway..."
    }

    if [ "$PHPVM_LINUX_DISTRO" = "arch" ] || [ "$PHPVM_LINUX_DISTRO" = "manjaro" ]; then
        arch_php_version=$(pacman -Si php 2> /dev/null | command grep -E '^Version' | command awk '{print $3}' | command cut -d. -f1,2)

        if [ "$version" = "$arch_php_version" ]; then
            if ! run_with_sudo pacman -S --noconfirm php; then
                phpvm_err "Failed to install PHP. Check available versions with: pacman -Ss php"
                return "$PHPVM_EXIT_ERROR"
            fi
        else
            phpvm_warn "PHP $version may not be available in Arch repos (current repo version: ${arch_php_version:-unknown})"
            phpvm_warn "Trying to install php$version from AUR or alternative sources..."
            if ! run_with_sudo pacman -S --noconfirm php"$version" 2> /dev/null; then
                phpvm_err "Failed to install PHP $version."
                phpvm_echo "Options:"
                phpvm_echo "  1. Install current version ($arch_php_version): phpvm install $arch_php_version"
                phpvm_echo "  2. Use AUR helper (yay/paru) for older versions"
                phpvm_echo "  3. Build from source"
                return "$PHPVM_EXIT_NOT_FOUND"
            fi
        fi
    else
        if ! pkg_install_php "$version"; then
            phpvm_err "Failed to install PHP $version. Package $package_name may not exist."
            return "$PHPVM_EXIT_NOT_FOUND"
        fi
    fi
    return "$PHPVM_EXIT_SUCCESS"
}

# Helper function to get the installed PHP version
get_installed_php_version() {
    phpvm_debug "Getting installed PHP version..."

    # If in test mode, return a mock version
    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        echo "8.0.0"
        return 0
    fi

    local version_output

    # Use cached command availability or check and cache
    if [ -z "$PHPVM_CACHE_PHP_CONFIG" ]; then
        if command_exists php-config; then
            PHPVM_CACHE_PHP_CONFIG="available"
        else
            PHPVM_CACHE_PHP_CONFIG="unavailable"
        fi
    fi

    if [ "$PHPVM_CACHE_PHP_CONFIG" = "available" ]; then
        if version_output=$(php-config --version 2> /dev/null); then
            echo "$version_output"
            return 0
        fi
    fi

    # Use cached command availability or check and cache
    if [ -z "$PHPVM_CACHE_PHP" ]; then
        if command_exists php; then
            PHPVM_CACHE_PHP="available"
        else
            PHPVM_CACHE_PHP="unavailable"
        fi
    fi

    if [ "$PHPVM_CACHE_PHP" = "available" ]; then
        if version_output=$(php -v 2> /dev/null); then
            echo "$version_output" | command awk '/^PHP/ {print $2}' | command head -n1
            return 0
        fi
    fi

    echo "N/A"
    return 1
}

# Switch to a specific PHP version
use_php_version() {
    local version="$1"
    local normalized_version

    [ -z "$version" ] && {
        phpvm_err "No PHP version specified to switch."
        return "$PHPVM_EXIT_INVALID_ARG"
    }

    # Resolve aliases to actual versions - propagate failure
    if ! version=$(phpvm_resolve_version "$version"); then
        return $?
    fi

    # Validate version format
    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format: $version. Expected format: X.Y, X.Y.Z, or 'system'"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    if [ "$version" != "system" ]; then
        normalized_version=$(phpvm_normalize_version "$version") || {
            phpvm_err "Invalid PHP version format: $version. Expected format: X.Y or X.Y.Z"
            return "$PHPVM_EXIT_INVALID_ARG"
        }
        phpvm_warn_patch_version_once "$version" "$normalized_version"
    fi

    # Store original PATH on first activation (enables deactivate)
    phpvm_store_original_path

    if [ "$version" = "system" ]; then
        phpvm_echo "Switching to PHP system..."
    else
        phpvm_echo "Switching to PHP $normalized_version..."
    fi

    # Handle test mode specifically
    if phpvm_is_test_mode; then
        if [ "$version" = "system" ]; then
            set_active_version "system" || return "$PHPVM_EXIT_FILE_ERROR"
            phpvm_echo "Switched to system PHP."
            return "$PHPVM_EXIT_SUCCESS"
        fi

        if phpvm_test_php_installed "$normalized_version"; then
            set_active_version "$normalized_version" || return "$PHPVM_EXIT_FILE_ERROR"
            phpvm_echo "Switched to PHP $normalized_version."
            return "$PHPVM_EXIT_SUCCESS"
        fi

        phpvm_err "PHP version $version is not installed."
        return "$PHPVM_EXIT_NOT_INSTALLED"
    fi

    if [ "$version" = "system" ]; then
        switch_to_system_php
        return $?
    fi

    switch_to_version_php "$normalized_version"
    return $?
}

switch_to_system_php() {
    case "$PKG_MANAGER" in
    brew)
        # Apple removed PHP from macOS starting with macOS Monterey 12.0
        if [ -n "$PHPVM_MACOS_MAJOR" ] && [ "$PHPVM_MACOS_MAJOR" -ge 12 ]; then
            if [ -d "$HOMEBREW_PREFIX/Cellar/php" ]; then
                phpvm_debug "Linking Homebrew php formula as system default (macOS $PHPVM_MACOS_VERSION)..."
                brew_link_php_unversioned || {
                    phpvm_err "Failed to link Homebrew php formula."
                    return "$PHPVM_EXIT_ERROR"
                }
                # Only set state AFTER successful switch
                set_active_version "system" || return "$PHPVM_EXIT_FILE_ERROR"
                update_current_symlink || true
                phpvm_echo "Switched to system PHP (Homebrew default)."
                return "$PHPVM_EXIT_SUCCESS"
            fi

            phpvm_warn "No system PHP available on macOS $PHPVM_MACOS_VERSION. Installing Homebrew PHP..."
            if brew install php > /dev/null 2>&1; then
                set_active_version "system" || return "$PHPVM_EXIT_FILE_ERROR"
                update_current_symlink || true
                phpvm_echo "Installed and switched to system PHP (Homebrew)."
                return "$PHPVM_EXIT_SUCCESS"
            fi
            phpvm_err "Failed to install system PHP via Homebrew."
            return "$PHPVM_EXIT_ERROR"
        fi

        if [ -x "/usr/bin/php" ]; then
            set_active_version "system" || return "$PHPVM_EXIT_FILE_ERROR"
            update_current_symlink || true
            phpvm_echo "Switched to system PHP (built-in macOS PHP)."
            return "$PHPVM_EXIT_SUCCESS"
        elif [ -d "$HOMEBREW_PREFIX/Cellar/php" ]; then
            phpvm_debug "Linking Homebrew php formula as system default..."
            brew_link_php_unversioned || {
                phpvm_err "Failed to link Homebrew php formula."
                return "$PHPVM_EXIT_ERROR"
            }
            set_active_version "system" || return "$PHPVM_EXIT_FILE_ERROR"
            update_current_symlink || true
            phpvm_echo "Switched to system PHP (Homebrew default)."
            return "$PHPVM_EXIT_SUCCESS"
        elif command_exists php; then
            set_active_version "system" || return "$PHPVM_EXIT_FILE_ERROR"
            update_current_symlink || true
            phpvm_echo "Switched to system PHP."
            return "$PHPVM_EXIT_SUCCESS"
        fi

        # No system PHP found - still set state but warn user
        set_active_version "system" || return "$PHPVM_EXIT_FILE_ERROR"
        update_current_symlink || true
        phpvm_echo "Switched to system PHP."
        phpvm_warn "No system PHP found. You may need to install PHP with 'brew install php' or switch to a specific version."
        return "$PHPVM_EXIT_SUCCESS"
        ;;
    apt | dnf | yum | pacman)
        if command_exists update-alternatives; then
            run_with_sudo update-alternatives --auto php || {
                phpvm_err "Failed to switch to system PHP version."
                return "$PHPVM_EXIT_ERROR"
            }
        elif command_exists alternatives; then
            run_with_sudo alternatives --auto php || {
                phpvm_err "Failed to switch to system PHP version."
                return "$PHPVM_EXIT_ERROR"
            }
        elif [ "$PHPVM_LINUX_DISTRO" = "arch" ] || [ "$PHPVM_LINUX_DISTRO" = "manjaro" ]; then
            if [ -x "/usr/bin/php" ]; then
                phpvm_debug "Using system PHP on Arch Linux"
            else
                phpvm_warn "No system PHP found. Install with: sudo pacman -S php"
            fi
        fi
        set_active_version "system" || return "$PHPVM_EXIT_FILE_ERROR"
        update_current_symlink || true
        phpvm_echo "Switched to system PHP."
        return "$PHPVM_EXIT_SUCCESS"
        ;;
    esac

    return "$PHPVM_EXIT_ERROR"
}

switch_to_version_php() {
    local version="$1"
    local normalized_version
    local installed_version
    local php_binary
    local target_formula

    normalized_version=$(phpvm_normalize_version "$version") || return "$PHPVM_EXIT_INVALID_ARG"

    case "$PKG_MANAGER" in
    brew)
        # CRITICAL: Resolve target formula BEFORE unlinking anything
        # This ensures we check the actual installed formula, not system PHP
        if ! target_formula=$(brew_resolve_formula_for_version "$normalized_version"); then
            phpvm_err "PHP version $normalized_version is not installed."
            phpvm_warn "Install with: phpvm install $normalized_version"
            return "$PHPVM_EXIT_NOT_INSTALLED"
        fi

        phpvm_debug "Resolved target formula: $target_formula"

        # Now safe to unlink all PHP versions
        brew_unlink_all_php

        # Link the resolved formula
        if [ "$target_formula" = "php" ]; then
            # Unversioned formula
            brew_link_php_unversioned || return "$PHPVM_EXIT_ERROR"
            phpvm_echo "Using PHP $normalized_version installed as 'php'."
        else
            # Versioned formula (php@X.Y)
            brew_link_php "$normalized_version" || return "$PHPVM_EXIT_ERROR"
        fi
        ;;
    apt | dnf | yum | pacman)
        # Preferred order: update-alternatives/alternatives → Arch special-case → dnf module → fail
        if command_exists update-alternatives || command_exists alternatives; then
            # update-alternatives or alternatives is available - use it
            if php_binary=$(linux_find_php_binary "$normalized_version"); then
                linux_set_php_alternative "$php_binary" "$normalized_version" || return "$PHPVM_EXIT_ERROR"
            else
                phpvm_err "PHP binary for version $normalized_version not found. Tried: /usr/bin/php$normalized_version"
                return "$PHPVM_EXIT_NOT_INSTALLED"
            fi
        elif [ "$PHPVM_LINUX_DISTRO" = "arch" ] || [ "$PHPVM_LINUX_DISTRO" = "manjaro" ]; then
            # Arch Linux typically has a single PHP version
            if [ -x "/usr/bin/php" ]; then
                installed_version=$(php -v 2> /dev/null | awk '/^PHP/ {print $2}' | cut -d. -f1,2)
                if [ "$installed_version" = "$normalized_version" ]; then
                    phpvm_debug "PHP $normalized_version already active on Arch Linux"
                else
                    phpvm_warn "PHP $normalized_version may not be the active version. Arch typically has one PHP version."
                    phpvm_warn "Current version: $installed_version, requested: $normalized_version"
                fi
            else
                phpvm_err "No PHP binary found. Install with: sudo pacman -S php"
                return "$PHPVM_EXIT_NOT_INSTALLED"
            fi
        elif [ "$PKG_MANAGER" = "dnf" ]; then
            # Try dnf module approach for RHEL/Fedora
            if command_exists dnf && dnf module list php > /dev/null 2>&1; then
                phpvm_debug "Attempting to enable PHP $normalized_version module"
                if ! run_with_sudo dnf module enable php:"$normalized_version" -y; then
                    phpvm_warn "Failed to enable PHP $normalized_version module."
                fi
            fi
            # After module enable, check if binary exists
            if php_binary=$(linux_find_php_binary "$normalized_version"); then
                if [ -x "$php_binary" ]; then
                    phpvm_debug "Using PHP binary: $php_binary"
                else
                    phpvm_err "PHP binary for version $normalized_version not found or not executable."
                    return "$PHPVM_EXIT_NOT_INSTALLED"
                fi
            else
                phpvm_err "PHP binary for version $normalized_version not found. Tried: /usr/bin/php$normalized_version"
                return "$PHPVM_EXIT_NOT_INSTALLED"
            fi
        else
            phpvm_err "Cannot switch PHP versions on this system. No supported method found."
            phpvm_warn "System: $PHPVM_LINUX_DISTRO $PHPVM_LINUX_VERSION, Package Manager: $PKG_MANAGER"
            phpvm_warn "Supported methods: update-alternatives, alternatives, dnf modules, Arch pacman"
            phpvm_warn "Please install one of: update-alternatives (Debian/Ubuntu), alternatives (RHEL/CentOS)"
            return "$PHPVM_EXIT_ERROR"
        fi
        ;;
    esac

    phpvm_debug "Updating symlink to PHP $normalized_version..."
    update_current_symlink || return "$PHPVM_EXIT_FILE_ERROR"

    set_active_version "$normalized_version" || return "$PHPVM_EXIT_FILE_ERROR"

    phpvm_echo "Switched to PHP $normalized_version."
    return "$PHPVM_EXIT_SUCCESS"
}

# Switch to the system PHP version
system_php_version() {
    phpvm_echo "Switching to system PHP version..."
    use_php_version "system"
    return $?
}

# Display the currently active PHP version
# Returns: version string, "system", or "none"
phpvm_current() {
    local active_version=""
    local php_version=""

    # First, check the active version file
    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
        active_version=$(command cat "$PHPVM_ACTIVE_VERSION_FILE" 2> /dev/null | command tr -d '[:space:]')
    fi

    # If we have an active version from the file, use it
    if [ -n "$active_version" ]; then
        echo "$active_version"
        return "$PHPVM_EXIT_SUCCESS"
    fi

    # Fallback: Try to get version from php -v
    if command -v php > /dev/null 2>&1; then
        php_version=$(php -v 2> /dev/null | command head -1 | command grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | command head -1)
        if [ -n "$php_version" ]; then
            # Check if this looks like a system PHP (not managed by phpvm or Homebrew)
            local php_path
            php_path=$(command -v php 2> /dev/null)
            if [ -n "$php_path" ]; then
                # Treat anything under PHPVM_DIR or HOMEBREW_PREFIX as managed
                case "$php_path" in
                "$PHPVM_DIR"/* | "$HOMEBREW_PREFIX"/*)
                    echo "$php_version"
                    ;;
                *)
                    echo "system"
                    ;;
                esac
                return "$PHPVM_EXIT_SUCCESS"
            fi
        fi
    fi

    # No PHP found
    echo "none"
    return "$PHPVM_EXIT_NOT_INSTALLED"
}

# Display the path to the PHP binary for a given version
# Usage: phpvm_which [version]
# If no version specified, shows path to current PHP
phpvm_which() {
    local version="$1"
    local php_path=""
    local normalized_version

    # If no version specified, use current (propagate failure if it fails)
    if [ -z "$version" ]; then
        version=$(phpvm_current) || return $?
    fi

    # Resolve aliases to actual versions
    version=$(phpvm_resolve_version "$version")

    # Handle special cases
    case "$version" in
    none)
        phpvm_err "No PHP version is currently active."
        return "$PHPVM_EXIT_NOT_INSTALLED"
        ;;
    system)
        php_path=$(command -v php 2> /dev/null || true)
        if [ -z "$php_path" ]; then
            phpvm_err "System PHP not found."
            return "$PHPVM_EXIT_NOT_FOUND"
        fi
        echo "$php_path"
        return "$PHPVM_EXIT_SUCCESS"
        ;;
    esac

    normalized_version=$(phpvm_normalize_version "$version") || {
        phpvm_err "Invalid PHP version format: $version. Expected format: X.Y or X.Y.Z"
        return "$PHPVM_EXIT_INVALID_ARG"
    }
    phpvm_warn_patch_version_once "$version" "$normalized_version"
    version="$normalized_version"

    # Handle test mode
    if phpvm_is_test_mode; then
        local mock_path
        mock_path=$(phpvm_test_php_path "$version")
        # Check if the mock PHP binary actually exists and is executable
        if [ -f "$mock_path" ] && [ -x "$mock_path" ]; then
            echo "$mock_path"
            return "$PHPVM_EXIT_SUCCESS"
        else
            phpvm_err "PHP $version not found in test environment."
            return "$PHPVM_EXIT_NOT_INSTALLED"
        fi
    fi

    # Find PHP binary for specific version
    php_path=$(get_php_binary_path "$version")

    # Verify binary exists
    if [ -z "$php_path" ]; then
        phpvm_err "PHP $version not found."
        return "$PHPVM_EXIT_NOT_INSTALLED"
    fi

    # Check if path exists but is not executable
    if [ -e "$php_path" ] && [ ! -x "$php_path" ]; then
        phpvm_err "PHP binary at $php_path is not executable."
        return "$PHPVM_EXIT_FILE_ERROR"
    fi

    # Check if path doesn't exist at all
    if [ ! -e "$php_path" ]; then
        phpvm_err "PHP binary for version $version not found at $php_path."
        return "$PHPVM_EXIT_NOT_INSTALLED"
    fi

    # Verify binary is executable
    if [ -x "$php_path" ]; then
        # For versioned packages, verify the version matches
        if [ "$PKG_MANAGER" != "brew" ]; then
            local installed_version
            installed_version=$("$php_path" -v 2> /dev/null | command head -1 | command grep -oE '[0-9]+\.[0-9]+' | command head -1)
            if [ -n "$installed_version" ] && [ "$installed_version" = "$version" ]; then
                echo "$php_path"
                return "$PHPVM_EXIT_SUCCESS"
            elif [ -z "$installed_version" ]; then
                phpvm_err "Cannot determine version of PHP at $php_path."
                return "$PHPVM_EXIT_ERROR"
            else
                phpvm_err "PHP version mismatch: expected $version, found $installed_version at $php_path."
                return "$PHPVM_EXIT_NOT_INSTALLED"
            fi
        else
            # For brew, path already indicates correct version
            echo "$php_path"
            return "$PHPVM_EXIT_SUCCESS"
        fi
    fi

    # Fallback error
    phpvm_err "PHP $version not found or not accessible."
    return "$PHPVM_EXIT_NOT_INSTALLED"
}

# Check if the script is being sourced (not executed directly)
# Returns 0 if sourced, 1 if executed
# NOTE: This script requires bash. The zsh check is kept for informational purposes only.
phpvm_is_sourced() {
    # Bash-specific check using BASH_SOURCE
    if [ -n "${BASH_SOURCE:-}" ]; then
        [ "${BASH_SOURCE[0]}" != "${0}" ]
    else
        # For other shells, assume sourced if $0 looks like a shell (e.g., -bash, bash, sh)
        case "$0" in
        -* | *sh) return 0 ;;
        *) return 1 ;;
        esac
    fi
}

# Store original PATH before phpvm modifications
# This is called on first activation to enable deactivate functionality
phpvm_store_original_path() {
    # Only store PATH if script is sourced (not executed directly)
    if ! phpvm_is_sourced; then
        phpvm_debug "Script not sourced, skipping PATH storage"
        return 0
    fi

    # Only store if not already stored
    if [ -z "${PHPVM_ORIGINAL_PATH:-}" ]; then
        export PHPVM_ORIGINAL_PATH="$PATH"
        phpvm_debug "Stored original PATH"
    fi
}

# Deactivate phpvm - temporarily disable PHP version management
# Restores the original PATH and clears phpvm state
phpvm_deactivate() {
    local silent="${1:-false}"

    # Check if phpvm is active
    if [ -z "${PHPVM_ORIGINAL_PATH:-}" ] && [ ! -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
        if [ "$silent" != "true" ]; then
            phpvm_warn "phpvm is not currently active."
        fi
        return "$PHPVM_EXIT_SUCCESS"
    fi

    # Restore original PATH only if phpvm stored it
    if [ -n "${PHPVM_ORIGINAL_PATH:-}" ]; then
        export PATH="$PHPVM_ORIGINAL_PATH"
        unset PHPVM_ORIGINAL_PATH
        phpvm_debug "Restored original PATH"
    fi

    # Clear active version file
    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
        rm -f "$PHPVM_ACTIVE_VERSION_FILE"
        phpvm_debug "Removed active version file"
    fi

    # Remove current symlink
    if [ -L "$PHPVM_CURRENT_SYMLINK" ] || [ -e "$PHPVM_CURRENT_SYMLINK" ]; then
        rm -f "$PHPVM_CURRENT_SYMLINK"
        phpvm_debug "Removed current symlink"
    fi

    # Clear phpvm state variables
    unset PHPVM_ACTIVE_VERSION

    if [ "$silent" != "true" ]; then
        phpvm_echo "phpvm deactivated. Run 'phpvm use <version>' to reactivate."
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

# Find .phpvmrc file in current or parent directories
find_phpvmrc() {
    local current_dir="$PWD"
    local depth=0
    local max_depth="${PHPVM_PHPVMRC_MAX_DEPTH:-25}"

    while [ "$current_dir" != "/" ] && [ "$depth" -lt "$max_depth" ]; do
        if [ -f "$current_dir/.phpvmrc" ]; then
            echo "$current_dir/.phpvmrc"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
        depth=$((depth + 1))
    done
    return 1
}

# Read and resolve PHP version from .phpvmrc in current or parent directories
# Usage: phpvm_read_phpvmrc_version
# Returns: resolved version on stdout, 1 if no .phpvmrc found or unreadable
phpvm_read_phpvmrc_version() {
    local phpvmrc_file
    local version

    if ! phpvmrc_file=$(find_phpvmrc); then
        return 1
    fi

    if [ ! -r "$phpvmrc_file" ]; then
        phpvm_debug "Cannot read $phpvmrc_file"
        return 1
    fi

    if ! version=$(command tr -d '[:space:]' < "$phpvmrc_file" 2> /dev/null); then
        phpvm_debug "Failed to read $phpvmrc_file"
        return 1
    fi

    # Resolve aliases before validation
    version=$(phpvm_resolve_version "$version")

    if [ -z "$version" ]; then
        phpvm_debug "No valid PHP version found in $phpvmrc_file"
        return 1
    fi

    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format in $phpvmrc_file: $version"
        return 1
    fi

    printf '%s\n' "$version"
    return 0
}

# Auto-switch PHP version based on .phpvmrc file
auto_switch_php_version() {
    local phpvmrc_file
    local version
    local normalized_version

    if ! phpvmrc_file=$(find_phpvmrc); then
        phpvm_warn "No .phpvmrc file found in the current or parent directories."
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    # Validate .phpvmrc file exists and is readable
    if [ ! -r "$phpvmrc_file" ]; then
        phpvm_err "Cannot read $phpvmrc_file"
        return "$PHPVM_EXIT_FILE_ERROR"
    fi

    # Read and validate version from .phpvmrc
    if ! version=$(tr -d '[:space:]' < "$phpvmrc_file" 2> /dev/null); then
        phpvm_err "Failed to read $phpvmrc_file"
        return "$PHPVM_EXIT_FILE_ERROR"
    fi

    # Resolve aliases before validation
    version=$(phpvm_resolve_version "$version")

    # Validate version is not empty and contains only valid characters
    if [ -z "$version" ]; then
        phpvm_warn "No valid PHP version found in $phpvmrc_file."
        return "$PHPVM_EXIT_ERROR"
    fi

    # Validate version format (X.Y, X.Y.Z, or system)
    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format in $phpvmrc_file: $version"
        return "$PHPVM_EXIT_ERROR"
    fi

    phpvm_echo "Auto-switching to PHP $version (from $phpvmrc_file)"
    if ! use_php_version "$version"; then
        phpvm_err "Failed to switch to PHP $version from $phpvmrc_file"
        return "$PHPVM_EXIT_ERROR"
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

# cd hook for automatic version switching on directory change
# Compares .phpvmrc version with active version, switches only if different
# Silent when no .phpvmrc is found in the directory tree
phpvm_cd_hook() {
    local version
    local current

    if ! version=$(phpvm_read_phpvmrc_version); then
        return 0
    fi

    current=$(phpvm_current 2> /dev/null | command tr -d '[:space:]')

    if [ "$version" = "$current" ]; then
        return 0
    fi

    phpvm_echo "Auto-switching to PHP $version (from .phpvmrc)"
    use_php_version "$version" || true
}

# List configured aliases
# Usage: phpvm_list_aliases [pattern]
phpvm_list_aliases() {
    local pattern="${1:-}"
    local alias_file
    local alias_name
    local alias_target
    local matched=false

    if [ ! -d "$PHPVM_DIR/alias" ]; then
        return 1
    fi

    for alias_file in "$PHPVM_DIR/alias"/*; do
        if [ -f "$alias_file" ]; then
            alias_name=$(basename "$alias_file")
            alias_target=$(command cat "$alias_file" 2> /dev/null | command tr -d '[:space:]')
            if [ -n "$pattern" ]; then
                # Use fixed-string literal match to avoid regex interpretation
                if echo "$alias_name" | command grep -Fqi "$pattern"; then
                    echo "  $alias_name -> $alias_target"
                    matched=true
                fi
            else
                echo "  $alias_name -> $alias_target"
                matched=true
            fi
        fi
    done

    if [ "$matched" = "true" ]; then
        return 0
    fi

    return 1
}

# List installed PHP versions
list_installed_versions() {
    local dir
    local base_name
    local version
    local active_version

    phpvm_echo "Installed PHP versions:"

    # Handle test mode specifically
    if phpvm_is_test_mode; then
        for dir in "$(phpvm_test_cellar_root)"/php*; do
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
        echo "  system (Homebrew default PHP)"
        echo ""
        if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
            active_version=$(command cat "$PHPVM_ACTIVE_VERSION_FILE")
            phpvm_echo "Active version: $active_version"
        else
            phpvm_warn "No active PHP version set."
        fi
        return "$PHPVM_EXIT_SUCCESS"
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
        echo "  system (Homebrew default PHP)"
        ;;
    apt | dnf | yum | pacman)
        # Use phpvm_linux_installed_versions for accurate binary detection
        # This scans actual /usr/bin/php* binaries and extracts versions
        phpvm_linux_installed_versions | while IFS= read -r ver; do
            echo "  $ver"
        done
        echo "  system (default system PHP)"
        ;;
    esac

    echo ""
    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
        active_version=$(command cat "$PHPVM_ACTIVE_VERSION_FILE")
        phpvm_echo "Active version: $active_version"
    else
        phpvm_warn "No active PHP version set."
    fi

    if phpvm_list_aliases > /dev/null 2>&1; then
        echo ""
        phpvm_echo "Aliases:"
        phpvm_list_aliases || true
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

# Print help message
print_help() {
    cat << EOF
phpvm - PHP Version Manager

Usage:
  phpvm install <version>   Install specified PHP version
  phpvm use <version>       Switch to specified PHP version
  phpvm uninstall <version> Remove specified PHP version
  phpvm current             Show currently active PHP version
  phpvm which [version]     Show path to PHP binary
  phpvm deactivate          Temporarily disable phpvm management
  phpvm system              Switch to system PHP version
  phpvm auto                Auto-switch based on .phpvmrc file
  phpvm list                List installed PHP versions
  phpvm alias [name] [ver]  Create, update, or list version aliases
  phpvm unalias <name>      Remove version alias
  phpvm help                Show this help message
  phpvm info                Show system information for debugging
  phpvm version             Show version information

Version Arguments:
  X.Y or X.Y.Z              Specific PHP version (e.g., 8.1 or 8.1.15)
  latest                    Latest installed version (not latest available)
  stable                    Alias for 'latest' (latest installed)
  system                    System default PHP
  <alias-name>              Any user-defined alias (e.g., 'default', 'prod')

Examples:
  phpvm install 8.1         Install PHP 8.1
  phpvm use 7.4             Switch to PHP 7.4
  phpvm use latest          Switch to latest installed version
  phpvm alias default 8.2   Create 'default' alias for PHP 8.2
  phpvm use default         Switch using alias
  phpvm current             Show current PHP version
  phpvm which               Show path to current PHP binary
  phpvm which 8.2           Show path to PHP 8.2 binary
  phpvm deactivate          Disable phpvm, restore original PATH
  phpvm system              Switch to system PHP version
  phpvm auto                Auto-switch based on current directory

Planned Features (Coming Soon):
  phpvm exec <ver> <cmd>    Execute command with specific PHP version (Phase 1)
  phpvm run <ver> [script]  Run PHP script with specific version (Phase 1)
  phpvm ls-remote [pattern] List available remote PHP versions (Phase 2)
  phpvm cache <dir|clear>   Manage cache directory (Phase 1)

Exit Codes:
  0   Success
  1   General error
  2   Invalid argument or usage error
  3   Version not found (not available)
  4   Version not installed locally
  5   File or permission error
  127 Unknown command
EOF
}

# Print version information
print_version() {
    cat << EOF
phpvm version $PHPVM_VERSION

PHP Version Manager for macOS and Linux
Author: Jerome Thayananthajothy <tjthavarshan@gmail.com>
Repository: https://github.com/Thavarshan/phpvm

Usage: phpvm help
EOF
}

# Print system information for debugging
print_system_info() {
    phpvm_echo "System Information:"
    echo ""

    # Get OS information
    get_os_info

    # Basic system info
    echo "OS Type: $PHPVM_OS_TYPE"
    echo "Architecture: $PHPVM_OS_ARCH"

    if [ "$PHPVM_OS_TYPE" = "Darwin" ]; then
        echo "macOS Version: ${PHPVM_MACOS_VERSION:-Unknown}"
        echo "macOS Major: ${PHPVM_MACOS_MAJOR:-Unknown}"
        echo "macOS Minor: ${PHPVM_MACOS_MINOR:-Unknown}"

        if command -v brew > /dev/null 2>&1; then
            echo "Homebrew: Installed"
            echo "Homebrew Prefix: ${HOMEBREW_PREFIX:-Unknown}"
            echo "Homebrew Version: $(brew --version 2> /dev/null | head -1 || echo 'Unknown')"
        else
            echo "Homebrew: Not installed"
        fi
    elif [ "$PHPVM_OS_TYPE" = "Linux" ]; then
        echo "Linux Distribution: ${PHPVM_LINUX_DISTRO:-Unknown}"
        echo "Linux Version: ${PHPVM_LINUX_VERSION:-Unknown}"
        echo "WSL: ${PHPVM_IS_WSL:-false}"
        if [ "$PHPVM_IS_WSL" = "true" ]; then
            echo "WSL Version: ${PHPVM_WSL_VERSION:-Unknown}"
        fi

        echo ""
        echo "Available Package Managers:"
        command -v apt-get > /dev/null 2>&1 && echo "  - apt-get: Available"
        command -v dnf > /dev/null 2>&1 && echo "  - dnf: Available"
        command -v yum > /dev/null 2>&1 && echo "  - yum: Available"
        command -v pacman > /dev/null 2>&1 && echo "  - pacman: Available"
        command -v brew > /dev/null 2>&1 && echo "  - brew (Linuxbrew): Available"

        if command -v update-alternatives > /dev/null 2>&1; then
            echo "  - update-alternatives: Available"
        fi
    fi

    echo ""
    echo "PHP Information:"
    if command -v php > /dev/null 2>&1; then
        echo "Current PHP: $(php -v 2> /dev/null | head -1 || echo 'Error getting version')"
        echo "PHP Binary: $(command -v php)"
    else
        echo "Current PHP: Not installed or not in PATH"
    fi

    if command -v php-config > /dev/null 2>&1; then
        echo "PHP Config: Available"
    else
        echo "PHP Config: Not available"
    fi

    echo ""
    echo "phpvm Configuration:"
    echo "phpvm Directory: $PHPVM_DIR"
    echo "PHP Binary Path: ${PHP_BIN_PATH:-Not set}"
    echo "Package Manager: ${PKG_MANAGER:-Not detected}"

    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
        echo "Active Version: $(command cat "$PHPVM_ACTIVE_VERSION_FILE")"
    else
        echo "Active Version: None set"
    fi

    echo ""
    echo "Environment Variables:"
    echo "DEBUG: ${DEBUG:-false}"
    echo "PHPVM_TEST_MODE: ${PHPVM_TEST_MODE:-false}"
    echo "PHPVM_AUTO_USE: ${PHPVM_AUTO_USE:-true}"
}

# Uninstall a specific PHP version
uninstall_php() {
    local version="$1"
    local mock_dir
    local test_prefix
    local normalized_version

    [ -z "$version" ] && {
        phpvm_err "No PHP version specified for uninstallation."
        return "$PHPVM_EXIT_INVALID_ARG"
    }

    # Resolve aliases to actual versions - propagate failure
    if ! version=$(phpvm_resolve_version "$version"); then
        return $?
    fi

    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format: $version"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi
    if [ "$version" = "system" ]; then
        phpvm_err "Cannot uninstall the 'system' PHP."
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    normalized_version=$(phpvm_normalize_version "$version") || {
        phpvm_err "Invalid PHP version format: $version"
        return "$PHPVM_EXIT_INVALID_ARG"
    }
    phpvm_warn_patch_version_once "$version" "$normalized_version"

    phpvm_echo "Uninstalling PHP $normalized_version..."

    # If in test mode, just remove the mock directory
    if phpvm_is_test_mode; then
        test_prefix=$(phpvm_test_prefix)
        case "$PKG_MANAGER" in
        brew)
            mock_dir="$(phpvm_test_php_cellar_dir "$normalized_version")"
            ;;
        apt)
            mock_dir="$test_prefix/var/lib/dpkg/info/php$normalized_version"
            ;;
        dnf | yum)
            mock_dir="$test_prefix/var/lib/rpm/php$normalized_version"
            ;;
        pacman)
            mock_dir="$test_prefix/var/lib/pacman/local/php$normalized_version"
            ;;
        *)
            phpvm_err "Test mode not supported for this package manager."
            return "$PHPVM_EXIT_ERROR"
            ;;
        esac
        # Safely remove mock directory only if it's in our test prefix
        if [ -n "$mock_dir" ] && [ "$mock_dir" != "/" ] && echo "$mock_dir" | grep -q "^$test_prefix"; then
            rm -rf "$mock_dir"
        fi
        phpvm_echo "PHP $normalized_version uninstalled."
        return "$PHPVM_EXIT_SUCCESS"
    fi

    # Check if package is installed using abstraction layer
    if ! is_php_package_installed "$normalized_version"; then
        phpvm_warn "PHP $version is not installed via $PKG_MANAGER."
        return "$PHPVM_EXIT_NOT_INSTALLED"
    fi

    # Uninstall using abstraction layer
    if ! pkg_uninstall_php "$normalized_version"; then
        phpvm_err "Failed to uninstall PHP $version with $PKG_MANAGER."
        return "$PHPVM_EXIT_ERROR"
    fi

    phpvm_echo "PHP $normalized_version uninstalled."

    # Clean up symlink and active version if this was the active version
    local was_active=false
    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ] && [ "$(command cat "$PHPVM_ACTIVE_VERSION_FILE")" = "$normalized_version" ]; then
        was_active=true
        rm -f "$PHPVM_CURRENT_SYMLINK"
        rm -f "$PHPVM_ACTIVE_VERSION_FILE"
    fi

    # If we removed the active version, restore a sane default
    if [ "$was_active" = "true" ]; then
        phpvm_warn "Active PHP version was uninstalled."

        case "$PKG_MANAGER" in
        brew)
            # Try to switch to system (unversioned PHP)
            phpvm_echo "Attempting to restore system PHP..."
            if switch_to_system_php; then
                phpvm_echo "Switched to system PHP."
            else
                phpvm_warn "Could not restore system PHP. Run 'phpvm use <version>' to select another."
            fi
            ;;
        apt | dnf | yum | pacman)
            # On Linux, try to use update-alternatives --auto
            phpvm_echo "Attempting to restore system PHP via update-alternatives..."
            if run_with_sudo update-alternatives --auto php > /dev/null 2>&1; then
                phpvm_echo "System PHP restored via update-alternatives."
            else
                phpvm_warn "Could not auto-restore system PHP. Run 'phpvm use <version>' to select another."
            fi
            ;;
        *)
            phpvm_warn "Please run 'phpvm use <version>' to select another PHP version."
            ;;
        esac
    fi

    return "$PHPVM_EXIT_SUCCESS"
}

# ============================================================================
# FEATURE PLACEHOLDERS - To be implemented in future versions
# These functions are stubs for planned features from the NVM feature gap analysis
# See NVM_FEATURE_GAPS.md for detailed implementation guidance
# ============================================================================

# Placeholder: Execute command with specific PHP version (HIGH PRIORITY - Phase 1)
# Usage: phpvm_exec <version> <command> [args...]
# Example: phpvm exec 8.2 composer install
phpvm_exec() {
    phpvm_err "The 'exec' command is not yet implemented."
    phpvm_warn "This feature is planned for Phase 1 of the NVM parity roadmap."
    phpvm_warn "Usage: phpvm exec <version> <command> [args...]"
    return $PHPVM_EXIT_ERROR
}

# Placeholder: Run PHP script with specific version (HIGH PRIORITY - Phase 1)
# Usage: phpvm_run <version> [script] [args...]
# Example: phpvm run 8.1 script.php arg1 arg2
phpvm_run() {
    phpvm_err "The 'run' command is not yet implemented."
    phpvm_warn "This feature is planned for Phase 1 of the NVM parity roadmap."
    phpvm_warn "Usage: phpvm run <version> [script] [args...]"
    return $PHPVM_EXIT_ERROR
}

# Placeholder: List available remote PHP versions (HIGH PRIORITY - Phase 2)
# Usage: phpvm_ls_remote [pattern]
# Example: phpvm ls-remote 8.2
phpvm_ls_remote() {
    phpvm_err "The 'ls-remote' command is not yet implemented."
    phpvm_warn "This feature is planned for Phase 2 of the NVM parity roadmap."
    phpvm_warn "Usage: phpvm ls-remote [pattern]"
    return $PHPVM_EXIT_ERROR
}

# Validate alias name format
phpvm_validate_alias_name() {
    local name="$1"
    # Use printf to avoid echo interpretation of strings like -n, -e
    printf '%s\n' "$name" | command grep -Eq '^[a-zA-Z0-9_-]+$'
}

# Placeholder: Manage version aliases (HIGH PRIORITY - Phase 1)
# Usage: phpvm_alias [name] [version]
# Example: phpvm alias default 8.2
phpvm_alias() {
    local name="$1"
    local version="$2"

    # List aliases (optionally filtered by pattern)
    if [ -z "$name" ]; then
        phpvm_echo "Version aliases:"
        if phpvm_list_aliases; then
            return 0
        fi
        echo "  (no aliases defined)"
        return 0
    fi

    # SECURITY: Validate alias name FIRST before any file path operations
    # This prevents path traversal attacks like "../../../etc/passwd"
    if ! phpvm_validate_alias_name "$name"; then
        phpvm_err "Invalid alias name: $name (use only letters, numbers, hyphens, and underscores)"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    # Pattern filter listing (phpvm alias <pattern>)
    if [ -z "$version" ] && [ ! -f "$PHPVM_DIR/alias/$name" ]; then
        phpvm_echo "Version aliases matching '$name':"
        if phpvm_list_aliases "$name"; then
            return 0
        fi
        echo "  (no aliases matched)"
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    # Show single alias
    if [ -z "$version" ]; then
        if [ -f "$PHPVM_DIR/alias/$name" ]; then
            local alias_target
            alias_target=$(command cat "$PHPVM_DIR/alias/$name" 2> /dev/null | command tr -d '[:space:]')
            echo "$name -> $alias_target"
            return 0
        fi
        phpvm_err "Alias '$name' not found."
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    # Prevent alias chains and circular references
    if [ "$name" = "$version" ]; then
        phpvm_err "Alias '$name' cannot refer to itself. Please specify a PHP version."
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    # Check if target is an alias BEFORE version validation
    # This gives a better error message for alias chains
    # Use phpvm_validate_alias_name first to ensure safe file access
    if phpvm_validate_alias_name "$version" 2> /dev/null && [ -f "$PHPVM_DIR/alias/$version" ]; then
        phpvm_err "Alias target '$version' is itself an alias. Please point aliases directly to a PHP version."
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    # Validate version format (security: prevents path traversal attacks)
    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format: $version"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    # Resolve version (already validated above)
    version=$(phpvm_resolve_version "$version")

    if phpvm_atomic_write "$PHPVM_DIR/alias/$name" "$version"; then
        phpvm_echo "Alias '$name' set to PHP $version"
        return 0
    fi

    phpvm_err "Failed to create alias '$name'"
    return "$PHPVM_EXIT_FILE_ERROR"
}

# Placeholder: Remove version alias (HIGH PRIORITY - Phase 1)
# Usage: phpvm_unalias <name>
# Example: phpvm unalias default
phpvm_unalias() {
    local name="$1"
    local alias_file

    if [ -z "$name" ]; then
        phpvm_err "Missing alias name."
        phpvm_warn "Usage: phpvm unalias <name>"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    # Validate alias name to prevent path traversal
    if ! phpvm_validate_alias_name "$name"; then
        phpvm_err "Invalid alias name: $name"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    alias_file="$PHPVM_DIR/alias/$name"
    if [ ! -f "$alias_file" ]; then
        phpvm_err "Alias '$name' not found."
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    if rm -f "$alias_file" 2> /dev/null; then
        phpvm_echo "Alias '$name' removed."
        return 0
    fi

    phpvm_err "Failed to remove alias '$name'"
    return "$PHPVM_EXIT_FILE_ERROR"
}

# Placeholder: Cache management (HIGH PRIORITY - Phase 1)
# Usage: phpvm_cache <dir|clear>
# Example: phpvm cache clear
phpvm_cache() {
    local subcmd="${1:-}"
    case "$subcmd" in
    dir)
        echo "$PHPVM_DIR/cache"
        return 0
        ;;
    clear)
        phpvm_err "The 'cache clear' command is not yet implemented."
        phpvm_warn "This feature is planned for Phase 1 of the NVM parity roadmap."
        return $PHPVM_EXIT_ERROR
        ;;
    *)
        phpvm_err "Unknown cache subcommand: $subcmd"
        phpvm_warn "Usage: phpvm cache <dir|clear>"
        return $PHPVM_EXIT_INVALID_ARG
        ;;
    esac
}

# ============================================================================
# END FEATURE PLACEHOLDERS
# ============================================================================

# Main function to handle commands
main() {
    local command
    local status

    # Parse command first - help/version don't need system initialization
    if [ "$#" -eq 0 ]; then
        phpvm_err "No command provided."
        print_help
        exit "$PHPVM_EXIT_INVALID_ARG"
    fi

    command="$1"
    shift

    # Only initialize for commands that need package manager detection
    case "$command" in
    help | --help | -h)
        print_help
        exit "$PHPVM_EXIT_SUCCESS"
        ;;
    version | --version | -v)
        print_version
        exit "$PHPVM_EXIT_SUCCESS"
        ;;
    *)
        # All other commands need system detection and package manager
        phpvm_init_or_die
        ;;
    esac

    case "$command" in
    use)
        if [ "$#" -eq 0 ]; then
            local rc_version
            if rc_version=$(phpvm_read_phpvmrc_version); then
                phpvm_echo "Found '$rc_version' in .phpvmrc"
                phpvm_with_lock use_php_version "$rc_version"
                status=$?
            elif [ -f "$PHPVM_DIR/alias/default" ]; then
                phpvm_with_lock use_php_version "default"
                status=$?
            else
                phpvm_err "No .phpvmrc found and no default alias set."
                phpvm_warn "Create a .phpvmrc file or set a default: phpvm alias default <version>"
                status=$PHPVM_EXIT_INVALID_ARG
            fi
        else
            phpvm_with_lock use_php_version "$@"
            status=$?
        fi
        exit "$status"
        ;;
    install)
        if [ "$#" -eq 0 ]; then
            local rc_version
            if rc_version=$(phpvm_read_phpvmrc_version); then
                phpvm_echo "Found '$rc_version' in .phpvmrc"
                phpvm_with_lock install_php "$rc_version"
                exit $?
            fi
            phpvm_err "No .phpvmrc found. Specify a PHP version to install."
            exit "$PHPVM_EXIT_INVALID_ARG"
        fi
        phpvm_with_lock install_php "$@"
        exit "$?"
        ;;
    uninstall)
        if [ "$#" -eq 0 ]; then
            phpvm_err "Missing PHP version argument for 'uninstall' command."
            exit "$PHPVM_EXIT_INVALID_ARG"
        fi
        phpvm_with_lock uninstall_php "$@"
        exit "$?"
        ;;
    current)
        phpvm_current
        exit "$?"
        ;;
    which)
        phpvm_which "$@"
        exit "$?"
        ;;
    deactivate)
        phpvm_with_lock phpvm_deactivate false
        exit "$?"
        ;;
    system)
        phpvm_with_lock system_php_version
        exit "$?"
        ;;
    auto)
        phpvm_with_lock auto_switch_php_version
        exit "$?"
        ;;
    list | ls)
        list_installed_versions
        exit "$?"
        ;;
    version | --version | -v)
        print_version
        exit "$PHPVM_EXIT_SUCCESS"
        ;;
    info | sysinfo)
        print_system_info
        exit "$PHPVM_EXIT_SUCCESS"
        ;;
    exec)
        if [ "$#" -eq 0 ]; then
            local rc_version
            if rc_version=$(phpvm_read_phpvmrc_version); then
                phpvm_echo "Found '$rc_version' in .phpvmrc"
            fi
        fi
        phpvm_exec "$@"
        exit "$?"
        ;;
    run)
        if [ "$#" -eq 0 ]; then
            local rc_version
            if rc_version=$(phpvm_read_phpvmrc_version); then
                phpvm_echo "Found '$rc_version' in .phpvmrc"
            fi
        fi
        phpvm_run "$@"
        exit "$?"
        ;;
    ls-remote)
        phpvm_ls_remote "$@"
        exit "$?"
        ;;
    alias)
        phpvm_with_lock phpvm_alias "$@"
        exit "$?"
        ;;
    unalias)
        phpvm_with_lock phpvm_unalias "$@"
        exit "$?"
        ;;
    cache)
        phpvm_cache "$@"
        exit "$?"
        ;;
    *)
        phpvm_err "Unknown command: $command"
        print_help
        exit "$PHPVM_EXIT_UNKNOWN_CMD"
        ;;
    esac
}

phpvm_init_or_die() {
    if ! create_directories; then
        exit "$PHPVM_EXIT_FILE_ERROR"
    fi
    if ! detect_system; then
        exit "$PHPVM_EXIT_ERROR"
    fi
    PHPVM_INITIALIZED=true
    export PHPVM_INITIALIZED
}

phpvm_init_if_needed() {
    if [ "${PHPVM_INITIALIZED:-false}" = "true" ]; then
        return 0
    fi

    if ! create_directories; then
        return "$PHPVM_EXIT_FILE_ERROR"
    fi
    if ! detect_system; then
        return "$PHPVM_EXIT_ERROR"
    fi

    PHPVM_INITIALIZED=true
    export PHPVM_INITIALIZED
    return 0
}

# Safe main execution with error handling
# Check if script is being executed (not sourced)
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Script sourced for function loading
    # Set environment for shell integration
    PHPVM_FUNCTIONS_LOADED=true
    export PHPVM_FUNCTIONS_LOADED

    # Initialize environment when sourced (do not exit on failure)
    phpvm_init_if_needed || true

    # Auto-use .phpvmrc if enabled and present (skip in test mode and non-interactive shells)
    # Use find_phpvmrc to search parent directories
    # Skip auto-switch in non-interactive shells (CI, scripts) to avoid unexpected behavior
    case $- in
    *i*)
        # Interactive shell - safe to auto-switch
        if [ "${PHPVM_TEST_MODE}" != "true" ] && [ "${PHPVM_AUTO_USE:-true}" = "true" ]; then
            if command -v find_phpvmrc > /dev/null 2>&1 && find_phpvmrc > /dev/null 2>&1; then
                if command -v auto_switch_php_version > /dev/null 2>&1; then
                    auto_switch_php_version 2> /dev/null || true
                fi
            fi

            # Register cd hook for automatic version switching
            if [ -n "${BASH_VERSION:-}" ]; then
                # Bash: append to PROMPT_COMMAND
                if [[ ! "${PROMPT_COMMAND:-}" =~ phpvm_cd_hook ]]; then
                    PROMPT_COMMAND="phpvm_cd_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
                fi
            elif [ -n "${ZSH_VERSION:-}" ]; then
                # Zsh: add to chpwd_functions array
                if [[ ! " ${chpwd_functions[*]:-} " =~ " phpvm_cd_hook " ]]; then
                    # shellcheck disable=SC2206  # Intentional: chpwd_functions is a zsh array, word splitting is safe here
                    chpwd_functions=(phpvm_cd_hook "${chpwd_functions[@]:-}")
                fi
            fi
        fi
        ;;
    *)
        # Non-interactive shell - skip auto-switch
        ;;
    esac
else
    # Script executed - run main
    # Verify main function exists
    if command -v main > /dev/null 2>&1; then
        main "$@"
        exit "$?"
    else
        phpvm_err "main function not found - script may be corrupted"
        exit 1
    fi
fi
