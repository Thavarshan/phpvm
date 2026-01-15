# Release Notes

## [Unreleased]

### Added

- **Alias management commands:** Added `phpvm alias` and `phpvm unalias` for version alias creation, listing, and removal.
- **Alias resolution support:** Aliases now resolve in `phpvm install`, `phpvm use`, and `phpvm which`.
- **Alias visibility:** `phpvm list` now shows configured aliases.
- **Quality assurance tooling:** Added ShellCheck and shfmt configuration, a QA Makefile, and a `qa.sh` runner script.
- **BATS test suite:** Added comprehensive BATS tests for core functionality and new alias behavior.
- **CI quality workflow:** Added a quality workflow for linting, formatting, and tests.

### Changed

- **Help output:** Promoted alias commands to the primary usage section.

### Internal

- **Alias helper utilities:** Added alias listing helper and alias resolution logic.
- **Test coverage:** Extended built-in test suite to cover alias functionality.

## [v1.7.0](https://github.com/Thavarshan/phpvm/compare/v1.6.0...v1.7.0) - 2025-12-10

### Added

- **New `phpvm current` command:** Display the currently active PHP version. Returns the version string, "system", or "none" depending on state.
- **New `phpvm which [version]` command:** Show the full path to the PHP binary for a given version. Supports all package managers (brew, apt, dnf, yum, pacman).
- **New `phpvm deactivate` command:** Temporarily disable phpvm management and restore the original PATH. Useful for debugging or temporarily using system defaults.
- **New `ls` alias for `list`:** Added `phpvm ls` as an alias for `phpvm list` for convenience.
- **Specific exit codes:** Implemented consistent exit codes across all commands for better scripting support:
  - `0` - Success
  - `1` - General error
  - `2` - Invalid argument or usage error
  - `3` - Version not found (not available)
  - `4` - Version not installed locally
  - `5` - File or permission error
  - `127` - Unknown command
- **Exit code documentation:** Added exit codes section to help output.
- **PATH preservation:** `phpvm use` now stores the original PATH on first activation to enable proper deactivation.

### Changed

- **Enhanced help output:** Updated help text with new commands, examples, and exit code documentation.
- **Improved error handling:** Key functions now return specific exit codes instead of generic error codes.

### Internal

- **Added exit code constants:** Defined `PHPVM_EXIT_*` constants for maintainability.
- **New helper functions:**
  - `phpvm_store_original_path()` - Preserves PATH for deactivate functionality
  - `phpvm_current()` - Returns current PHP version
  - `phpvm_which()` - Resolves PHP binary paths
  - `phpvm_deactivate()` - Disables phpvm temporarily
- **Expanded test suite:** Added tests for `phpvm_current`, `phpvm_which`, and `phpvm_deactivate` (now 14 tests total).

## [v1.6.0](https://github.com/Thavarshan/phpvm/compare/v1.5.0...v1.6.0) - 2025-09-15

### Added

- **Smart repository detection:** Added intelligent detection of missing PHP repositories on RHEL/Fedora systems with automatic suggestions for enabling Remi's repository.
- **Enhanced error messaging:** Implemented comprehensive error handling with actionable solutions when PHP packages are not found in default repositories.
- **Repository setup guidance:** Added detailed step-by-step instructions for enabling EPEL and Remi repositories on Fedora, RHEL, Rocky Linux, AlmaLinux, and CentOS systems.

### Changed

- **Consolidated GitHub Actions workflows:** Streamlined CI/CD from 7 separate workflow files down to 3 focused workflows, eliminating duplication while maintaining comprehensive test coverage.
- **Enhanced multi-distribution testing:** Expanded automated testing to cover 13 Linux distributions (Ubuntu, Debian, Fedora, Rocky Linux, AlmaLinux, Arch Linux, Alpine Linux) with 4 different package managers (apt, dnf, pacman, apk).
- **Improved cross-platform compatibility:** Fixed package installation issues for RHEL-family distributions (Rocky/Alma Linux) and Alpine Linux in CI environments.
- **Streamlined workflow organization:** Reorganized tests into logical categories: syntax analysis, core functionality, PHP usage, multi-distribution compatibility, performance testing, and end-to-end integration.
- **Intelligent PHP installation:** Enhanced PHP installation process to check package availability before attempting installation and provide specific guidance when packages are missing.

### Fixed

- **Fixed coreutils package conflicts:** Resolved dnf installation conflicts in Rocky Linux and AlmaLinux by adding `--allowerasing` flag to handle coreutils-single vs coreutils package conflicts.
- **Fixed Alpine Linux container compatibility:** Resolved bash availability issues in Alpine Linux containers by dynamically selecting appropriate shell (sh vs bash) for initial container startup.
- **Fixed virtual package installation:** Resolved apt installation failure for `awk` virtual package by explicitly installing `gawk` package instead.

### Removed

- **Removed emoji characters:** Cleaned up all emoji usage from codebase for better terminal compatibility and professional appearance.
- **Removed redundant workflow files:** Eliminated duplicate testing workflows (use.yml, comprehensive-test.yml, performance-test.yml, integration-test.yml) by consolidating functionality into main test.yml.

## [v1.5.0](https://github.com/Thavarshan/phpvm/compare/v1.4.1...v1.5.0) - 2025-08-15

### Added

- **Added comprehensive version command support:** Implemented `phpvm version`, `phpvm --version`, and `phpvm -v` commands with detailed information including author, repository link, and usage hints.
- **Added intelligent system PHP detection:** Enhanced system PHP switching to properly detect and use Homebrew's main `php` formula as the system default on modern macOS.
- **Added post-install validation:** Added checks for PHP binary availability after installation with helpful warnings if binaries are missing.

### Changed

- **Improved shebang for WSL compatibility:** Changed from `#!/bin/sh` to `#!/bin/bash` for better compatibility with WSL and Linux distributions.
- **Enhanced Homebrew link failure detection:** Improved detection and handling of "already linked" warnings from Homebrew with proper error reporting and user guidance.
- **Updated system PHP messaging:** Changed misleading "macOS built-in PHP" references to accurate "Homebrew default PHP" messaging that reflects modern macOS reality.
- **Improved PHP version detection on Linux:** Enhanced `dpkg-query` usage for more reliable PHP version listing on Debian/Ubuntu systems.
- **Enhanced unlinking logic:** Replaced problematic wildcard unlinking with proper iteration through installed PHP formulas.

### Fixed

- **Fixed false success reporting on Homebrew link failures:** Script now properly detects when `brew link` fails due to "already linked" status and returns error instead of false success.
- **Fixed WSL script execution issues:** Resolved problem where phpvm would exit silently without output on WSL/Ubuntu systems due to shell compatibility issues.
- **Fixed system PHP switching on macOS:** System switching now correctly links to Homebrew's main PHP installation instead of looking for non-existent `/usr/bin/php`.
- **Fixed PHP version listing on Linux:** Improved reliability of `phpvm list` command showing installed PHP versions on apt-based systems.
- **Fixed error handling for missing PHP binaries:** Added proper error handling when PHP commands are not available, preventing script crashes.

## [v1.4.1](https://github.com/Thavarshan/phpvm/compare/v1.4.0...v1.4.1) - 2025-07-13

### Fixed

- **Fixed script execution detection failing on macOS/zsh:** Resolved critical issue where `phpvm` commands (`help`, `list`, `use`, etc.) would run silently without any output on macOS systems using zsh shell, making the tool appear completely non-functional.
- **Fixed execution detection logic in `phpvm_should_execute_main()`:** The original detection method incorrectly identified script execution as "sourcing" on macOS/zsh environments, causing the script to only load functions without executing the main command handler.
- **Enhanced shell compatibility with argument-based detection:** Added more reliable execution detection by checking for script arguments as the primary indicator, with the original `return` test maintained as fallback for POSIX shell compatibility.
- **Improved detection layer ordering:** Reorganized execution detection logic to prioritize more reliable methods (argument presence) over shell-specific tests that behave inconsistently across different environments.

## [v1.4.0](https://github.com/Thavarshan/phpvm/compare/v1.3.0...v1.4.0) - 2025-06-23

### Added

- **Added comprehensive uninstall functionality:** Implemented `phpvm uninstall` command to completely remove phpvm from the system, including cleaning up shell profile modifications and removing all installed PHP versions.
- **Added VSCode development settings:** Included VSCode workspace configuration and settings for improved development experience and consistency across contributors.
- **Added enhanced POSIX compliance:** Improved shell script compatibility across different Unix-like systems and shell environments for better portability.

### Changed

- **Enhanced shell profile management:** Improved detection and modification of shell configuration files (.bashrc, .zshrc, .profile) for more reliable setup and removal processes.
- **Improved cross-platform compatibility:** Enhanced script behavior to work more consistently across different operating systems and shell environments.
- **Strengthened code quality:** Multiple refinements to shell scripting practices for better POSIX compliance and reduced platform-specific issues.

### Fixed

- **Fixed POSIX compliance issues:** Resolved shell scripting compatibility problems that could cause issues on certain Unix systems or when using different shell interpreters.
- **Fixed installation/uninstallation edge cases:** Improved handling of various system configurations during installation and uninstallation processes.
- **Enhanced error handling during cleanup operations:** Better error reporting and recovery when removing phpvm components from the system.

## [v1.3.0](https://github.com/Thavarshan/phpvm/compare/v1.2.0...v1.3.0) - 2025-05-11

## Added

- Added `system` command to easily switch back to system PHP version
- Added timestamps to all log messages for better traceability and debugging
- Added log levels (INFO, ERROR, WARNING, DEBUG) for more structured logging
- Added `run_with_sudo` helper function to centralize sudo usage logic
- Added comprehensive self-tests with `phpvm test` command
- Added test for corrupted `.phpvmrc` file handling
- Added better support for detecting and using latest PHP version from Homebrew
- Added improved error messages with more detailed information
- Added ability to run self-tests with `phpvm test` command
- Added debugging capability via `DEBUG=true` environment variable

## Changed

- Changed logging format to include timestamps and log levels
- Changed sudo handling to use a centralized helper function
- Changed path expansion to use `$HOME` instead of tilde notation for better compatibility
- Changed error handling to provide more descriptive and actionable messages
- Changed test framework to be integrated directly into the script
- Changed help message to include information about the `test` command
- Improved bash/zsh shell compatibility with better sourcing logic
- Improved code organization and reduced duplication with helper functions

## Fixed

- Fixed shell crash issue when sourcing in zsh with p10k theme
- Fixed path expansion issues in Ubuntu bashrc configurations
- Fixed missing system PHP switching functionality on macOS
- Fixed detection of latest PHP version on macOS when installed via Homebrew's generic 'php' formula
- Fixed potential sudo permission issues on Linux by using `run_with_sudo` consistently
- Fixed auto-switching edge case with invalid or corrupted `.phpvmrc` files
- Fixed script execution issues when sourced from shell initialization files
- Fixed various edge cases in version detection and switching

## [v1.2.0](https://github.com/Thavarshan/phpvm/compare/v1.1.0...v1.2.0) - 2025-02-15

### Added

- **GitHub Actions CI/CD Integration:** Added workflows for running automated tests and verifying PHPVM functionality on macOS and Linux.
- **Linux Compatibility:** Implemented Homebrew mock support to allow testing on both macOS and Linux environments.
- **Extended Test Suite:** Improved BATS test coverage to handle different system environments and dependencies.

### Changed

- **Improved Homebrew Detection:** The script now properly checks for Homebrew availability and handles missing installations more gracefully.
- **Refactored Test Setup:** The `setup` function in `test_phpvm.bats` now ensures correct sourcing of `phpvm.sh` and mocks Homebrew on Linux.
- **Better Error Messages:** Adjusted error outputs for clarity when Homebrew or PHP versions are unavailable.

### Fixed

- **Fixed Ubuntu Compatibility Issues:** The tests no longer fail due to missing Homebrew; instead, they mock Homebrew behavior on Linux.
- **Resolved Test Failures:** The `install_php`, `use_php_version`, and `auto_switch_php_version` tests now properly execute across different OS platforms.
- **Prevented Test Cleanup Failures:** The `teardown` function now ensures `.phpvmrc` and other temporary files are removed only if they exist.

## [v1.1.0](https://github.com/Thavarshan/phpvm/compare/v1.0.0...v1.1.0) - 2025-02-09

### Added

- Added comprehensive error handling to the main `phpvm` script for robust operations.
- Added checks for command availability (e.g., `curl`) in the installation script.
- Added a suite of unit tests using BATS for automated testing of core functionalities.
- Added clear and informative, color-coded terminal messages for user interactions.

### Changed

- Enhanced the installation script to safely modify user shell profiles and avoid duplicate entries.
- Updated the main `phpvm` script to use strict mode (`set -euo pipefail`) for improved reliability.
- Improved overall error reporting to capture and relay issues during directory creation, downloading, and setting file permissions.

### Fixed

- Fixed various shellcheck warnings such as:
  - SC2034 (unused variables)
  - SC2086 (unquoted variables)
  - SC2155 (variable declaration and assignment in one line)
  - SC2128 (incorrect array handling)
- Fixed potential issues with word splitting and globbing by ensuring proper quoting of variables in command calls.

## [v1.0.0](https://github.com/Thavarshan/phpvm/compare/v0.0.1...v1.0.0) - 2025-02-04

### Added

- Auto-switching PHP versions based on `.phpvmrc`.
- Improved support for macOS Homebrew installations.
- Enhanced installation script for easy setup using `curl` or `wget`.
- More robust error handling and output formatting.
- Extended compatibility with `bash` and `zsh` shells.

### Fixed

- Resolved issues with Homebrew PHP detection on macOS.
- Prevented terminal crashes due to incorrect sourcing in shell startup scripts.
- Improved handling of missing PHP versions.

## [v0.0.1](https://github.com/Thavarshan/phpvm/compare/v0.0.0...v0.0.1) - 2024-10-05

Initial release for public testing and feedback.
