# AGENTS.md

This file provides guidance to AI coding agents working in the `gitai` repository.

## Project Overview

`gitai` is a shell script-based CLI toolset that uses AI (via the `llm` command) to help with Git workflows: generating commit messages (`ai-commit-msg`), creating pull requests (`aipr`), and generating tags (`aitag`).

**Language**: Bash shell scripts
**Dependencies**: `git`, `llm`, `gh` (GitHub CLI), `jq`, `bats-core` (testing)

## Architecture

The project uses a **shared library pattern** to eliminate code duplication:
- `lib/gitai-common.sh` (375 lines) - Shared library with common functions
- `aipr` (581 lines) - PR creation/update tool
- `aitag` (184 lines) - Tag generation tool
- `ai-commit-msg` (139 lines) - Git commit message hook

All scripts source the shared library for common functionality (colors, spinner, temp files, git utils, LLM integration).

## Build/Test/Lint Commands

### No Build System
Executable bash scripts - no compilation required.

### Testing with BATS
The project uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) with **67 tests** (all passing).

```bash
# Install BATS
brew install bats-core

# Run all tests (67 tests)
bats tests/

# Run specific test file
bats tests/gitai-common.bats  # 41 library tests
bats tests/aipr.bats          # 9 aipr tests
bats tests/aitag.bats         # 9 aitag tests
bats tests/ai-commit-msg.bats # 8 commit msg tests

# Run single test by name
bats tests/gitai-common.bats -f "gitai_create_temp_file"

# Run with verbose output
bats -t tests/

# Run specific test by line number
bats tests/gitai-common.bats:42
```

**Test Structure**:
- `tests/test_helper.bash` - Mock utilities (git, llm, gh, jq, brew)
- All external commands are mocked - no real git operations or AI calls
- Tests run in isolated temporary directories with automatic cleanup

### Linting
```bash
shellcheck ai-commit-msg aipr aitag lib/gitai-common.sh
```

## Code Style Guidelines

### Shared Library Pattern
All scripts source `lib/gitai-common.sh` with Homebrew-aware loading:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITAI_LIB_PATH="${GITAI_LIB_PATH:-$(brew --prefix 2>/dev/null)/share/gitai/lib/gitai-common.sh}"

if [ -f "$GITAI_LIB_PATH" ]; then
    source "$GITAI_LIB_PATH"
elif [ -f "$SCRIPT_DIR/lib/gitai-common.sh" ]; then
    source "$SCRIPT_DIR/lib/gitai-common.sh"
else
    echo "Error: Cannot find gitai-common.sh library" >&2
    exit 1
fi
```

### Naming Conventions
- **Library functions**: `gitai_function_name()` (e.g., `gitai_spin_animation`, `gitai_create_temp_file`)
- **Backward compat wrappers**: `function_name()` calls `gitai_function_name()`
- **Global variables**: `UPPERCASE` (e.g., `GITAI_SPIN_PID`, `GITAI_TEMP_FILES`)
- **Local variables**: `lowercase` with `local` keyword
- **Constants**: `UPPERCASE` (e.g., `GITAI_RED='\033[0;31m'`)

### Formatting
- **Indentation**: 4 spaces (no tabs)
- **Line length**: ~120 chars preferred
- **Quoting**: Always quote variables: `"$variable"`
- **Arrays**: Track with `ARRAY_NAME+=("$item")`

### Error Handling
```bash
# Check git repo
if ! gitai_is_git_repo; then
    echo -e "${GITAI_RED}Error: Not in a Git repository${GITAI_NC}" >&2
    exit 1
fi

# Check required commands
gitai_check_required_commands git llm gh jq || exit 1

# Validate inputs early
if [ -z "$TAG_NAME" ]; then
    echo -e "${GITAI_RED}Error: Tag name required${GITAI_NC}" >&2
    exit 1
fi
```

### Common Library Functions
Use these from `lib/gitai-common.sh`:

```bash
# Colors (use GITAI_ prefix or backward compat aliases)
echo -e "${GITAI_GREEN}Success${GITAI_NC}"

# Temp files (auto-cleanup on EXIT/SIGINT/TERM)
temp_file=$(gitai_create_temp_file ".txt")

# Git utilities
gitai_is_git_repo                    # Check if in git repo
gitai_get_current_branch             # Get current branch name
gitai_remote_to_url "origin"         # Get remote URL

# Command checking
gitai_check_required_commands git llm gh

# Config initialization (Homebrew-aware)
gitai_init_config "$config_file" "prompts/file.txt"

# LLM integration
gitai_setup_llm_model                # Setup LLM_MODEL env var
gitai_call_llm "prompt" "input" "msg"
gitai_generate_with_prompt_file "$file" "input" "English" "msg"

# Spinner animation
gitai_spin_animation "Loading..." &
GITAI_SPIN_PID=$!
# ... do work ...
gitai_kill_spin

# Cleanup handler
trap gitai_cleanup SIGINT
```

### Writing Tests
Use BATS with test helpers:

```bash
#!/usr/bin/env bats
load test_helper

setup() {
    setup_mock_environment  # Creates temp dir, mocks all commands
    setup_git_repo          # Creates mock git repo
}

teardown() {
    teardown_test_dir       # Cleans up
}

@test "description of test" {
    run command_to_test
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected output" ]]
}
```

**Available mocks**: `mock_git`, `mock_llm`, `mock_gh`, `mock_jq`, `mock_brew`

## Environment Variables

- `GITAI_MODEL` - Default LLM model
- `GITAI_LANG` - Language for generated content (default: English)
- `GITAI_SKIP_AI_COMMIT_MSG_HOOK` - Skip commit hook when set
- `GITAI_COMMIT_MSG_PROMPT` - Custom commit message prompt path
- `GITAI_PR_PROMPT_TITLE` - Custom PR title prompt path
- `GITAI_PR_PROMPT_BODY` - Custom PR body prompt path
- `GITAI_TAG_PROMPT` - Custom tag prompt path
- `GITAI_LIB_PATH` - Override library path (for testing)

## Making Changes

### Adding Common Functionality
1. Add to `lib/gitai-common.sh` with `gitai_` prefix
2. Add backward compatibility wrapper if needed
3. Export function: `export -f gitai_function_name`
4. Write tests in `tests/gitai-common.bats`
5. Update this file if it's a commonly used pattern

### Modifying Scripts
1. **Maintain backward compatibility** - critical for Homebrew users
2. Use library functions instead of duplicating code
3. Write BATS tests for new functionality
4. Update help text in `show_help()` function
5. Test with: `bats tests/` and manual testing

### Writing Tests
1. Add tests to appropriate `tests/*.bats` file
2. Use mocks from `test_helper.bash` - never call real git/llm/gh
3. Test both success and failure cases
4. Keep tests focused and independent
5. Run `bats tests/` to verify all tests pass

## Common Pitfalls

- **Library loading**: Always use the Homebrew-aware pattern above
- **Quoting**: Always quote variables to handle spaces
- **Mocking**: In tests, mock ALL external commands (git, llm, gh, jq)
- **Temp files**: Use `gitai_create_temp_file()` for auto-cleanup
- **Exit codes**: Return 0 for success, 1 for failure
- **Error output**: Use `>&2` for all error messages
- **Portability**: Use `mktemp -q -t` for macOS compatibility
- **Backward compat**: Keep old function names as wrappers

## Key Files

- `lib/gitai-common.sh` - Shared library (375 lines)
- `ai-commit-msg` - Git hook (139 lines)
- `aipr` - PR tool (581 lines)
- `aitag` - Tag tool (184 lines)
- `tests/` - BATS test suite (67 tests, 1547 lines)
- `prompts/` - LLM prompt templates
- `completions/` - Shell completions (bash, zsh, fish)

## Reference

See `CLAUDE.md` for additional context and `REFACTORING_SUMMARY.md` for details on the shared library refactoring.
