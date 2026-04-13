#!/usr/bin/env bash
# Bash/Zsh tab completion for phpvm
# Source this file or place it in your completions directory

_phpvm_completions() {
    local cur prev commands
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"

    commands="install uninstall use current which list ls ls-remote alias unalias exec run resolve cache deactivate system auto info version help unload"

    case "$prev" in
    use | uninstall | which | exec | run | resolve)
        # Complete with installed versions + aliases
        local versions=""
        local phpvm_dir="${PHPVM_DIR:-$HOME/.phpvm}"

        # Installed versions from active_version tracking
        if [ -d "$phpvm_dir/alias" ]; then
            local alias_file
            for alias_file in "$phpvm_dir/alias"/*; do
                [ -f "$alias_file" ] && versions="$versions ${alias_file##*/}"
            done
        fi

        # Try to get installed versions from package manager
        if command -v brew > /dev/null 2>&1; then
            local formula
            while IFS= read -r formula; do
                local ver="${formula#php@}"
                [ "$formula" = "php" ] && continue
                versions="$versions $ver"
            done < <(brew list --formula 2> /dev/null | command grep -E '^php(@[0-9]+\.[0-9]+)?$')
        fi

        versions="$versions system"
        # shellcheck disable=SC2207  # Intentional: word splitting for COMPREPLY
        COMPREPLY=($(compgen -W "$versions" -- "$cur"))
        return
        ;;
    alias)
        # Complete with alias subcommands or existing aliases
        if [ "$COMP_CWORD" -eq 2 ]; then
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "default" -- "$cur"))
        fi
        return
        ;;
    unalias)
        # Complete with existing alias names
        local aliases=""
        local phpvm_dir="${PHPVM_DIR:-$HOME/.phpvm}"
        if [ -d "$phpvm_dir/alias" ]; then
            local alias_file
            for alias_file in "$phpvm_dir/alias"/*; do
                [ -f "$alias_file" ] && aliases="$aliases ${alias_file##*/}"
            done
        fi
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$aliases" -- "$cur"))
        return
        ;;
    cache)
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "clear" -- "$cur"))
        return
        ;;
    phpvm)
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return
        ;;
    esac

    # Default: complete commands
    # shellcheck disable=SC2207
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
}

complete -F _phpvm_completions phpvm
