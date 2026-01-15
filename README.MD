[![PHP Version Manager (phpvm)](./assets/Banner.png)](https://github.com/Thavarshan/phpvm)

[![Test](https://github.com/Thavarshan/phpvm/actions/workflows/test.yml/badge.svg)](https://github.com/Thavarshan/phpvm/actions/workflows/test.yml)
[![Security](https://github.com/Thavarshan/phpvm/actions/workflows/security-test.yml/badge.svg)](https://github.com/Thavarshan/phpvm/actions/workflows/security-test.yml)
[![Version](https://img.shields.io/github/v/release/Thavarshan/phpvm.svg)](https://github.com/Thavarshan/phpvm/releases)
[![GitHub stars](https://img.shields.io/github/stars/Thavarshan/phpvm.svg)](https://github.com/Thavarshan/phpvm/stargazers)

# PHP Version Manager (phpvm)

## Introduction

`phpvm` is a lightweight PHP Version Manager that allows you to easily install, switch between, and manage multiple PHP versions via the command line.

**Example:**

```sh
$ phpvm version
phpvm version 1.7.0

PHP Version Manager for macOS and Linux
Author: Jerome Thayananthajothy <tjthavarshan@gmail.com>
Repository: https://github.com/Thavarshan/phpvm

Usage: phpvm help

$ phpvm use 8.2
Switching to PHP 8.2...
Switched to PHP 8.2.
$ php -v
PHP 8.2.10
$ phpvm use 8.1
Switching to PHP 8.1...
Switched to PHP 8.1.
$ php -v
PHP 8.1.13
```

## Features

- Install and manage multiple PHP versions.
- Seamlessly switch between installed PHP versions.
- Auto-switch PHP versions based on project `.phpvmrc`.
- Alias management for versions (`phpvm alias`, `phpvm unalias`).
- Cache directory inspection (`phpvm cache dir`).
- Supports macOS (via Homebrew) and Linux distributions including WSL.
- **Smart repository detection** for RHEL/Fedora systems with automatic setup guidance.
- **Enhanced error handling** with actionable solutions when PHP packages are missing.
- **Intelligent package availability checking** before attempting installations.
- Enhanced cross-platform compatibility with improved shell support.
- Works with common shells (`bash`, `zsh`).
- Comprehensive version commands (`phpvm version`, `phpvm --version`, `phpvm -v`).
- Post-install validation with helpful warnings for missing binaries.
- Enhanced Homebrew integration with better link failure detection.
- Informative, color-coded feedback with timestamps for logs.
- Comprehensive BATS test suite for verifying functionality.
- Helper functions for better maintainability and reduced code duplication.

## Installation

### Install & Update phpvm

To **install** or **update** phpvm, run one of the following commands:

```sh
curl -o- https://raw.githubusercontent.com/Thavarshan/phpvm/main/install.sh | bash
```

```sh
wget -qO- https://raw.githubusercontent.com/Thavarshan/phpvm/main/install.sh | bash
```

This script will download and set up `phpvm` in `~/.phpvm` and automatically update your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.profile`) with the following lines:

```sh
export PHPVM_DIR="$HOME/.phpvm"
export PATH="$PHPVM_DIR/bin:$PATH"
[ -s "$PHPVM_DIR/phpvm.sh" ] && . "$PHPVM_DIR/phpvm.sh"
```

### Verify Installation

Run the following command:

```sh
command -v phpvm
```

If the installation was successful, it should output the path to `phpvm`.

## Usage

### Available Commands

| Command                    | Description                                |
| -------------------------- | ------------------------------------------ |
| `phpvm install <version>`  | Install a specific PHP version             |
| `phpvm use <version>`      | Switch to a specific PHP version           |
| `phpvm current`            | Display the currently active PHP version   |
| `phpvm which [version]`    | Show the path to PHP binary for a version  |
| `phpvm deactivate`         | Temporarily disable phpvm and restore PATH |
| `phpvm system`             | Switch to system/Homebrew default PHP      |
| `phpvm list` or `phpvm ls` | List all installed PHP versions            |
| `phpvm alias [name] [ver]` | Create, update, or list version aliases    |
| `phpvm unalias <name>`     | Remove version alias                       |
| `phpvm cache dir`          | Show phpvm cache directory                 |
| `phpvm auto`               | Auto-switch based on `.phpvmrc` file       |
| `phpvm version`            | Show version information                   |
| `phpvm --version`          | Show version information (alias)           |
| `phpvm -v`                 | Show version information (alias)           |
| `phpvm help`               | Show help message                          |

### Installing PHP Versions

To install a specific version of PHP:

```sh
phpvm install 8.1
```

**Smart Repository Detection**: On RHEL/Fedora systems, phpvm automatically detects if PHP packages are available in your current repositories. If not, it provides step-by-step instructions to enable the necessary repositories (like Remi's repository) before installation.

### Switching PHP Versions

To switch between installed versions:

```sh
phpvm use 8.0
```

To switch back to the system PHP version (Homebrew default on macOS):

```sh
phpvm system
```

Verify the active version with:

```sh
php -v
```

### Checking Current PHP Version

To see which PHP version is currently active:

```sh
phpvm current
```

This will display the active PHP version, "system" (if using system PHP), or "none" (if no PHP is active).

### Finding PHP Binary Paths

To find the path to a PHP binary for any version:

```sh
# Show path for a specific version
phpvm which 8.2

# Show path for current version
phpvm which
```

This works across all package managers (Homebrew, apt, dnf, yum, pacman) and is useful for IDE configuration or scripting.

### Temporarily Disabling phpvm

To temporarily disable phpvm and restore your original PATH:

```sh
phpvm deactivate
```

This is useful for debugging or when you need to use the system default PHP temporarily. To re-enable phpvm, simply use `phpvm use <version>` again.

### Version Information

To check the phpvm version and get information:

```sh
phpvm version
# or
phpvm --version
# or
phpvm -v
```

### Auto-Switching PHP Versions

Create a `.phpvmrc` file in your project directory to specify the desired PHP version:

```sh
echo "8.1" > .phpvmrc
```

When you navigate to that project directory and run:

```sh
phpvm auto
```

phpvm will automatically detect and switch to the version specified in the `.phpvmrc` file.

Aliases can also be used in `.phpvmrc`:

```sh
echo "default" > .phpvmrc
phpvm auto
```

### Listing Installed Versions

To list all installed PHP versions:

```sh
phpvm list
```

This will show all installed PHP versions and indicate the currently active one.

### Managing Aliases

Create or update a version alias:

```sh
phpvm alias default 8.2
phpvm alias production 8.1
```

List aliases:

```sh
phpvm alias
```

List aliases matching a pattern:

```sh
phpvm alias def
```

Remove an alias:

```sh
phpvm unalias production
```

Aliases also appear in `phpvm list` output when defined.

You can also use `latest` or `stable` as shorthand for the latest installed PHP version:

```sh
phpvm use latest
phpvm use stable
```

### Cache Directory

Show the phpvm cache directory:

```sh
phpvm cache dir
```

### Planned Commands (Coming Soon)

The following commands are in progress and may return a "not yet implemented" message:

- `phpvm exec <version> <command> [args...]`
- `phpvm run <version> [script] [args...]`
- `phpvm ls-remote [pattern]`
- `phpvm cache clear`

### Exit Codes

phpvm uses specific exit codes for better scripting support:

| Exit Code | Meaning                           |
| --------- | --------------------------------- |
| `0`       | Success                           |
| `1`       | General error                     |
| `2`       | Invalid argument or usage error   |
| `3`       | Version not found (not available) |
| `4`       | Version not installed locally     |
| `5`       | File or permission error          |
| `127`     | Unknown command                   |

Example usage in scripts:

```sh
phpvm use 8.2
if [ $? -eq 0 ]; then
    echo "Successfully switched to PHP 8.2"
else
    echo "Failed to switch PHP version"
fi
```

## Uninstallation

To completely remove `phpvm`, run:

```sh
rm -rf ~/.phpvm
```

Then remove the following lines from your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```sh
export PHPVM_DIR="$HOME/.phpvm"
export PATH="$PHPVM_DIR/bin:$PATH"
[ -s "$PHPVM_DIR/phpvm.sh" ] && . "$PHPVM_DIR/phpvm.sh"
```

## Troubleshooting

If you experience issues with `phpvm`, try the following:

### General Issues

- Run `phpvm test` to verify all functions are working correctly
- Check the phpvm version with `phpvm version` or `phpvm --version`
- Ensure your shell profile is sourcing `phpvm.sh`
- Restart your terminal after installing or updating
- Verify that the required package manager is installed:
  - Homebrew for macOS
  - apt, dnf, yum, or pacman for Linux
- Check for permission issues during the installation or PHP version switching process
- For Linux systems, you may need to use `sudo` for installation and switching
- On WSL systems, ensure you're using bash shell compatibility
- If you encounter Homebrew link issues on macOS, try manually relinking: `brew unlink php@X.Y && brew link --force php@X.Y`
- Refer to the [Changelog](./CHANGELOG.md) for recent updates and fixes

### Repository Setup for RHEL/Fedora Systems

If you encounter "PHP packages not found" errors on RHEL-family distributions, phpvm will automatically provide setup instructions. You can also manually enable the required repositories:

#### Fedora Systems

```bash
# Install Remi's repository
sudo dnf install https://rpms.remirepo.net/fedora/remi-release-$(rpm -E %fedora).rpm

# Enable the repository
sudo dnf config-manager --set-enabled remi

# Enable specific PHP version (example for PHP 8.3)
sudo dnf config-manager --set-enabled remi-php83
```

#### RHEL/Rocky/AlmaLinux/CentOS Systems

```bash
# Install EPEL repository
sudo dnf install epel-release

# Install Remi's repository
sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm

# Enable the repositories
sudo dnf config-manager --set-enabled remi
sudo dnf config-manager --set-enabled remi-php83  # for PHP 8.3
```

#### Alternative: Use Homebrew on Linux

If you prefer to avoid repository management, you can install Homebrew on Linux:

```bash
# Install Homebrew on Linux
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to your shell profile
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc

# Now phpvm will use Homebrew instead of dnf/yum
phpvm install 8.3
```

## Development & Testing

phpvm features comprehensive testing using the BATS (Bash Automated Testing System) framework. The project includes extensive GitHub Actions workflows that test every aspect of the script.

### Running Tests

Run the BATS test suite to validate all functionality:

```sh
# Run all tests
make test-bats

# Or run BATS directly
bats tests/

# Run specific test file
bats tests/01_core.bats
```

The BATS test suite verifies:

- Core functionality (version management, installation, switching)
- System detection and OS compatibility
- PHP version installation (mocked)
- Version switching and validation
- Auto-switching based on .phpvmrc
- Input validation and security
- System PHP integration

### Comprehensive GitHub Actions Testing

The project features a streamlined CI/CD pipeline with comprehensive testing workflows:

#### 1. **Core Testing** (`.github/workflows/test.yml`)

Comprehensive testing workflow including:

- **Multi-Distribution Testing**: 13 Linux distributions across 4 package managers
  - **Ubuntu**: 20.04, 22.04, 24.04
  - **Debian**: 11 (Bullseye), 12 (Bookworm)
  - **RHEL/CentOS**: Rocky Linux 8 & 9, AlmaLinux 8 & 9, Fedora 38 & 39
  - **Arch Linux**: Latest
  - **Alpine Linux**: 3.18, 3.19
- **Cross-Platform Testing**: Ubuntu and macOS (Intel and Apple Silicon)
- **PHP Usage Testing**: Installation, version switching, and auto-detection
- **Performance Testing**: Startup time, concurrent operations, load testing
- **Integration Testing**: End-to-end workflows, installation simulation, error recovery

#### 2. **Security Testing** (`.github/workflows/security-test.yml`)

Specialized security validation including:

- Input validation and injection prevention
- Path traversal protection
- Privilege escalation prevention
- Buffer overflow protection
- File permission security
- Environment variable security
- Symlink attack prevention

#### 3. **Release Validation** (`.github/workflows/release.yml`)

Release testing and validation for new versions.

### Testing Coverage

The testing suite covers:

- **All supported Linux distributions** with their native package managers
- **macOS versions** across Intel and Apple Silicon architectures
- **WSL environments** (Windows Subsystem for Linux)
- **Package managers**: apt, dnf, yum, pacman, Homebrew, Linuxbrew
- **Security scenarios**: malicious input, path traversal, privilege escalation
- **Performance scenarios**: load testing, memory usage, scalability
- **Edge cases**: corrupted files, permission issues, network failures
- **Error recovery**: state corruption, missing dependencies

### Running Tests Locally

```sh
# Run built-in tests
./phpvm.sh test

# Test input validation
./phpvm.sh install "invalid..version"  # Should fail gracefully

# Test system information
./phpvm.sh info

# Test with debug output
DEBUG=true ./phpvm.sh version
```

### Debugging

To enable debug output, set the `DEBUG` environment variable to `true`:

```sh
DEBUG=true phpvm install 8.1
```

## Maintainers

`phpvm` is maintained by [Jerome Thayananthajothy](https://github.com/Thavarshan).

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.

## Disclaimer

`phpvm` is provided as-is without any warranties. Use it at your own risk.
