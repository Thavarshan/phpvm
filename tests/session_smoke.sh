#!/usr/bin/env bash
set -euo pipefail

PHPVM_DIR=$(mktemp -d "${TMPDIR:-/tmp}/phpvm-session-smoke.XXXXXX")
export PHPVM_DIR
export PHPVM_SWITCH_MODE=session
export PHPVM_AUTO_USE=false
trap 'rm -rf "$PHPVM_DIR"' EXIT

phpvm_version() {
    php -r 'echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;'
}

source "$(cd "$(dirname "$0")/.." && pwd)/phpvm.sh" --no-use
if command -v brew > /dev/null 2>&1; then
    export PKG_MANAGER=brew
    export HOMEBREW_PREFIX="$(brew --prefix)"
fi
phpvm use 8.2
[[ "$(phpvm_version)" = 8.2 ]]
active_bin="$PHPVM_SESSION_BIN/php"

bash -c 'source "$1" --no-use; phpvm use 8.3; [[ "$(php -r '\''echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;'\'')" = 8.3 ]]' _ "$PHPVM_SCRIPT_PATH"
zsh -c 'source "$1" --no-use; phpvm use 8.3; [[ "$(php -r '\''echo PHP_MAJOR_VERSION,".",PHP_MINOR_VERSION;'\'')" = 8.3 ]]' _ "$PHPVM_SCRIPT_PATH"

[[ "$(phpvm_version)" = 8.2 ]]
[[ "$(phpvm current)" = 8.2 ]]
[[ ! -e "$PHPVM_ACTIVE_VERSION_FILE" ]]
phpvm deactivate
[[ "$(command -v php)" != "$active_bin" ]]
