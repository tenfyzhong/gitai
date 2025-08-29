# gitai

`gitai` is a set of command-line tools that use AI to help you with your Git workflow. It can help you write commit messages, create pull requests, and generate tags.

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
    ln -s "$(which llm-commit-msg)" ~/.git-hooks/prepare-commit-msg
    ```

#### Per-Project Setup

If you want to use the hook only for a specific project:

1. **Navigate into your project's hooks directory:**

    ```bash
    cd /path/to/your/repo/.git/hooks
    ```

2. **Link the hook script:**

    ```bash
    ln -s "$(which llm-commit-msg)" ./prepare-commit-msg
    ```

Now, whenever you run `git commit`, the hook will automatically generate a commit message for you.

### `aipr`

`aipr` is a command-line tool that uses AI to generate a pull request for you. It will generate a title and body for your pull request based on the changes in your current branch.

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
* `--model <name>`: LLM model to use for generating PR content.
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
* `--model MODEL`: Specify LLM model to use.
* `--lang <lang>`: Generate content in specified language (default: `English`).
* `-h, --help`: Show this help message.

## Customizing Prompts

You can customize the prompts used by `gitai` by creating your own prompt files. The default prompt files are located in `$HOME/.config/gitai/prompts`.

You can specify a custom prompt file using the `--prompt` flag for `aitag`, and `--prompt-title` and `--prompt-body` for `aipr`.

## Environment Variables

* `GITAI_MODEL`: Set the default LLM model to use.
* `GITAI_LANG`: Set the default language for generation.
* `GITAI_COMMIT_MSG_PROMPT`: Override the default commit message prompt file path.
* `GITAI_PR_PROMPT_TITLE`: Override the default PR title prompt file path.
* `GITAI_PR_PROMPT_BODY`: Override the default PR body prompt file path.
* `GITAI_TAG_PROMPT`: Override the default tag prompt file path.
* `GITAI_SKIP_AI_COMMIT_MSG_HOOK`: If set, the `ai-commit-msg` hook will be skipped.

## License

[MIT](LICENSE)
