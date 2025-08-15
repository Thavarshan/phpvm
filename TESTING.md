# PHPVM GitHub Actions Testing Suite

## Overview

This document describes the comprehensive GitHub Actions testing suite set up for phpvm to ensure reliable functionality across multiple platforms and environments.

## Workflows Created

### 1. **Comprehensive Test** (`comprehensive-test.yml`)
**Purpose**: Main testing workflow covering all core functionality
**Triggers**: Push to main/development/fix/feature branches, PRs, weekly schedule
**Platforms**: Ubuntu (latest, 20.04), macOS (latest, 12)

**Test Coverage**:
- ✅ Syntax validation and ShellCheck analysis
- ✅ All version commands (`phpvm version`, `phpvm --version`, `phpvm -v`) 
- ✅ Help and list commands
- ✅ Integrated self-tests
- ✅ PHP installation and version switching
- ✅ System PHP switching with improved messaging
- ✅ `.phpvmrc` auto-switching functionality
- ✅ Error handling for invalid commands/versions
- ✅ Cross-platform compatibility (macOS Homebrew + Linux package managers)
- ✅ Shell compatibility testing (bash, zsh)
- ✅ Performance benchmarking and memory usage

### 2. **Edge Cases** (`edge-cases.yml`)
**Purpose**: Test edge cases and cross-platform compatibility issues
**Triggers**: Push to main, PRs, manual dispatch

**Test Coverage**:
- ✅ WSL simulation and bash-specific features
- ✅ Multiple Linux distribution containers (Ubuntu, Debian, CentOS)
- ✅ Package manager detection across different systems
- ✅ Version command consistency verification
- ✅ Enhanced error handling validation
- ✅ Homebrew integration edge cases on macOS
- ✅ `.phpvmrc` edge cases (missing, empty, invalid, whitespace)
- ✅ Self-test robustness across multiple runs
- ✅ Resource usage monitoring

### 3. **Installation Testing** (`installation-test.yml`)
**Purpose**: Verify installation processes and scripts
**Triggers**: Push to main, PRs, manual dispatch, releases

**Test Coverage**:
- ✅ Installation script syntax validation
- ✅ cURL-based installation testing
- ✅ Installation verification and functionality checks
- ✅ Uninstallation process testing
- ✅ Cross-platform installation compatibility

### 4. **Release Testing** (`release-test.yml`)
**Purpose**: Final verification for releases
**Triggers**: Published releases, pre-releases, manual dispatch

**Test Coverage**:
- ✅ Release version verification
- ✅ All core commands functionality
- ✅ Installation from release tags
- ✅ Performance regression testing
- ✅ Documentation verification (README, commands)
- ✅ Changelog verification

### 5. **Existing Workflows** (Enhanced)
- `test.yml`: Basic integrated self-tests
- `use.yml`: PHP installation and usage workflow

## Key Testing Features

### **v1.5.0 Specific Testing**
- ✅ **New Version Commands**: All three variants (`version`, `--version`, `-v`)
- ✅ **Enhanced Cross-Platform Support**: WSL, Linux distributions
- ✅ **Improved Error Handling**: Homebrew link failures, missing binaries
- ✅ **System PHP Messaging**: Updated "Homebrew default PHP" messaging
- ✅ **Bash Shebang Compatibility**: WSL and Linux shell compatibility
- ✅ **Post-Install Validation**: Binary availability checks

### **Platform Coverage**
- **macOS**: Latest and macOS-12 with Homebrew integration
- **Ubuntu**: Latest and 20.04 LTS versions
- **Linux Containers**: Debian, CentOS for broad compatibility
- **Package Managers**: brew, apt, dnf, yum, pacman detection
- **Shell Environments**: bash, zsh, dash (POSIX) compatibility

### **Test Categories**
1. **Functional Tests**: All commands work as expected
2. **Integration Tests**: Installation, switching, auto-switching
3. **Compatibility Tests**: Cross-platform, shell, distribution
4. **Edge Case Tests**: Error conditions, malformed inputs
5. **Performance Tests**: Speed, memory usage, regression
6. **Installation Tests**: cURL, wget, verification, cleanup

## Workflow Execution

### **Automatic Triggers**
- **Push** to main, development, fix/*, feature/* branches
- **Pull Requests** to main, development
- **Releases** (published, pre-released)
- **Scheduled** (weekly on Sundays at 2 AM UTC)

### **Manual Triggers**
- All workflows support `workflow_dispatch` for manual execution
- Release testing can be triggered with custom version input

## Benefits

### **Quality Assurance**
- ✅ **Multi-Platform Validation**: Ensures phpvm works on all supported systems
- ✅ **Regression Prevention**: Catches issues before they reach users
- ✅ **Edge Case Coverage**: Tests unusual scenarios and error conditions
- ✅ **Performance Monitoring**: Tracks resource usage and execution speed

### **Development Confidence**
- ✅ **Automated Validation**: Every change is thoroughly tested
- ✅ **Cross-Platform Verification**: No platform-specific issues slip through
- ✅ **Release Readiness**: Comprehensive validation before releases
- ✅ **Documentation Sync**: Ensures docs match functionality

### **User Experience**
- ✅ **Reliable Installation**: Installation methods are verified to work
- ✅ **Cross-Platform Consistency**: Same experience across all platforms
- ✅ **Error Handling**: Users get helpful error messages
- ✅ **Performance**: Commands execute efficiently

## Maintenance

### **Workflow Updates**
- Workflows are version-controlled and can be updated with phpvm changes
- New features should add corresponding tests to relevant workflows
- Platform versions should be updated periodically (Ubuntu LTS, macOS versions)

### **Monitoring**
- GitHub Actions dashboard shows workflow status
- Failed workflows require investigation and fixes
- Performance trends can be monitored over time

## Usage

### **For Contributors**
- All PRs automatically trigger comprehensive testing
- Check workflow results before merging
- Add new tests when adding new features

### **For Maintainers**
- Monitor workflow health and update as needed
- Use release workflows for final verification
- Review performance trends and address regressions

### **For Users**
- Badge status in README shows current test status
- Release workflows ensure stable releases
- Installation methods are continuously verified

## Conclusion

This comprehensive testing suite ensures phpvm v1.5.0 and future versions maintain high quality, reliability, and cross-platform compatibility. The automated workflows catch issues early, provide confidence in releases, and ensure a consistent user experience across all supported platforms.

The 823 lines of workflow configuration provide extensive coverage that would be impractical to test manually, making this an essential part of the phpvm development process.
