#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KEEP_REPO=0
REMOTE_CREATED=0
REPO_SLUG=
REPO_URL=
TEST_ROOT=
PR_URLS=()
AGENTS=(pi oh-my-pi codex claude-code)

usage() {
    cat <<'EOF'
Usage: tests/integration-github.sh [--keep-repo]

Run real end-to-end tests against pi, oh-my-pi, codex, and claude-code.
For every agent, the test covers ai-commit-msg, aitag, and aipr, then verifies
the pushed branch, pushed tag, and pull request content through GitHub.

Options:
  --keep-repo  Keep the temporary GitHub repository for manual verification.
  -h, --help   Show this help message.

By default both the local temporary directory and GitHub repository are removed.
The active gh account must be able to create and delete private repositories.
EOF
}

log() {
    printf '==> %s\n' "$*"
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

cleanup() {
    local status=$?
    local cleanup_failed=0
    trap - EXIT

    if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then
        rm -rf -- "$TEST_ROOT"
    fi

    if [ "$REMOTE_CREATED" = 1 ]; then
        if [ "$KEEP_REPO" = 1 ]; then
            printf '\nGitHub repository retained for manual verification:\n  %s\n' "$REPO_URL"
            if [ "${#PR_URLS[@]}" -gt 0 ]; then
                printf 'Pull requests:\n'
                printf '  %s\n' "${PR_URLS[@]}"
            fi
        else
            log "Deleting GitHub repository $REPO_SLUG"
            if ! gh repo delete "$REPO_SLUG" --yes; then
                cleanup_failed=1
                printf 'Error: Failed to delete %s. Delete it manually with:\n  gh repo delete %q --yes\n' \
                    "$REPO_SLUG" "$REPO_SLUG" >&2
            fi
        fi
    fi

    if [ "$status" -eq 0 ] && [ "$cleanup_failed" -ne 0 ]; then
        status=1
    fi
    exit "$status"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' is not installed."
}

assert_contains() {
    local value=$1
    local expected=$2
    local description=$3
    case "$value" in
        *"$expected"*) ;;
        *) fail "$description does not contain expected marker '$expected'. Actual value: $value" ;;
    esac
}

agent_command() {
    case "$1" in
        pi) echo pi ;;
        oh-my-pi) echo omp ;;
        codex) echo codex ;;
        claude-code) echo claude ;;
    esac
}

write_prompts() {
    local agent=$1
    local commit_marker=$2
    local tag_marker=$3
    local title_marker=$4
    local body_marker=$5

    cat >"$TEST_ROOT/commit-$agent.txt" <<EOF
Generate a concise Git commit message for the supplied diff.
The response must contain this exact verification marker: $commit_marker
Return only the commit message, without Markdown fences or commentary.
EOF

    cat >"$TEST_ROOT/tag-$agent.txt" <<EOF
Generate a concise annotated Git tag message for the supplied diff.
The response must contain this exact verification marker: $tag_marker
Return only the tag message, without Markdown fences or commentary.
EOF

    cat >"$TEST_ROOT/pr-title-$agent.txt" <<EOF
Generate a concise pull request title.
The title must contain this exact verification marker: $title_marker
EOF

    cat >"$TEST_ROOT/pr-body-$agent.txt" <<EOF
Generate a clear pull request body.
The body must contain this exact verification marker: $body_marker
EOF
}

run_agent_test() {
    local agent=$1
    local index=$2
    local repo_dir=$3
    local branch="integration-$agent"
    local tag="gitai-integration-v$index"
    local marker_prefix="GITAI_E2E_${agent//-/_}_${RUN_ID}"
    local commit_marker="${marker_prefix}_COMMIT"
    local tag_marker="${marker_prefix}_TAG"
    local title_marker="${marker_prefix}_PR_TITLE"
    local body_marker="${marker_prefix}_PR_BODY"
    local message_file="$TEST_ROOT/commit-message-$agent"
    local pr_output="$TEST_ROOT/aipr-$agent.log"
    local commit_message tag_message local_sha remote_sha pr_json pr_url

    log "Testing $agent with ai-commit-msg, aitag, and aipr"
    write_prompts "$agent" "$commit_marker" "$tag_marker" "$title_marker" "$body_marker"

    git -C "$repo_dir" switch -q main
    git -C "$repo_dir" switch -q -c "$branch"
    printf 'integration change generated for %s\n' "$agent" >"$repo_dir/change-$agent.txt"
    git -C "$repo_dir" add "change-$agent.txt"
    : >"$message_file"

    (
        cd "$repo_dir"
        EDITOR=true \
            GITAI_AGENT="$agent" \
            GITAI_MODEL='' \
            GITAI_LANG=English \
            GITAI_COMMIT_MSG_PROMPT="$TEST_ROOT/commit-$agent.txt" \
            "$PROJECT_ROOT/ai-commit-msg" "$message_file"
    )
    commit_message=$(cat "$message_file")
    assert_contains "$commit_message" "$commit_marker" "$agent commit message"
    git -C "$repo_dir" commit -q -F "$message_file"

    printf 'y\n' | (
        cd "$repo_dir"
        EDITOR=true \
            GITAI_AGENT="$agent" \
            GITAI_MODEL='' \
            GITAI_LANG=English \
            GITAI_TAG_PROMPT="$TEST_ROOT/tag-$agent.txt" \
            "$PROJECT_ROOT/aitag" --annotate "$tag"
    )
    tag_message=$(git -C "$repo_dir" for-each-ref --format='%(contents)' "refs/tags/$tag")
    assert_contains "$tag_message" "$tag_marker" "$agent tag message"

    git -C "$repo_dir" push -q -u origin "$branch"
    git -C "$repo_dir" push -q origin "refs/tags/$tag"

    local_sha=$(git -C "$repo_dir" rev-parse "$branch")
    remote_sha=$(git -C "$repo_dir" ls-remote origin "refs/heads/$branch" | awk '{print $1}')
    [ "$local_sha" = "$remote_sha" ] || fail "$agent branch was not pushed at the expected commit."
    git -C "$repo_dir" ls-remote --exit-code origin "refs/tags/$tag" >/dev/null || \
        fail "$agent tag was not pushed to GitHub."

    printf 'y\n' | (
        cd "$repo_dir"
        EDITOR=true \
            GITAI_AGENT="$agent" \
            GITAI_MODEL='' \
            GITAI_LANG=English \
            GITAI_PR_PROMPT_TITLE="$TEST_ROOT/pr-title-$agent.txt" \
            GITAI_PR_PROMPT_BODY="$TEST_ROOT/pr-body-$agent.txt" \
            "$PROJECT_ROOT/aipr" --base main
    ) >"$pr_output"

    pr_json=$(gh pr view "$branch" --repo "$REPO_SLUG" \
        --json url,title,body,state,headRefName,baseRefName)
    printf '%s\n' "$pr_json" | jq -e \
        --arg title_marker "$title_marker" \
        --arg body_marker "$body_marker" \
        --arg branch "$branch" \
        '.state == "OPEN"
         and .headRefName == $branch
         and .baseRefName == "main"
         and (.title | contains($title_marker))
         and (.body | contains($body_marker))' >/dev/null || \
        fail "$agent pull request did not match the expected title, body, state, or branches: $pr_json"

    pr_url=$(printf '%s\n' "$pr_json" | jq -r '.url')
    PR_URLS+=("$agent: $pr_url")
    log "$agent passed: $pr_url"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --keep-repo)
            KEEP_REPO=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

for command in git gh jq awk; do
    require_command "$command"
done
for agent in "${AGENTS[@]}"; do
    require_command "$(agent_command "$agent")"
done
for command in ai-commit-msg aitag aipr gitai-agent gitai-common.sh; do
    [ -x "$PROJECT_ROOT/$command" ] || fail "$PROJECT_ROOT/$command is not executable."
done
CLAUDE_AUTH_JSON=$(claude auth status 2>&1) || \
    fail "Claude Code is not authenticated. Run 'claude auth login' first."
printf '%s\n' "$CLAUDE_AUTH_JSON" | jq -e '.loggedIn == true' >/dev/null 2>&1 || \
    fail "Claude Code is not authenticated. Run 'claude auth login' first."
AUTH_JSON=$(gh auth status --active --hostname github.com --json hosts 2>/dev/null) || \
    fail "Could not inspect gh authentication. Run 'gh auth login' first."
AUTH_STATE=$(printf '%s\n' "$AUTH_JSON" | jq -r \
    '.hosts["github.com"][] | select(.active == true) | .state' | head -n1)
[ "$AUTH_STATE" = success ] || fail "gh is not authenticated for github.com. Run 'gh auth login' first."

if [ "$KEEP_REPO" = 0 ]; then
    AUTH_SCOPES=$(printf '%s\n' "$AUTH_JSON" | jq -r \
        '.hosts["github.com"][] | select(.active == true) | .scopes // ""' | head -n1)
    NORMALIZED_SCOPES=${AUTH_SCOPES// /}
    if [ -n "$NORMALIZED_SCOPES" ]; then
        case ",$NORMALIZED_SCOPES," in
            *,delete_repo,*) ;;
            *)
                fail "Default cleanup requires the delete_repo scope. Run 'gh auth refresh -h github.com -s delete_repo', or use --keep-repo."
                ;;
        esac
    fi
fi

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gitai-integration.XXXXXX")
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

RUN_ID="$(date -u +%Y%m%d%H%M%S)-$$-$RANDOM"
OWNER=$(gh api user --jq '.login')
[ -n "$OWNER" ] || fail "Could not determine the active GitHub account."
REPO_NAME="gitai-integration-$RUN_ID"
REPO_SLUG="$OWNER/$REPO_NAME"
REPO_URL="https://github.com/$REPO_SLUG"
REPO_DIR="$TEST_ROOT/repo"

if gh repo view "$REPO_SLUG" >/dev/null 2>&1; then
    fail "Refusing to use existing repository $REPO_SLUG."
fi

log "Creating private GitHub repository $REPO_SLUG"
gh repo create "$REPO_SLUG" --private --description "Temporary gitai integration test repository"
REMOTE_CREATED=1
gh repo clone "$REPO_SLUG" "$REPO_DIR"
git -C "$REPO_DIR" config user.name "gitai integration test"
git -C "$REPO_DIR" config user.email "gitai-integration@example.invalid"
git -C "$REPO_DIR" symbolic-ref HEAD refs/heads/main
printf 'gitai integration test repository\n' >"$REPO_DIR/README.md"
git -C "$REPO_DIR" add README.md
git -C "$REPO_DIR" commit -q -m "chore: initialize integration repository"
git -C "$REPO_DIR" push -q -u origin main

index=1
for agent in "${AGENTS[@]}"; do
    run_agent_test "$agent" "$index" "$REPO_DIR"
    index=$((index + 1))
done

printf '\nAll GitHub integration tests passed for: %s\n' "${AGENTS[*]}"
