#!/usr/bin/env bash

{
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

    phpvm_download() {
        if phpvm_has "curl"; then
            curl --fail --compressed -q "$@"
        elif phpvm_has "wget"; then
            ARGS=$(phpvm_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' -e 's/--compressed //' -e 's/--fail //' -e 's/-L //' -e 's/-I /--server-response /' -e 's/-s /-q /' -e 's/-sS /-nv /' -e 's/-o /-O /' -e 's/-C - /-c /')
            eval wget $ARGS
        fi
    }

    install_phpvm_from_git() {
        local INSTALL_DIR
        INSTALL_DIR="$(phpvm_install_dir)"

        if [ -d "$INSTALL_DIR/.git" ]; then
            phpvm_echo "=> phpvm is already installed in $INSTALL_DIR, updating using git"
            command git -C "$INSTALL_DIR" pull --ff-only || {
                phpvm_echo >&2 'Failed to update phpvm. Please report this!'
                exit 1
            }
        else
            phpvm_echo "=> Downloading phpvm from git to '$INSTALL_DIR'"
            mkdir -p "${INSTALL_DIR}"
            command git clone "https://github.com/Thavarshan/phpvm.git" --depth=1 "${INSTALL_DIR}" || {
                phpvm_echo >&2 'Failed to clone phpvm repo. Please report this!'
                exit 1
            }
        fi

        # Install Node.js dependencies
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

    phpvm_detect_profile() {
        if [ "${PROFILE-}" = '/dev/null' ]; then
            return
        fi

        if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
            phpvm_echo "${PROFILE}"
            return
        fi

        local SHELL_TYPE
        SHELL_TYPE="$(basename "$SHELL")"

        if [ "$SHELL_TYPE" = "bash" ]; then
            if [ -f "$HOME/.bashrc" ]; then
                phpvm_echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                phpvm_echo "$HOME/.bash_profile"
            fi
        elif [ "$SHELL_TYPE" = "zsh" ]; then
            if [ -f "$HOME/.zshrc" ]; then
                phpvm_echo "$HOME/.zshrc"
            elif [ -f "$HOME/.zprofile" ]; then
                phpvm_echo "$HOME/.zprofile"
            fi
        fi
    }

    phpvm_do_install() {
        install_phpvm_from_git
        inject_phpvm_config
        phpvm_echo "=> phpvm installation completed successfully!"
    }

    phpvm_do_install
}
