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

    phpvm_create_launcher() {
        local INSTALL_DIR
        INSTALL_DIR="$(phpvm_install_dir)"

        # Create the bin directory if it doesn't exist
        mkdir -p "$INSTALL_DIR/bin"

        # Create a shell script that runs the index.js
        cat <<EOL >"$INSTALL_DIR/bin/phpvm"
#!/usr/bin/env bash
node "\$PHPVM_DIR/index.js" "\$@"
EOL

        # Make the shell script executable
        chmod +x "$INSTALL_DIR/bin/phpvm"
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
[[ -s \"\$PHPVM_DIR/index.js\" ]] && export PATH=\"\$PHPVM_DIR/bin:\$PATH\" && node \"\$PHPVM_DIR/index.js\"
"

        if [ -n "$PHPVM_PROFILE" ]; then
            if ! command grep -qc '/phpvm/bin/phpvm' "$PHPVM_PROFILE"; then
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
