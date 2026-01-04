# phpvm Feature Parity Checklist

A quick reference checklist of features needed to achieve full functional parity with nvm.

## ✅ Already Implemented (Compatible with NVM)

- [x] `phpvm install <version>` - Install PHP version
- [x] `phpvm use <version>` - Switch to PHP version
- [x] `phpvm uninstall <version>` - Remove PHP version
- [x] `phpvm current` - Display active version
- [x] `phpvm which [version]` - Show path to PHP binary
- [x] `phpvm deactivate` - Disable phpvm temporarily
- [x] `phpvm list` / `phpvm ls` - List installed versions
- [x] `phpvm version` - Show phpvm version
- [x] Auto-switching via `.phpvmrc` file

## 🔴 HIGH PRIORITY - Missing Core Features

### Alias System
- [ ] `phpvm alias [pattern]` - List all aliases (or filter by pattern)
- [ ] `phpvm alias <name> <version>` - Create/update version alias
- [ ] `phpvm unalias <name>` - Remove alias
- [ ] Support `default` alias concept
- [ ] Support using aliases in `use`, `install`, etc.
- [ ] Show aliases in `phpvm list` output

### Remote Version Management
- [ ] `phpvm ls-remote` - List all available PHP versions
- [ ] `phpvm ls-remote <pattern>` - Filter remote versions by pattern
- [ ] `phpvm ls-remote --no-colors` - Disable colored output
- [ ] Package manager integration for version discovery

### Command Execution
- [ ] `phpvm exec <version> <command> [args]` - Execute command with specific PHP version
- [ ] `phpvm run <version> [script] [args]` - Run PHP script with specific version
- [ ] Support for `--silent` flag in exec/run
- [ ] Preserve exit codes from executed commands

### Cache Management
- [ ] `phpvm cache dir` - Display cache directory location
- [ ] `phpvm cache clear` - Clear all cached data
- [ ] Create cache directory structure
- [ ] Implement metadata caching for ls-remote

## 🟡 MEDIUM PRIORITY - Enhanced Usability

### Enhanced Install Command
- [ ] `phpvm install <version> --alias=<name>` - Set alias after install
- [ ] `phpvm install <version> --default` - Set as default after install
- [ ] `phpvm install <version> --save` - Write to .phpvmrc after install
- [ ] `phpvm install <version> --silent` - Silent installation
- [ ] Support for `latest` keyword

### Enhanced Use Command
- [ ] `phpvm use <version> --silent` - Silent version switching
- [ ] `phpvm use <version> --save` - Write to .phpvmrc after switch
- [ ] Support for partial version matching

### Version Resolution
- [ ] `phpvm version <pattern>` - Resolve version pattern locally
- [ ] `phpvm version-remote <pattern>` - Resolve version pattern remotely
- [ ] Support patterns: "8", "8.2", "latest", "stable"
- [ ] Smart version matching (e.g., "8" → "8.3.1")

### Shell Integration
- [ ] `phpvm unload` - Completely unload phpvm from shell
- [ ] Enhanced unload to remove all functions
- [ ] Clear all PHPVM_* environment variables

### Package Migration
- [ ] `phpvm reinstall-packages <source-version>` - Migrate extensions
- [ ] List extensions from source version
- [ ] Attempt installation in target version
- [ ] Report success/failure for each extension

### Debugging
- [ ] `phpvm debug` - Comprehensive debug information
- [ ] Show all PHPVM_* variables
- [ ] Show PATH contents
- [ ] Show alias list
- [ ] Show cache information

## 🟢 LOW PRIORITY - Nice to Have

### Pattern Matching
- [ ] Support partial versions in all commands
- [ ] `phpvm install latest` - Install latest available
- [ ] `phpvm install stable` - Install latest stable
- [ ] `phpvm use 8` - Use latest 8.x installed

### Customization
- [ ] `phpvm set-colors <codes>` - Customize output colors
- [ ] User configuration file support
- [ ] Persistent color preferences

### Silent Mode
- [ ] Global `--silent` flag support
- [ ] Silent mode for all commands
- [ ] Configurable verbosity levels

### Additional Enhancements
- [ ] `phpvm list --no-colors` - Disable colors in list
- [ ] `phpvm list --no-alias` - Hide aliases in list
- [ ] Tab completion for bash/zsh
- [ ] Man page documentation

## 🎯 phpvm Unique Features (Not in NVM)

These features are already in phpvm but not in nvm:

- [x] `phpvm test` - Built-in comprehensive self-tests
- [x] `phpvm info` / `phpvm sysinfo` - System information display
- [x] `phpvm system` - Explicit system version command
- [x] Multi-package-manager support (apt, dnf, yum, pacman, brew)
- [x] Repository setup guidance for RHEL/Fedora
- [x] WSL-specific detection and handling
- [x] Comprehensive error handling with actionable solutions
- [x] Timestamped logging
- [x] Atomic file operations

## Implementation Statistics

### Current Status
- **Features in phpvm:** 13 commands
- **Features in nvm:** 22+ commands
- **Features to add:** 18+ features
- **Feature parity:** ~60%

### Estimated Effort
- **HIGH priority:** 4-5 weeks
- **MEDIUM priority:** 4-5 weeks  
- **LOW priority:** 2-3 weeks
- **Total implementation:** 10-12 weeks
- **Additional code:** ~1500-2000 lines
- **Testing:** 2-3 weeks
- **Documentation:** 1 week

## Quick Reference: Command Mapping

| NVM Command | PHPVM Equivalent | Status |
|-------------|------------------|--------|
| `nvm install <v>` | `phpvm install <v>` | ✅ Done |
| `nvm uninstall <v>` | `phpvm uninstall <v>` | ✅ Done |
| `nvm use <v>` | `phpvm use <v>` | ✅ Done |
| `nvm current` | `phpvm current` | ✅ Done |
| `nvm ls` | `phpvm list/ls` | ✅ Done |
| `nvm ls-remote` | `phpvm ls-remote` | ❌ Missing |
| `nvm which` | `phpvm which` | ✅ Done |
| `nvm alias` | `phpvm alias` | ❌ Missing |
| `nvm unalias` | `phpvm unalias` | ❌ Missing |
| `nvm exec` | `phpvm exec` | ❌ Missing |
| `nvm run` | `phpvm run` | ❌ Missing |
| `nvm deactivate` | `phpvm deactivate` | ✅ Done |
| `nvm unload` | `phpvm unload` | ❌ Missing |
| `nvm version` | `phpvm version` | 🟡 Partial |
| `nvm version-remote` | `phpvm version-remote` | ❌ Missing |
| `nvm cache` | `phpvm cache` | ❌ Missing |
| `nvm reinstall-packages` | `phpvm reinstall-packages` | ❌ Missing |
| `nvm set-colors` | `phpvm set-colors` | ❌ Missing |
| `nvm debug` | `phpvm debug` | 🟡 Partial (info) |
| N/A | `phpvm test` | ✅ Unique |
| N/A | `phpvm system` | ✅ Unique |
| N/A | `phpvm auto` | ✅ Unique |

## Legend

- ✅ **Done** - Feature fully implemented
- 🟡 **Partial** - Feature partially implemented
- ❌ **Missing** - Feature not implemented
- 🔴 **HIGH** - Essential for feature parity
- 🟡 **MEDIUM** - Important for usability
- 🟢 **LOW** - Nice to have

---

**Last Updated:** 2026-01-04  
**Document Version:** 1.0  
**For detailed analysis, see:** [NVM_FEATURE_GAPS.md](./NVM_FEATURE_GAPS.md)
