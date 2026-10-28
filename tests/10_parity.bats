#!/usr/bin/env bats
# nvm-parity features: ls filtering (#39), extension reinstall (#40),
# composer.json auto-switching (#41), and Zsh completion (#38).

load test_helper

# Put fake commands first on PATH
stub_command() {
    mkdir -p "$TEST_DIR/stub"
    printf '#!/bin/sh\n%s\n' "$2" > "$TEST_DIR/stub/$1"
    chmod +x "$TEST_DIR/stub/$1"
    case ":$PATH:" in
    *":$TEST_DIR/stub:"*) ;;
    *) export PATH="$TEST_DIR/stub:$PATH" ;;
    esac
}

# Create a fake PHP binary that reports its version and a module list
# Usage: fake_php <path> <X.Y> <module>...
fake_php() {
    local path="$1"
    local version="$2"
    shift 2
    mkdir -p "$(dirname "$path")"
    {
        printf '#!/bin/sh\n'
        printf 'if [ "$1" = "-r" ]; then printf "%s\\n"; exit 0; fi\n' "$version"
        printf 'if [ "$1" = "-m" ]; then\n'
        printf '    printf "[PHP Modules]\\n"\n'
        for module in "$@"; do
            printf '    printf "%%s\\n" "%s"\n' "$module"
        done
        printf '    printf "\\n[Zend Modules]\\n"\n'
        printf 'fi\n'
    } > "$path"
    chmod +x "$path"
}

# --- #39: phpvm ls <pattern> ---

@test "ls filters installed versions by whole version components (#39)" {
    install_php 8.1
    install_php 8.2
    install_php 8.20
    install_php 7.4

    run list_installed_versions 8
    [ "$status" -eq 0 ]
    [[ "$output" =~ "8.1" ]]
    [[ "$output" =~ "8.20" ]]
    [[ ! "$output" =~ "7.4" ]]
    [[ ! "$output" =~ "system" ]]

    run list_installed_versions 8.2
    [ "$status" -eq 0 ]
    [[ "$output" =~ "matching '8.2'" ]]
    [[ "$output" =~ "  8.2" ]]
    [[ ! "$output" =~ "8.20" ]]
    [[ ! "$output" =~ "8.1" ]]
}

@test "ls resolves aliases and filters to system (#39)" {
    install_php 8.1
    install_php 8.2
    phpvm_alias project 8.2 > /dev/null

    run list_installed_versions project
    [ "$status" -eq 0 ]
    [[ "$output" =~ "matching 'project'" ]]
    [[ "$output" =~ "8.2" ]]
    [[ ! "$output" =~ "8.1" ]]
    [[ ! "$output" =~ "Aliases:" ]]

    run list_installed_versions system
    [ "$status" -eq 0 ]
    [[ "$output" =~ "system" ]]
    [[ ! "$output" =~ "8.2" ]]
}

@test "ls reports no matches and rejects invalid patterns (#39)" {
    install_php 8.2
    run list_installed_versions 9
    [ "$status" -eq 3 ]
    [[ "$output" =~ "No installed PHP versions match '9'" ]]

    run list_installed_versions 'a;b'
    [ "$status" -eq 2 ]

    run bash "$BATS_TEST_DIRNAME/../phpvm.sh" ls 8.2
    [ "$status" -eq 0 ]
    [[ "$output" =~ "8.2" ]]
}

@test "ls without a pattern still lists aliases and the system entry (#39)" {
    install_php 8.2
    run list_installed_versions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "system" ]]
    [[ "$output" =~ "Aliases:" ]]
}

@test "session-mode ls accepts a pattern (#39)" {
    install_php 8.1
    install_php 8.2
    export PHPVM_SWITCH_MODE=session
    phpvm use 8.2 > /dev/null
    run phpvm ls 8.2
    [ "$status" -eq 0 ]
    [[ "$output" =~ "-> 8.2" ]]
    [[ ! "$output" =~ "8.1" ]]
}

# --- #41: composer.json auto-switching ---

@test "automatic switching ignores composer.json unless enabled (#41)" {
    install_php 8.1
    install_php 8.2
    export PHPVM_SWITCH_MODE=session
    phpvm use 8.1 > /dev/null
    mkdir -p "$TEST_DIR/app"
    printf '{"require":{"php":"^8.2"}}\n' > "$TEST_DIR/app/composer.json"
    cd "$TEST_DIR/app"

    phpvm_cd_hook > /dev/null
    [ "$(phpvm current)" = "8.1" ]

    run auto_switch_php_version
    [ "$status" -eq 3 ]
}

@test "PHPVM_AUTO_USE_COMPOSER switches on directory change and with auto (#41)" {
    install_php 8.1
    install_php 8.2
    install_php 8.3
    export PHPVM_SWITCH_MODE=session PHPVM_AUTO_USE_COMPOSER=true
    phpvm use 8.1 > /dev/null
    mkdir -p "$TEST_DIR/app"
    printf '{"require":{"php":">=8.2 <8.3"}}\n' > "$TEST_DIR/app/composer.json"

    cd "$TEST_DIR/app"
    run phpvm_cd_hook
    [[ "$output" =~ "Auto-switching to PHP 8.2 (from project pin)" ]]
    phpvm_cd_hook > /dev/null
    PHPVM_LAST_HOOK_PWD=""
    phpvm_cd_hook > /dev/null
    [ "$(phpvm current)" = "8.2" ]

    phpvm use 8.1 > /dev/null
    phpvm auto > /dev/null
    [ "$(phpvm current)" = "8.2" ]

    run auto_switch_php_version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found PHP requirement '>=8.2 <8.3' in composer.json; using 8.2" ]]
}

# --- #38: completion ---

@test "Zsh registers phpvm completion when compinit is loaded (#38)" {
    if ! command -v zsh > /dev/null 2>&1; then
        skip "zsh is required for the Zsh completion test"
    fi
    install_php 8.2
    mkdir -p "$PHPVM_DIR/completions"
    cp "$BATS_TEST_DIRNAME/../completions/phpvm.bash" "$PHPVM_DIR/completions/"

    run zsh -f -c '
        autoload -Uz compinit && compinit -u -D
        source "$1" --no-use
        (( ${+_comps[phpvm]} )) || { echo "not registered"; exit 1; }
        complete_words() {
            emulate -L sh
            setopt kshglob noshglob braceexpand
            COMP_WORDS=("$@")
            COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
            COMPREPLY=()
            _phpvm_completions
            echo "${COMPREPLY[*]}"
        }
        echo "commands: $(complete_words phpvm us)"
        echo "versions: $(complete_words phpvm use "")"
        echo "ls: $(complete_words phpvm ls 8)"
    ' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    # bashcompinit's compgen leaves prefix matching to Zsh, so the function
    # returns every candidate; Zsh filters them against the typed word
    [ "$status" -eq 0 ]
    [[ "$output" =~ "commands: ".*" use " ]]
    [[ "$output" =~ "commands: ".*"reinstall-extensions" ]]
    [[ "$output" =~ "versions: ".*"8.2" ]]
    [[ "$output" =~ "versions: ".*"system" ]]
    [[ "$output" =~ "ls: ".*"8.2" ]]
}

@test "Zsh without compinit sources phpvm without completion errors (#38)" {
    if ! command -v zsh > /dev/null 2>&1; then
        skip "zsh is required for the Zsh completion test"
    fi
    mkdir -p "$PHPVM_DIR/completions"
    cp "$BATS_TEST_DIRNAME/../completions/phpvm.bash" "$PHPVM_DIR/completions/"
    run zsh -f -c 'source "$1" --no-use && echo loaded' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "loaded" ]
}

@test "Bash completion offers installed versions and unload removes it (#38)" {
    install_php 8.2
    mkdir -p "$PHPVM_DIR/completions"
    cp "$BATS_TEST_DIRNAME/../completions/phpvm.bash" "$PHPVM_DIR/completions/"
    run bash -c '
        source "$1" --no-use
        complete -p phpvm > /dev/null || { echo "not registered"; exit 1; }
        COMP_WORDS=(phpvm use ""); COMP_CWORD=2
        _phpvm_completions
        echo "versions: ${COMPREPLY[*]}"
        COMP_WORDS=(phpvm install --re); COMP_CWORD=2
        _phpvm_completions
        echo "flags: ${COMPREPLY[*]}"
        phpvm unload > /dev/null
        complete -p phpvm > /dev/null 2>&1 && echo "still registered"
        declare -F _phpvm_completions > /dev/null && echo "function left"
        true
    ' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "versions: ".*"8.2" ]]
    [[ "$output" =~ "flags: --reinstall-extensions-from" ]]
    [[ ! "$output" =~ "still registered" ]]
    [[ ! "$output" =~ "function left" ]]
}

# --- #40: reinstall extensions ---

@test "missing extensions are worked out from php -m (#40)" {
    fake_php "$TEST_DIR/from/php" 8.2 Core curl intl mysqli pdo_mysql "Zend OPcache"
    fake_php "$TEST_DIR/to/php" 8.3 Core curl
    run phpvm_missing_extensions "$TEST_DIR/from/php" "$TEST_DIR/to/php"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | paste -s -d ' ' -)" = "intl mysqli pdo_mysql opcache" ]
}

@test "apt reinstall installs mapped packages and reports unavailable ones (#40)" {
    fake_php "$TEST_DIR/8.2/php" 8.2 Core curl intl mysqli pdo_mysql redis dom xmlwriter "Zend OPcache"
    fake_php "$TEST_DIR/8.3/php" 8.3 Core curl
    export APT_LOG="$TEST_DIR/apt.log"
    stub_command apt-cache 'case "$2" in php8.3-redis) c="(none)" ;; *) c="1.0" ;; esac
printf "%s:\n  Installed: (none)\n  Candidate: %s\n" "$2" "$c"'
    stub_command apt-get 'printf "%s\n" "$*" >> "$APT_LOG"'
    PHPVM_TEST_MODE=false
    PKG_MANAGER=apt
    get_php_binary_path() { printf '%s/%s/php\n' "$TEST_DIR" "$1"; }
    run_with_sudo() { "$@"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 3 ]
    [[ "$output" =~ "missing from PHP 8.3: intl mysqli pdo_mysql redis dom xmlwriter opcache" ]]
    grep -qx 'install -y php8.3-intl php8.3-mysql php8.3-xml php8.3-opcache' "$APT_LOG"
    [[ "$output" =~ "No apt package found for: redis" ]]
}

@test "Homebrew reinstall uses the target version's pecl (#40)" {
    fake_php "$TEST_DIR/8.2/bin/php" 8.2 Core redis xdebug
    fake_php "$TEST_DIR/8.3/bin/php" 8.3 Core
    export PECL_LOG="$TEST_DIR/pecl.log"
    printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$PECL_LOG"\n[ "$2" != xdebug ]\n' > "$TEST_DIR/8.3/bin/pecl"
    chmod +x "$TEST_DIR/8.3/bin/pecl"
    PHPVM_TEST_MODE=false
    PKG_MANAGER=brew
    get_php_binary_path() { printf '%s/%s/bin/php\n' "$TEST_DIR" "$1"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 1 ]
    grep -qx 'install redis' "$PECL_LOG"
    grep -qx 'install xdebug' "$PECL_LOG"
    [[ "$output" =~ "pecl could not install: xdebug" ]]
}

@test "reinstall lists extensions where it cannot install them and validates versions (#40)" {
    fake_php "$TEST_DIR/8.2/php" 8.2 Core redis
    fake_php "$TEST_DIR/8.3/php" 8.3 Core
    PHPVM_TEST_MODE=false
    PKG_MANAGER=dnf
    get_php_binary_path() { printf '%s/%s/php\n' "$TEST_DIR" "$1"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Install these extensions for PHP 8.3 manually: redis" ]]

    run phpvm_reinstall_extensions 8.3 8.3
    [ "$status" -eq 2 ]
    run phpvm_reinstall_extensions 7.1 8.3
    [ "$status" -eq 4 ]
    run phpvm_reinstall_extensions
    [ "$status" -eq 2 ]

    printf '8.3\n' > "$PHPVM_ACTIVE_VERSION_FILE"
    run phpvm_reinstall_extensions 8.2
    [[ "$output" =~ "missing from PHP 8.3: redis" ]]
}

@test "install --reinstall-extensions-from runs after the install and validates options (#40)" {
    local script="$BATS_TEST_DIRNAME/../phpvm.sh"
    bash "$script" install 8.2 > /dev/null

    run bash "$script" install 8.3 --reinstall-extensions-from=8.2
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PHP 8.3 installed." ]]
    [[ "$output" =~ "already loads every extension PHP 8.2 loads" ]]

    run bash "$script" install 8.4 --reinstall-extensions-from 8.2
    [ "$status" -eq 0 ]

    run bash "$script" install 8.3 --reinstall-extensions-from
    [ "$status" -eq 2 ]
    run bash "$script" install 8.3 --bogus
    [ "$status" -eq 2 ]
    run bash "$script" install 8.2 8.3
    [ "$status" -eq 2 ]
}
