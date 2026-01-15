# Development Setup Guide for phpvm

This guide will help you set up your development environment for contributing to phpvm.

## Prerequisites

- macOS or Linux
- Git
- Bash 4.0+ (or compatible shell)
- Basic understanding of shell scripting

## Quick Setup

```bash
# Clone the repository
git clone https://github.com/Thavarshan/phpvm.git
cd phpvm

# Install development dependencies
make install

# Install git hooks
make install-hooks

# Run all checks to verify setup
make check
```

## Detailed Setup

### 1. Install Development Tools

#### macOS (Homebrew)

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install development tools
brew install shellcheck shfmt bats-core
```

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y shellcheck bats

# shfmt (manual installation)
wget -O shfmt https://github.com/mvdan/sh/releases/download/v3.12.0/shfmt_v3.12.0_linux_amd64
chmod +x shfmt
sudo mv shfmt /usr/local/bin/
```

#### Fedora/RHEL

```bash
sudo dnf install -y ShellCheck

# Install BATS and shfmt manually (see Ubuntu instructions)
```

### 2. Configure Git Hooks

Install pre-commit hooks to automatically run quality checks:

```bash
make install-hooks
```

This will:
- Check code formatting before each commit
- Run linter (ShellCheck) before each commit
- Prevent commits if checks fail

To bypass hooks (use sparingly):

```bash
git commit --no-verify
```

### 3. Configure Your Editor

#### VS Code

Install recommended extensions:

```bash
code --install-extension timonwong.shellcheck
code --install-extension foxundermoon.shell-format
code --install-extension rogalmic.bash-debug
```

The project includes `.vscode/settings.json` with:
- ShellCheck integration
- Shell script formatting settings
- File associations
- Testing support

#### Vim/Neovim

Add to your `.vimrc` or `init.vim`:

```vim
" Enable syntax checking with ShellCheck
let g:syntastic_sh_checkers = ['shellcheck']
let g:syntastic_sh_shellcheck_args = '-x'

" Set indentation for shell scripts
autocmd FileType sh setlocal shiftwidth=4 tabstop=4 expandtab
```

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Changes

Edit `phpvm.sh` or other files as needed.

### 3. Run Quality Checks

```bash
# Quick check (fast feedback)
make lint

# Format code
make format

# Run tests
make test

# Run all checks
make check
```

### 4. Write Tests

Add tests for new features:

**Built-in tests** - Add to `phpvm.sh` `run_tests()` function:

```bash
test_your_feature() {
    # Test logic here
    return 0
}
```

**BATS tests** - Add to appropriate file in `tests/`:

```bash
@test "your feature works correctly" {
    run your_function arg1 arg2
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected" ]]
}
```

### 5. Commit Changes

```bash
git add .
git commit -m "feat: add new feature"
```

Pre-commit hooks will run automatically.

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub.

## Available Commands

### Quality Assurance

```bash
make help          # Show all available commands
make install       # Install development dependencies
make install-hooks # Install git pre-commit hooks
make lint          # Run ShellCheck linter
make format        # Format code with shfmt
make format-check  # Check formatting (CI mode)
make test          # Run built-in tests
make test-bats     # Run BATS test suite
make test-all      # Run all tests
make check         # Run all quality checks
make clean         # Remove temporary files
make release       # Prepare for release
```

### Direct Script Usage

```bash
# Run quality assurance script
./qa.sh

# Run phpvm tests
bash phpvm.sh test

# Run BATS tests
bats tests/

# Run ShellCheck
shellcheck phpvm.sh install.sh

# Format with shfmt
shfmt -w -i 4 -sr phpvm.sh install.sh
```

## Testing

### Test Structure

```
tests/
├── test_helper.bash    # Setup and helper functions
├── 01_core.bats        # Core functionality
├── 02_features.bats    # Features and placeholders
└── 03_error_handling.bats  # Error handling
```

### Running Tests

```bash
# All tests
make test-all

# Built-in tests only
make test

# BATS tests only
make test-bats

# Specific BATS file
bats tests/01_core.bats

# With verbose output
bats -t tests/
```

### Writing Tests

See [TESTING.md](TESTING.md) and [tests/README.md](tests/README.md) for detailed information.

## Code Style Guidelines

### Shell Script Style

- **Indentation:** 4 spaces (no tabs)
- **Line length:** 120 characters max
- **Function naming:** `snake_case`
- **Variable naming:** `UPPER_CASE` for globals, `lower_case` for locals
- **Comments:** Use `#` for single-line comments
- **Error handling:** Always check return codes

### Example

```bash
# Good function example
phpvm_example_function() {
    local input="$1"
    local result

    # Validate input
    if [ -z "$input" ]; then
        phpvm_err "Input required"
        return $PHPVM_EXIT_INVALID_ARG
    fi

    # Process input
    result=$(process_input "$input")

    # Return result
    echo "$result"
    return 0
}
```

### Commit Message Convention

Follow conventional commits:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Build process or auxiliary tool changes

**Examples:**

```bash
feat(alias): add alias management system
fix(install): handle missing repository gracefully
docs(testing): update testing guide
test(core): add tests for version resolution
```

## Troubleshooting

### ShellCheck warnings

Read the warning message and fix accordingly. Common issues:

- `SC2086`: Quote variables to prevent word splitting
- `SC2155`: Declare and assign separately
- `SC2034`: Variable appears unused

Disable specific warnings if intentional:

```bash
# shellcheck disable=SC2086
some_command $unquoted_var
```

### Tests fail locally but pass in CI

1. Ensure you're using bash, not sh
2. Check your package manager setup
3. Verify environment variables
4. Review test isolation

### Pre-commit hook issues

```bash
# Bypass hooks temporarily
git commit --no-verify

# Remove hooks
rm .git/hooks/pre-commit

# Reinstall hooks
make install-hooks
```

## CI/CD

### GitHub Actions Workflows

- **quality.yml** - Runs linting, formatting, and all tests
- **test.yml** - Main test suite across platforms
- **security-test.yml** - Security analysis
- **release.yml** - Release automation

### Local CI Simulation

```bash
# Run same checks as CI
make check

# Or use qa script
./qa.sh
```

## Resources

- [TESTING.md](TESTING.md) - Comprehensive testing guide
- [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) - Feature implementation guide
- [NVM_FEATURE_GAPS.md](NVM_FEATURE_GAPS.md) - Feature roadmap
- [BATS Documentation](https://bats-core.readthedocs.io/)
- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

## Getting Help

- **Issues:** [GitHub Issues](https://github.com/Thavarshan/phpvm/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Thavarshan/phpvm/discussions)
- **Documentation:** Check the docs directory

## Next Steps

1. **Explore the codebase** - Read `phpvm.sh` to understand structure
2. **Run tests** - Get familiar with the test suite
3. **Pick an issue** - Look for "good first issue" labels
4. **Implement Phase 1 features** - See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
5. **Ask questions** - Don't hesitate to open discussions

Happy coding! 🚀

---

**Last Updated:** January 15, 2026
**For Contributors:** Thank you for contributing to phpvm!
