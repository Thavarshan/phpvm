#!/bin/bash

# phpvm - A PHP Version Manager for macOS and Linux
# Author: Jerome Thayananthajothy (tjthavarshan@gmail.com)
# Version: 1.7.0

# shellcheck disable=SC2155  # Allow declare and assign on same line for better readability

PHPVM_VERSION="1.7.0"

# Test mode flag (set by run_tests function)
PHPVM_TEST_MODE="${PHPVM_TEST_MODE:-false}"

# Fix to prevent shell crash when sourced
if (return 0 2> /dev/null); then
    return 0
fi

PHPVM_DIR="${PHPVM_DIR:-$HOME/.phpvm}"
PHPVM_VERSIONS_DIR="$PHPVM_DIR/versions"
PHPVM_ACTIVE_VERSION_FILE="$PHPVM_DIR/active_version"
PHPVM_CURRENT_SYMLINK="$PHPVM_DIR/current"
DEBUG=false # Set to true to enable debug logs

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
PHPVM_CACHE_UPDATE_ALTERNATIVES=""

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
    if command -v tput > /dev/null 2>&1; then
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
phpvm_echo() { log_with_timestamp "INFO" "$*"; }
phpvm_err() { log_with_timestamp "ERROR" "$*" >&2; }
phpvm_warn() { log_with_timestamp "WARNING" "$*" >&2; }
phpvm_debug() { [ "$DEBUG" = "true" ] && log_with_timestamp "DEBUG" "$*"; }

# Atomic file write - writes to temp file then moves to target
# This prevents race conditions and partial writes
phpvm_atomic_write() {
    local target_file="$1"
    local content="$2"
    local temp_file
    local target_dir

    # Get directory of target file
    target_dir="$(dirname "$target_file")"

    # Create temp file in same directory (for atomic mv on same filesystem)
    temp_file="${target_dir}/.phpvm_tmp_$$_$(date +%s)"

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

# Create the required directory structure
create_directories() {
    mkdir -p "$PHPVM_VERSIONS_DIR" || {
        phpvm_err "Failed to create directory $PHPVM_VERSIONS_DIR"
        return 1
    }

    # Create alias directory for future alias support
    # This directory will store version aliases (e.g., default -> 8.2)
    mkdir -p "$PHPVM_DIR/alias" 2> /dev/null || true

    # Create cache directory for future caching support
    # This will store metadata and potentially downloaded packages
    mkdir -p "$PHPVM_DIR/cache" 2> /dev/null || true
}

# Get OS information
get_os_info() {
    OS_TYPE="$(command uname -s)"
    OS_ARCH="$(command uname -m)"

    # Detect macOS version
    if [ "$OS_TYPE" = "Darwin" ]; then
        if command -v sw_vers > /dev/null 2>&1; then
            MACOS_VERSION="$(sw_vers -productVersion)"
            MACOS_MAJOR="$(echo "$MACOS_VERSION" | command cut -d. -f1)"
            MACOS_MINOR="$(echo "$MACOS_VERSION" | command cut -d. -f2)"
        fi
    fi

    # Detect Linux distribution and WSL
    if [ "$OS_TYPE" = "Linux" ]; then
        # Check for WSL (Windows Subsystem for Linux)
        if [ -f "/proc/version" ] && command grep -qi "microsoft\|WSL" /proc/version 2> /dev/null; then
            IS_WSL=true
            if command grep -qi "wsl2" /proc/version 2> /dev/null; then
                WSL_VERSION="2"
            else
                WSL_VERSION="1"
            fi
            phpvm_debug "Detected WSL $WSL_VERSION environment"
        else
            IS_WSL=false
        fi

        # Try modern method first
        if [ -f "/etc/os-release" ]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            LINUX_DISTRO="$ID"
            LINUX_VERSION="$VERSION_ID"
        elif [ -f "/etc/lsb-release" ]; then
            # shellcheck disable=SC1091
            . /etc/lsb-release
            LINUX_DISTRO="$(echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]')"
            LINUX_VERSION="$DISTRIB_RELEASE"
        elif [ -f "/etc/redhat-release" ]; then
            LINUX_DISTRO="rhel"
            LINUX_VERSION="$(command grep -o '[0-9]' /etc/redhat-release | command head -1)"
        elif [ -f "/etc/debian_version" ]; then
            LINUX_DISTRO="debian"
            LINUX_VERSION="$(command cat /etc/debian_version)"
        fi

        # WSL-specific adjustments
        if [ "$IS_WSL" = "true" ]; then
            phpvm_debug "WSL detected - applying WSL-specific configurations"
            # WSL may have different PATH requirements
            if [ "$WSL_VERSION" = "1" ]; then
                phpvm_warn "WSL 1 detected. Some features may not work as expected."
            fi
        fi
    fi
}

# Detect the system's package manager and OS
detect_system() {
    # Get detailed OS information
    get_os_info

    if [ "$OS_TYPE" = "Darwin" ]; then
        PKG_MANAGER="brew"
        if ! command -v brew > /dev/null 2>&1; then
            phpvm_err "Homebrew is not installed. Please install Homebrew first."
            phpvm_warn "Visit https://brew.sh to install Homebrew."
            return 1
        fi

        # Handle different macOS versions and architectures
        if command -v brew > /dev/null 2>&1; then
            HOMEBREW_PREFIX=$(brew --config 2> /dev/null | command grep "HOMEBREW_PREFIX" | command cut -d: -f2 | command tr -d ' ' || brew --prefix)
        fi

        # Fallback for different macOS versions
        if [ -z "$HOMEBREW_PREFIX" ]; then
            if [ "$OS_ARCH" = "arm64" ] && [ -d "/opt/homebrew" ]; then
                HOMEBREW_PREFIX="/opt/homebrew"
            elif [ -d "/usr/local" ]; then
                HOMEBREW_PREFIX="/usr/local"
            fi
        fi

        PHP_BIN_PATH="$HOMEBREW_PREFIX/bin"
        phpvm_debug "Detected macOS $MACOS_VERSION on $OS_ARCH, Homebrew prefix: $HOMEBREW_PREFIX"
        return 0
    fi

    # Enhanced Linux package manager detection with distribution-specific logic
    if [ "$OS_TYPE" = "Linux" ]; then
        phpvm_debug "Detected Linux distribution: $LINUX_DISTRO $LINUX_VERSION"

        # Debian/Ubuntu family
        if command -v apt-get > /dev/null 2>&1; then
            PKG_MANAGER="apt"
            PHP_BIN_PATH="/usr/bin"

            # Check for specific Ubuntu/Debian PHP package patterns
            if [ "$LINUX_DISTRO" = "ubuntu" ] || [ "$LINUX_DISTRO" = "debian" ]; then
                # Modern Ubuntu/Debian uses php-fpm patterns
                if [ "$LINUX_DISTRO" = "ubuntu" ] && [ -n "$LINUX_VERSION" ]; then
                    # Ubuntu 20.04+ has different PHP packaging
                    case "$LINUX_VERSION" in
                    20.* | 22.* | 24.*)
                        PHP_PACKAGE_PATTERN="php"
                        ;;
                    *)
                        PHP_PACKAGE_PATTERN="php"
                        ;;
                    esac
                fi
            fi

        # RHEL/Fedora/CentOS family
        elif command -v dnf > /dev/null 2>&1; then
            PKG_MANAGER="dnf"
            PHP_BIN_PATH="/usr/bin"

            # Fedora-specific adjustments
            if [ "$LINUX_DISTRO" = "fedora" ]; then
                # Fedora uses different PHP version patterns
                PHP_PACKAGE_PATTERN="php"
            fi

        elif command -v yum > /dev/null 2>&1; then
            PKG_MANAGER="yum"
            PHP_BIN_PATH="/usr/bin"

            # RHEL/CentOS specific adjustments
            if [ "$LINUX_DISTRO" = "rhel" ] || [ "$LINUX_DISTRO" = "centos" ]; then
                # May need EPEL repository for modern PHP versions
                if [ -n "$LINUX_VERSION" ] && [ "$LINUX_VERSION" -lt 8 ]; then
                    phpvm_warn "RHEL/CentOS $LINUX_VERSION may require EPEL repository for modern PHP versions"
                fi
            fi

        # Arch Linux family
        elif command -v pacman > /dev/null 2>&1; then
            PKG_MANAGER="pacman"
            PHP_BIN_PATH="/usr/bin"

            # Arch Linux specific adjustments
            if [ "$LINUX_DISTRO" = "arch" ] || [ "$LINUX_DISTRO" = "manjaro" ]; then
                # Arch uses different versioning scheme
                PHP_PACKAGE_PATTERN="php"
            fi

        # Linuxbrew as fallback
        elif command -v brew > /dev/null 2>&1; then
            PKG_MANAGER="brew"

            # Enhanced Linuxbrew detection
            if [ -n "$HOMEBREW_PREFIX" ]; then
                # Use existing prefix
                :
            elif [ -d "/home/linuxbrew/.linuxbrew" ]; then
                HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
            elif [ -d "$HOME/.linuxbrew" ]; then
                HOMEBREW_PREFIX="$HOME/.linuxbrew"
            elif command -v brew > /dev/null 2>&1; then
                HOMEBREW_PREFIX=$(brew --prefix 2> /dev/null || echo "/usr/local")
            else
                HOMEBREW_PREFIX="/usr/local"
            fi

            PHP_BIN_PATH="$HOMEBREW_PREFIX/bin"
            phpvm_debug "Using Linuxbrew at $HOMEBREW_PREFIX"

        else
            phpvm_err "No supported package manager found (apt, dnf, yum, pacman, or brew)."
            phpvm_warn "Detected: $LINUX_DISTRO $LINUX_VERSION"
            phpvm_warn "Consider installing one of the supported package managers or Linuxbrew."
            return 1
        fi
    else
        phpvm_err "Unsupported operating system: $OS_TYPE"
        return 1
    fi
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

    # Check for dangerous characters that could enable command injection
    # Reject: backticks, $(), semicolons, pipes, redirects, newlines, etc.
    if echo "$input" | command grep -qE '[`$;|&<>(){}\\[:space:]]|[[:cntrl:]]'; then
        phpvm_err "Input contains invalid characters"
        return 1
    fi

    # Only allow alphanumeric, dots, and hyphens
    if ! echo "$input" | command grep -qE '^[a-zA-Z0-9.\-]+$'; then
        phpvm_err "Input contains invalid characters"
        return 1
    fi

    echo "$input"
    return 0
}

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
    if echo "$version" | command grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
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
        fi
    fi

    # Check alias file first
    if [ -f "$PHPVM_DIR/alias/$input" ]; then
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
            done < <(dpkg-query -W -f='${Package}\n' 2> /dev/null | grep -E '^php[0-9]+\.[0-9]+' | sed 's/^php//')
            ;;
        dnf | yum)
            while read -r version; do
                versions+=("$version")
            done < <($PKG_MANAGER list installed 2> /dev/null | grep -E 'php[0-9]+\.' | awk '{print $1}' | sed 's/^php//')
            ;;
        pacman)
            while read -r version; do
                versions+=("$version")
            done < <(pacman -Q 2> /dev/null | grep '^php' | awk '{print $1}' | sed 's/^php//')
            ;;
        esac
    fi

    if [ ${#versions[@]} -eq 0 ]; then
        return 1
    fi

    latest=$(printf '%s\n' "${versions[@]}" | sort -V | tail -1)
    if [ -n "$latest" ]; then
        echo "$latest"
        return 0
    fi

    return 1
}

# Check if Remi repository is available/enabled for RHEL/Fedora systems
check_remi_repository() {
    # Check if Remi repository is installed
    if command -v dnf > /dev/null 2>&1; then
        dnf repolist enabled 2> /dev/null | grep -q remi
    elif command -v yum > /dev/null 2>&1; then
        yum repolist enabled 2> /dev/null | grep -q remi
    else
        return 1
    fi
}

# Detect if PHP packages are available in current repositories
detect_php_availability() {
    local version="$1"

    case "$PKG_MANAGER" in
    dnf)
        if dnf search "php$version" 2> /dev/null | grep -q "php$version"; then
            return 0
        elif dnf search "php" 2> /dev/null | grep -q "php[0-9]"; then
            # Some PHP packages exist, but not the requested version
            return 2
        else
            # No PHP packages found at all
            return 1
        fi
        ;;
    yum)
        if yum search "php$version" 2> /dev/null | grep -q "php$version"; then
            return 0
        elif yum search "php" 2> /dev/null | grep -q "php[0-9]"; then
            return 2
        else
            return 1
        fi
        ;;
    apt)
        if apt-cache search "php$version" 2> /dev/null | grep -q "php$version"; then
            return 0
        else
            return 1
        fi
        ;;
    *)
        # For other package managers, assume available
        return 0
        ;;
    esac
}

# Provide repository setup suggestions for RHEL/Fedora systems
suggest_repository_setup() {
    local version="$1"
    local major_minor
    local major_version

    if [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        if [ "$LINUX_DISTRO" = "fedora" ]; then
            phpvm_echo ""
            phpvm_echo "PHP packages not found in default Fedora repositories."
            phpvm_echo "To install PHP $version, you need to enable Remi's repository:"
            phpvm_echo ""
            phpvm_echo "  # Install Remi's repository"
            if [ -n "$LINUX_VERSION" ]; then
                phpvm_echo "  sudo dnf install https://rpms.remirepo.net/fedora/remi-release-$LINUX_VERSION.rpm"
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
            phpvm_echo "After setting up the repository, try: phpvm install $version"

        elif [ "$LINUX_DISTRO" = "rhel" ] || [ "$LINUX_DISTRO" = "rocky" ] || [ "$LINUX_DISTRO" = "almalinux" ] || [ "$LINUX_DISTRO" = "centos" ]; then
            phpvm_echo ""
            phpvm_echo "PHP packages not found in default RHEL/CentOS repositories."
            phpvm_echo "To install PHP $version, you need to enable EPEL and Remi repositories:"
            phpvm_echo ""
            phpvm_echo "  # Install EPEL repository"
            phpvm_echo "  sudo dnf install epel-release"
            phpvm_echo ""
            phpvm_echo "  # Install Remi's repository"
            if [ -n "$LINUX_VERSION" ]; then
                major_version=$(echo "$LINUX_VERSION" | cut -d. -f1)
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

# Install PHP using the detected package manager
install_php() {
    local version="$1"
    local availability_status

    [ -z "$version" ] && {
        phpvm_err "No PHP version specified for installation."
        return 1
    }

    # Resolve aliases to actual versions
    version=$(phpvm_resolve_version "$version")

    # Validate version format
    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format: $version. Expected format: X.Y or X.Y.Z"
        return 1
    fi

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
        # Update package list
        run_with_sudo apt-get update || {
            phpvm_warn "Failed to update package list, continuing anyway..."
        }

        # Handle different Ubuntu/Debian PHP installation patterns
        if [ "$LINUX_DISTRO" = "ubuntu" ]; then
            case "$LINUX_VERSION" in
            20.* | 22.* | 24.*)
                # Modern Ubuntu: Try php-fpm and php-cli packages
                if ! run_with_sudo apt-get install -y php"$version"-fpm php"$version"-cli; then
                    # Fallback to basic php package
                    if ! run_with_sudo apt-get install -y php"$version"; then
                        phpvm_err "Failed to install PHP $version. You may need to add ondrej/php PPA:"
                        phpvm_err "sudo add-apt-repository ppa:ondrej/php && sudo apt-get update"
                        return 1
                    fi
                fi
                ;;
            18.* | 16.*)
                # Older Ubuntu versions
                if ! run_with_sudo apt-get install -y php"$version"; then
                    phpvm_err "Failed to install PHP $version. Package php$version may not exist."
                    phpvm_warn "Consider upgrading Ubuntu or adding ondrej/php PPA"
                    return 1
                fi
                ;;
            *)
                # Default fallback
                if ! run_with_sudo apt-get install -y php"$version"; then
                    phpvm_err "Failed to install PHP $version. Package php$version may not exist."
                    return 1
                fi
                ;;
            esac
        elif [ "$LINUX_DISTRO" = "debian" ]; then
            # Debian-specific installation
            if ! run_with_sudo apt-get install -y php"$version"-fpm php"$version"-cli; then
                if ! run_with_sudo apt-get install -y php"$version"; then
                    phpvm_err "Failed to install PHP $version. You may need to add sury.org repository:"
                    phpvm_err "curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x"
                    return 1
                fi
            fi
        else
            # Generic apt-based system
            if ! run_with_sudo apt-get install -y php"$version"; then
                phpvm_err "Failed to install PHP $version. Package php$version may not exist."
                return 1
            fi
        fi

        # Post-install check for binary
        if ! [ -x "/usr/bin/php$version" ]; then
            phpvm_warn "php$version installed, but /usr/bin/php$version not found. You may need to install php$version-cli or check your PATH."
        fi
        ;;
    dnf)
        # Fedora/RHEL 8+ with dnf
        # First, check if PHP packages are available
        detect_php_availability "$version"
        availability_status=$?

        if [ $availability_status -eq 1 ]; then
            # No PHP packages found - suggest repository setup
            phpvm_err "PHP packages not found in current repositories."
            suggest_repository_setup "$version"
            return 1
        elif [ $availability_status -eq 2 ]; then
            # Some PHP packages exist, but not the requested version
            phpvm_warn "PHP $version not found, but other PHP versions are available."
            phpvm_echo "Available PHP packages:"
            dnf search php 2> /dev/null | grep "^php[0-9]" | head -5
            phpvm_echo ""
            if ! check_remi_repository; then
                phpvm_echo "For more PHP versions, consider enabling Remi's repository:"
                suggest_repository_setup "$version"
            fi
            return 1
        fi

        # Packages are available, proceed with installation
        if [ "$LINUX_DISTRO" = "fedora" ]; then
            # Fedora uses different PHP packages
            if ! run_with_sudo dnf install -y php"$version" php"$version"-cli; then
                phpvm_err "Failed to install PHP $version."
                # Check if Remi repository might help
                if ! check_remi_repository; then
                    phpvm_echo ""
                    phpvm_echo "If the package wasn't found, you might need Remi's repository:"
                    suggest_repository_setup "$version"
                fi
                return 1
            fi
        else
            # RHEL/CentOS with dnf
            if ! run_with_sudo dnf install -y php"$version"; then
                phpvm_err "Failed to install PHP $version."
                # Check if repositories might help
                if ! check_remi_repository; then
                    phpvm_echo ""
                    phpvm_echo "You may need to enable additional repositories:"
                    suggest_repository_setup "$version"
                fi
                return 1
            fi
        fi
        ;;
    yum)
        # RHEL/CentOS 7 and older
        if [ "$LINUX_DISTRO" = "rhel" ] || [ "$LINUX_DISTRO" = "centos" ]; then
            if [ -n "$LINUX_VERSION" ] && [ "$LINUX_VERSION" -lt 8 ]; then
                phpvm_warn "Installing PHP $version on RHEL/CentOS $LINUX_VERSION"
                phpvm_warn "You may need EPEL and Remi repositories for modern PHP versions"
            fi
        fi

        # Check PHP availability first
        detect_php_availability "$version"
        availability_status=$?

        if [ $availability_status -eq 1 ]; then
            # No PHP packages found - suggest repository setup
            phpvm_err "PHP packages not found in current repositories."
            suggest_repository_setup "$version"
            return 1
        elif [ $availability_status -eq 2 ]; then
            # Some PHP packages exist, but not the requested version
            phpvm_warn "PHP $version not found, but other PHP versions are available."
            if ! check_remi_repository; then
                phpvm_echo "For more PHP versions, consider enabling Remi's repository:"
                suggest_repository_setup "$version"
            fi
            return 1
        fi

        if ! run_with_sudo yum install -y php"$version"; then
            phpvm_err "Failed to install PHP $version."
            if ! check_remi_repository; then
                phpvm_echo ""
                phpvm_echo "You may need to enable additional repositories:"
                suggest_repository_setup "$version"
            fi
            return 1
        fi
        ;;
    pacman)
        # Arch Linux
        run_with_sudo pacman -Sy || {
            phpvm_warn "Failed to sync package databases, continuing anyway..."
        }

        if [ "$LINUX_DISTRO" = "arch" ] || [ "$LINUX_DISTRO" = "manjaro" ]; then
            # Arch Linux typically has 'php' package for current version
            # Check if the requested version matches what's in the repos
            local arch_php_version
            arch_php_version=$(pacman -Si php 2> /dev/null | command grep -E '^Version' | command awk '{print $3}' | command cut -d. -f1,2)

            if [ "$version" = "$arch_php_version" ]; then
                # Requested version matches current Arch PHP version
                if ! run_with_sudo pacman -S --noconfirm php; then
                    phpvm_err "Failed to install PHP. Check available versions with: pacman -Ss php"
                    return 1
                fi
            else
                # Requested version differs from what's in repos
                phpvm_warn "PHP $version may not be available in Arch repos (current repo version: ${arch_php_version:-unknown})"
                phpvm_warn "Trying to install php$version from AUR or alternative sources..."
                if ! run_with_sudo pacman -S --noconfirm php"$version" 2> /dev/null; then
                    phpvm_err "Failed to install PHP $version."
                    phpvm_echo "Options:"
                    phpvm_echo "  1. Install current version ($arch_php_version): phpvm install $arch_php_version"
                    phpvm_echo "  2. Use AUR helper (yay/paru) for older versions"
                    phpvm_echo "  3. Build from source"
                    return 1
                fi
            fi
        else
            # Generic pacman system
            if ! run_with_sudo pacman -S --noconfirm php"$version"; then
                phpvm_err "Failed to install PHP $version. Package php$version may not exist."
                return 1
            fi
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

    local version_output

    # Use cached command availability or check and cache
    if [ -z "$PHPVM_CACHE_PHP_CONFIG" ]; then
        if command -v php-config > /dev/null 2>&1; then
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
        if command -v php > /dev/null 2>&1; then
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
    local link_output
    local installed_version
    local formula_list
    local php_formula
    local php_binary

    [ -z "$version" ] && {
        phpvm_err "No PHP version specified to switch."
        return "$PHPVM_EXIT_INVALID_ARG"
    }

    # Resolve aliases to actual versions
    version=$(phpvm_resolve_version "$version")

    # Validate version format
    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format: $version. Expected format: X.Y, X.Y.Z, or 'system'"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    # Store original PATH on first activation (enables deactivate)
    phpvm_store_original_path

    phpvm_echo "Switching to PHP $version..."

    # Handle test mode specifically
    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        if [ "$version" = "system" ]; then
            echo "system" > "$PHPVM_ACTIVE_VERSION_FILE"
            phpvm_echo "Switched to system PHP."
            return "$PHPVM_EXIT_SUCCESS"
        fi

        if [ -d "${TEST_PREFIX:-/tmp}/opt/homebrew/Cellar/php@$version" ]; then
            echo "$version" > "$PHPVM_ACTIVE_VERSION_FILE"
            phpvm_echo "Switched to PHP $version."
            return "$PHPVM_EXIT_SUCCESS"
        else
            phpvm_err "PHP version $version is not installed."
            return "$PHPVM_EXIT_NOT_INSTALLED"
        fi
    fi

    case "$PKG_MANAGER" in
    brew)
        phpvm_debug "Unlinking any existing PHP version..."
        brew unlink php > /dev/null 2>&1 || true
        # Unlink all versioned PHP installations
        # Use a safer approach to handle potential failures in command substitution
        if formula_list=$(brew list --formula 2> /dev/null); then
            # Process the list directly without subshell to ensure all unlinks happen
            for php_formula in $(echo "$formula_list" | command grep -E '^php@[0-9]+\.[0-9]+$'); do
                if [ -n "$php_formula" ]; then
                    phpvm_debug "Unlinking $php_formula..."
                    brew unlink "$php_formula" > /dev/null 2>&1 || true
                fi
            done
        fi

        if [ "$version" = "system" ]; then
            # Special case for switching to system PHP
            phpvm_atomic_write "$PHPVM_ACTIVE_VERSION_FILE" "system" || {
                phpvm_err "Failed to write active version file"
                return 1
            }
            # Remove the current symlink since we're using system PHP
            rm -f "$PHPVM_CURRENT_SYMLINK"

            # Handle different macOS versions
            # Apple removed PHP from macOS starting with macOS Monterey 12.0
            if [ -n "$MACOS_MAJOR" ] && [ "$MACOS_MAJOR" -ge 12 ]; then
                # macOS 12+ doesn't have built-in PHP, use Homebrew
                if [ -d "$HOMEBREW_PREFIX/Cellar/php" ]; then
                    phpvm_debug "Linking Homebrew php formula as system default (macOS $MACOS_VERSION)..."
                    brew link php --force --overwrite > /dev/null 2>&1 || {
                        phpvm_err "Failed to link Homebrew php formula."
                        return 1
                    }
                    phpvm_echo "Switched to system PHP (Homebrew default)."
                    return 0
                else
                    phpvm_warn "No system PHP available on macOS $MACOS_VERSION. Installing Homebrew PHP..."
                    if brew install php > /dev/null 2>&1; then
                        phpvm_echo "Installed and switched to system PHP (Homebrew)."
                        return 0
                    else
                        phpvm_err "Failed to install system PHP via Homebrew."
                        return 1
                    fi
                fi
            else
                # macOS 11 and earlier may have built-in PHP
                if [ -x "/usr/bin/php" ]; then
                    phpvm_echo "Switched to system PHP (built-in macOS PHP)."
                    return 0
                elif [ -d "$HOMEBREW_PREFIX/Cellar/php" ]; then
                    phpvm_debug "Linking Homebrew php formula as system default..."
                    brew link php --force --overwrite > /dev/null 2>&1 || {
                        phpvm_err "Failed to link Homebrew php formula."
                        return 1
                    }
                    phpvm_echo "Switched to system PHP (Homebrew default)."
                    return 0
                elif command -v php > /dev/null 2>&1; then
                    phpvm_echo "Switched to system PHP."
                    return 0
                else
                    phpvm_echo "Switched to system PHP."
                    phpvm_warn "No system PHP found. You may need to install PHP with 'brew install php' or switch to a specific version."
                    return 0
                fi
            fi
        fi

        if [ -d "$HOMEBREW_PREFIX/Cellar/php@$version" ]; then
            phpvm_debug "Linking PHP $version..."
            link_output=$(brew link php@"$version" --force --overwrite 2>&1)
            if echo "$link_output" | grep -iq "Already linked"; then
                phpvm_warn "Homebrew reports PHP $version is already linked. To relink, run: brew unlink php@${version} && brew link --force php@${version}"
                phpvm_warn "Switch NOT completed. Please relink manually."
                return 1
            elif echo "$link_output" | grep -q "Error"; then
                phpvm_err "Failed to link PHP $version: $link_output"
                return 1
            fi
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
        # Linux-specific PHP switching logic
        if [ "$version" = "system" ]; then
            # Handle system PHP differently per distribution
            if command -v update-alternatives > /dev/null 2>&1; then
                # Use update-alternatives if available
                run_with_sudo update-alternatives --auto php || {
                    phpvm_err "Failed to switch to system PHP version."
                    return 1
                }
            elif [ "$LINUX_DISTRO" = "arch" ] || [ "$LINUX_DISTRO" = "manjaro" ]; then
                # Arch Linux: system PHP is typically the main 'php' package
                if [ -x "/usr/bin/php" ]; then
                    phpvm_debug "Using system PHP on Arch Linux"
                else
                    phpvm_warn "No system PHP found. Install with: sudo pacman -S php"
                fi
            fi
            phpvm_atomic_write "$PHPVM_ACTIVE_VERSION_FILE" "system" || {
                phpvm_err "Failed to write active version file"
                return 1
            }
            phpvm_echo "Switched to system PHP."
            return 0
        fi

        # Version-specific switching
        if command -v update-alternatives > /dev/null 2>&1; then
            # Debian/Ubuntu style with update-alternatives
            php_binary="/usr/bin/php$version"

            # Handle different binary naming patterns
            if [ ! -f "$php_binary" ]; then
                # Try alternative patterns
                if [ -f "/usr/bin/php-$version" ]; then
                    php_binary="/usr/bin/php-$version"
                elif [ -f "/usr/bin/php${version/./}" ]; then
                    php_binary="/usr/bin/php${version/./}"
                fi
            fi

            if [ -f "$php_binary" ]; then
                # Install alternative if not already present
                if ! update-alternatives --list php 2> /dev/null | grep -q "$php_binary"; then
                    phpvm_debug "Installing alternative for PHP $version"
                    run_with_sudo update-alternatives --install /usr/bin/php php "$php_binary" 10 || {
                        phpvm_warn "Failed to install alternative, trying direct switch..."
                    }
                fi

                run_with_sudo update-alternatives --set php "$php_binary" || {
                    phpvm_err "Failed to switch to PHP $version using update-alternatives."
                    return 1
                }
            else
                phpvm_err "PHP binary for version $version not found. Tried: $php_binary"
                return 1
            fi

        elif [ "$LINUX_DISTRO" = "arch" ] || [ "$LINUX_DISTRO" = "manjaro" ]; then
            # Arch Linux: versions are typically managed by pacman
            if [ -x "/usr/bin/php" ]; then
                # Check if it's the right version
                installed_version=$(php -v 2> /dev/null | awk '/^PHP/ {print $2}' | cut -d. -f1,2)
                if [ "$installed_version" = "$version" ]; then
                    phpvm_debug "PHP $version already active on Arch Linux"
                else
                    phpvm_warn "PHP $version may not be the active version. Arch typically has one PHP version."
                    phpvm_warn "Current version: $installed_version, requested: $version"
                fi
            else
                phpvm_err "No PHP binary found. Install with: sudo pacman -S php"
                return 1
            fi

        elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
            # RHEL/Fedora: may use alternatives or modules
            if command -v dnf > /dev/null 2>&1 && dnf module list php > /dev/null 2>&1; then
                # Try dnf modules for RHEL 8+
                phpvm_debug "Attempting to enable PHP $version module"
                if ! run_with_sudo dnf module enable php:"$version" -y; then
                    phpvm_warn "Failed to enable PHP $version module. Trying direct binary switch..."
                fi
            fi

            # Fallback to binary switching
            php_binary="/usr/bin/php$version"
            if [ -f "$php_binary" ]; then
                if command -v update-alternatives > /dev/null 2>&1; then
                    run_with_sudo update-alternatives --set php "$php_binary" || {
                        phpvm_err "Failed to switch to PHP $version."
                        return 1
                    }
                fi
            else
                phpvm_err "PHP binary for version $version not found at $php_binary"
                return 1
            fi

        else
            phpvm_err "Cannot switch PHP versions on this system. No supported method found."
            phpvm_warn "System: $LINUX_DISTRO $LINUX_VERSION, Package Manager: $PKG_MANAGER"
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

    phpvm_atomic_write "$PHPVM_ACTIVE_VERSION_FILE" "$version" || {
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
        return 0
    fi

    # Fallback: Try to get version from php -v
    if command -v php > /dev/null 2>&1; then
        php_version=$(php -v 2> /dev/null | command head -1 | command grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | command head -1)
        if [ -n "$php_version" ]; then
            # Check if this looks like a system PHP (not managed by phpvm)
            local php_path
            php_path=$(command -v php 2> /dev/null)
            if [ -n "$php_path" ]; then
                # If PHP is not in our managed paths, it's likely system PHP
                case "$php_path" in
                "$PHPVM_DIR"* | "$HOMEBREW_PREFIX"/opt/php*)
                    echo "$php_version"
                    ;;
                *)
                    echo "system"
                    ;;
                esac
                return 0
            fi
        fi
    fi

    # No PHP found
    echo "none"
    return 1
}

# Display the path to the PHP binary for a given version
# Usage: phpvm_which [version]
# If no version specified, shows path to current PHP
phpvm_which() {
    local version="$1"
    local php_path=""

    # If no version specified, use current
    if [ -z "$version" ]; then
        version=$(phpvm_current)
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
        # Find system PHP (not managed by phpvm/homebrew)
        if [ "$OS_TYPE" = "Darwin" ]; then
            # On macOS, system PHP is typically in /usr/bin
            if [ -x "/usr/bin/php" ]; then
                php_path="/usr/bin/php"
            fi
        else
            # On Linux, check common locations
            for path in /usr/bin/php /usr/local/bin/php; do
                if [ -x "$path" ]; then
                    php_path="$path"
                    break
                fi
            done
        fi

        if [ -z "$php_path" ]; then
            phpvm_err "System PHP not found."
            return "$PHPVM_EXIT_NOT_FOUND"
        fi
        echo "$php_path"
        return "$PHPVM_EXIT_SUCCESS"
        ;;
    esac

    # Handle test mode
    if [ "${PHPVM_TEST_MODE}" = "true" ]; then
        local mock_path="${TEST_PREFIX:-/tmp}/opt/homebrew/Cellar/php@$version/bin/php"
        if [ -d "$(dirname "$mock_path")" ]; then
            echo "$mock_path"
            return "$PHPVM_EXIT_SUCCESS"
        fi
    fi

    # Find PHP binary for specific version
    case "$PKG_MANAGER" in
    brew)
        # Check Homebrew paths
        local brew_prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"

        # Try versioned formula first (php@8.1)
        if [ -x "$brew_prefix/opt/php@$version/bin/php" ]; then
            php_path="$brew_prefix/opt/php@$version/bin/php"
        # Try unversioned formula (php) - check if it matches requested version
        elif [ -x "$brew_prefix/opt/php/bin/php" ]; then
            local installed_version
            installed_version=$("$brew_prefix/opt/php/bin/php" -v 2> /dev/null | command head -1 | command grep -oE '[0-9]+\.[0-9]+' | command head -1)
            if [ "$installed_version" = "$version" ]; then
                php_path="$brew_prefix/opt/php/bin/php"
            fi
        fi
        ;;
    apt)
        # Debian/Ubuntu paths
        if [ -x "/usr/bin/php$version" ]; then
            php_path="/usr/bin/php$version"
        fi
        ;;
    dnf | yum)
        # RHEL/Fedora paths - check Remi-style paths first
        if [ -x "/usr/bin/php$version" ]; then
            php_path="/usr/bin/php$version"
        elif [ -x "/usr/bin/php" ]; then
            # Check if default php matches version
            local installed_version
            installed_version=$(/usr/bin/php -v 2> /dev/null | command head -1 | command grep -oE '[0-9]+\.[0-9]+' | command head -1)
            if [ "$installed_version" = "$version" ]; then
                php_path="/usr/bin/php"
            fi
        fi
        ;;
    pacman)
        # Arch Linux - PHP is typically just /usr/bin/php
        if [ -x "/usr/bin/php" ]; then
            local installed_version
            installed_version=$(/usr/bin/php -v 2> /dev/null | command head -1 | command grep -oE '[0-9]+\.[0-9]+' | command head -1)
            if [ "$installed_version" = "$version" ]; then
                php_path="/usr/bin/php"
            fi
        fi
        ;;
    esac

    if [ -z "$php_path" ]; then
        phpvm_err "PHP $version not found."
        return "$PHPVM_EXIT_NOT_INSTALLED"
    fi

    echo "$php_path"
    return 0
}

# Store original PATH before phpvm modifications
# This is called on first activation to enable deactivate functionality
phpvm_store_original_path() {
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
        return 0
    fi

    # Restore original PATH if we have it stored
    if [ -n "${PHPVM_ORIGINAL_PATH:-}" ]; then
        export PATH="$PHPVM_ORIGINAL_PATH"
        unset PHPVM_ORIGINAL_PATH
        phpvm_debug "Restored original PATH"
    else
        # Fallback: Remove phpvm-managed paths from PATH
        local new_path=""
        local IFS=':'
        for path_entry in $PATH; do
            case "$path_entry" in
            "$PHPVM_DIR"* | "${HOMEBREW_PREFIX:-/opt/homebrew}"/opt/php*)
                phpvm_debug "Removing from PATH: $path_entry"
                ;;
            *)
                if [ -n "$new_path" ]; then
                    new_path="$new_path:$path_entry"
                else
                    new_path="$path_entry"
                fi
                ;;
            esac
        done
        export PATH="$new_path"
    fi

    # Clear active version file
    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
        rm -f "$PHPVM_ACTIVE_VERSION_FILE"
        phpvm_debug "Removed active version file"
    fi

    # Remove current symlink
    if [ -L "$PHPVM_CURRENT_SYMLINK" ]; then
        rm -f "$PHPVM_CURRENT_SYMLINK"
        phpvm_debug "Removed current symlink"
    fi

    # Clear phpvm state variables
    unset PHPVM_ACTIVE_VERSION

    if [ "$silent" != "true" ]; then
        phpvm_echo "phpvm deactivated. Run 'phpvm use <version>' to reactivate."
    fi

    return 0
}

# Find .phpvmrc file in current or parent directories
find_phpvmrc() {
    local current_dir="$PWD"
    local depth=0
    local max_depth=5

    while [ "$current_dir" != "/" ] && [ $depth -lt $max_depth ]; do
        if [ -f "$current_dir/.phpvmrc" ]; then
            echo "$current_dir/.phpvmrc"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
        depth=$((depth + 1))
    done
    return 1
}

# Auto-switch PHP version based on .phpvmrc file
auto_switch_php_version() {
    local phpvmrc_file
    local version

    if ! phpvmrc_file=$(find_phpvmrc); then
        phpvm_warn "No .phpvmrc file found in the current or parent directories."
        return 1
    fi

    # Validate .phpvmrc file exists and is readable
    if [ ! -r "$phpvmrc_file" ]; then
        phpvm_err "Cannot read $phpvmrc_file"
        return 1
    fi

    # Read and validate version from .phpvmrc
    if ! version=$(tr -d '[:space:]' < "$phpvmrc_file" 2> /dev/null); then
        phpvm_err "Failed to read $phpvmrc_file"
        return 1
    fi

    # Resolve aliases before validation
    version=$(phpvm_resolve_version "$version")

    # Validate version is not empty and contains only valid characters
    if [ -z "$version" ]; then
        phpvm_warn "No valid PHP version found in $phpvmrc_file."
        return 1
    fi

    # Validate version format (X.Y, X.Y.Z, or system)
    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format in $phpvmrc_file: $version"
        return 1
    fi

    phpvm_echo "Auto-switching to PHP $version (from $phpvmrc_file)"
    if ! use_php_version "$version"; then
        phpvm_err "Failed to switch to PHP $version from $phpvmrc_file"
        return 1
    fi

    return 0
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
                if echo "$alias_name" | command grep -qi "$pattern"; then
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
        echo "  system (Homebrew default PHP)"
        echo ""
        if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
            active_version=$(command cat "$PHPVM_ACTIVE_VERSION_FILE")
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
        echo "  system (Homebrew default PHP)"
        ;;
    apt)
        dpkg-query -W -f='${Package}\n' | grep -E '^php[0-9]+\.[0-9]+' | sed 's/^php//' | awk '{print "  "$1}'
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
  phpvm test                Run self-tests to verify functionality
  phpvm info                Show system information for debugging
  phpvm version             Show version information

Examples:
  phpvm install 8.1         Install PHP 8.1
  phpvm use 7.4             Switch to PHP 7.4
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
    echo "OS Type: $OS_TYPE"
    echo "Architecture: $OS_ARCH"

    if [ "$OS_TYPE" = "Darwin" ]; then
        echo "macOS Version: ${MACOS_VERSION:-Unknown}"
        echo "macOS Major: ${MACOS_MAJOR:-Unknown}"
        echo "macOS Minor: ${MACOS_MINOR:-Unknown}"

        if command -v brew > /dev/null 2>&1; then
            echo "Homebrew: Installed"
            echo "Homebrew Prefix: ${HOMEBREW_PREFIX:-Unknown}"
            echo "Homebrew Version: $(brew --version 2> /dev/null | head -1 || echo 'Unknown')"
        else
            echo "Homebrew: Not installed"
        fi
    elif [ "$OS_TYPE" = "Linux" ]; then
        echo "Linux Distribution: ${LINUX_DISTRO:-Unknown}"
        echo "Linux Version: ${LINUX_VERSION:-Unknown}"
        echo "WSL: ${IS_WSL:-false}"
        if [ "$IS_WSL" = "true" ]; then
            echo "WSL Version: ${WSL_VERSION:-Unknown}"
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
    cat > "$MOCK_BIN_DIR/brew" << 'EOF'
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
    cat > "$MOCK_BIN_DIR/uname" << 'EOF'
#!/bin/sh
echo "Darwin"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/uname"

    # Mock php and php-config commands
    cat > "$MOCK_BIN_DIR/php" << 'EOF'
#!/bin/sh
if [ "$1" = "-v" ]; then
    echo "PHP 8.0.0 (cli)"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/php"

    cat > "$MOCK_BIN_DIR/php-config" << 'EOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
    echo "8.0.0"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/php-config"

    # Mock sudo command
    cat > "$MOCK_BIN_DIR/sudo" << 'EOF'
#!/bin/sh
# Just execute the command without actual sudo
"$@"
exit $?
EOF
    chmod +x "$MOCK_BIN_DIR/sudo"

    # Mock id command
    cat > "$MOCK_BIN_DIR/id" << 'EOF'
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
        "$@" > "$output_file" 2>&1

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

        "$@" > /dev/null 2>&1
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
        cat > "$MOCK_BIN_DIR/testcmd" << 'EOF'
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
        install_php "7.4" > /dev/null
        local status=$?

        # Check for success and file existence
        [ $status -eq 0 ] && [ -d "$TEST_DIR/opt/homebrew/Cellar/php@7.4/bin" ]
    }

    # Test use_php_version
    test_use_php_version() {
        # Create mock installation
        mkdir -p "$TEST_DIR/opt/homebrew/Cellar/php@7.4/bin"

        # Test switching
        use_php_version "7.4" > /dev/null
        local status=$?

        # Check for success and correct active version
        [ $status -eq 0 ] && [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "7.4" ]
    }

    # Test use default alias
    test_use_default_alias() {
        mkdir -p "$TEST_DIR/opt/homebrew/Cellar/php@8.2/bin"
        phpvm_alias "default" "8.2" > /dev/null 2>&1 || return 1

        use_php_version "default" > /dev/null
        local status=$?

        [ $status -eq 0 ] && [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.2" ]
    }

    # Test system_php_version
    test_system_php_version() {
        system_php_version > /dev/null
        local status=$?

        # Check for success and correct active version
        [ $status -eq 0 ] && [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "system" ]
    }

    # Test auto_switch_php_version
    test_auto_switch() {
        # Create mock installation
        mkdir -p "$TEST_DIR/opt/homebrew/Cellar/php@7.4/bin"

        # Create a project with .phpvmrc
        mkdir -p "$HOME/project"
        echo "7.4" > "$HOME/project/.phpvmrc"

        # Change to the project directory
        cd "$HOME/project" || return 1

        # Test auto-switching
        auto_switch_php_version > /dev/null
        local status=$?

        # Check for success and correct active version
        [ $status -eq 0 ] && [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "7.4" ]
    }

    # Test auto_switch_php_version with alias
    test_auto_switch_alias() {
        # Create mock installation
        mkdir -p "$TEST_DIR/opt/homebrew/Cellar/php@8.1/bin"

        # Create alias
        phpvm_alias "default" "8.1" > /dev/null 2>&1 || return 1

        # Create a project with .phpvmrc
        mkdir -p "$HOME/alias_project"
        echo "default" > "$HOME/alias_project/.phpvmrc"

        # Change to the project directory
        cd "$HOME/alias_project" || return 1

        # Test auto-switching
        auto_switch_php_version > /dev/null
        local status=$?

        # Check for success and correct active version
        [ $status -eq 0 ] && [ "$(cat "$PHPVM_ACTIVE_VERSION_FILE")" = "8.1" ]
    }

    # Test handling of corrupted .phpvmrc file
    test_corrupted_phpvmrc() {
        # Create an invalid .phpvmrc file (empty)
        mkdir -p "$HOME/bad_project"
        touch "$HOME/bad_project/.phpvmrc"

        # Change to the project directory
        cd "$HOME/bad_project" || return 1

        # Test auto-switching with empty .phpvmrc
        output=$(auto_switch_php_version 2>&1)
        status=$?

        # Should fail with an appropriate warning
        [ $status -eq 1 ] && echo "$output" | grep -q "No valid PHP version found"
    }

    # Test phpvm_current function
    test_phpvm_current() {
        # Test 1: With active version file set
        echo "8.2" > "$PHPVM_ACTIVE_VERSION_FILE"
        local result
        result=$(phpvm_current)
        if [ "$result" != "8.2" ]; then
            echo "Expected '8.2', got '$result'"
            return 1
        fi

        # Test 2: With different version
        echo "7.4" > "$PHPVM_ACTIVE_VERSION_FILE"
        result=$(phpvm_current)
        if [ "$result" != "7.4" ]; then
            echo "Expected '7.4', got '$result'"
            return 1
        fi

        # Test 3: With system version
        echo "system" > "$PHPVM_ACTIVE_VERSION_FILE"
        result=$(phpvm_current)
        if [ "$result" != "system" ]; then
            echo "Expected 'system', got '$result'"
            return 1
        fi

        # Test 4: With no active version file (should return "none" or fallback)
        rm -f "$PHPVM_ACTIVE_VERSION_FILE"
        result=$(phpvm_current)
        # In test mode with mock php, it should return something (not empty)
        if [ -z "$result" ]; then
            echo "Expected non-empty result, got empty"
            return 1
        fi

        return 0
    }

    # Test phpvm_which function
    test_phpvm_which() {
        # Create mock PHP installation directory
        local mock_php_dir="${TEST_PREFIX}/opt/homebrew/Cellar/php@8.1/bin"
        mkdir -p "$mock_php_dir"

        # Test 1: With active version set, no argument
        echo "8.1" > "$PHPVM_ACTIVE_VERSION_FILE"
        local result
        result=$(phpvm_which 2> /dev/null)
        # Should return a path (mock path in test mode)
        if [ -z "$result" ]; then
            echo "Test 1 failed: Expected non-empty path for current version"
            return 1
        fi

        # Test 2: With specific version argument
        result=$(phpvm_which "8.1" 2> /dev/null)
        if [ -z "$result" ]; then
            echo "Test 2 failed: Expected non-empty path for version 8.1"
            return 1
        fi

        # Test 3: With system version
        echo "system" > "$PHPVM_ACTIVE_VERSION_FILE"
        result=$(phpvm_which 2>&1)
        # Should either return a path or an error message
        if [ -z "$result" ]; then
            echo "Test 3 failed: Expected output for system version"
            return 1
        fi

        # Test 4: With 'none' active version (should fail)
        rm -f "$PHPVM_ACTIVE_VERSION_FILE"
        # Mock phpvm_current to return "none"
        echo "none" > "$PHPVM_ACTIVE_VERSION_FILE"
        result=$(phpvm_which 2>&1)
        status=$?
        # When version is "none", it should error
        # (In practice it reads "none" from file, which isn't a valid version)

        return 0
    }

    # Test alias management
    test_phpvm_alias() {
        local alias_file="$PHPVM_DIR/alias/test-alias"

        # Create alias
        phpvm_alias "test-alias" "8.1" > /dev/null 2>&1 || return 1
        [ -f "$alias_file" ] || return 1

        # Resolve alias
        if [ "$(phpvm_resolve_version test-alias)" != "8.1" ]; then
            echo "Alias did not resolve correctly"
            return 1
        fi

        # Show alias
        if ! phpvm_alias "test-alias" | grep -q "test-alias"; then
            echo "Alias display failed"
            return 1
        fi

        # Remove alias
        phpvm_unalias "test-alias" > /dev/null 2>&1 || return 1
        [ ! -f "$alias_file" ] || return 1

        return 0
    }

    # Test phpvm_deactivate function
    test_phpvm_deactivate() {
        # Setup: Simulate an active phpvm state
        echo "8.1" > "$PHPVM_ACTIVE_VERSION_FILE"
        mkdir -p "$PHPVM_DIR"
        ln -sf "/tmp/fake/php" "$PHPVM_CURRENT_SYMLINK" 2> /dev/null || true

        # Store a fake original PATH
        export PHPVM_ORIGINAL_PATH="/usr/bin:/bin"
        local old_path="$PATH"
        export PATH="/fake/phpvm/path:$PATH"

        # Test 1: Deactivate should succeed (run directly, not in subshell)
        phpvm_deactivate "true" # silent mode
        local status=$?

        if [ $status -ne 0 ]; then
            echo "Test 1 failed: deactivate returned non-zero status"
            export PATH="$old_path"
            return 1
        fi

        # Test 2: Active version file should be removed
        if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ]; then
            echo "Test 2 failed: active version file still exists"
            export PATH="$old_path"
            return 1
        fi

        # Test 3: PHPVM_ORIGINAL_PATH should be unset (can only check when not in subshell)
        if [ -n "${PHPVM_ORIGINAL_PATH:-}" ]; then
            echo "Test 3 failed: PHPVM_ORIGINAL_PATH should be unset"
            export PATH="$old_path"
            return 1
        fi

        # Test 4: Deactivating when already deactivated should be fine
        local output
        output=$(phpvm_deactivate 2>&1)
        status=$?
        if [ $status -ne 0 ]; then
            echo "Test 4 failed: second deactivate should succeed"
            export PATH="$old_path"
            return 1
        fi

        # Test 5: Output should contain appropriate message
        if ! echo "$output" | grep -qE "deactivated|not currently active"; then
            echo "Test 5 failed: Expected deactivate message in output"
            export PATH="$old_path"
            return 1
        fi

        # Restore PATH for other tests
        export PATH="$old_path"
        return 0
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
    test_function "use default alias" test_use_default_alias || failed=$((failed + 1))

    total=$((total + 1))
    test_function "system_php_version" test_system_php_version || failed=$((failed + 1))

    total=$((total + 1))
    test_function "auto_switch_php_version" test_auto_switch || failed=$((failed + 1))

    total=$((total + 1))
    test_function "auto_switch_php_version alias" test_auto_switch_alias || failed=$((failed + 1))

    total=$((total + 1))
    test_function "corrupted .phpvmrc handling" test_corrupted_phpvmrc || failed=$((failed + 1))

    total=$((total + 1))
    test_function "phpvm_current" test_phpvm_current || failed=$((failed + 1))

    total=$((total + 1))
    test_function "phpvm_which" test_phpvm_which || failed=$((failed + 1))

    total=$((total + 1))
    test_function "phpvm_alias" test_phpvm_alias || failed=$((failed + 1))

    total=$((total + 1))
    test_function "phpvm_deactivate" test_phpvm_deactivate || failed=$((failed + 1))

    # Clean up - ensure TEST_DIR is a valid temp directory before removal
    # Safety checks: must be non-empty, must start with temp directory patterns, must not be a system directory
    if [ -n "$TEST_DIR" ] &&
        [ "$TEST_DIR" != "/" ] &&
        [ "$TEST_DIR" != "$HOME" ] &&
        [ "$TEST_DIR" != "/tmp" ] &&
        [ "$TEST_DIR" != "/var" ] &&
        [ "$TEST_DIR" != "/var/folders" ] &&
        echo "$TEST_DIR" | command grep -qE '^(/tmp/|/var/folders/|/private/var/folders/)'; then
        rm -rf "$TEST_DIR"
    else
        phpvm_debug "Skipping cleanup: TEST_DIR '$TEST_DIR' did not match expected temp patterns"
    fi

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
    local version="$1"
    local mock_dir

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
        # Safely remove mock directory only if it's in our test prefix
        if [ -n "$mock_dir" ] && [ "$mock_dir" != "/" ] && echo "$mock_dir" | grep -q "^${TEST_PREFIX:-/tmp}"; then
            rm -rf "$mock_dir"
        fi
        phpvm_echo "PHP $version uninstalled."
        return 0
    fi

    case "$PKG_MANAGER" in
    brew)
        if brew list --versions php@"$version" > /dev/null 2>&1; then
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
            run_with_sudo "$PKG_MANAGER" remove -y php"$version" || {
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
    if [ -f "$PHPVM_ACTIVE_VERSION_FILE" ] && [ "$(command cat "$PHPVM_ACTIVE_VERSION_FILE")" = "$version" ]; then
        rm -f "$PHPVM_CURRENT_SYMLINK"
        rm -f "$PHPVM_ACTIVE_VERSION_FILE"
        phpvm_warn "Active PHP version was uninstalled. Please select another version."
    fi

    return 0
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

    # Validate alias name
    if ! echo "$name" | command grep -qE '^[a-zA-Z0-9_-]+$'; then
        phpvm_err "Invalid alias name: $name (use only letters, numbers, hyphens, and underscores)"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    # Resolve version and validate
    version=$(phpvm_resolve_version "$version")
    if ! validate_php_version "$version"; then
        phpvm_err "Invalid PHP version format: $version"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

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

    if [ -z "$name" ]; then
        phpvm_err "Missing alias name."
        phpvm_warn "Usage: phpvm unalias <name>"
        return "$PHPVM_EXIT_INVALID_ARG"
    fi

    if [ ! -f "$PHPVM_DIR/alias/$name" ]; then
        phpvm_err "Alias '$name' not found."
        return "$PHPVM_EXIT_NOT_FOUND"
    fi

    if rm -f "$PHPVM_DIR/alias/$name" 2> /dev/null; then
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

    # Only run if not being sourced
    create_directories
    detect_system

    if [ "$#" -eq 0 ]; then
        phpvm_err "No command provided."
        print_help
        exit $PHPVM_EXIT_INVALID_ARG
    fi

    command="$1"
    shift

    case "$command" in
    use)
        if [ "$#" -eq 0 ]; then
            if [ -f "$PHPVM_DIR/alias/default" ]; then
                use_php_version "default"
            else
                phpvm_err "Missing PHP version argument for 'use' command."
                phpvm_warn "Set a default alias with: phpvm alias default <version>"
                exit $PHPVM_EXIT_INVALID_ARG
            fi
        else
            use_php_version "$@"
        fi
        ;;
    install)
        if [ "$#" -eq 0 ]; then
            phpvm_err "Missing PHP version argument for 'install' command."
            exit $PHPVM_EXIT_INVALID_ARG
        fi
        install_php "$@"
        ;;
    uninstall)
        if [ "$#" -eq 0 ]; then
            phpvm_err "Missing PHP version argument for 'uninstall' command."
            exit $PHPVM_EXIT_INVALID_ARG
        fi
        uninstall_php "$@"
        ;;
    current)
        phpvm_current
        ;;
    which)
        phpvm_which "$@"
        ;;
    deactivate)
        phpvm_deactivate
        ;;
    system)
        system_php_version
        ;;
    auto)
        auto_switch_php_version
        ;;
    list | ls)
        list_installed_versions
        ;;
    help)
        print_help
        ;;
    version | --version | -v)
        print_version
        ;;
    test)
        run_tests
        ;;
    info | sysinfo)
        print_system_info
        ;;
    exec)
        phpvm_exec "$@"
        ;;
    run)
        phpvm_run "$@"
        ;;
    ls-remote)
        phpvm_ls_remote "$@"
        ;;
    alias)
        phpvm_alias "$@"
        ;;
    unalias)
        phpvm_unalias "$@"
        ;;
    cache)
        phpvm_cache "$@"
        ;;
    *)
        phpvm_err "Unknown command: $command"
        print_help
        exit $PHPVM_EXIT_UNKNOWN_CMD
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
    if (return 0 2> /dev/null); then
        return 1 # Sourced
    else
        return 0 # Executed
    fi
}

# Safe main execution with error handling
if phpvm_should_execute_main "$@"; then
    phpvm_debug "Executing main with $# arguments"

    # Verify main function exists
    if command -v main > /dev/null 2>&1; then
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
        if command -v auto_switch_php_version > /dev/null 2>&1; then
            auto_switch_php_version 2> /dev/null || true
        fi
    fi
fi
