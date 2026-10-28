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

# Print existing alias names for completion
_phpvm_complete_aliases() {
    local phpvm_dir="${PHPVM_DIR:-$HOME/.phpvm}"
    local alias_file

    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt local_options null_glob
    fi
    if [ -d "$phpvm_dir/alias" ]; then
        for alias_file in "$phpvm_dir/alias"/*; do
            [ -f "$alias_file" ] && printf '%s\n' "${alias_file##*/}"
        done
    fi
}

_phpvm_completions() {
    local cur prev command position word i
    local commands="install uninstall use current which list ls ls-remote alias unalias exec run resolve reinstall-extensions cache deactivate system auto info version help unload self-update"
    local option="--reinstall-extensions-from"

    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev=""
    if [ "$COMP_CWORD" -gt 0 ]; then
        prev="${COMP_WORDS[COMP_CWORD - 1]}"
    fi

    # The command itself
    if [ "$COMP_CWORD" -le 1 ]; then
        # shellcheck disable=SC2207  # Intentional: word splitting for COMPREPLY
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return
    fi
    command="${COMP_WORDS[1]}"

    # The --reinstall-extensions-from value. Bash splits "--opt=value" at "=",
    # giving the words "--opt", "=", "value"; Zsh keeps it as one word.
    if [ "$cur" = "=" ] && [ "$prev" = "$option" ]; then
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$(_phpvm_complete_versions)" -- ""))
        return
    fi
    if [ "$prev" = "=" ] && [ "$COMP_CWORD" -ge 2 ] && [ "${COMP_WORDS[COMP_CWORD - 2]}" = "$option" ]; then
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$(_phpvm_complete_versions)" -- "$cur"))
        return
    fi
    if [ "$prev" = "$option" ]; then
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$(_phpvm_complete_versions)" -- "$cur"))
        return
    fi
    case "$cur" in
    "$option"=*)
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -P "$option=" -W "$(_phpvm_complete_versions)" -- "${cur#*=}"))
        return
        ;;
    esac

    # Position of the current word among the command's arguments (1 = first).
    # Earlier options, option values, and Bash's "=" split words don't count.
    position=1
    i=2
    while [ "$i" -lt "$COMP_CWORD" ]; do
        word="${COMP_WORDS[i]}"
        case "$word" in
        -* | "=") ;;
        *)
            if [ "${COMP_WORDS[i - 1]}" != "$option" ] && [ "${COMP_WORDS[i - 1]}" != "=" ]; then
                position=$((position + 1))
            fi
            ;;
        esac
        i=$((i + 1))
    done

    case "$command" in
    install)
        case "$cur" in
        -*)
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "$option" -- "$cur"))
            ;;
        esac
        ;;
    use | uninstall | which | resolve | list | ls | exec | run)
        if [ "$position" -eq 1 ]; then
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "$(_phpvm_complete_versions)" -- "$cur"))
        fi
        ;;
    reinstall-extensions)
        if [ "$position" -le 2 ]; then
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "$(_phpvm_complete_versions)" -- "$cur"))
        fi
        ;;
    alias)
        if [ "$position" -eq 1 ]; then
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "default $(_phpvm_complete_aliases)" -- "$cur"))
        elif [ "$position" -eq 2 ]; then
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "$(_phpvm_complete_versions)" -- "$cur"))
        fi
        ;;
    unalias)
        if [ "$position" -eq 1 ]; then
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "$(_phpvm_complete_aliases)" -- "$cur"))
        fi
        ;;
    cache)
        if [ "$position" -eq 1 ]; then
            # shellcheck disable=SC2207
            COMPREPLY=($(compgen -W "dir clear" -- "$cur"))
        fi
        ;;
    self-update)
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "--force" -- "$cur"))
        ;;
    esac
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
