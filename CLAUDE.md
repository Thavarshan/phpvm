# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## phpvm Development Guide

## Project Overview

**phpvm** is a lightweight PHP Version Manager for macOS and Linux that enables easy installation, switching, and management of multiple PHP versions via command line. The project is built as a single, comprehensive bash script with extensive cross-platform compatibility.

## Architecture

### Core Components

- **`phpvm.sh`** - Main functionality (1000+ lines of bash)
  - PHP version installation and management
  - Cross-platform package manager detection
  - Version switching with symlink management
  - Auto-switching based on `.phpvmrc` files
  - Built-in comprehensive test suite

- **`install.sh`** - Installation script
  - Downloads and sets up phpvm
  - Configures shell profile integration
  - Handles different shell types (bash/zsh)

- **`versions/`** - Directory for PHP version metadata (currently empty)

### Package Manager Support

The tool detects and works with multiple package managers:
- **macOS**: Homebrew (`brew`)
- **Linux**: apt, dnf, yum, pacman
- **Linuxbrew**: Supported on Linux systems

## Key Functionality

### Version Management
- Install PHP versions using system package managers
- Switch between installed versions using symlinks and package manager tools
- System PHP fallback support
- Active version tracking via `~/.phpvm/active_version`

### Auto-Switching
- Detects `.phpvmrc` files in current/parent directories (up to 5 levels)
- Automatically switches to specified PHP version
- Handles corrupted/invalid `.phpvmrc` files gracefully

### Testing Framework
- BATS (Bash Automated Testing System) test suite in `tests/` directory
- Mock environment creation for testing with `PHPVM_TEST_MODE=true`
- Comprehensive test coverage including edge cases
- Run tests with: `bats tests/`

## Development Guidelines

### Code Style
- POSIX-compliant bash scripting where possible
- Comprehensive error handling with structured logging
- Timestamped log messages with levels (INFO, ERROR, WARNING, DEBUG)
- Helper functions to reduce code duplication

### Testing
- Run tests: `bats tests/`
- Tests create isolated mock environments with `PHPVM_TEST_MODE=true`
- All core functionality is tested including error conditions
- Tests verify cross-platform compatibility
- GitHub Actions runs automated tests on Ubuntu and macOS
- Shell syntax checking with `bash -n phpvm.sh`
- ShellCheck static analysis for code quality

### Debugging
- Enable debug mode: `DEBUG=true phpvm <command>`
- Debug logs provide detailed execution tracing
- Test mode can be enabled with `PHPVM_TEST_MODE=true`

## Common Development Tasks

### Adding New Commands

1. Add command handler in the `main()` function case statement
2. Implement the command function following naming convention `command_name()`
3. Add help text in `print_help()`
4. Add BATS tests in the `tests/` directory

### Supporting New Package Managers
1. Add detection logic in `detect_system()`
2. Add installation logic in `install_php()`
3. Add version switching logic in `use_php_version()`
4. Add version listing logic in `list_installed_versions()`
5. Add uninstall logic in `uninstall_php()`

### Testing Changes

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/01_core.bats

# Enable debug mode for troubleshooting
DEBUG=true bats tests/

# Test specific functionality manually with test mode
PHPVM_TEST_MODE=true DEBUG=true ./phpvm.sh install 8.1
PHPVM_TEST_MODE=true DEBUG=true ./phpvm.sh use 8.1

# Check shell syntax
bash -n phpvm.sh
bash -n install.sh

# Run performance checks
time ./phpvm.sh version
time ./phpvm.sh help
```

### Release Process
1. Update version number in `PHPVM_VERSION` variable
2. Update CHANGELOG.md with new features/fixes
3. Test across different platforms
4. Ensure all tests pass
5. Update README.md if needed

## Key Functions in phpvm.sh

- `main()` - Entry point with command routing
- `detect_system()` - Package manager and OS detection
- `install_php()` - PHP version installation logic
- `use_php_version()` - Version switching functionality
- `find_phpvmrc()` - Auto-detection of .phpvmrc files
- Helper functions: `run_with_sudo()`, `phpvm_echo()`, `phpvm_err()`, `phpvm_warn()`, `phpvm_debug()`
- Package manager abstraction: `pkg_install_php()`, `pkg_uninstall_php()`, `pkg_search_php()`

## File Structure

```
phpvm/
├── CLAUDE.md          # This file
├── CHANGELOG.md       # Release history
├── LICENSE           # MIT license
├── README.MD         # User documentation
├── TESTING.md        # Testing documentation (minimal)
├── assets/           # Project images
├── install-bats.sh   # BATS installation script
├── install.sh        # Main installation script
├── phpvm.sh          # Core functionality (~1000 lines)
├── versions/         # Version metadata directory
└── .github/          # GitHub workflows and templates
    └── workflows/
        ├── test.yml  # Automated testing
        ├── use.yml   # Usage testing
        └── release.yml # Release automation
```

## Environment Variables

- `PHPVM_DIR` - Installation directory (default: `~/.phpvm`)
- `DEBUG` - Enable debug logging (set to `true`)
- `PHPVM_TEST_MODE` - Enable test mode (set to `true`)
- `PHPVM_SOURCED` - Control execution vs sourcing behavior
- `PHPVM_AUTO_USE` - Enable automatic `.phpvmrc` detection (default: `true`)

## Cross-Platform Considerations

### macOS Specifics
- Relies on Homebrew for PHP installation
- Uses `brew link/unlink` for version switching
- Handles Homebrew prefix detection automatically

### Linux Specifics
- Supports multiple package managers
- Uses `update-alternatives` for version switching where available
- Requires `sudo` privileges for system-level operations

### Shell Compatibility
- Works with bash and zsh
- POSIX-compliant where possible
- Handles different shell profile files (.bashrc, .zshrc, .profile)

## Security Considerations

- Uses `run_with_sudo()` helper for controlled privilege escalation
- Validates input parameters before system operations
- No hardcoded credentials or sensitive data
- Safe handling of temporary files and directories

## Performance Notes

- Lightweight single-script architecture
- Minimal external dependencies
- Fast execution due to bash implementation
- Efficient directory traversal for `.phpvmrc` detection
