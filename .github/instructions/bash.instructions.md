---
applyTo: "**/*.{sh,bats,bash}"
description: "Use when writing or editing bash scripts, BATS tests, or shell helpers. Covers phpvm bash coding standards, variable naming, safe patterns, and testing conventions."
---
# Bash Script Standards for phpvm

## Variable Naming
- Prefix ALL global/exported variables with `PHPVM_` (e.g., `PHPVM_DIR`, `PHPVM_EXIT_ERROR`)
- Use lowercase `snake_case` for local variables (`local resolved`, `local package_name`)
- Define exit codes as named constants: `PHPVM_EXIT_SUCCESS=0`, `PHPVM_EXIT_ERROR=1`, etc.

## External Commands
- Always use the `command` prefix for external utilities: `command grep`, `command awk`, `command sort`, `command cut`
- Use the `command_exists` helper instead of inline `command -v X > /dev/null 2>&1`

## Output & Strings
- Use `printf '%s\n'` instead of `echo` when outputting variable content (avoids `-n`/`-e` interpretation)
- Use `$()` for command substitution, never backticks
- Double-quote all variable expansions: `"$var"`, `"${arr[@]}"`
- Single-quote strings with no expansions: regex patterns, format strings

## Control Flow
- Use `if/then/fi` instead of `[ test ] && cmd` for functions that must return 0 on success
- Use `|| { ... }` blocks for inline error bailouts:
  ```bash
  mkdir -p "$dir" || {
      phpvm_err "Failed to create directory $dir"
      return 1
  }
  ```
- Use `case/esac` for command routing (not chained elif)

## Loops & Input Processing
- Use `while IFS= read -r line` loops instead of `for x in $(...)` to avoid word-splitting
- Use process substitution `< <(cmd)` when feeding loops from commands

## Functions
- Declare as `func_name() { ... }` (no `function` keyword, no space before parens)
- Document with `# Purpose:`, `# Usage:`, `# Returns:` comment blocks
- Always `return` explicit exit codes (0 success, 1+ failure)

## Logging
- Use the project helpers: `phpvm_echo` (info), `phpvm_err` (error→stderr), `phpvm_warn` (warning→stderr), `phpvm_debug` (debug-only)
- Never use raw `echo` for user-facing messages

## ShellCheck
- Code must pass ShellCheck without warnings
- Suppress only with inline comments and justification: `# shellcheck disable=SC2155  # combined declare+assign is intentional`

## BATS Tests
- Place tests in `tests/` named `NN_topic.bats` (zero-padded number prefix)
- Use `test_helper.bash` for shared setup/teardown (creates `TEST_DIR`, sets `PHPVM_TEST_MODE=true`)
- Assert with `[ "$status" -eq 0 ]` and `[[ "$output" =~ "pattern" ]]`
- Each test must be self-contained—never depend on state from a previous test
