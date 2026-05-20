[![PHP Version Manager (phpvm)](./assets/Banner.png)](https://github.com/Thavarshan/phpvm)

[![CI Pipeline](https://github.com/Thavarshan/phpvm/actions/workflows/ci.yml/badge.svg)](https://github.com/Thavarshan/phpvm/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/release/Thavarshan/phpvm.svg)](https://github.com/Thavarshan/phpvm/releases)
[![GitHub stars](https://img.shields.io/github/stars/Thavarshan/phpvm.svg)](https://github.com/Thavarshan/phpvm/stargazers)

# PHP Version Manager (phpvm)

## Introduction

`phpvm` is a lightweight PHP Version Manager that allows you to easily install, switch between, and manage multiple PHP versions via the command line.

**Example:**

```sh
$ phpvm version
phpvm version 1.11.0

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
- **Run commands with a specific PHP version** without globally switching (`phpvm exec`, `phpvm run`).
- **List available remote PHP versions** from your system package manager (`phpvm ls-remote`).
- **Install the latest available remote PHP version** with `phpvm install latest-remote`.
- **Resolve version descriptors and aliases** to installed version numbers (`phpvm resolve`).
- Auto-switch PHP versions based on project `.phpvmrc` (configurable depth via `PHPVM_PHPVMRC_MAX_DEPTH`).
- Automatic directory-based switching via built-in cd hook (`PROMPT_COMMAND` for bash, `chpwd` for zsh).
- **Auto-set `default` alias** on first `phpvm install` (matches nvm behaviour).
- Alias management for versions (`phpvm alias`, `phpvm unalias`).
- Built-in version shortcuts: `latest`, `stable`, and user-defined aliases.
- **Bash tab completion** — context-aware completions for commands, versions, and aliases (auto-loaded on source).
- **`--no-use` flag** for sourcing without auto-switch or cd hook registration (`source phpvm.sh --no-use`).
- **Unload phpvm** from the current shell session (`phpvm unload`).
- Cache management: inspect (`phpvm cache dir`) and clear (`phpvm cache clear`).
- **`PHPVM_BIN` export** — active PHP binary directory exported after every version switch.
- **`XDG_CONFIG_HOME` fallback** — `PHPVM_DIR` respects `$XDG_CONFIG_HOME/phpvm` when set.
- **Improved `phpvm list` output** with `->` marker for the active version and `(default)` annotation.
- System information and debugging (`phpvm info`).
- Supports macOS (via Homebrew) and Linux distributions including WSL.
- **Smart repository detection** for RHEL/Fedora systems with automatic setup guidance.
- **Enhanced error handling** with actionable solutions when PHP packages are missing.
- **Intelligent package availability checking** before attempting installations.
- **Concurrency-safe operations** with file-based locking to prevent race conditions.
- **Specific exit codes** for scripting (0–5, 127).
- Enhanced cross-platform compatibility with improved shell support.
- Works with common shells (`bash`, `zsh`).
- Comprehensive version commands (`phpvm version`, `phpvm --version`, `phpvm -v`).
- Post-install validation with helpful warnings for missing binaries.
- Enhanced Homebrew integration with better link failure detection.
- Informative, color-coded feedback with `NO_COLOR` support.
- Comprehensive BATS test suite for verifying functionality.
- Atomic file writes for safe state management.

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

| Command                                    | Description                                                               |
| ------------------------------------------ | ------------------------------------------------------------------------- |
| `phpvm install [version]`                  | Install a PHP version (reads `.phpvmrc` if no version given)              |
| `phpvm use [version]`                      | Switch PHP version (reads `.phpvmrc` → default alias if no version given) |
| `phpvm uninstall <version>`                | Remove a specific PHP version                                             |
| `phpvm current`                            | Display the currently active PHP version                                  |
| `phpvm which [version]`                    | Show the path to PHP binary for a version                                 |
| `phpvm exec <version> <command> [args...]` | Run a command with a specific PHP version (subshell isolation)            |
| `phpvm run <version> [script] [args...]`   | Run a PHP script with a specific version                                  |
| `phpvm deactivate`                         | Temporarily disable phpvm and restore PATH                                |
| `phpvm unload`                             | Remove phpvm from the current shell session                               |
| `phpvm system`                             | Switch to system/Homebrew default PHP                                     |
| `phpvm auto`                               | Auto-switch based on `.phpvmrc` file                                      |
| `phpvm list` or `phpvm ls`                 | List all installed PHP versions                                           |
| `phpvm ls-remote [pattern]`                | List available remote PHP versions                                        |
| `phpvm install latest-remote`               | Install the latest remote PHP version available                          |
| `phpvm resolve <version\|alias>`           | Resolve a version descriptor to an installed version                      |
| `phpvm alias [name] [ver]`                 | Create, update, or list version aliases                                   |
| `phpvm unalias <name>`                     | Remove version alias                                                      |
| `phpvm cache <dir\|clear>`                 | Show or clear the phpvm cache directory                                   |
| `phpvm info`                               | Show system information for debugging                                     |
| `phpvm version`                            | Show version information                                                  |
| `phpvm --version` / `-v`                   | Show version information (aliases)                                        |
| `phpvm help`                               | Show help message                                                         |

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

**Automatic switching on `cd`**: When phpvm is sourced into your shell, it registers a cd hook that detects `.phpvmrc` files and switches PHP versions automatically as you navigate between directories. No manual command needed — just `cd` into a project.

- **Bash**: Uses `PROMPT_COMMAND`
- **Zsh**: Uses `chpwd_functions`
- Gated behind `PHPVM_AUTO_USE=true` (the default)
- Skips switching if already on the correct version

**Using `use` and `install` without a version**: When no version argument is given, these commands read `.phpvmrc` automatically:

```sh
# Reads version from .phpvmrc in current or parent directories
phpvm use
phpvm install
```

`phpvm use` follows this fallback chain: `.phpvmrc` → `default` alias → error.

**Manual switching**: You can also trigger auto-switching explicitly:

```sh
phpvm auto
```

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

The active version is marked with `->` and highlighted in green. If a `default` alias is set, it is annotated inline:

```
Installed PHP versions:
->   8.2 (default)
     8.1
     8.0
     system

Active version: 8.2
```

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

### Cache Management

Show the phpvm cache directory:

```sh
phpvm cache dir
```

Clear all cached files:

```sh
phpvm cache clear
```

### System Information

Show system details for debugging:

```sh
phpvm info
```

This displays OS type, architecture, package manager, installed PHP versions, and other diagnostic information useful for bug reports.

### Uninstalling PHP Versions

To remove a specific PHP version:

```sh
phpvm uninstall 7.4
```

### Running Commands with a Specific PHP Version

Use `phpvm exec` to run any command with a specific PHP version without globally switching. The command executes in a subshell, so your current shell session is unaffected:

```sh
# Run composer install with PHP 8.2
phpvm exec 8.2 composer install

# Run a linter with PHP 8.1
phpvm exec 8.1 ./vendor/bin/phpstan analyse
```

Use `phpvm run` as a shortcut for `phpvm exec <version> php`:

```sh
# Run a PHP script with PHP 8.1
phpvm run 8.1 script.php arg1 arg2

# Equivalent to:
phpvm exec 8.1 php script.php arg1 arg2
```

Both commands resolve aliases and keywords (`default`, `latest`, `stable`) before execution.

### Listing Available Remote Versions

List PHP versions available for installation from your system package manager:

```sh
phpvm ls-remote
```

Filter by pattern:

```sh
phpvm ls-remote 8.2
```

Supported package managers: Homebrew, apt, dnf, yum, and pacman.

### Resolving Versions

Resolve a version descriptor, alias, or keyword to a locally installed version number:

```sh
# Resolve an alias
phpvm resolve default    # → 8.2

# Resolve a keyword
phpvm resolve latest     # → 8.3

# Pass through a concrete version (if installed)
phpvm resolve 8.1        # → 8.1
```

This is useful in CI scripts or tooling that needs to know which version an alias points to.

### Unloading phpvm

Remove phpvm from the current shell session entirely:

```sh
phpvm unload
```

This deactivates phpvm, removes the cd hook, and unsets all phpvm functions and variables. To use phpvm again, re-source it:

```sh
source ~/.phpvm/phpvm.sh
```

### Tab Completion

phpvm includes built-in bash tab completion that is automatically loaded when phpvm is sourced. It provides context-aware completions for:

- All phpvm commands
- Installed PHP versions (for `use`, `uninstall`, `which`, `exec`, `run`, `resolve`)
- Alias names (for `unalias`)
- Cache subcommands (`dir`, `clear`)

No additional setup is required — completions are loaded from `$PHPVM_DIR/completions/phpvm.bash`.

### Sourcing with `--no-use`

Load phpvm functions without triggering auto-switch or registering the cd hook:

```sh
source ~/.phpvm/phpvm.sh --no-use
```

This is useful for lazy-loading setups where you want phpvm functions available but don't want automatic version switching on shell startup.

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

## Environment Variables

| Variable                  | Default    | Description                                                                              |
| ------------------------- | ---------- | ---------------------------------------------------------------------------------------- |
| `PHPVM_DIR`               | `~/.phpvm` | Installation directory (falls back to `$XDG_CONFIG_HOME/phpvm` if `XDG_CONFIG_HOME` set) |
| `PHPVM_BIN`               | _(export)_ | Active PHP binary directory (set after version switch, unset on deactivate)              |
| `PHPVM_AUTO_USE`          | `true`     | Enable automatic `.phpvmrc` detection when sourced                                       |
| `PHPVM_PHPVMRC_MAX_DEPTH` | `25`       | Max parent directories to traverse when searching for `.phpvmrc`                         |
| `PHPVM_DEBUG`             | `false`    | Enable debug logging with timestamps                                                     |
| `NO_COLOR`                | _(unset)_  | Disable color output ([no-color.org](https://no-color.org/))                             |
| `PHPVM_LOG_TIMESTAMPS`    | `false`    | Always show timestamps in log output                                                     |

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

- Run the test suite with `bats tests/` to verify all functions are working correctly
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

The project features a streamlined CI/CD pipeline with comprehensive testing in a single consolidated workflow:

#### **CI Pipeline** (`.github/workflows/ci.yml`)

Consolidated testing workflow including:

- **Quick Checks**: Shell syntax validation, ShellCheck analysis, code formatting, and quality checks
- **Security Testing**: Input validation, path traversal protection, privilege escalation prevention, buffer overflow protection, file permission security, environment variable security, and symlink attack prevention
- **BATS Test Suite**: Comprehensive automated testing across Ubuntu and macOS
- **Core Functionality Tests**: Version commands, basic commands, error handling, and .phpvmrc auto-switching across multiple platforms
- **PHP Integration Tests**: Installation flow, version operations, project workflows, and error recovery testing
- **Multi-Distribution Testing** (scheduled weekly): 5 Linux distributions
  - **Ubuntu**: 22.04, 24.04
  - **Debian**: 12 (Bookworm)
  - **Fedora**: 39
  - **Alpine Linux**: 3.19
- **Performance Testing** (scheduled weekly): Startup time benchmarks, concurrent operations, and load testing
- **Quality Gate**: Final validation ensuring all required checks pass

#### **Release Workflow** (`.github/workflows/release.yml`)

Release-specific workflow including:

- Release readiness verification
- Version consistency validation
- Documentation checks
- Release artifact generation and packaging

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
# Syntax check
bash -n phpvm.sh

# Run all BATS tests
bats tests/

# Run specific test file
bats tests/01_core.bats

# Test input validation
./phpvm.sh install "invalid..version"  # Should fail gracefully

# Test system information
./phpvm.sh info

# Test with debug output
PHPVM_DEBUG=true ./phpvm.sh version
```

### Debugging

To enable debug output, set the `PHPVM_DEBUG` environment variable to `true`:

```sh
PHPVM_DEBUG=true phpvm install 8.1
```

## Maintainers

`phpvm` is maintained by [Jerome Thayananthajothy](https://github.com/Thavarshan).

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.

## Disclaimer

`phpvm` is provided as-is without any warranties. Use it at your own risk.
