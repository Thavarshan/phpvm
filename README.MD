[![PHP Version Manager (phpvm)](./assets/Banner.png)](https://github.com/Thavarshan/phpvm)

[![Test](https://github.com/Thavarshan/phpvm/actions/workflows/test.yml/badge.svg)](https://github.com/Thavarshan/phpvm/actions/workflows/test.yml)
[![Use](https://github.com/Thavarshan/phpvm/actions/workflows/use.yml/badge.svg)](https://github.com/Thavarshan/phpvm/actions/workflows/use.yml)
[![Version](https://img.shields.io/github/v/release/Thavarshan/phpvm.svg)](https://github.com/Thavarshan/phpvm/releases)
[![GitHub stars](https://img.shields.io/github/stars/Thavarshan/phpvm.svg)](https://github.com/Thavarshan/phpvm/stargazers)

# PHP Version Manager (phpvm)

## Introduction

`phpvm` is a lightweight PHP Version Manager that allows you to easily install, switch between, and manage multiple PHP versions via the command line.

**Example:**

```sh
$ phpvm version
phpvm version 1.5.0

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
- Supports macOS (via Homebrew) and Linux distributions including WSL.
- Enhanced cross-platform compatibility with improved shell support.
- Works with common shells (`bash`, `zsh`).
- Comprehensive version commands (`phpvm version`, `phpvm --version`, `phpvm -v`).
- Post-install validation with helpful warnings for missing binaries.
- Improved error handling with detailed messages and suggestions.
- Enhanced Homebrew integration with better link failure detection.
- Informative, color-coded feedback with timestamps for logs.
- Includes unit tests with BATS for automated testing.
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

| Command                   | Description                           |
| ------------------------- | ------------------------------------- |
| `phpvm install <version>` | Install a specific PHP version        |
| `phpvm use <version>`     | Switch to a specific PHP version      |
| `phpvm system`            | Switch to system/Homebrew default PHP |
| `phpvm list`              | List all installed PHP versions       |
| `phpvm auto`              | Auto-switch based on `.phpvmrc` file  |
| `phpvm test`              | Run built-in self-tests               |
| `phpvm version`           | Show version information              |
| `phpvm --version`         | Show version information (alias)      |
| `phpvm -v`                | Show version information (alias)      |
| `phpvm help`              | Show help message                     |

### Installing PHP Versions

To install a specific version of PHP:

```sh
phpvm install 8.1
```

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

### Listing Installed Versions

To list all installed PHP versions:

```sh
phpvm list
```

This will show all installed PHP versions and indicate the currently active one.

### Running Self-Tests

phpvm includes built-in self-tests to verify everything is working correctly:

```sh
phpvm test
```

This will run a series of tests on your system to ensure all phpvm functions are working properly.

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

## Development & Testing

phpvm features comprehensive testing across multiple platforms and scenarios. The project includes extensive GitHub Actions workflows that test every aspect of the script.

### Built-in Testing

phpvm includes built-in self-tests that validate all core functionality:

```sh
# Run the built-in tests
phpvm test

# Get detailed system information for debugging
phpvm info
```

The built-in test framework verifies:

- Output and formatting functions
- System detection and OS compatibility
- PHP version installation (mocked)
- Version switching and validation
- Auto-switching based on .phpvmrc
- Input validation and security
- System PHP integration

### Comprehensive GitHub Actions Testing

The project includes multiple specialized testing workflows:

#### 1. **Comprehensive Distribution Testing** (`.github/workflows/comprehensive-test.yml`)
Tests across multiple Linux distributions and scenarios:
- **Ubuntu**: 20.04, 22.04, 24.04
- **Debian**: 11 (Bullseye), 12 (Bookworm)
- **RHEL/CentOS**: Rocky Linux 8 & 9, AlmaLinux 8 & 9
- **Fedora**: 38, 39
- **Arch Linux**: Latest
- **Alpine Linux**: 3.18, 3.19
- **macOS**: Intel (13) and Apple Silicon (14, latest)

#### 2. **Security Testing** (`.github/workflows/security-test.yml`)
Comprehensive security validation including:
- Input validation and injection prevention
- Path traversal protection
- Privilege escalation prevention
- Buffer overflow protection
- File permission security
- Environment variable security
- Symlink attack prevention

#### 3. **Performance Testing** (`.github/workflows/performance-test.yml`)
Performance and load testing including:
- Baseline performance measurements
- Memory usage analysis
- Concurrent operations testing
- High-frequency operations
- Scalability testing
- Memory leak detection

#### 4. **Integration Testing** (`.github/workflows/integration-test.yml`)
End-to-end integration testing including:
- Real-world scenario simulation
- Multi-version workflows
- Cross-platform compatibility
- Installation simulation
- Documentation validation

#### 5. **Legacy Testing** (`.github/workflows/test.yml`)
Original testing workflow for basic functionality validation.

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
