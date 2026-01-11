# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`gitai` is a shell script-based CLI toolset that uses AI (via the `llm` command) to help with Git workflows: generating commit messages, pull requests, and tags.

## Core Tools

| Script | Purpose | Dependencies |
|--------|---------|--------------|
| `ai-commit-msg` | Git hook for auto-generating commit messages | `llm`, `git` |
| `aipr` | Generate PR titles/bodies, create/update PRs | `llm`, `git`, `gh`, `jq` |
| `aitag` | Generate annotated/signed tag messages | `llm`, `git` |

## Architecture

All scripts follow a consistent pattern:
1. Config init → 2. Dependency check → 3. Input gathering (git diff) → 4. LLM call → 5. User confirmation → 6. Git operation

### Shared Patterns
- `spin_animation()` / `kill_spin()`: Terminal spinner during LLM processing
- `cleanup()`: SIGINT handler
- `init_config()`: Copy default prompts from Homebrew install to `~/.config/gitai/prompts/`
- ANSI color codes: `RED`, `GREEN`, `YELLOW`, `BLUE`, `NC`

## Development

### Testing Scripts
```bash
./ai-commit-msg --help
./aipr --help
./aitag --help
```

### Local Git Hook Testing
```bash
ln -s $(pwd)/ai-commit-msg ~/.git-hooks/prepare-commit-msg
git config --global core.hooksPath ~/.git-hooks
```

## Configuration

### Environment Variables
- `GITAI_MODEL`: Default LLM model
- `GITAI_LANG`: Language for generated content (default: English)
- `GITAI_SKIP_AI_COMMIT_MSG_HOOK`: Skip the commit hook when set
- `GITAI_COMMIT_MSG_PROMPT`, `GITAI_PR_PROMPT_TITLE`, `GITAI_PR_PROMPT_BODY`, `GITAI_TAG_PROMPT`: Custom prompt file paths

### Prompt Files
Default location: `~/.config/gitai/prompts/`
- Fallback prompts shipped in `prompts/` directory
- Homebrew installs to `$(brew --prefix)/share/gitai/prompts/`

## Shell Completions
Located in `completions/`:
- Bash: `aipr.bash`, `aitag.bash`
- Zsh: `_aipr`, `_aitag`
- Fish: `aipr.fish`, `aitag.fish`

## Key Implementation Details

### ai-commit-msg
- Exits early for merge commits (checks if `$2` is set)
- Prepends generated message to existing commit file content
- Uses `git diff --cached` for staged changes

### aipr
- Auto-discovers PR templates in `.github/`, `docs/`, or root
- Supports forked repos (different head/base remotes)
- Checks for unpushed commits and offers to push
- Updates existing PRs if one already exists for the branch

### aitag
- Uses diff since last tag, or all files if no previous tags exist
- Opens editor for message review before creating tag
