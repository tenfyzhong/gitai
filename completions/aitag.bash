#!/usr/bin/env bash

_aitag() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"
    opts="-h --help -a --annotate -s --sign -u --local-user --prompt --model --lang"

    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
        return 0
    fi

    case "$prev" in
        -u | --local-user)
            opts=$(gpg --list-secret-keys --keyid-format LONG | grep uid | awk -F'[<>]' '{print $2}')
            COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
            return 0
            ;;
        --prompt)
            compopt -o filenames
            COMPREPLY=($(compgen -f -- "${cur}"))
            return 0
            ;;
        --model)
            if [[ -z "${GITAI_AGENT:-}" || "$GITAI_AGENT" = pi ]] && command -v pi >/dev/null 2>&1; then
                opts=$(pi --list-models | awk 'NR > 1 {print $1 "/" $2}')
            else
                opts=
            fi
            COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
            ;;
    esac

    return 0
}
complete -F _aitag aitag
