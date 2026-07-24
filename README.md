# gitai

`gitai` is a set of command-line tools that use a locally installed AI coding agent to help with your Git workflow. It can help you write commit messages, create pull requests, and generate tags.

## Requirements

Install and configure at least one supported agent: [pi](https://github.com/badlogic/pi-mono), [Oh My Pi](https://github.com/can1357/oh-my-pi), [Codex CLI](https://github.com/openai/codex), or [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview). `gitai` invokes the selected agent non-interactively without write-capable tools and without persisting a session.

Set `GITAI_AGENT` to choose an agent explicitly. Accepted values are `pi`, `oh-my-pi` (or `omp`), `codex`, and `claude-code` (or `claude`). When it is unset, `gitai` uses the first available agent in this order: pi, Oh My Pi, Codex, Claude Code. It exits with an error if none is available.

## Installation

```bash
brew install tenfyzhong/tap/gitai
```

## Tools

### `ai-commit-msg`

`ai-commit-msg` is a git hook that uses AI to generate a commit message for you. It is run automatically when you run `git commit`.

#### Global Setup (Recommended)

This method will apply the hook to all your local repositories.

1. **Create a global hooks directory:**

    ```bash
    mkdir -p ~/.git-hooks
    ```

2. **Configure Git to use this directory:**

    ```bash
    git config --global core.hooksPath ~/.git-hooks
    ```

3. **Link the hook script:**

    ```bash
    ln -s "$(which ai-commit-msg)" ~/.git-hooks/prepare-commit-msg
    ```

#### Per-Project Setup

If you want to use the hook only for a specific project:

1. **Navigate into your project's hooks directory:**

    ```bash
    cd /path/to/your/repo/.git/hooks
    ```

2. **Link the hook script:**

    ```bash
    ln -s "$(which ai-commit-msg)" ./prepare-commit-msg
    ```

Now, whenever you run `git commit`, the hook will automatically generate a commit message for you.

### `aipr`

`aipr` is a command-line tool that uses AI to generate a pull request for you. It generates the title and body together in one agent interaction based on the changes in your current branch.

#### Usage

```bash
aipr [options]
```

**Options:**

* `-r, --remote <name>`: The remote repository to use (default: `origin`).
* `-B, --base <branch>`: The branch into which you want your code merged.
* `-H, --head <branch>`: The branch that contains commits for your pull request (default: current branch).
* `-T, --template <file>`: Specify a PR template file to use.
* `--prompt-title <file>`: Path to PR title prompt template (default: `$HOME/.config/gitai/prompts/aipr-title-prompt.txt`).
* `--prompt-body <file>`: Path to PR body prompt template (default: `$HOME/.config/gitai/prompts/aipr-body-prompt.txt`).
* `--model <model>`: Model to use with the selected agent.
* `--update-title`: Update PR title when editing existing PR.
* `--lang <lang>`: Generate content in specified language (default: `English`).
* `-h, --help`: Show this help message.

All flags provided by `gh pr create/edit` can be passed to the `aipr` command.

### `aitag`

`aitag` is a command-line tool that uses AI to generate a tag for you. It will generate a tag message for you based on the changes since the last tag.

#### Usage

```bash
aitag [OPTIONS] TAG_NAME [COMMIT]
```

**Options:**

* `-a, --annotate`: Create an annotated tag.
* `-s, --sign`: Create a signed tag.
* `-u, --local-user USER`: Create tag with specific user.
* `--prompt FILE`: Use custom prompt file (default: `$HOME/.config/gitai/prompts/aitag-prompt.txt`)..
* `--model <model>`: Model to use with the selected agent.
* `--lang <lang>`: Generate content in specified language (default: `English`).
* `-h, --help`: Show this help message.

## Customizing Prompts

You can customize the prompts used by `gitai` by creating your own prompt files. The default prompt files are located in `$HOME/.config/gitai/prompts`.

You can specify a custom prompt file using the `--prompt` flag for `aitag`, and `--prompt-title` and `--prompt-body` for `aipr`.

## Environment Variables

* `GITAI_AGENT`: Select `pi`, `oh-my-pi`, `codex`, or `claude-code`. Common executable-name aliases `omp` and `claude` are also accepted. When unset, agents are auto-detected in that order.
* `GITAI_MODEL`: Set the model to use. When unset, the selected agent's configured default is used.
* `GITAI_LANG`: Set the default language for generation.
* `GITAI_COMMIT_MSG_PROMPT`: Override the default commit message prompt file path.
* `GITAI_PR_PROMPT_TITLE`: Override the default PR title prompt file path.
* `GITAI_PR_PROMPT_BODY`: Override the default PR body prompt file path.
* `GITAI_TAG_PROMPT`: Override the default tag prompt file path.
* `GITAI_SKIP_AI_COMMIT_MSG_HOOK`: If set, the `ai-commit-msg` hook will be skipped.

## Testing

Run the shell integration suite with `tests/run.sh`. The tests use temporary Git repositories and stubbed agent commands, so they do not make AI requests.

To run the real GitHub end-to-end suite, first configure all four supported agents. Claude Code must be signed in (`claude auth login`), and `gh` must have permission to create and delete private repositories. Classic OAuth tokens need the `delete_repo` scope, which can be added with `gh auth refresh -h github.com -s delete_repo`. Then run:

```bash
tests/integration-github.sh
```

The suite creates one temporary private GitHub repository. For each of pi, Oh My Pi, Codex, and Claude Code, it creates a branch, generates and verifies a commit message with `ai-commit-msg`, creates and verifies an annotated tag with `aitag`, creates a pull request with `aipr`, and verifies the remote branch, tag, PR title, PR body, state, and base/head branches. The local temporary directory and GitHub repository are deleted on success or failure.

Use `--keep-repo` to retain the GitHub repository for manual verification:

```bash
tests/integration-github.sh --keep-repo
```

The retained repository and PR URLs are printed before the script exits. If automatic deletion fails, the script exits unsuccessfully and prints the exact `gh repo delete` command needed for cleanup.

To manually test this checkout in place of a Homebrew installation, run:

```bash
scripts/brew-dev-link link
```

This runs `brew unlink gitai` and links `aipr`, `aitag`, `ai-commit-msg`, the internal `gitai-agent` runner, and the shared `gitai-common.sh` runtime from the current checkout into Homebrew's `bin` directory. Restore the installed Homebrew version after testing with:

```bash
scripts/brew-dev-link restore
```

The restore command only removes symbolic links that point to the current checkout. It refuses to overwrite or remove unrelated paths.

## License

[MIT](LICENSE)
