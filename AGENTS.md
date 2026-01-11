# AGENTS.md

This file provides guidance to AI coding agents working in the `gitai` repository.

## Project Overview

`gitai` is a shell script-based CLI toolset that uses AI (via the `llm` command) to help with Git workflows: generating commit messages (`ai-commit-msg`), creating pull requests (`aipr`), and generating tags (`aitag`).

**Language**: Bash shell scripts
**Dependencies**: `git`, `llm`, `gh` (GitHub CLI), `jq`

## Build/Test/Lint Commands

### No Build System
This project consists of executable bash scripts with no compilation or build step required.

### Testing Scripts
There is no automated test framework. Test manually:

```bash
# Test help output
./ai-commit-msg --help
./aipr --help
./aitag --help

# Test ai-commit-msg as git hook
ln -s $(pwd)/ai-commit-msg ~/.git-hooks/prepare-commit-msg
git config --global core.hooksPath ~/.git-hooks
# Make changes and run: git commit

# Test aipr (requires git repo with changes)
./aipr --help
./aipr -B main -H feature-branch

# Test aitag
./aitag --help
./aitag v1.0.0
```

### Linting
No automated linting configured. Use `shellcheck` manually if available:
```bash
shellcheck ai-commit-msg aipr aitag
```

### Running Single Test
N/A - no test framework exists. All testing is manual/integration testing.

## Code Style Guidelines

### File Structure
All scripts follow this pattern:
1. Shebang (`#!/usr/bin/env bash`)
2. ANSI color code definitions
3. Default config paths
4. Helper functions (spin_animation, cleanup, etc.)
5. Main logic functions
6. Argument parsing
7. Main execution flow

### Formatting
- **Indentation**: 4 spaces (no tabs)
- **Line length**: No strict limit, but keep readable (~120 chars preferred)
- **Blank lines**: Use to separate logical sections

### Naming Conventions
- **Functions**: `snake_case` (e.g., `spin_animation`, `check_required_commands`, `is_git_repo`)
- **Global variables**: `UPPERCASE` (e.g., `SPIN_PID`, `DEFAULT_PROMPT_FILE`, `TEMP_FILES`)
- **Local variables**: `lowercase` (e.g., `local branch="$1"`, `local remote`)
- **Constants**: `UPPERCASE` (e.g., `RED='\033[0;31m'`, `NC='\033[0m'`)

### Variables and Types
- Always quote variables: `"$variable"` not `$variable`
- Use `local` for function-scoped variables
- Declare arrays: `local -a array_name` or `ARRAY_NAME=()`
- Use `${variable}` for clarity in complex expressions

### Imports/Dependencies
- Check required commands at script start:
  ```bash
  check_required_commands() {
      for cmd in git llm; do
          if ! command -v "$cmd" >/dev/null 2>&1; then
              echo "Error: $cmd is not installed"
          fi
      done
  }
  ```
- No formal import system (bash doesn't have one)
- External dependencies: `git`, `llm`, `gh`, `jq`, `mktemp`, `tput`

### Error Handling
- **Exit codes**: Use `exit 1` for errors, `exit 0` for success
- **Error messages**: Write to stderr with `>&2`
- **Color errors**: Use `${RED}Error: message${NC}` format
- **Validation**: Check inputs before use (git repo, file exists, valid commit, etc.)
- **Cleanup**: Always use `trap cleanup SIGINT` for interrupt handling
- **Early returns**: Exit early on validation failures

Example:
```bash
if ! is_git_repo; then
    echo -e "${RED}Error: Not in a Git repository${NC}" >&2
    exit 1
fi
```

### Functions
- Define functions before they're called
- Use `local` for all function variables
- Return 0 for success, 1 for failure
- Document complex functions with comments

### Comments
- Use `#` for single-line comments
- Explain "why" not "what" for complex logic
- Credit sources when adapting code (e.g., Harper Reed reference)
- Document function purpose for non-obvious functions

### ANSI Colors
Always define at top of script:
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color
```

Use with `echo -e`: `echo -e "${GREEN}Success${NC}"`

### Shared Patterns

#### Spinner Animation
All scripts use `spin_animation()` and `kill_spin()` for long-running LLM operations:
```bash
spin_animation "Generating message" &
SPIN_PID=$!
# ... do work ...
kill_spin
```

#### Cleanup Handler
```bash
cleanup() {
    echo -e "\n${RED}Script interrupted. Cleaning up...${NC}"
    kill_spin
    tput cnorm  # Show cursor
    exit 1
}
trap cleanup SIGINT
```

#### Config Initialization
```bash
init_config() {
    if [ ! -f "$DEFAULT_PROMPT_FILE" ]; then
        brew_prompt=$(brew --prefix)/share/gitai/prompts/filename.txt
        if [ ! -f "$brew_prompt" ]; then
            echo "Error: Can't find default config" >&2
            exit 1
        fi
        mkdir -p "$(dirname "$DEFAULT_PROMPT_FILE")"
        cp "$brew_prompt" "$DEFAULT_PROMPT_FILE"
    fi
}
```

#### Temp File Management
```bash
TEMP_FILES=()
trap 'rm -f "${TEMP_FILES[@]}"' EXIT SIGINT TERM

create_temp_file() {
    local temp_file
    temp_file=$(mktemp -q -t "gitai")
    TEMP_FILES+=("$temp_file")
    echo "$temp_file"
}
```

## Environment Variables

Scripts respect these environment variables:
- `GITAI_MODEL`: Default LLM model
- `GITAI_LANG`: Language for generated content (default: English)
- `GITAI_SKIP_AI_COMMIT_MSG_HOOK`: Skip commit hook when set
- `GITAI_COMMIT_MSG_PROMPT`: Custom commit message prompt path
- `GITAI_PR_PROMPT_TITLE`: Custom PR title prompt path
- `GITAI_PR_PROMPT_BODY`: Custom PR body prompt path
- `GITAI_TAG_PROMPT`: Custom tag prompt path

## Key Files

- `ai-commit-msg`: Git prepare-commit-msg hook (173 lines)
- `aipr`: PR creation/update tool (618 lines)
- `aitag`: Tag generation tool (210 lines)
- `prompts/`: Default prompt templates
- `completions/`: Shell completion scripts (bash, zsh, fish)
- `CLAUDE.md`: Additional context for Claude Code

## Making Changes

### Adding New Features
1. Follow existing script patterns
2. Add help text to `show_help()` function
3. Update README.md with new options
4. Test manually with various scenarios
5. Consider adding shell completions

### Modifying Existing Scripts
1. Maintain backward compatibility
2. Keep consistent with other scripts' patterns
3. Test all code paths manually
4. Update help text if changing options

### Prompt Templates
Located in `prompts/` directory. Follow existing format:
- Clear instructions for LLM
- Specify output format
- Include "Think carefully" reminder
- Keep concise but complete

## Common Pitfalls

- **Quoting**: Always quote variables to handle spaces
- **Exit codes**: Check command success with `if ! command; then`
- **Portability**: Use `mktemp -q -t` for macOS compatibility
- **Terminal detection**: Check `[ -t 1 ]` before using tput/animations
- **Cleanup**: Always trap signals and clean up temp files
- **Error output**: Use `>&2` for all error messages

## Reference: CLAUDE.md

See `CLAUDE.md` for additional context on architecture, implementation details, and testing approaches.
