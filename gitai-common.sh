#!/usr/bin/env bash

# Shared runtime functions for the gitai command entrypoints.

RED='\033[0;31m'
# Used by entrypoints that source this file.
# shellcheck disable=SC2034
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
# Used by entrypoints that source this file.
# shellcheck disable=SC2034
BLUE='\033[0;34m'
NC='\033[0m'

SPIN_PID=${SPIN_PID:-}

gitai_spin_animation() {
    local msg=$1
    if ! [ -t 1 ]; then
        echo "$msg..."
        return
    fi

    local spinner=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i
    while true; do
        for i in "${spinner[@]}"; do
            tput civis
            tput el1
            printf "\r${YELLOW}%s${NC} %s..." "$i" "$msg"
            sleep 0.1
            tput cub $((${#msg} + 5))
        done
    done
}

gitai_kill_spin() {
    if [ -n "$SPIN_PID" ]; then
        kill "$SPIN_PID" 2>/dev/null || true
        wait "$SPIN_PID" 2>/dev/null || true
        SPIN_PID=
        printf "\n"
    fi
}

gitai_handle_interrupt() {
    echo -e "\n${RED}Script interrupted. Cleaning up...${NC}"
    gitai_kill_spin
    tput cnorm
    exit 1
}

gitai_is_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

gitai_check_required_commands() {
    local missing=0
    local command
    for command in "$@"; do
        if ! command -v "$command" >/dev/null 2>&1; then
            echo "Error: $command is not installed"
            missing=$((missing + 1))
        fi
    done
    [ "$missing" -eq 0 ]
}

gitai_init_agent_runner() {
    local script_dir=$1
    local entrypoint=$2
    AGENT_RUNNER="$script_dir/gitai-agent"
    if [ ! -x "$AGENT_RUNNER" ]; then
        echo -e "${RED}Error: gitai-agent is not installed next to $entrypoint.${NC}" >&2
        return 1
    fi
}

gitai_check_agent_runner() {
    "$AGENT_RUNNER" --check >/dev/null
}

gitai_extract_json_object() {
    jq -ceRrs '
        . as $raw
        | first(
            ($raw | fromjson? | select(type == "object")),
            ($raw
                | sub("^\\s*```(?:json)?\\s*"; "")
                | sub("\\s*```\\s*$"; "")
                | fromjson?
                | select(type == "object")),
            ($raw | split("\n")[] | fromjson? | select(type == "object")),
            ($raw
                | try capture("(?s)(?<json>\\{.*\\})").json catch empty
                | fromjson?
                | select(type == "object"))
        )
    '
}

gitai_strip_code_fences() {
    awk 'BEGIN { in_fence=0 }
         /^[[:space:]]*```[a-zA-Z]*[[:space:]]*$/ { in_fence=!in_fence; next }
         !in_fence { print }'
}
