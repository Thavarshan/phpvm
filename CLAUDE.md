# CLAUDE.md - phpvm Development Guide

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
- Built-in self-tests (`phpvm test`)
- Mock environment creation for testing
- Comprehensive test coverage including edge cases
- No external testing dependencies required

## Development Guidelines

### Code Style
- POSIX-compliant bash scripting where possible
- Comprehensive error handling with structured logging
- Timestamped log messages with levels (INFO, ERROR, WARNING, DEBUG)
- Helper functions to reduce code duplication

### Testing
- Run tests: `./phpvm.sh test`
- Tests create isolated mock environments
- All core functionality is tested including error conditions
- Tests verify cross-platform compatibility

### Debugging
- Enable debug mode: `DEBUG=true phpvm <command>`
- Debug logs provide detailed execution tracing
- Test mode can be enabled with `PHPVM_TEST_MODE=true`

## Common Development Tasks

### Adding New Commands
1. Add command handler in the `main()` function case statement
2. Implement the command function following naming convention `command_name()`
3. Add help text in `print_help()`
4. Add tests in the `run_tests()` function

### Supporting New Package Managers
1. Add detection logic in `detect_system()`
2. Add installation logic in `install_php()`
3. Add version switching logic in `use_php_version()`
4. Add version listing logic in `list_installed_versions()`
5. Add uninstall logic in `uninstall_php()`

### Testing Changes
```bash
# Run all tests
./phpvm.sh test

# Enable debug mode for troubleshooting
DEBUG=true ./phpvm.sh test

# Test specific functionality manually
DEBUG=true ./phpvm.sh install 8.1
DEBUG=true ./phpvm.sh use 8.1
```

### Release Process
1. Update version number in `PHPVM_VERSION` variable
2. Update CHANGELOG.md with new features/fixes
3. Test across different platforms
4. Ensure all tests pass
5. Update README.md if needed

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
├── phpvm.sh          # Core functionality
└── versions/         # Version metadata directory
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