#!/bin/sh
{
    # Ensure the entire script is downloaded and executed
    set -e

    phpvm_has() {
        command -v "$1" > /dev/null 2>&1
    }

    phpvm_echo() {
        printf "\033[32m%s\033[0m\n" "$*"
    }

    phpvm_err() {
        printf "\033[31mError: %s\033[0m\n" "$*" >&2
    }

    phpvm_warn() {
        printf "\033[33mWarning: %s\033[0m\n" "$*" >&2
    }

    # Default installation directory
    PHPVM_DIR="${PHPVM_DIR:-$HOME/.phpvm}"
    PHPVM_SCRIPT="$PHPVM_DIR/phpvm.sh"
    GITHUB_REPO_URL="https://raw.githubusercontent.com/Thavarshan/phpvm/main/phpvm.sh"

    phpvm_install_dir() {
        if [ -n "$PHPVM_DIR" ]; then
            printf %s "$PHPVM_DIR"
        else
            printf %s "$HOME/.phpvm"
        fi
    }

    phpvm_download() {
        if phpvm_has "curl"; then
            curl --fail --compressed -q "$@"
        elif phpvm_has "wget"; then
            # Adding -O- to output to stdout for wget
            wget -O- "$@"
        else
            phpvm_err "curl or wget is required to install phpvm."
            exit 1
        fi
    }

    phpvm_detect_profile() {
        if [ -n "${PROFILE-}" ] && [ -f "$PROFILE" ]; then
            echo "$PROFILE"
            return
        fi

        local DETECTED_PROFILE=""
        local SHELL_NAME=""

        # Get the shell from PS1 or SHELL variable
        SHELL_NAME="$(basename "$SHELL")"

        if [ "$SHELL_NAME" = "zsh" ]; then
            if [ -f "$HOME/.zshrc" ]; then
                DETECTED_PROFILE="$HOME/.zshrc"
            fi
        elif [ "$SHELL_NAME" = "bash" ]; then
            if [ -f "$HOME/.bashrc" ]; then
                DETECTED_PROFILE="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                DETECTED_PROFILE="$HOME/.bash_profile"
            fi
        fi

        if [ -z "$DETECTED_PROFILE" ]; then
            for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"; do
                if [ -f "$HOME/$EACH_PROFILE" ]; then
                    DETECTED_PROFILE="$HOME/$EACH_PROFILE"
                    break
                fi
            done
        fi

        echo "$DETECTED_PROFILE"
    }

    install_phpvm_as_script() {
        local INSTALL_DIR
        INSTALL_DIR="$(phpvm_install_dir)"
        mkdir -p "$INSTALL_DIR/bin"

        phpvm_echo "Downloading phpvm script from $GITHUB_REPO_URL..."
        phpvm_download "$GITHUB_REPO_URL" > "$INSTALL_DIR/phpvm.sh" || {
            phpvm_err "Failed to download phpvm script"
            exit 1
        }

        chmod +x "$INSTALL_DIR/phpvm.sh"
        ln -sf "$INSTALL_DIR/phpvm.sh" "$INSTALL_DIR/bin/phpvm"
    }

    phpvm_do_install() {
        phpvm_echo "Installing phpvm..."
        install_phpvm_as_script

        local PROFILE
        PROFILE="$(phpvm_detect_profile)"

        if [ -n "$PROFILE" ]; then
            # Check if phpvm is already configured in the profile
            if grep -qF 'PHPVM_DIR' "$PROFILE" 2> /dev/null; then
                phpvm_echo "phpvm already configured in $PROFILE (skipping)"
            else
                phpvm_echo "Adding phpvm to $PROFILE"

                # Check shell type and use appropriate syntax
                if echo "$PROFILE" | grep -q "zsh"; then
                    # For zsh - use proper if statement to prevent shell crash
                    printf "\nexport PHPVM_DIR=\"%s\"\nexport PATH=\"\$PHPVM_DIR/bin:\$PATH\"\nif [[ -s \"\$PHPVM_DIR/phpvm.sh\" ]]; then\n  source \"\$PHPVM_DIR/phpvm.sh\"\nfi\n" "$(phpvm_install_dir)" >> "$PROFILE"
                else
                    # For bash and others - use POSIX compatible syntax
                    printf "\nexport PHPVM_DIR=\"%s\"\nexport PATH=\"\$PHPVM_DIR/bin:\$PATH\"\n[ -s \"\$PHPVM_DIR/phpvm.sh\" ] && . \"\$PHPVM_DIR/phpvm.sh\"\n" "$(phpvm_install_dir)" >> "$PROFILE"
                fi
            fi
        else
            phpvm_warn "Could not detect profile file. Please manually add the following to your shell profile:"
            printf "\nexport PHPVM_DIR=\"%s\"\nexport PATH=\"\$PHPVM_DIR/bin:\$PATH\"\n[ -s \"\$PHPVM_DIR/phpvm.sh\" ] && . \"\$PHPVM_DIR/phpvm.sh\"\n" "$(phpvm_install_dir)"
        fi

        phpvm_echo "Applying changes..."
        export PATH="$PHPVM_DIR/bin:$PATH"

        # Only source the profile if it exists
        if [ -f "$PROFILE" ]; then
            # Use . instead of source for POSIX compatibility
            # shellcheck disable=SC1090
            . "$PROFILE" 2> /dev/null || true
        fi

        phpvm_echo "phpvm installation complete!"
        phpvm_echo "You may need to restart your terminal or run: source $PROFILE"
        phpvm_echo "Then try: phpvm install 8.2 && phpvm use 8.2"
    }

    phpvm_do_install
} # End of script
