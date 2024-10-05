#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

    phpvm_has() {
        type "$1" >/dev/null 2>&1
    }

    phpvm_echo() {
        command printf %s\\n "$*" 2>/dev/null
    }

    phpvm_grep() {
        GREP_OPTIONS='' command grep "$@"
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
        phpvm_echo "v1.0.0" # replace with your current phpvm version
    }

    phpvm_download() {
        if phpvm_has "curl"; then
            curl --fail --compressed -q "$@"
        elif phpvm_has "wget"; then
            # Emulate curl with wget
            ARGS=$(phpvm_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' \
                -e 's/--compressed //' \
                -e 's/--fail //' \
                -e 's/-L //' \
                -e 's/-I /--server-response /' \
                -e 's/-s /-q /' \
                -e 's/-sS /-nv /' \
                -e 's/-o /-O /' \
                -e 's/-C - /-c /')
            # shellcheck disable=SC2086
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
    }

    install_phpvm_as_script() {
        local INSTALL_DIR
        INSTALL_DIR="$(phpvm_install_dir)"
        local PHPVM_SOURCE
        PHPVM_SOURCE="https://raw.githubusercontent.com/your-username/phpvm/main/index.js"

        phpvm_echo "=> Downloading phpvm as a script to '$INSTALL_DIR'"
        mkdir -p "$INSTALL_DIR"
        phpvm_download -s "$PHPVM_SOURCE" -o "$INSTALL_DIR/index.js" || {
            phpvm_echo >&2 "Failed to download '$PHPVM_SOURCE'"
            return 1
        }

        chmod a+x "$INSTALL_DIR/index.js" || {
            phpvm_echo >&2 "Failed to mark '$INSTALL_DIR/index.js' as executable"
            return 1
        }
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
        if [ -z "${METHOD}" ]; then
            # Autodetect install method
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

        phpvm_echo

        local PHPVM_PROFILE
        PHPVM_PROFILE="$(phpvm_detect_profile)"
        local PROFILE_INSTALL_DIR
        PROFILE_INSTALL_DIR="$(phpvm_install_dir | command sed "s:^$HOME:\$HOME:")"

        SOURCE_STR="\\nexport PHPVM_DIR=\"${PROFILE_INSTALL_DIR}\"\\n[ -s \"\$PHPVM_DIR/index.js\" ] && \\. \"\$PHPVM_DIR/index.js\"  # This loads phpvm\\n"

        if [ -z "${PHPVM_PROFILE-}" ]; then
            phpvm_echo "=> Profile not found. Tried ~/.bashrc, ~/.bash_profile, ~/.zshrc, ~/.zprofile."
            phpvm_echo "=> Create one of them and run this script again"
            phpvm_echo "=> Alternatively, append the following lines to the correct file yourself:"
            command printf "${SOURCE_STR}"
            phpvm_echo
        else
            if ! command grep -qc '/phpvm/index.js' "$PHPVM_PROFILE"; then
                phpvm_echo "=> Appending phpvm source string to $PHPVM_PROFILE"
                command printf "${SOURCE_STR}" >>"$PHPVM_PROFILE"
            else
                phpvm_echo "=> phpvm source string already in $PHPVM_PROFILE"
            fi
        fi

        # Source phpvm immediately
        # shellcheck source=/dev/null
        \. "$(phpvm_install_dir)/index.js"

        phpvm_echo "=> Close and reopen your terminal to start using phpvm or run the following to use it now:"
        command printf "${SOURCE_STR}"
    }

    phpvm_do_install

} # this ensures the entire script is downloaded #
