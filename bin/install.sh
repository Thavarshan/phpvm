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
        # Fetch the latest version from GitHub, fallback to 'main' if no releases
        latest_version=$(curl -s https://api.github.com/repos/Thavarshan/phpvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

        # Default to 'main' if no release is found
        if [ -z "$latest_version" ]; then
            phpvm_echo "main"
        else
            phpvm_echo "$latest_version"
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

        # Checkout the latest release or 'main' if no releases
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

        phpvm_create_launcher
    }

    phpvm_create_launcher() {
        local INSTALL_DIR
        INSTALL_DIR="$(phpvm_install_dir)"

        # Create a shell script that runs the index.js
        cat <<EOL >"$INSTALL_DIR/phpvm"
#!/usr/bin/env bash
export PHPVM_DIR="${INSTALL_DIR}"
node "\$PHPVM_DIR/index.js" "\$@"
EOL

        # Make the shell script executable
        chmod +x "$INSTALL_DIR/phpvm"
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

    inject_phpvm_config() {
        local PHPVM_PROFILE
        PHPVM_PROFILE="$(phpvm_detect_profile)"
        local PROFILE_INSTALL_DIR
        PROFILE_INSTALL_DIR="$(phpvm_install_dir | command sed "s:^$HOME:\$HOME:")"

        PHPVM_CONFIG_STR="
# Load PHPVM if it exists (similar to nvm)
export PHPVM_DIR=\"\$HOME/.phpvm\"
[[ -s \"\$PHPVM_DIR/phpvm\" ]] && source \"\$PHPVM_DIR/phpvm\"
"

        if [ -n "$PHPVM_PROFILE" ]; then
            if ! command grep -qc '/phpvm' "$PHPVM_PROFILE"; then
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

        phpvm_echo "=> phpvm installation completed successfully!"
    }

    phpvm_do_install

} # this ensures the entire script is downloaded #
