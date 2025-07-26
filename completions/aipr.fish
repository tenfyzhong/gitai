function _aipr_models
    llm models | grep -v '^Default' | sed 's/^[^:]*: \([^(]*\)\( (.*)\)\?/\1/'
end

function _aipr_bases
    git branch -r --format='%(refname:short)' | grep -v 'HEAD' | sed 's/[^\/]\+\/\(.*\)/\1/'
end

complete -c aipr -f
complete -c aipr -s h -l help -d "Show help message"
complete -c aipr -s r -l remote -x -a "(git remote)" -d "The remote repository to use"
complete -c aipr -s B -l base -x -a "(_aipr_bases)" -d "The base branch to compare against"
complete -c aipr -s H -l head -x -a "(git branch --format='%(refname:short)')" -d "The head branch to compare from"
complete -c aipr -s T -l template -r -F -d "Specify a PR template file to use"
complete -c aipr -l prompt-title -r -F -d "Path to PR title prompt template"
complete -c aipr -l prompt-body -r -F -d "Path to PR body prompt template"
complete -c aipr -l model -x -a "(_aipr_models)" -d "LLM model to use for generating PR content"
complete -c aipr -l update-title -d "Update PR title when editing existing PR"
