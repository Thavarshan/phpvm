# NVM Feature Gaps Analysis for phpvm

**Date:** 2026-01-04  
**Analysis Version:** 1.0  
**phpvm Version Analyzed:** 1.7.0  
**nvm Version Reference:** Latest (4662 lines)

## Executive Summary

This document provides a comprehensive analysis of features present in **nvm (Node Version Manager)** that are currently missing from **phpvm (PHP Version Manager)**. The goal is to achieve functional parity between the two tools, making phpvm as feature-complete as nvm.

## Methodology

1. Downloaded and analyzed nvm.sh from the official nvm-sh/nvm repository
2. Reviewed phpvm.sh source code (2261 lines)
3. Compared command structures, flags, and capabilities
4. Categorized features by implementation priority
5. Identified phpvm-specific advantages

## Current Feature Comparison

### Commands Present in Both Tools

| Feature | NVM Command | PHPVM Command | Status |
|---------|-------------|---------------|--------|
| Install version | `nvm install <version>` | `phpvm install <version>` | ✅ |
| Switch version | `nvm use <version>` | `phpvm use <version>` | ✅ |
| Uninstall version | `nvm uninstall <version>` | `phpvm uninstall <version>` | ✅ |
| Show current version | `nvm current` | `phpvm current` | ✅ |
| Show binary path | `nvm which` | `phpvm which` | ✅ |
| Deactivate | `nvm deactivate` | `phpvm deactivate` | ✅ |
| List installed | `nvm ls` | `phpvm list/ls` | ✅ |
| Help | N/A (built-in) | `phpvm help` | ✅ |
| Version info | `nvm --version` | `phpvm version` | ✅ |

### Commands Missing from PHPVM

| Priority | NVM Command | Description | Implementation Complexity |
|----------|-------------|-------------|---------------------------|
| **HIGH** | `nvm alias <name> <version>` | Create version aliases | Medium |
| **HIGH** | `nvm unalias <name>` | Remove aliases | Low |
| **HIGH** | `nvm alias [pattern]` | List aliases | Low |
| **HIGH** | `nvm ls-remote` | List available versions | High |
| **HIGH** | `nvm ls-remote <pattern>` | Filter remote versions | High |
| **HIGH** | `nvm exec <version> <command>` | Execute command with version | Medium |
| **HIGH** | `nvm run <version> [args]` | Run script with version | Medium |
| **HIGH** | `nvm cache dir` | Show cache directory | Low |
| **HIGH** | `nvm cache clear` | Clear cache | Low |
| **MEDIUM** | `nvm version <version>` | Resolve version locally | Medium |
| **MEDIUM** | `nvm version-remote <version>` | Resolve version remotely | High |
| **MEDIUM** | `nvm reinstall-packages <version>` | Migrate packages | High |
| **MEDIUM** | `nvm unload` | Unload from shell | Low |
| **MEDIUM** | `nvm debug` | Debug information | Low |
| **LOW** | `nvm set-colors` | Customize colors | Low |
| **LOW** | `nvm install-latest-npm` | Upgrade npm equivalent | N/A for PHP |

## Detailed Feature Analysis

### 1. Alias Management System (HIGH PRIORITY)

**Current State:** phpvm has no alias system.

**NVM Implementation:**
- Stores aliases in `$NVM_DIR/alias/` directory
- Each alias is a file containing the target version
- Special aliases: `default`, `node`, `iojs`, `stable`, `unstable`
- Commands: `alias`, `unalias`, `alias <name> <version>`

**Proposed PHPVM Implementation:**
```bash
# Directory structure
$PHPVM_DIR/alias/          # Alias storage directory
$PHPVM_DIR/alias/default   # Default PHP version
$PHPVM_DIR/alias/latest    # Latest installed version
$PHPVM_DIR/alias/stable    # Latest stable version

# Commands to implement
phpvm alias [pattern]                  # List all aliases (or matching pattern)
phpvm alias <name> <version>           # Create/update alias
phpvm unalias <name>                   # Remove alias
phpvm use <alias>                      # Use version by alias
phpvm install <version> --default      # Install and set as default

# Examples
phpvm alias default 8.2
phpvm alias production 8.1
phpvm use default
phpvm list --aliases  # Show aliases in list output
```

**Implementation Steps:**
1. Create `$PHPVM_DIR/alias/` directory structure
2. Add `phpvm_alias()` function for creating aliases
3. Add `phpvm_unalias()` function for removing aliases
4. Add `phpvm_list_aliases()` function for listing
5. Add `phpvm_resolve_alias()` function for alias resolution
6. Modify `use_php_version()` to support alias names
7. Modify `list_installed_versions()` to show aliases
8. Add tests for alias functionality

**Files to Create/Modify:**
- Add alias directory initialization in `create_directories()`
- Add alias functions (approx. 200 lines)
- Update `main()` case statement
- Update `print_help()`
- Add tests in `run_tests()`

---

### 2. Remote Version Listing (HIGH PRIORITY)

**Current State:** phpvm cannot list available versions before installation.

**NVM Implementation:**
- Queries nodejs.org API for available versions
- Supports filtering by version pattern
- Shows LTS versions with labels
- Caches results temporarily

**Proposed PHPVM Implementation:**
```bash
# Commands to implement
phpvm ls-remote                        # List all available PHP versions
phpvm ls-remote <pattern>              # Filter versions (e.g., "8", "8.2")
phpvm ls-remote --no-colors            # Disable colored output

# Package manager specific implementations
# Homebrew: Parse `brew search php@` output
# APT: Parse `apt-cache search php` output
# DNF/YUM: Parse `dnf search php` output
# Pacman: Parse `pacman -Ss php` output
```

**Implementation Steps:**
1. Create `phpvm_ls_remote()` function
2. Implement package-manager-specific queries:
   - Homebrew: `brew search '/^php@?[0-9.]*$/'`
   - APT: `apt-cache search '^php[0-9.]*$'`
   - DNF: `dnf search php --showduplicates`
   - YUM: `yum search php --showduplicates`
   - Pacman: `pacman -Ss '^php[0-9.]*$'`
3. Parse and format output consistently
4. Add version filtering by pattern
5. Add caching mechanism (optional)
6. Handle network/repository errors gracefully
7. Add color support for output

**Implementation Challenges:**
- Different package managers have different output formats
- Some package managers require sudo for cache updates
- Network connectivity issues
- Repository availability varies by distribution

**Files to Modify:**
- Add `phpvm_ls_remote()` function (approx. 150 lines)
- Add helper functions for parsing outputs
- Update `main()` case statement
- Update `print_help()`

---

### 3. Command Execution with Version Context (HIGH PRIORITY)

**Current State:** phpvm can only switch versions globally; cannot run commands with specific versions.

**NVM Implementation:**
- `nvm exec <version> <command>`: Executes any command with version in PATH
- `nvm run <version> [script] [args]`: Specifically runs node with version
- Temporarily modifies PATH without affecting shell

**Proposed PHPVM Implementation:**
```bash
# Commands to implement
phpvm exec <version> <command> [args...]    # Execute command with PHP version
phpvm run <version> [script] [args...]      # Run PHP script with version

# Examples
phpvm exec 8.2 composer install
phpvm exec 8.1 php -v
phpvm run 8.0 script.php arg1 arg2
phpvm exec 7.4 vendor/bin/phpunit

# With flags
phpvm exec 8.2 --silent -- composer install
phpvm run 8.1 --save script.php
```

**Implementation Steps:**
1. Create `phpvm_exec()` function
2. Create `phpvm_run()` function (wrapper around exec)
3. Implement temporary PATH modification in subshell
4. Validate version exists before execution
5. Support alias resolution
6. Handle command not found errors
7. Preserve exit codes from executed commands
8. Support --silent flag

**Implementation Details:**
```bash
phpvm_exec() {
    local version="$1"
    shift
    local command="$@"
    
    # Validate version exists
    local php_path=$(phpvm_which "$version")
    [ $? -ne 0 ] && return 1
    
    # Execute in subshell with modified PATH
    (
        export PATH="$(dirname "$php_path"):$PATH"
        exec $command
    )
}

phpvm_run() {
    local version="$1"
    shift
    phpvm_exec "$version" php "$@"
}
```

**Files to Modify:**
- Add `phpvm_exec()` and `phpvm_run()` functions (approx. 100 lines)
- Update `main()` case statement
- Update `print_help()`
- Add tests for exec and run

---

### 4. Cache Management (HIGH PRIORITY)

**Current State:** phpvm relies entirely on package managers; has no cache directory.

**NVM Implementation:**
- `$NVM_DIR/cache/` stores downloaded archives
- `nvm cache dir` shows cache location
- `nvm cache clear` removes cached files
- Reduces re-download time

**Proposed PHPVM Implementation:**
```bash
# Cache directory structure
$PHPVM_DIR/cache/              # Main cache directory
$PHPVM_DIR/cache/archives/     # Downloaded package archives (if applicable)
$PHPVM_DIR/cache/metadata/     # Version metadata cache
$PHPVM_DIR/cache/tmp/          # Temporary files

# Commands to implement
phpvm cache dir                # Show cache directory path
phpvm cache clear              # Clear all cache
phpvm cache clear archives     # Clear only archives
phpvm cache clear metadata     # Clear only metadata
```

**Implementation Steps:**
1. Create cache directory structure
2. Implement `phpvm_cache_dir()` function
3. Implement `phpvm_cache_clear()` function
4. Add metadata caching for ls-remote
5. Add safe deletion with confirmation
6. Add cache size reporting

**Files to Modify:**
- Add cache directory creation in `create_directories()`
- Add `phpvm_cache_dir()` and `phpvm_cache_clear()` (approx. 80 lines)
- Update `main()` case statement
- Update `print_help()`

---

### 5. Enhanced Install Options (MEDIUM PRIORITY)

**Current State:** `phpvm install` accepts only version number.

**NVM Implementation:**
- `--alias=<name>`: Set alias after install
- `--default`: Set as default after install
- `--save`: Write to .nvmrc after install
- `--no-progress`: Disable progress bars
- `--lts`, `--lts=<name>`: Install LTS versions

**Proposed PHPVM Implementation:**
```bash
# Enhanced install command
phpvm install <version> [flags]

# Flags to implement
--alias=<name>     # Set alias after installation
--default          # Set as default version
--save             # Write to .phpvmrc after installation
--silent           # Suppress output
--no-confirm       # Skip confirmations

# Examples
phpvm install 8.2 --default --save
phpvm install 8.1 --alias=production
phpvm install 7.4 --silent
```

**Implementation Steps:**
1. Add flag parsing in `install_php()`
2. Add post-install alias setting
3. Add post-install .phpvmrc writing
4. Add confirmation prompts
5. Add silent mode support

---

### 6. Enhanced Use Options (MEDIUM PRIORITY)

**Current State:** `phpvm use` accepts only version number.

**NVM Implementation:**
- `--silent`: Suppress output
- `--save`: Write to .nvmrc
- `--lts`, `--lts=<name>`: Use LTS versions

**Proposed PHPVM Implementation:**
```bash
# Enhanced use command
phpvm use <version> [flags]

# Flags to implement
--silent           # Suppress output
--save             # Write to .phpvmrc in current directory

# Examples
phpvm use 8.2 --save
phpvm use default --silent
phpvm use production --save
```

---

### 7. Version Resolution (MEDIUM PRIORITY)

**Current State:** phpvm requires exact version numbers.

**NVM Implementation:**
- `nvm version <version>`: Resolve locally
- `nvm version-remote <version>`: Resolve remotely
- Supports patterns like "8", "8.x", "lts/*"

**Proposed PHPVM Implementation:**
```bash
# Commands to implement
phpvm version <pattern>         # Resolve pattern to installed version
phpvm version-remote <pattern>  # Resolve pattern to remote version

# Pattern support
phpvm version 8              # Returns latest 8.x.x installed
phpvm version 8.2            # Returns latest 8.2.x installed
phpvm version latest         # Returns latest installed version
phpvm version stable         # Returns latest stable version

# Examples
$ phpvm version 8
8.3.1
$ phpvm version-remote 8.2
8.2.15
```

---

### 8. Package/Extension Migration (MEDIUM PRIORITY)

**Current State:** No extension migration support.

**NVM Implementation:**
- `nvm reinstall-packages <version>`: Copies global npm packages

**Proposed PHPVM Implementation:**
```bash
# Command to implement
phpvm reinstall-packages <source-version>   # Migrate extensions to current version
phpvm reinstall-packages <src> <dest>       # Migrate between specific versions

# Example
phpvm use 8.2
phpvm reinstall-packages 8.1  # Copy extensions from 8.1 to 8.2
```

**Implementation Challenges:**
- PHP extensions are compiled per version
- Package manager differences (pecl vs apt-get)
- Extension compatibility varies by PHP version
- May require recompilation

**Possible Approach:**
1. List extensions from source version: `php -m`
2. Filter to installed extensions (exclude bundled)
3. Attempt to install each in target version
4. Report success/failure for each extension

---

### 9. Unload Command (MEDIUM PRIORITY)

**Current State:** phpvm has `deactivate` but not full unload.

**NVM Implementation:**
- `nvm unload`: Removes all nvm functions from shell
- More complete than deactivate

**Proposed PHPVM Implementation:**
```bash
# Command to implement
phpvm unload                   # Completely unload phpvm from shell

# What it should do:
1. Remove all phpvm functions from shell
2. Restore original PATH
3. Unset all PHPVM_* environment variables
4. Remove phpvm command from shell
```

---

### 10. Debug Command (MEDIUM PRIORITY)

**Current State:** phpvm has `info` command with basic information.

**NVM Implementation:**
- Shows detailed debugging information
- Includes versions, paths, shell info, environment variables

**Proposed PHPVM Implementation:**
```bash
# Enhanced debug command
phpvm debug                    # Comprehensive debug output

# Should include:
- phpvm version
- phpvm directory
- Active PHP version
- All installed versions
- Shell information ($SHELL, $SHLVL)
- OS information
- Package manager information
- PATH contents
- All PHPVM_* environment variables
- Alias list
- .phpvmrc location and content
- Cache information
```

---

### 11. Smart Version Pattern Matching (LOW PRIORITY)

**Current State:** Requires exact version like "8.1" or "8.2.1".

**Proposed Enhancement:**
```bash
# Smart matching
phpvm install 8              # Install latest 8.x
phpvm use 8.2                # Use latest 8.2.x
phpvm use latest             # Use latest installed
phpvm install stable         # Install latest stable
```

---

### 12. Color Customization (LOW PRIORITY)

**Current State:** phpvm has fixed colors.

**NVM Implementation:**
- `nvm set-colors <codes>`: Customize output colors
- Format: "yMeBg" (yellow, Magenta, etc.)

**Proposed PHPVM Implementation:**
```bash
# Command to implement
phpvm set-colors <color-codes>

# Example
phpvm set-colors cgYmW  # cyan, green, Yellow, magenta, White
```

---

## Implementation Roadmap

### Phase 1: Core Features (Weeks 1-3)
1. ✅ Analysis and documentation (Week 1)
2. Alias management system (Week 2)
3. Cache management (Week 2)
4. Command execution (exec, run) (Week 3)

### Phase 2: Remote & Resolution (Weeks 4-6)
5. Remote version listing (ls-remote) (Week 4-5)
6. Version resolution (version, version-remote) (Week 6)

### Phase 3: Enhanced Options (Weeks 7-8)
7. Install flags (--alias, --default, --save) (Week 7)
8. Use flags (--silent, --save) (Week 7)
9. Silent mode support across commands (Week 8)
10. Unload command (Week 8)

### Phase 4: Advanced Features (Weeks 9-10)
11. Package/extension migration (Week 9)
12. Debug command enhancement (Week 9)
13. Smart version pattern matching (Week 10)
14. Color customization (Week 10)

### Phase 5: Testing & Documentation (Week 11-12)
15. Comprehensive testing for all new features
16. Update documentation
17. Update examples and README
18. Performance optimization
19. Security review

## Testing Strategy

### Unit Tests
- Test each new function independently
- Mock system calls where appropriate
- Test error conditions
- Test edge cases

### Integration Tests
- Test command combinations
- Test across different package managers
- Test on different operating systems
- Test with different shells

### User Acceptance Tests
- Test common workflows
- Test migration from old versions
- Performance benchmarks
- User feedback collection

## Backward Compatibility

All new features must maintain backward compatibility:
- Existing commands must work unchanged
- New flags must be optional
- Default behavior must remain consistent
- Old .phpvmrc files must still work

## Documentation Requirements

For each new feature:
- Update help text in `print_help()`
- Update README.md with examples
- Add to CHANGELOG.md
- Update CLAUDE.md if needed
- Add inline code comments
- Create usage examples

## Success Criteria

phpvm will be considered feature-complete relative to nvm when:
1. All HIGH priority features are implemented and tested
2. At least 75% of MEDIUM priority features are implemented
3. Core functionality matches nvm behavior
4. All tests pass on supported platforms
5. Documentation is complete and accurate
6. Performance is acceptable (no significant slowdown)
7. User feedback is positive

## Notes and Caveats

### PHP vs Node.js Differences
- **No LTS concept**: PHP doesn't have official LTS versions like Node.js
- **Package managers**: PHP relies on system package managers (apt, brew, etc.) while nvm downloads binaries
- **Extensions**: PHP has compiled extensions (C modules) vs npm packages (JavaScript)
- **Compilation**: nvm can compile from source; phpvm uses pre-built packages

### Package Manager Limitations
- **apt/yum/dnf**: Version availability depends on repository configuration
- **Homebrew**: Limited to versions in Homebrew formulae
- **pacman**: Arch Linux typically has only current version
- Some features (like binary caching) may not apply

### Implementation Considerations
- Maintain cross-platform compatibility (macOS, Linux, WSL)
- Keep script size manageable (currently ~2300 lines)
- Preserve excellent error handling
- Maintain security standards
- Keep installation simple

## Conclusion

This analysis identifies 15+ major features missing from phpvm that exist in nvm. Implementing these features in priority order will bring phpvm to full feature parity with nvm, making it the most comprehensive PHP version manager available.

**Estimated Total Effort:** 10-12 weeks for full implementation
**Lines of Code to Add:** Approximately 1500-2000 lines
**Testing Effort:** 2-3 weeks
**Documentation Effort:** 1 week

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-04  
**Prepared by:** GitHub Copilot Analysis  
**For:** phpvm Project Enhancement
