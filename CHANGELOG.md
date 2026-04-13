# Release Notes

## [Unreleased]

## [v1.11.0](https://github.com/Thavarshan/phpvm/compare/v1.10.0...v1.11.0) - 2026-04-13

### Added

- **`exec` command:** Run a command with a specific PHP version without globally switching. Executes in a subshell to isolate PATH changes from the current shell. Usage: `phpvm exec <version> <command> [args...]`.
- **`run` command:** Sugar for `phpvm exec <version> php <script>`. Usage: `phpvm run <version> [script] [args...]`.
- **`ls-remote` command:** List available PHP versions from system package manager repositories (Homebrew, apt, dnf, yum, pacman). Supports optional pattern filtering (e.g., `phpvm ls-remote 8.2`).
- **`resolve` command:** Resolve a version descriptor, alias, or keyword to a locally installed version number. Usage: `phpvm resolve <version|alias|keyword>`.
- **`unload` command:** Remove phpvm from the current shell session — deactivates, removes cd hooks, unsets all phpvm functions and variables. Only works when sourced (matches nvm behaviour).
- **`cache clear` command:** Clear the phpvm cache directory. Replaces the previous stub.
- **`--no-use` flag on source:** `source phpvm.sh --no-use` loads functions without auto-switching or registering the cd hook. Useful for lazy-loading setups.
- **Bash tab completion:** New `completions/phpvm.bash` file with context-aware completions for commands, installed versions, and alias names. Auto-sourced when phpvm is loaded.
- **Auto-set `default` alias on first install:** When no `default` alias exists, the first `phpvm install` automatically sets it (matches nvm behaviour).
- **`PHPVM_BIN` export:** After every version switch, `PHPVM_BIN` is exported with the active PHP binary directory. Unset on deactivate.
- **XDG_CONFIG_HOME fallback:** `PHPVM_DIR` now respects `$XDG_CONFIG_HOME/phpvm` when `XDG_CONFIG_HOME` is set and `PHPVM_DIR` is not.

### Fixed

- **`hash -r` after version switch:** Added `command hash -r` to `switch_to_version_php()`, `switch_to_system_php()`, and `phpvm_deactivate()` to invalidate the bash command hash table. Prevents stale binary resolution after switching versions.
- **`phpvm_current` uses `printf` instead of `echo`:** Consistent with project conventions; avoids potential `-n`/`-e` misinterpretation.
- **Auto-default alias works in test mode:** The auto-default alias logic now fires for both real and mock installations.

### Changed

- **`list` output formatting:** Active version is marked with a `->` arrow prefix and green colouring. Versions matching the `default` alias show a `(default)` annotation.
- **Help text updated:** Removed "Planned Features" section; all commands now shown as implemented with examples.

### Internal

- **Version bump:** Updated to v1.11.0.
- **New tests:** 30 BATS tests covering exec, run, ls-remote, resolve, cache clear, list formatting, auto-default alias, and help text. Replaced 5 obsolete stub tests.
- **All tests passing:** 78 BATS tests pass.

## [v1.10.0](https://github.com/Thavarshan/phpvm/compare/v1.9.4...v1.10.0) - 2026-03-28

### Added

- **`.phpvmrc` auto-read for `use` (no args):** `phpvm use` without a version argument now reads `.phpvmrc` from the current or parent directories. Falls back to the default alias if no `.phpvmrc` is found, then errors if neither exists.
- **`.phpvmrc` auto-read for `install` (no args):** `phpvm install` without a version argument now reads `.phpvmrc` to determine which version to install.
- **`.phpvmrc` awareness for `exec` and `run` (no args):** The `exec` and `run` stubs now detect and report the `.phpvmrc` version when invoked without arguments.
- **`phpvm_read_phpvmrc_version()` helper:** Shared function that finds, reads, resolves aliases, and validates `.phpvmrc` in a single call.
- **`phpvm_cd_hook()` for automatic directory-based switching:** When phpvm is sourced, a cd hook is registered via `PROMPT_COMMAND` (bash) or `chpwd_functions` (zsh) that automatically switches PHP versions when entering a directory with a `.phpvmrc`. Gated behind `PHPVM_AUTO_USE=true` (the default). Skips switching if already on the correct version.

### Changed

- **`use` no-arg priority:** `.phpvmrc` now takes precedence over the default alias when running `phpvm use` without arguments.
- **Error messages for no-arg `use`/`install`:** Updated to reflect the new `.phpvmrc` fallback behaviour.

### Internal

- **Version bump:** Updated to v1.10.0.
- **New tests:** 5 new BATS tests for `.phpvmrc` auto-read behaviour (use reads .phpvmrc, use prefers .phpvmrc over default, install reads .phpvmrc, error when no .phpvmrc or default, error when no .phpvmrc for install).
- **Updated error-handling tests:** Adjusted existing no-arg error tests to match new messages.
- **All tests passing:** 56 BATS tests pass.

## [v1.9.4](https://github.com/Thavarshan/phpvm/compare/v1.9.3...v1.9.4) - 2026-03-15

### Fixed

- **Fixed `README.MD` → `README.md` casing in `release.yml`:** The release workflow referenced `README.MD` but the file is `README.md`, causing CI failures on case-sensitive Linux filesystems.
- **Fixed `README.MD` → `README.md` casing in `CLAUDE.md` file structure diagram.**

### Internal

- **Version bump:** Updated to v1.9.4.

## [v1.9.3](https://github.com/Thavarshan/phpvm/compare/v1.9.2...v1.9.3) - 2026-03-15

### Fixed

- **Fixed ShellCheck SC2086 in `find_phpvmrc`:** Double-quoted `$depth` and `$max_depth` in arithmetic comparison to prevent globbing and word splitting.

### Internal

- **Version bump:** Updated to v1.9.3.

## [v1.9.2](https://github.com/Thavarshan/phpvm/compare/v1.9.1...v1.9.2) - 2026-03-15

### Changed

- **Namespaced global OS variables:** Renamed `OS_TYPE`, `OS_ARCH`, `MACOS_VERSION`, `MACOS_MAJOR`, `MACOS_MINOR`, `IS_WSL`, `WSL_VERSION`, `LINUX_DISTRO`, and `LINUX_VERSION` to `PHPVM_`-prefixed equivalents (`PHPVM_OS_TYPE`, etc.) to prevent namespace pollution when the script is sourced into user shells.
- **Made `.phpvmrc` search depth configurable:** `find_phpvmrc` now uses `PHPVM_PHPVMRC_MAX_DEPTH` environment variable (default: 25) instead of a hardcoded value.
- **Replaced `echo` with `printf` in version validation:** `is_valid_version_format()` and `phpvm_normalize_version()` now use `printf '%s\n'` to avoid potential misinterpretation of version strings starting with `-e` or `-n`.
- **Inlined nested functions in `suggest_repository_setup`:** Removed `suggest_repository_heading()` and `suggest_repository_footer()` inner function definitions that were re-created on every call.
- **Fixed word-splitting in `brew_unlink_all_php`:** Replaced `for ... in $(echo | grep)` pattern with a safe `while IFS= read -r` loop.

### Removed

- **Removed unused `PHPVM_CACHE_UPDATE_ALTERNATIVES` variable.**

### Internal

- **Version bump:** Updated to v1.9.2.
- **All tests passing:** 51 BATS tests pass.

## [v1.9.1](https://github.com/Thavarshan/phpvm/compare/v1.9.0...v1.9.1) - 2026-03-15

### Fixed

- **Fixed `phpvm_debug` returning non-zero in non-debug mode:** Changed from `[ test ] && cmd` pattern (which returns exit code 1 when DEBUG is off) to `if/then/fi`, preventing silent failures in `set -e` contexts or when used as last statement before `return $?`.
- **Fixed `phpvm_with_lock` lock leak on interruption:** Moved `phpvm_unlock` before trap restoration so the lock is released while cleanup traps are still active, eliminating the window where an interrupt could leak the lock.
- **Fixed `get_php_binary_path` stdout side-effect on Linux:** Captured `linux_find_php_binary` output into a variable before echoing, preventing potential double output when the function's stdout mixed with the fallback path.

### Changed

- **Eliminated double initialization:** Removed redundant `phpvm_init_if_needed` calls from `install_php`, `use_php_version`, `phpvm_current`, `phpvm_which`, `list_installed_versions`, `auto_switch_php_version`, and `uninstall_php`. Initialization is now handled centrally by `main()` (via `phpvm_init_or_die`) and the sourced-path entry point, avoiding duplicate `detect_system()` calls (notably the expensive `brew --prefix`).
- **Moved `package_name` computation in `install_php`:** The `get_php_package_name` call was computed but unused by most package manager branches. It is now only computed in the `pacman` case arm that actually needs it.

### Internal

- **Version bump:** Updated to v1.9.1.
- **All tests passing:** 51 BATS tests pass.

## [v1.9.0](https://github.com/Thavarshan/phpvm/compare/v1.8.0...v1.9.0) - 2026-01-30

### Fixed

- **Fixed error propagation in version resolution:** Commands like `phpvm use latest` and `phpvm install latest` now correctly propagate failures from `phpvm_resolve_version` instead of silently swallowing errors.
- **Fixed state consistency in `switch_to_system_php`:** State file (`active_version=system`) is now only written AFTER the switch operation succeeds, preventing state lies when brew link operations fail.
- **Fixed apt install/uninstall symmetry:** Uninstall now removes `php${version}-cli`, `php${version}-common`, and `php${version}-fpm` packages symmetrically with what install creates.
- **Fixed alias directory reliability:** Alias directory creation is now required (not best-effort). If `$PHPVM_DIR/alias` cannot be created, phpvm fails with a clear error message.
- **Fixed symlink robustness:** `update_current_symlink` now uses `command -v php` to resolve the actual binary path, ensuring the symlink points to what the shell would execute.
- **Fixed path traversal vulnerability in alias resolution:** `phpvm_resolve_version` now validates alias names before file access, preventing path traversal attacks like `../../../etc/passwd`.
- **Fixed path traversal vulnerability in alias commands:** `phpvm_alias` now validates alias names BEFORE any file path operations.
- **Fixed trap restoration in sourced shells:** `phpvm_with_lock` now explicitly clears traps with `trap - SIGNAL` when user had no existing trap, preventing phpvm's cleanup traps from being permanently installed in the user's shell session.
- **Fixed init ordering for help/version commands:** Moved command parsing before `phpvm_init_or_die` so `phpvm help` and `phpvm version` work without requiring package manager detection or system initialization.
- **Fixed Linux version listing accuracy:** Unified all Linux package managers (apt/dnf/yum/pacman) to use `phpvm_linux_installed_versions` which scans actual binaries, eliminating inaccurate package name listings like `8.2-cli` or `8.2-fpm`.
- **Fixed system PHP symlink consistency:** System switching now calls `update_current_symlink` to maintain consistent `$PHPVM_DIR/current` symlink behavior across all switching modes.
- **Fixed alias security vulnerability:** Reordered validation in `phpvm_alias` to validate version format before using it in file path checks, preventing potential path traversal attacks with malicious alias targets.
- **Fixed yum installation strategy:** Implemented proper Remi repository detection and naming conventions (`php82-php-cli` format), replacing incorrect `yum install php8.2` approach that would always fail.
- **Fixed lock PID staleness:** Added explicit `lock_pid=""` reset at top of each `phpvm_lock` loop iteration to prevent stale PID values in error messages.
- **Fixed unversioned PHP formula detection:** Homebrew's unversioned `php` formula is now correctly identified before any unlinking operations, preventing false version matches from system PHP.
- **Fixed `phpvm which` for unversioned formulas:** Correctly returns path to unversioned PHP installed as `php` formula.
- **Fixed apt package search:** `pkg_search_php()` now explicitly checks for `Candidate: (none)` to avoid false positives from `apt-cache policy`.
- **Fixed `echo` usage in input validation:** Replaced `echo "$var" | grep` with `printf '%s\n' "$var" | grep` throughout to prevent interpretation of strings like `-n`, `-e`, backslash escapes.
- **Fixed `phpvm_which()` failure propagation:** Now properly propagates failures from `phpvm_current` using `|| return $?`.
- **Fixed shellcheck SC2221/SC2222 warnings:** Simplified `phpvm_is_sourced()` case pattern to avoid overlapping matches.

### Changed

- **Introduced `command_exists()` helper:** Replaced 40+ instances of `command -v X > /dev/null 2>&1` with single reusable function for cleaner command availability checks.
- **Introduced `ensure_phpvm_dirs()` function:** Consolidated repeated `mkdir -p $PHPVM_DIR/X` patterns into centralized directory creation function.
- **Introduced `brew_link_php_unversioned()` function:** Extracted duplicate `brew link php --force --overwrite` logic with error handling into single reusable function.
- **Introduced `is_valid_version_format()` function:** Consolidated duplicate version regex validation pattern into single validation helper.
- **Added `brew_php_major_minor()` helper:** Reads version directly from `$HOMEBREW_PREFIX/opt/php/bin/php` instead of PATH-based `php -r`, eliminating conflicts with system PHP.
- **Reordered version switching flow:** Now resolves target formula, then unlinks all PHP, then links resolved formula, preventing "version check breaks after unlink" bugs.
- **Improved Linux binary scanning:** Broadened skip patterns to prevent accidentally executing PHP helper binaries (`*fpm*`, `*cgi*`, `*dbg*`, `*ize*`, `*config*`).
- **Ubuntu/Debian apt packages:** Changed from non-existent `php8.2` to actual `php8.2-cli` format used by ondrej/sury PPA.
- **Fedora/RHEL dnf packages:** Implemented correct module stream approach instead of fictional versioned packages.
- **Brew availability check:** Changed from fragile `brew search | grep` to stable `brew info <formula>` API.
- **Trap preservation in `phpvm_with_lock()`:** Now saves and restores user's existing trap handlers instead of clobbering them.
- **Stale lock detection and auto-cleanup:** Lock mechanism now checks if lock holder PID is still running and automatically removes stale locks.

### Added

- **Interactive shell guard:** Auto-switch from `.phpvmrc` now only runs in interactive shells using `case $- in *i*)` pattern.
- **Test mode package manager bypass:** Test mode now sets sandbox defaults without requiring actual brew/apt/dnf.

### Internal

- **Bash-only support documented:** Added explicit notice that script requires bash (uses bashisms).
- **Intentional symlink behavior clarified:** Added comment explaining `update_current_symlink()` links to resolved `php` binary by design.
- **Dnf module stream workflow:** Added inline documentation about RHEL/Fedora module stream management.
- **Version bump:** Updated to v1.9.0.
- **All tests passing:** 51 BATS tests pass (added 4 security tests for path traversal protection).

## [v1.8.0](https://github.com/Thavarshan/phpvm/compare/v1.7.0...v1.8.0) - 2026-01-12

### Added

- **Alias management commands:** Added `phpvm alias` and `phpvm unalias` for version alias creation, listing, and removal.
- **Alias pattern filtering:** `phpvm alias <pattern>` now filters aliases by name.
- **Alias resolution support:** Aliases now resolve in `phpvm install`, `phpvm use`, and `phpvm which`.
- **Alias visibility:** `phpvm list` now shows configured aliases.
- **Alias resolution in `.phpvmrc`:** `phpvm auto` now resolves aliases defined in `.phpvmrc`.
- **Latest/stable keywords:** `latest` and `stable` now resolve to the latest installed PHP version.
- **Quality assurance tooling:** Added ShellCheck and shfmt configuration and a comprehensive QA Makefile.
- **BATS test suite:** Added comprehensive BATS tests for core functionality and new alias behavior.
- **CI quality workflow:** Added a quality workflow for linting, formatting, and tests.

### Changed

- **Help output:** Promoted alias commands to the primary usage section.

### Removed

- **Built-in test command:** Removed `phpvm test` command in favor of BATS test suite only.

### Internal

- **Alias helper utilities:** Added alias listing helper and alias resolution logic.
- **Test coverage:** Extended BATS test suite to cover alias functionality and all core features.

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
