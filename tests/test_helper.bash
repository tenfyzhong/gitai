#!/usr/bin/env bash
# test_helper.bash - Test utilities and mocks for gitai BATS tests

# Get the project root directory
GITAI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GITAI_ROOT

# Source the shared library for testing
export GITAI_LIB_PATH="$GITAI_ROOT/lib/gitai-common.sh"
if [ -f "$GITAI_LIB_PATH" ]; then
	source "$GITAI_LIB_PATH"
fi

# Test fixtures directory
FIXTURES_DIR="${GITAI_ROOT}/tests/fixtures"
export FIXTURES_DIR

# ============================================================================
# Test Setup and Teardown Helpers
# ============================================================================

# Setup a temporary test directory
setup_test_dir() {
	TEST_DIR="$(mktemp -d -t gitai-test.XXXXXX)"
	export TEST_DIR
	cd "$TEST_DIR" || exit 1
}

# Cleanup test directory
teardown_test_dir() {
	if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
		rm -rf "$TEST_DIR"
	fi
}

# Mock the git command to avoid real git operations
mock_git() {
	local mock_dir="$TEST_DIR/mock-bin"
	mkdir -p "$mock_dir"

	cat >"$mock_dir/git" <<'EOF'
#!/usr/bin/env bash
# Mock git command for testing

case "$1" in
    init)
        mkdir -p .git
        echo "Initialized empty Git repository"
        ;;
    config)
        case "$2" in
            --get)
                # Return mock config values
                case "$3" in
                    "branch."*.remote)
                        echo "origin"
                        exit 0
                        ;;
                    user.name)
                        echo "Test User"
                        exit 0
                        ;;
                    user.email)
                        echo "test@example.com"
                        exit 0
                        ;;
                esac
                ;;
            *)
                # Just return success for other config operations
                exit 0
                ;;
        esac
        ;;
    add)
        # Simulate successful add
        exit 0
        ;;
    commit)
        # Simulate successful commit
        echo "[mock] 1 file changed, 1 insertion(+)"
        exit 0
        ;;
    rev-parse)
        case "$2" in
            --is-inside-work-tree)
                if [ -d .git ]; then
                    echo "true"
                    exit 0
                else
                    exit 1
                fi
                ;;
            --abbrev-ref)
                if [ "$3" = "HEAD" ]; then
                    if [ -f .git/HEAD ]; then
                        cat .git/HEAD
                    else
                        echo "main"
                    fi
                    exit 0
                fi
                ;;
            --show-toplevel)
                pwd
                exit 0
                ;;
            --verify)
                # Simulate commit verification
                echo "abc123def456"
                exit 0
                ;;
            HEAD)
                echo "abc123def456"
                exit 0
                ;;
        esac
        ;;
    remote)
        case "$2" in
            add)
                # Simulate adding remote
                exit 0
                ;;
            get-url)
                echo "https://github.com/test/repo.git"
                exit 0
                ;;
            "")
                # List remotes
                echo "origin"
                exit 0
                ;;
        esac
        ;;
    checkout)
        # Simulate branch checkout
        if [[ "$2" == "-b" || "$2" == "-q" ]]; then
            local branch="${3:-${2}}"
            echo "$branch" > .git/HEAD
        fi
        exit 0
        ;;
    diff)
        if [[ "$*" == *"--cached"* ]]; then
            # Return empty for no staged changes
            exit 0
        else
            # Return mock diff
            echo "diff --git a/test.txt b/test.txt"
            echo "+new content"
            exit 0
        fi
        ;;
    tag)
        case "$2" in
            --sort=*)
                # List tags
                echo "v0.1.0"
                exit 0
                ;;
            *)
                # Create tag
                exit 0
                ;;
        esac
        ;;
    ls-files)
        echo "README.md"
        echo "test.txt"
        exit 0
        ;;
    log)
        echo "abc123 Test commit"
        exit 0
        ;;
    fetch)
        # Simulate successful fetch
        exit 0
        ;;
    ls-remote)
        if [[ "$2" == "--exit-code" ]]; then
            exit 0
        fi
        echo "abc123  refs/heads/main"
        exit 0
        ;;
    status)
        echo "On branch main"
        echo "nothing to commit, working tree clean"
        exit 0
        ;;
    *)
        # Default: return success
        exit 0
        ;;
esac
exit 0
EOF

	chmod +x "$mock_dir/git"
	export PATH="$mock_dir:$PATH"
}

# Setup a temporary git repository for testing
setup_git_repo() {
	setup_test_dir
	mock_git

	# Create mock .git directory
	mkdir -p .git
	echo "main" >.git/HEAD

	# Create initial file
	echo "# Test Repo" >README.md
}

# Add a remote to the test git repo
add_git_remote() {
	local remote_name="${1:-origin}"
	local remote_url="${2:-https://github.com/test/repo.git}"
	# Just create a marker file for the remote
	mkdir -p .git/remotes
	echo "$remote_url" >".git/remotes/$remote_name"
}

# Create a test branch
create_test_branch() {
	local branch_name="${1:-test-branch}"
	echo "$branch_name" >.git/HEAD
}

# Make changes to trigger git diff
make_test_changes() {
	echo "Test change" >>test-file.txt
	# Just create the file, mock git will handle the rest
}

# ============================================================================
# Mock Command Functions
# ============================================================================

# Mock the llm command to return predefined responses
mock_llm() {
	local response="${1:-Generated content from LLM}"

	# Create a mock llm script in PATH
	local mock_dir="$TEST_DIR/mock-bin"
	mkdir -p "$mock_dir"

	cat >"$mock_dir/llm" <<EOF
#!/usr/bin/env bash
# Mock llm command for testing

case "\$1" in
    models)
        if [ "\$2" = "default" ]; then
            echo "gpt-4"
        else
            echo "gpt-4"
            echo "gpt-3.5-turbo"
            echo "claude-3"
        fi
        ;;
    -s|--system)
        # Read from stdin and return mock response
        cat > /dev/null
        echo "$response"
        ;;
    *)
        echo "$response"
        ;;
esac
exit 0
EOF

	chmod +x "$mock_dir/llm"
	export PATH="$mock_dir:$PATH"
}

# Mock the gh (GitHub CLI) command
mock_gh() {
	local mock_dir="$TEST_DIR/mock-bin"
	mkdir -p "$mock_dir"

	cat >"$mock_dir/gh" <<'EOF'
#!/usr/bin/env bash
# Mock gh command for testing

case "$1" in
    pr)
        case "$2" in
            create)
                echo "https://github.com/test/repo/pull/123"
                exit 0
                ;;
            edit)
                echo "Updated PR #123"
                exit 0
                ;;
            list)
                if [[ "$*" == *"--json"* ]]; then
                    echo "[]"
                else
                    echo "No pull requests found"
                fi
                exit 0
                ;;
            view)
                if [[ "$*" == *"--json"* ]]; then
                    echo '{"body":"Old PR body","number":123}'
                else
                    echo "PR #123"
                fi
                exit 0
                ;;
        esac
        ;;
    repo)
        if [[ "$2" == "view" ]]; then
            echo '{"owner":{"login":"testuser"},"name":"testrepo","defaultBranchRef":{"name":"main"}}'
            exit 0
        fi
        ;;
esac
exit 0
EOF

	chmod +x "$mock_dir/gh"
	export PATH="$mock_dir:$PATH"
}

# Mock the jq command
mock_jq() {
	local mock_dir="$TEST_DIR/mock-bin"
	mkdir -p "$mock_dir"

	cat >"$mock_dir/jq" <<'EOF'
#!/usr/bin/env bash
# Mock jq command for testing
# Simple implementation that handles basic queries

input=$(cat)

case "$1" in
    -r)
        # Raw output mode
        case "$2" in
            '.owner.login')
                echo "testuser"
                ;;
            '.name')
                echo "testrepo"
                ;;
            '.defaultBranchRef.name')
                echo "main"
                ;;
            '.body')
                echo "Old PR body"
                ;;
            '.[0].number')
                echo "123"
                ;;
            *)
                echo "$input"
                ;;
        esac
        ;;
    *)
        echo "$input"
        ;;
esac
exit 0
EOF

	chmod +x "$mock_dir/jq"
	export PATH="$mock_dir:$PATH"
}

# Mock brew command
mock_brew() {
	local prefix="${1:-/usr/local}"

	local mock_dir="$TEST_DIR/mock-bin"
	mkdir -p "$mock_dir"

	cat >"$mock_dir/brew" <<EOF
#!/usr/bin/env bash
# Mock brew command for testing

case "\$1" in
    --prefix)
        echo "$prefix"
        ;;
    *)
        echo "Unknown brew command: \$*" >&2
        exit 1
        ;;
esac
exit 0
EOF

	chmod +x "$mock_dir/brew"
	export PATH="$mock_dir:$PATH"
}

# Setup mock Homebrew installation structure
setup_mock_homebrew() {
	local prefix="${1:-$TEST_DIR/homebrew}"

	mock_brew "$prefix"

	# Create mock Homebrew directory structure
	mkdir -p "$prefix/share/gitai/prompts"
	mkdir -p "$prefix/share/gitai/lib"

	# Copy actual library and prompts
	cp "$GITAI_ROOT/lib/gitai-common.sh" "$prefix/share/gitai/lib/"
	cp "$GITAI_ROOT/prompts"/*.txt "$prefix/share/gitai/prompts/" 2>/dev/null || true

	export HOMEBREW_PREFIX="$prefix"
}

# ============================================================================
# Assertion Helpers
# ============================================================================

# Assert that a file exists
assert_file_exists() {
	local file="$1"
	[ -f "$file" ] || {
		echo "Expected file to exist: $file" >&2
		return 1
	}
}

# Assert that a file does not exist
assert_file_not_exists() {
	local file="$1"
	[ ! -f "$file" ] || {
		echo "Expected file to not exist: $file" >&2
		return 1
	}
}

# Assert that a directory exists
assert_dir_exists() {
	local dir="$1"
	[ -d "$dir" ] || {
		echo "Expected directory to exist: $dir" >&2
		return 1
	}
}

# Assert that output contains a string
assert_output_contains() {
	local expected="$1"
	echo "$output" | grep -q "$expected" || {
		echo "Expected output to contain: $expected" >&2
		echo "Actual output: $output" >&2
		return 1
	}
}

# Assert that output does not contain a string
assert_output_not_contains() {
	local unexpected="$1"
	echo "$output" | grep -q "$unexpected" && {
		echo "Expected output to not contain: $unexpected" >&2
		echo "Actual output: $output" >&2
		return 1
	}
	return 0
}

# Assert exit status equals expected
assert_status_equals() {
	local expected="$1"
	[ "$status" -eq "$expected" ] || {
		echo "Expected exit status: $expected, got: $status" >&2
		return 1
	}
}

# Assert exit status is success (0)
assert_success() {
	assert_status_equals 0
}

# Assert exit status is failure (non-zero)
assert_failure() {
	[ "$status" -ne 0 ] || {
		echo "Expected failure but got success (exit 0)" >&2
		return 1
	}
}

# ============================================================================
# Utility Functions
# ============================================================================

# Skip test if command is not available
skip_if_command_not_found() {
	local cmd="$1"
	if ! command -v "$cmd" >/dev/null 2>&1; then
		skip "Command not found: $cmd"
	fi
}

# Create a temporary config directory
setup_config_dir() {
	CONFIG_DIR="$TEST_DIR/.config/gitai"
	mkdir -p "$CONFIG_DIR/prompts"
	export HOME="$TEST_DIR"
}

# Create test prompt files
create_test_prompts() {
	setup_config_dir

	echo "Generate a commit message" >"$CONFIG_DIR/prompts/ai-commit-msg-prompt.txt"
	echo "Generate a PR title" >"$CONFIG_DIR/prompts/aipr-title-prompt.txt"
	echo "Generate a PR body" >"$CONFIG_DIR/prompts/aipr-body-prompt.txt"
	echo "Generate a tag message" >"$CONFIG_DIR/prompts/aitag-prompt.txt"
}

# Capture output and status of a command
run_command() {
	output=$("$@" 2>&1)
	status=$?
}

# Run command and capture output separately
run_with_stderr() {
	local stdout_file="$TEST_DIR/stdout.txt"
	local stderr_file="$TEST_DIR/stderr.txt"

	"$@" >"$stdout_file" 2>"$stderr_file"
	status=$?

	output=$(cat "$stdout_file")
	stderr=$(cat "$stderr_file")
}

# ============================================================================
# Mock Environment Setup
# ============================================================================

# Setup complete mock environment for testing
setup_mock_environment() {
	setup_test_dir
	setup_config_dir
	create_test_prompts
	setup_mock_homebrew
	mock_git
	mock_llm "Generated test content"
	mock_gh
	mock_jq
}

# Export functions for use in BATS tests
export -f setup_test_dir
export -f teardown_test_dir
export -f setup_git_repo
export -f add_git_remote
export -f create_test_branch
export -f make_test_changes
export -f mock_git
export -f mock_llm
export -f mock_gh
export -f mock_jq
export -f mock_brew
export -f setup_mock_homebrew
export -f assert_file_exists
export -f assert_file_not_exists
export -f assert_dir_exists
export -f assert_output_contains
export -f assert_output_not_contains
export -f assert_status_equals
export -f assert_success
export -f assert_failure
export -f skip_if_command_not_found
export -f setup_config_dir
export -f create_test_prompts
export -f run_command
export -f run_with_stderr
export -f setup_mock_environment
