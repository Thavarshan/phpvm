#!/usr/bin/env bash
# Bash/Zsh tab completion for phpvm
# Source this file or place it in your completions directory. In Zsh it uses
# bashcompinit, which needs the completion system (compinit) to be loaded first.

# Print installed PHP versions and alias names for completion
_phpvm_complete_versions() {
    local phpvm_dir="${PHPVM_DIR:-$HOME/.phpvm}"
    local alias_file
    local formula

    # An empty alias directory must not abort the loop under Zsh's nomatch
    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt local_options null_glob
    fi

    if [ -d "$phpvm_dir/alias" ]; then
        for alias_file in "$phpvm_dir/alias"/*; do
            [ -f "$alias_file" ] && printf '%s\n' "${alias_file##*/}"
        done
    fi

    # phpvm knows the installed versions for every supported package manager
    if command -v phpvm_installed_versions > /dev/null 2>&1; then
        phpvm_installed_versions 2> /dev/null
    elif command -v brew > /dev/null 2>&1; then
        while IFS= read -r formula; do
            [ "$formula" = "php" ] && continue
            printf '%s\n' "${formula#php@}"
        done < <(brew list --formula 2> /dev/null | command grep -E '^php(@[0-9]+\.[0-9]+)?$')
    fi

    # "default" is offered through the alias directory once it exists
    printf '%s\n' system latest stable
}

_phpvm_completions() {
    local cur prev commands
    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt local_options null_glob
    fi
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"

    commands="install uninstall use current which list ls ls-remote alias unalias exec run resolve reinstall-extensions cache deactivate system auto info version help unload self-update"

    case "$prev" in
    use | uninstall | which | exec | run | resolve | list | ls | reinstall-extensions | --reinstall-extensions-from)
        # shellcheck disable=SC2207  # Intentional: word splitting for COMPREPLY
        COMPREPLY=($(compgen -W "$(_phpvm_complete_versions)" -- "$cur"))
        return
        ;;
    install)
        if [[ "$cur" == -* ]]; then
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "--reinstall-extensions-from" -- "$cur"))
        fi
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
        COMPREPLY=($(compgen -W "dir clear" -- "$cur"))
        return
        ;;
    self-update)
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "--force" -- "$cur"))
        return
        ;;
    phpvm)
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return
        ;;
    esac

    # Version arguments after a selected version (exec/run commands) stay free-form
    if [ "$COMP_CWORD" -le 1 ]; then
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    fi
}

# Zsh: reuse the Bash function through bashcompinit (as nvm does)
if [ -n "${ZSH_VERSION:-}" ]; then
    if ! command -v compdef > /dev/null 2>&1; then
        # The Zsh completion system is not loaded; nothing to register with
        return 0 2> /dev/null || true
    fi
    autoload -U +X bashcompinit && bashcompinit
fi

complete -F _phpvm_completions phpvm
