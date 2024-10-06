phpvm_create_launcher() {
    local INSTALL_DIR
    INSTALL_DIR="$(phpvm_install_dir)"

    # Create the bin directory if it doesn't exist
    mkdir -p "$INSTALL_DIR/bin"

    # Create a shell script that runs the index.js
    cat <<EOL >"$INSTALL_DIR/bin/phpvm"
#!/usr/bin/env bash
export PHPVM_DIR="$INSTALL_DIR"
node "\$PHPVM_DIR/index.js" "\$@"
EOL

    # Make the shell script executable
    chmod +x "$INSTALL_DIR/bin/phpvm"

    # Create a symlink in /usr/local/bin (which is typically in PATH)
    if [ -d "/usr/local/bin" ]; then
        sudo ln -sf "$INSTALL_DIR/bin/phpvm" "/usr/local/bin/phpvm"
    else
        phpvm_echo "Warning: /usr/local/bin does not exist. You may need to manually add $INSTALL_DIR/bin to your PATH."
    fi
}

inject_phpvm_config() {
    local PHPVM_PROFILE
    PHPVM_PROFILE="$(phpvm_detect_profile)"
    local PROFILE_INSTALL_DIR
    PROFILE_INSTALL_DIR="$(phpvm_install_dir | command sed "s:^$HOME:\$HOME:")"

    PHPVM_CONFIG_STR="
# PHPVM
export PHPVM_DIR=\"$PROFILE_INSTALL_DIR\"
export PATH=\"\$PHPVM_DIR/bin:\$PATH\"
"

    if [ -n "$PHPVM_PROFILE" ]; then
        if ! command grep -qc 'PHPVM_DIR' "$PHPVM_PROFILE"; then
            phpvm_echo "=> Injecting phpvm config into $PHPVM_PROFILE"
            echo -e "$PHPVM_CONFIG_STR" >>"$PHPVM_PROFILE"
        else
            phpvm_echo "=> phpvm config already exists in $PHPVM_PROFILE"
        fi
    else
        phpvm_echo "=> No profile found for phpvm config injection"
        phpvm_echo "   Please add the following to your shell configuration file:"
        phpvm_echo "$PHPVM_CONFIG_STR"
    fi
}
