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

@test "session-mode auto keeps Composer resolution failures distinct from no pin (#41)" {
    install_php 8.1
    export PHPVM_SWITCH_MODE=session PHPVM_AUTO_USE_COMPOSER=true
    mkdir -p "$TEST_DIR/app" "$TEST_DIR/empty"
    printf '{"require":{"php":"^9.0"}}\n' > "$TEST_DIR/app/composer.json"

    cd "$TEST_DIR/app"
    run phpvm auto
    [ "$status" -eq 4 ]

    cd "$TEST_DIR/empty"
    run phpvm auto
    [ "$status" -eq 3 ]
}

# --- #38: completion ---

@test "Bash completion handles argument positions and the option's value (#38)" {
    install_php 8.2
    mkdir -p "$PHPVM_DIR/completions"
    cp "$BATS_TEST_DIRNAME/../completions/phpvm.bash" "$PHPVM_DIR/completions/"
    run bash -c '
        source "$1" --no-use
        complete_words() {
            COMP_WORDS=("$@")
            COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
            COMPREPLY=()
            _phpvm_completions
            echo "${COMPREPLY[*]}"
        }
        echo "install-option: $(complete_words phpvm install 8.4 --re)"
        echo "second-version: $(complete_words phpvm reinstall-extensions 8.1 "")"
        echo "after-equals: $(complete_words phpvm install 8.4 --reinstall-extensions-from =)"
        echo "value-after-equals: $(complete_words phpvm install 8.4 --reinstall-extensions-from = 8)"
        echo "joined-value: $(complete_words phpvm install 8.4 --reinstall-extensions-from=8)"
        echo "spaced-value: $(complete_words phpvm install --reinstall-extensions-from 8)"
        echo "exec-command: [$(complete_words phpvm exec 8.2 "")]"
        echo "alias-version: $(complete_words phpvm alias prod 8)"
    ' _ "$BATS_TEST_DIRNAME/../phpvm.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "install-option: --reinstall-extensions-from" ]]
    [[ "$output" =~ "second-version: ".*"8.2" ]]
    [[ "$output" =~ "after-equals: ".*"8.2" ]]
    [[ "$output" =~ "value-after-equals: 8.2" ]]
    [[ "$output" =~ "joined-value: --reinstall-extensions-from=8.2" ]]
    [[ "$output" =~ "spaced-value: 8.2" ]]
    [[ "$output" =~ "exec-command: []" ]]
    [[ "$output" =~ "alias-version: 8.2" ]]
}

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
    stub_command phpenmod 'exit 0'
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

# A target PHP whose module list is Core plus the names listed in $LOADED_FILE
fake_php_loaded_file() {
    mkdir -p "$(dirname "$1")"
    cat > "$1" << 'EOF'
#!/bin/sh
case "$1" in
-r) printf '8.3\n' ;;
-m)
    printf '[PHP Modules]\nCore\n'
    cat "$LOADED_FILE" 2> /dev/null
    printf '\n[Zend Modules]\n'
    ;;
esac
EOF
    chmod +x "$1"
}

@test "apt reinstall enables installed-but-disabled extensions with phpenmod (#40)" {
    fake_php "$TEST_DIR/8.2/php" 8.2 Core curl
    fake_php_loaded_file "$TEST_DIR/8.3/php"
    export LOADED_FILE="$TEST_DIR/loaded" ENMOD_LOG="$TEST_DIR/enmod.log"
    : > "$LOADED_FILE"
    stub_command apt-cache 'printf "%s:\n  Installed: 1.0\n  Candidate: 1.0\n" "$2"'
    stub_command apt-get 'exit 0'
    stub_command phpenmod 'printf "%s\n" "$*" >> "$ENMOD_LOG"; printf "%s\n" "$3" >> "$LOADED_FILE"'
    PHPVM_TEST_MODE=false
    PKG_MANAGER=apt
    get_php_binary_path() { printf '%s/%s/php\n' "$TEST_DIR" "$1"; }
    run_with_sudo() { "$@"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 0 ]
    grep -qx -- '-v 8.3 curl' "$ENMOD_LOG"
}

@test "apt reinstall fails when an installed extension still does not load (#40)" {
    fake_php "$TEST_DIR/8.2/php" 8.2 Core curl
    fake_php_loaded_file "$TEST_DIR/8.3/php"
    export LOADED_FILE="$TEST_DIR/loaded"
    : > "$LOADED_FILE"
    stub_command apt-cache 'printf "%s:\n  Installed: 1.0\n  Candidate: 1.0\n" "$2"'
    stub_command apt-get 'exit 0'
    stub_command phpenmod 'exit 0'
    PHPVM_TEST_MODE=false
    PKG_MANAGER=apt
    get_php_binary_path() { printf '%s/%s/php\n' "$TEST_DIR" "$1"; }
    run_with_sudo() { "$@"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Installed but not loaded by PHP 8.3: curl" ]]
    [[ "$output" =~ "sudo phpenmod -v 8.3 curl" ]]
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

# A target PHP whose module list reflects the extension= lines in its scan directory
fake_php_with_scan_dir() {
    mkdir -p "$(dirname "$1")"
    cat > "$1" << 'EOF'
#!/bin/sh
case "$1" in
-r)
    case "$2" in
    *SCAN_DIR*) printf '%s' "$PHP_SCAN_DIR" ;;
    *extension_dir*) printf '%s' "$PHP_EXTENSION_DIR" ;;
    *) printf '8.3\n' ;;
    esac
    ;;
-m)
    printf '[PHP Modules]\nCore\n'
    cat "$PHP_SCAN_DIR"/*.ini 2> /dev/null | sed -nE 's/^(zend_)?extension=//p'
    printf '\n[Zend Modules]\n'
    ;;
esac
EOF
    chmod +x "$1"
}

@test "Homebrew reinstall enables pecl-built extensions so PHP loads them (#40)" {
    fake_php "$TEST_DIR/8.2/bin/php" 8.2 Core redis xdebug
    fake_php_with_scan_dir "$TEST_DIR/8.3/bin/php"
    printf '#!/bin/sh\nexit 0\n' > "$TEST_DIR/8.3/bin/pecl"
    chmod +x "$TEST_DIR/8.3/bin/pecl"
    export PHP_SCAN_DIR="$TEST_DIR/conf.d"
    mkdir -p "$PHP_SCAN_DIR"
    PHPVM_TEST_MODE=false
    PKG_MANAGER=brew
    get_php_binary_path() { printf '%s/%s/bin/php\n' "$TEST_DIR" "$1"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 0 ]
    [ "$(cat "$PHP_SCAN_DIR/phpvm-redis.ini")" = "extension=redis" ]
    [ "$(cat "$PHP_SCAN_DIR/phpvm-xdebug.ini")" = "zend_extension=xdebug" ]
    [[ "$output" =~ "Enabled in $PHP_SCAN_DIR: redis xdebug" ]]
}

@test "Homebrew reinstall enables existing libraries without invoking pecl (#44)" {
    fake_php "$TEST_DIR/8.2/bin/php" 8.2 Core redis xdebug
    fake_php_with_scan_dir "$TEST_DIR/8.3/bin/php"
    export PHP_SCAN_DIR="$TEST_DIR/conf.d" PHP_EXTENSION_DIR="$TEST_DIR/extensions"
    export PECL_LOG="$TEST_DIR/pecl.log"
    mkdir -p "$PHP_SCAN_DIR" "$PHP_EXTENSION_DIR"
    touch "$PHP_EXTENSION_DIR/redis.so" "$PHP_EXTENSION_DIR/xdebug.so"
    printf '#!/bin/sh\nprintf "called\\n" >> "$PECL_LOG"\nexit 1\n' > "$TEST_DIR/8.3/bin/pecl"
    chmod +x "$TEST_DIR/8.3/bin/pecl"
    PHPVM_TEST_MODE=false
    PKG_MANAGER=brew
    get_php_binary_path() { printf '%s/%s/bin/php\n' "$TEST_DIR" "$1"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 0 ]
    [ ! -e "$PECL_LOG" ]
    [ "$(cat "$PHP_SCAN_DIR/phpvm-redis.ini")" = "extension=redis" ]
    [ "$(cat "$PHP_SCAN_DIR/phpvm-xdebug.ini")" = "zend_extension=xdebug" ]
}

@test "Homebrew reinstall enables libraries left by a failed pecl install (#44)" {
    fake_php "$TEST_DIR/8.2/bin/php" 8.2 Core redis xdebug
    fake_php_with_scan_dir "$TEST_DIR/8.3/bin/php"
    export PHP_SCAN_DIR="$TEST_DIR/conf.d" PHP_EXTENSION_DIR="$TEST_DIR/extensions"
    mkdir -p "$PHP_SCAN_DIR" "$PHP_EXTENSION_DIR"
    printf '#!/bin/sh\n[ "$2" = redis ] && touch "$PHP_EXTENSION_DIR/$2.so"\nexit 1\n' > "$TEST_DIR/8.3/bin/pecl"
    chmod +x "$TEST_DIR/8.3/bin/pecl"
    PHPVM_TEST_MODE=false
    PKG_MANAGER=brew
    get_php_binary_path() { printf '%s/%s/bin/php\n' "$TEST_DIR" "$1"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 1 ]
    [ "$(cat "$PHP_SCAN_DIR/phpvm-redis.ini")" = "extension=redis" ]
    [ ! -e "$PHP_SCAN_DIR/phpvm-xdebug.ini" ]
    [[ "$output" =~ "pecl could not install: xdebug" ]]
    [[ ! "$output" =~ "pecl could not install: redis" ]]
}

@test "Homebrew reinstall leaves existing extension ini settings untouched (#40)" {
    fake_php "$TEST_DIR/8.2/bin/php" 8.2 Core redis
    fake_php_with_scan_dir "$TEST_DIR/8.3/bin/php"
    printf '#!/bin/sh\nexit 0\n' > "$TEST_DIR/8.3/bin/pecl"
    chmod +x "$TEST_DIR/8.3/bin/pecl"
    export PHP_SCAN_DIR="$TEST_DIR/conf.d"
    mkdir -p "$PHP_SCAN_DIR"
    printf 'redis.session.locking_enabled=1\n;extension=redis\n' > "$PHP_SCAN_DIR/ext-redis.ini"
    PHPVM_TEST_MODE=false
    PKG_MANAGER=brew
    get_php_binary_path() { printf '%s/%s/bin/php\n' "$TEST_DIR" "$1"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 0 ]
    [ "$(cat "$PHP_SCAN_DIR/ext-redis.ini")" = "$(printf 'redis.session.locking_enabled=1\n;extension=redis')" ]
    [ "$(cat "$PHP_SCAN_DIR/phpvm-redis.ini")" = "extension=redis" ]
}

@test "Homebrew reinstall reports extensions PHP still does not load (#40)" {
    fake_php "$TEST_DIR/8.2/bin/php" 8.2 Core redis
    fake_php_with_scan_dir "$TEST_DIR/8.3/bin/php"
    printf '#!/bin/sh\nexit 0\n' > "$TEST_DIR/8.3/bin/pecl"
    chmod +x "$TEST_DIR/8.3/bin/pecl"
    export PHP_SCAN_DIR=""
    PHPVM_TEST_MODE=false
    PKG_MANAGER=brew
    get_php_binary_path() { printf '%s/%s/bin/php\n' "$TEST_DIR" "$1"; }

    run phpvm_reinstall_extensions 8.2 8.3
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Installed but not loaded by PHP: redis" ]]
    [[ ! "$output" =~ "Enabled in" ]]
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
