function _aitag_models
    llm models | grep -v '^Default' | sed 's/^[^:]*: \([^(]*\)\( (.*)\)\?/\1/'
end

function _aitag_user
    gpg --list-secret-keys --keyid-format LONG | grep uid | awk '{print $3}' | sort | uniq
end

complete -c aitag -f
complete -c aitag -s h -l help -d "Show help message"
complete -c aitag -s a -l annotate -d "Create annotated tag"
complete -c aitag -s s -l sign -d "Create signed tag"
complete -c aitag -s u -l local-user -d "Create tag with specific user" -x -a "(git config --get-regexp user.name | cut -d' ' -f2)"
complete -c aitag -l prompt -d "Use custom prompt file" -r -F
complete -c aitag -l model -d "Specify LLM model to use" -x -a "(_aitag_models)"
complete -c aitag -l lang -d "Generate content in specified language (default: English)"
