#!/usr/bin/env bash
# gitai-common.sh - Shared library for gitai tools
# This library provides common functionality used across all gitai scripts

# Prevent multiple sourcing
if [ -n "$GITAI_COMMON_LOADED" ]; then
	return 0
fi
GITAI_COMMON_LOADED=1

# ============================================================================
# ANSI Color Codes
# ============================================================================
# These color codes are used for styling terminal output across all gitai tools

GITAI_RED='\033[0;31m'    # Error messages
GITAI_GREEN='\033[0;32m'  # Success messages
GITAI_YELLOW='\033[0;33m' # Warnings and info
GITAI_BLUE='\033[0;34m'   # Headers and highlights
GITAI_NC='\033[0m'        # Reset to default color

# Backward compatibility aliases (scripts can use either)
RED="$GITAI_RED"
GREEN="$GITAI_GREEN"
YELLOW="$GITAI_YELLOW"
BLUE="$GITAI_BLUE"
NC="$GITAI_NC"

# ============================================================================
# Global State Variables
# ============================================================================

GITAI_SPIN_PID=
GITAI_TEMP_FILES=()

# Backward compatibility
SPIN_PID=
TEMP_FILES=()

# ============================================================================
# Spinner Animation Functions
# ============================================================================

# Display a spinning animation during long-running operations
# Usage: gitai_spin_animation "Loading message" &
#        GITAI_SPIN_PID=$!
gitai_spin_animation() {
	local msg="$1"

	# Only show animation if output is going to a terminal
	if ! [ -t 1 ]; then
		echo "$msg..." # Just show the message without animation
		return
	fi

	# Array of spinner characters for the animation
	local spinner=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

	# Infinite loop to keep the animation running
	while true; do
		for i in "${spinner[@]}"; do
			tput civis                                                # Hide cursor
			tput el1                                                  # Clear line from cursor to beginning
			printf "\r${GITAI_YELLOW}%s${GITAI_NC} %s..." "$i" "$msg" # Print spinner and message
			sleep 0.1                                                 # Control animation speed
			tput cub $((${#msg} + 5))                                 # Move cursor back
		done
	done
}

# Backward compatibility wrapper
spin_animation() {
	gitai_spin_animation "$@"
}

# Stop the spinner animation
# Usage: gitai_kill_spin
gitai_kill_spin() {
	local pid_var="${1:-GITAI_SPIN_PID}"
	local pid="${!pid_var}"

	if [ -n "$pid" ]; then
		kill "$pid" 2>/dev/null
		wait "$pid" 2>/dev/null
		eval "$pid_var="
		printf "\n"
	fi
}

# Backward compatibility wrapper
kill_spin() {
	# Check both SPIN_PID and GITAI_SPIN_PID for backward compatibility
	if [ -n "$SPIN_PID" ]; then
		gitai_kill_spin SPIN_PID
	elif [ -n "$GITAI_SPIN_PID" ]; then
		gitai_kill_spin GITAI_SPIN_PID
	fi
}

# ============================================================================
# Cleanup and Signal Handling
# ============================================================================

# Default cleanup handler for SIGINT
# Usage: trap gitai_cleanup SIGINT
gitai_cleanup() {
	echo -e "\n${GITAI_RED}Script interrupted. Cleaning up...${GITAI_NC}"
	gitai_kill_spin
	tput cnorm # Show the cursor
	exit 1
}

# Backward compatibility wrapper
cleanup() {
	gitai_cleanup
}

# ============================================================================
# Temporary File Management
# ============================================================================

# Create a temporary file and track it for cleanup
# Usage: temp_file=$(gitai_create_temp_file "suffix")
gitai_create_temp_file() {
	local suffix="${1:-gitai}"
	local temp_file

	# Try GNU mktemp with suffix support, fall back to portable version for macOS
	temp_file=$(mktemp -q --suffix="$suffix" 2>/dev/null || mktemp -q -t "$suffix")

	if [[ -z "$temp_file" || ! -f "$temp_file" ]]; then
		echo "Error: Failed to create temporary file." >&2
		exit 1
	fi

	# Track in both arrays for backward compatibility
	GITAI_TEMP_FILES+=("$temp_file")
	TEMP_FILES+=("$temp_file")

	echo "$temp_file"
	return 0
}

# Backward compatibility wrapper
create_temp_file() {
	gitai_create_temp_file "$@"
}

# Setup automatic cleanup of temp files on exit
# Usage: gitai_setup_temp_cleanup (called automatically)
gitai_setup_temp_cleanup() {
	trap 'rm -f "${GITAI_TEMP_FILES[@]}" "${TEMP_FILES[@]}"' EXIT SIGINT TERM
}

# ============================================================================
# Git Utility Functions
# ============================================================================

# Check if current directory is inside a git repository
# Returns: 0 if in git repo, 1 otherwise
gitai_is_git_repo() {
	git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Backward compatibility wrapper
is_git_repo() {
	gitai_is_git_repo
}

# Get the current git branch name
# Returns: branch name or empty string on error
gitai_get_current_branch() {
	git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Backward compatibility wrapper
get_current_branch() {
	gitai_get_current_branch
}

# Get the remote for a given branch
# Usage: gitai_get_branch_remote "branch-name"
gitai_get_branch_remote() {
	local branch="$1"
	if [ -z "$branch" ]; then
		return 1
	fi

	local remote
	remote=$(git config --get "branch.$branch.remote" 2>/dev/null)

	if [ -z "$remote" ]; then
		# If no remote configured, try to select one
		if command -v gitai_select_remote >/dev/null 2>&1; then
			remote=$(gitai_select_remote)
		fi
	fi

	echo "$remote"
}

# Backward compatibility wrapper
get_branch_remote() {
	gitai_get_branch_remote "$@"
}

# Convert remote name to URL
# Usage: gitai_remote_to_url "origin"
gitai_remote_to_url() {
	git remote get-url "$1" 2>/dev/null
}

# Backward compatibility wrapper
remote_2_url() {
	gitai_remote_to_url "$@"
}

# ============================================================================
# Command Checking
# ============================================================================

# Check if required commands are installed
# Usage: gitai_check_required_commands git llm jq
# Returns: 0 if all commands exist, number of missing commands otherwise
gitai_check_required_commands() {
	local missing=0
	local cmd

	for cmd in "$@"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			echo -e "${GITAI_RED}Error: $cmd is not installed${GITAI_NC}" >&2
			missing=$((missing + 1))
		fi
	done

	return $missing
}

# Backward compatibility wrapper
check_required_commands() {
	gitai_check_required_commands "$@"
}

# ============================================================================
# Configuration Management
# ============================================================================

# Initialize configuration file from Homebrew installation
# Usage: gitai_init_config "/path/to/default/file.txt" "prompts/file.txt"
# Args: $1 = default config path, $2 = homebrew relative path
gitai_init_config() {
	local default_file="$1"
	local brew_relative_path="$2"

	if [ ! -f "$default_file" ]; then
		local brew_file
		brew_file="$(brew --prefix 2>/dev/null)/share/gitai/$brew_relative_path"

		if [ ! -f "$brew_file" ]; then
			echo -e "${GITAI_RED}Error: Can't find default configuration file." >&2
			echo -e "Expected at: $default_file" >&2
			echo -e "Or Homebrew location: $brew_file${GITAI_NC}" >&2
			return 1
		fi

		local dir
		dir=$(dirname "$default_file")
		mkdir -p "$dir"
		cp "$brew_file" "$default_file"

		echo -e "${GITAI_GREEN}Initialized config: $default_file${GITAI_NC}" >&2
	fi

	return 0
}

# ============================================================================
# LLM Integration
# ============================================================================

# Setup LLM model from environment or default
# Usage: gitai_setup_llm_model
# Sets: LLM_MODEL environment variable
gitai_setup_llm_model() {
	local model="${GITAI_MODEL}"

	if [ -z "$model" ]; then
		if command -v llm >/dev/null 2>&1; then
			model=$(llm models default 2>/dev/null)
		fi
	fi

	if [ -n "$model" ]; then
		export LLM_MODEL="$model"
	fi

	echo "$model"
}

# Call LLM with a prompt and input, showing spinner
# Usage: result=$(gitai_call_llm "prompt text" "input text" "spinner message")
gitai_call_llm() {
	local prompt="$1"
	local input="$2"
	local spinner_msg="${3:-Generating with LLM}"

	gitai_spin_animation "$spinner_msg" &
	GITAI_SPIN_PID=$!
	SPIN_PID=$GITAI_SPIN_PID # Backward compatibility

	local result
	result=$(echo "$input" | llm -s "$prompt" 2>&1)
	local exit_code=$?

	gitai_kill_spin

	if [ $exit_code -ne 0 ]; then
		echo -e "${GITAI_RED}Error: LLM command failed:${GITAI_NC}" >&2
		echo "$result" >&2
		return 1
	fi

	echo "$result"
	return 0
}

# Generate content using a prompt file
# Usage: result=$(gitai_generate_with_prompt_file "prompt.txt" "input" "language" "spinner msg")
gitai_generate_with_prompt_file() {
	local prompt_file="$1"
	local input="$2"
	local language="${3:-English}"
	local spinner_msg="${4:-Generating content}"

	if [ ! -f "$prompt_file" ]; then
		echo -e "${GITAI_RED}Error: Prompt file not found: $prompt_file${GITAI_NC}" >&2
		return 1
	fi

	local prompt_content
	prompt_content=$(cat "$prompt_file")

	local full_prompt
	full_prompt=$(
		cat <<EOF
All non-code text responses must be written in the $language language indicated.

$prompt_content
EOF
	)

	gitai_call_llm "$full_prompt" "$input" "$spinner_msg"
}

# ============================================================================
# Library Initialization
# ============================================================================

# Automatically setup temp file cleanup when library is sourced
gitai_setup_temp_cleanup

# Export functions for use in scripts
export -f gitai_spin_animation spin_animation
export -f gitai_kill_spin kill_spin
export -f gitai_cleanup cleanup
export -f gitai_create_temp_file create_temp_file
export -f gitai_is_git_repo is_git_repo
export -f gitai_get_current_branch get_current_branch
export -f gitai_get_branch_remote get_branch_remote
export -f gitai_remote_to_url remote_2_url
export -f gitai_check_required_commands check_required_commands
export -f gitai_init_config
export -f gitai_setup_llm_model
export -f gitai_call_llm
export -f gitai_generate_with_prompt_file
