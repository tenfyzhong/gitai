#!/usr/bin/env bash

_pr_completion() {
    local cur prev opts
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    allopts="-h --help -r --remote -B --base -H --head -T --template --prompt-title --prompt-body --model --update-title"

    if [[ "$cur" = "-"* ]]; then
        opts="$allopts"
        COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
        return 0
    fi

    case "${prev}" in
        -r|--remote)
            opts=$(git remote)
            ;;
        -B|--base)
            opts=$(git branch -r --format='%(refname:short)' | grep -v 'HEAD' | sed 's/[^\/]\+\/\(.*\)/\1/')
            ;;
        -H|--head)
            opts=$(git branch --format='%(refname:short)')
            ;;
        -T|--template)
            compopt -o filenames
            COMPREPLY=( $(compgen -f -- "${cur}") )
            return 0
            ;;
        --prompt-title)
            compopt -o filenames
            COMPREPLY=( $(compgen -f -- "${cur}") )
            return 0
            ;;
        --prompt-body)
            compopt -o filenames
            COMPREPLY=( $(compgen -f -- "${cur}") )
            return 0
            ;;
        --model)
            opts=$(llm models | grep -v '^Default' | sed 's/^[^:]*: \([^(]*\)\( (.*)\)\?/\1/')
            ;;
    esac

    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
}

complete -F _pr_completion aipr
