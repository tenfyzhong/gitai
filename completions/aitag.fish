function _aitag_models
    if test -z "$GITAI_AGENT" -o "$GITAI_AGENT" = pi
        command -q pi; and pi --list-models | awk 'NR > 1 {print $1 "/" $2}'
    end
end

function _aitag_user
    gpg --list-secret-keys --keyid-format LONG | grep uid | awk -F'[<>]' '{print $2}'
end

complete -c aitag -f
complete -c aitag -s h -l help -d "Show help message"
complete -c aitag -s a -l annotate -d "Create annotated tag"
complete -c aitag -s s -l sign -d "Create signed tag"
complete -c aitag -s u -l local-user -d "Create tag with specific user" -x -a "(_aitag_user)"
complete -c aitag -s f -l force -d "Allow tag creation outside the main or master branch"
complete -c aitag -l prompt -d "Use custom prompt file" -r -F
complete -c aitag -l model -d "model to use with the selected AI agent" -x -a "(_aitag_models)"
complete -c aitag -l lang -d "Generate content in specified language (default: English)"
