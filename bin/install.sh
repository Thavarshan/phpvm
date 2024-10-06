#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

    phpvm_has() {
        type "$1" >/dev/null 2>&1
    }

    phpvm_echo() {
        command printf %s\\n "$*" 2>/dev/null
    }

    phpvm_default_install_dir() {
        [ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.phpvm" || printf %s "${XDG_CONFIG_HOME}/phpvm"
    }

    phpvm_install_dir() {
        if [ -n "$PHPVM_DIR" ]; then
            printf %s "${PHPVM_DIR}"
        else
            phpvm_default_install_dir
        fi
    }

    phpvm_latest_version() {
        # Fetch the latest version from GitHub
        latest_version=$(curl -s https://api.github.com/repos/Thavarshan/phpvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

        # Default to main if the version is not found
        if [ -z "$latest_version" ]; then
            latest_version="main"
        fi

        phpvm_echo "$latest_version"
    }

    phpvm_download() {
        if phpvm_has "curl"; then
            curl --fail --compressed -q "$@"
        elif phpvm_has "wget"; then
            ARGS=$(phpvm_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' \
                -e 's/--compressed //' -e 's/--fail //' -e 's/-L //' -e 's/-I /--server-response /' \
                -e 's/-s /-q /' -e 's/-sS /-nv /' -e 's/-o /-O /' -e 's/-C - /-c /')
            eval wget $ARGS
        fi
    }

    install_phpvm_from_git() {
        local INSTALL_DIR
        INSTALL_DIR="$(phpvm_install_dir)"
        local PHPVM_VERSION
        PHPVM_VERSION="${PHPVM_INSTALL_VERSION:-$(phpvm_latest_version)}"

        if [ -d "$INSTALL_DIR/.git" ]; then
            phpvm_echo "=> phpvm is already installed in $INSTALL_DIR, updating using git"
            command printf '\r=> '
        else
            phpvm_echo "=> Downloading phpvm from git to '$INSTALL_DIR'"
            mkdir -p "${INSTALL_DIR}"
            command git clone "https://github.com/Thavarshan/phpvm.git" --depth=1 "${INSTALL_DIR}" || {
                phpvm_echo >&2 'Failed to clone phpvm repo. Please report this!'
                exit 1
            }
        fi

        command git -C "$INSTALL_DIR" checkout "$PHPVM_VERSION" || {
            phpvm_echo >&2 "Failed to checkout the version $PHPVM_VERSION. Please report this!"
            exit 1
        }

        phpvm_echo "=> Cleaning up git repository"
        command git -C "$INSTALL_DIR" gc --auto --aggressive --prune=now || {
            phpvm_echo >&2 'Failed to clean up git repository. Please report this!'
            exit 1
        }

        if ! phpvm_has "node"; then
            phpvm_echo "Node.js is required to run phpvm. Please install Node.js and try again."
            exit 1
        fi

        phpvm_echo "=> Installing Node.js dependencies"
        command npm install --prefix "$INSTALL_DIR" || {
            phpvm_echo >&2 'Failed to install Node.js dependencies. Please report this!'
            exit 1
        }
    }

    inject_phpvm_config() {
        local PHPVM_PROFILE
        PHPVM_PROFILE="$(phpvm_detect_profile)"
        local PROFILE_INSTALL_DIR
        PROFILE_INSTALL_DIR="$(phpvm_install_dir | command sed "s:^$HOME:\$HOME:")"

        PHPVM_CONFIG_STR="
# Load PHPVM if necessary (this will allow phpvm to be invoked manually)
if [ -s \"\$PHPVM_DIR/index.js\" ]; then
    export PATH=\"\$PHPVM_DIR/bin:\$PATH\"
fi
"

        if [ -n "$PHPVM_PROFILE" ]; then
            if ! command grep -qc '/phpvm/index.js' "$PHPVM_PROFILE"; then
                phpvm_echo "=> Injecting phpvm config into $PHPVM_PROFILE"
                echo -e "$PHPVM_CONFIG_STR" >>"$PHPVM_PROFILE"
            else
                phpvm_echo "=> phpvm config already exists in $PHPVM_PROFILE"
            fi
        else
            phpvm_echo "=> No profile found for phpvm config injection"
        fi
    }

    phpvm_do_install() {
        if [ -z "${METHOD}" ]; then
            if phpvm_has git; then
                install_phpvm_from_git
            elif phpvm_has curl || phpvm_has wget; then
                install_phpvm_as_script
            else
                phpvm_echo >&2 'You need git, curl, or wget to install phpvm'
                exit 1
            fi
        else
            phpvm_echo >&2 "Unexpected install method: $METHOD"
            exit 1
        fi

        inject_phpvm_config

        node "$(phpvm_install_dir)/index.js"

        phpvm_echo "=> phpvm installation completed successfully!"
    }

    phpvm_do_install

} # this ensures the entire script is downloaded #
