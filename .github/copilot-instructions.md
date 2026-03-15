# Copilot Instructions for phpvm

## Project Context

phpvm is a PHP Version Manager written as a single bash script (`phpvm.sh`). It supports macOS (Homebrew) and Linux (apt, dnf, yum, pacman). Tests use BATS.

## Code Style

- POSIX-compliant bash where possible
- All global variables must be prefixed with `PHPVM_` to avoid namespace pollution when sourced
- Use `command` prefix for external commands (e.g., `command grep`, `command awk`)
- Use `printf '%s\n'` instead of `echo` when piping variable content to avoid `-n`/`-e` interpretation
- Use `if/then/fi` instead of `[ test ] && cmd` for functions that must return 0 on success
- Use `while IFS= read -r` loops instead of `for x in $(...)` to avoid word-splitting issues
- Prefer `command_exists` helper over inline `command -v X > /dev/null 2>&1`

## Testing

```bash
bash -n phpvm.sh          # Syntax check
bats tests/               # Run all tests
bats tests/01_core.bats   # Run specific test file
```

Tests run in isolated mock environments with `PHPVM_TEST_MODE=true`.

## Release Procedure

Conventions: tag = `X.Y.Z` (no `v` prefix), title = `vX.Y.Z` (with `v` prefix).

1. Bump `PHPVM_VERSION` in `phpvm.sh`
2. Add entry to `CHANGELOG.md` under `[Unreleased]` with format:
   ```
   ## [vX.Y.Z](https://github.com/Thavarshan/phpvm/compare/vPREV...vX.Y.Z) - YYYY-MM-DD
   ```
3. Run `bash -n phpvm.sh && bats tests/` — all tests must pass
4. Commit: `git commit -m "chore: release vX.Y.Z — short description"`
5. Push: `git push origin main`
6. Create release: `gh release create X.Y.Z --title "vX.Y.Z" --notes-file <file>`
   - Use `--notes-file` for multi-line notes to avoid shell quoting issues

## Key Environment Variables

- `PHPVM_DIR` — Installation directory (default: `~/.phpvm`)
- `PHPVM_TEST_MODE` — Enable test/mock mode
- `DEBUG` — Enable debug logging
- `PHPVM_AUTO_USE` — Enable automatic `.phpvmrc` detection
- `PHPVM_PHPVMRC_MAX_DEPTH` — Max parent directory traversal for `.phpvmrc` (default: 25)
