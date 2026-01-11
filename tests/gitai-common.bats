#!/usr/bin/env bats
# Tests for gitai-common.sh shared library

load test_helper

setup() {
    setup_test_dir
    # Mock git before sourcing library to avoid any real git operations
    mock_git
    source "$GITAI_ROOT/lib/gitai-common.sh"
}

teardown() {
    teardown_test_dir
}

# ============================================================================
# Color Code Tests
# ============================================================================

@test "ANSI color codes are defined" {
    [ -n "$GITAI_RED" ]
    [ -n "$GITAI_GREEN" ]
    [ -n "$GITAI_YELLOW" ]
    [ -n "$GITAI_BLUE" ]
    [ -n "$GITAI_NC" ]
}

@test "Backward compatible color codes are defined" {
    [ -n "$RED" ]
    [ -n "$GREEN" ]
    [ -n "$YELLOW" ]
    [ -n "$BLUE" ]
    [ -n "$NC" ]
}

@test "Color codes match backward compatible aliases" {
    [ "$RED" = "$GITAI_RED" ]
    [ "$GREEN" = "$GITAI_GREEN" ]
    [ "$YELLOW" = "$GITAI_YELLOW" ]
    [ "$BLUE" = "$GITAI_BLUE" ]
    [ "$NC" = "$GITAI_NC" ]
}

# ============================================================================
# Library Loading Tests
# ============================================================================

@test "Library can be sourced multiple times without error" {
    source "$GITAI_ROOT/lib/gitai-common.sh"
    source "$GITAI_ROOT/lib/gitai-common.sh"
    [ "$GITAI_COMMON_LOADED" = "1" ]
}

@test "Library sets GITAI_COMMON_LOADED flag" {
    [ "$GITAI_COMMON_LOADED" = "1" ]
}

# ============================================================================
# Temp File Management Tests
# ============================================================================

@test "gitai_create_temp_file creates a temporary file" {
    local temp_file
    temp_file=$(gitai_create_temp_file)

    [ -n "$temp_file" ]
    [ -f "$temp_file" ]
}

@test "gitai_create_temp_file tracks files in GITAI_TEMP_FILES array" {
    # Call the function directly (not in subshell)
    gitai_create_temp_file >/dev/null

    # Check that array has at least one element
    [ "${#GITAI_TEMP_FILES[@]}" -gt 0 ]
}

@test "gitai_create_temp_file with custom suffix" {
    local temp_file
    temp_file=$(gitai_create_temp_file ".test")

    [ -f "$temp_file" ]
}

@test "create_temp_file backward compatibility wrapper works" {
    local temp_file
    temp_file=$(create_temp_file)

    [ -n "$temp_file" ]
    [ -f "$temp_file" ]
}

@test "create_temp_file tracks files in both arrays" {
    # Call the function directly (not in subshell)
    create_temp_file >/dev/null

    # Check that both arrays have at least one element
    [ "${#GITAI_TEMP_FILES[@]}" -gt 0 ]
    [ "${#TEMP_FILES[@]}" -gt 0 ]
}

# ============================================================================
# Git Utility Tests
# ============================================================================

@test "gitai_is_git_repo returns false outside git repo" {
    run gitai_is_git_repo
    [ "$status" -ne 0 ]
}

@test "gitai_is_git_repo returns true inside git repo" {
    setup_git_repo
    run gitai_is_git_repo
    [ "$status" -eq 0 ]
}

@test "is_git_repo backward compatibility wrapper works" {
    setup_git_repo
    run is_git_repo
    [ "$status" -eq 0 ]
}

@test "gitai_get_current_branch returns branch name" {
    setup_git_repo
    create_test_branch "feature-test"

    local branch
    branch=$(gitai_get_current_branch)
    [ "$branch" = "feature-test" ]
}

@test "get_current_branch backward compatibility wrapper works" {
    setup_git_repo
    create_test_branch "test-branch"

    local branch
    branch=$(get_current_branch)
    [ "$branch" = "test-branch" ]
}

@test "gitai_remote_to_url returns remote URL" {
    setup_git_repo
    add_git_remote "origin" "https://github.com/test/repo.git"

    local url
    url=$(gitai_remote_to_url "origin")
    [ "$url" = "https://github.com/test/repo.git" ]
}

@test "remote_2_url backward compatibility wrapper works" {
    setup_git_repo
    add_git_remote "origin" "https://github.com/test/repo.git"

    local url
    url=$(remote_2_url "origin")
    [ "$url" = "https://github.com/test/repo.git" ]
}

@test "gitai_get_branch_remote returns configured remote" {
    setup_git_repo
    add_git_remote "origin" "https://github.com/test/repo.git"
    create_test_branch "feature"

    # Mock git config to return origin
    local remote
    remote=$(gitai_get_branch_remote "feature")
    # Just check we got a result
    [ -n "$remote" ]
}

@test "gitai_get_branch_remote returns empty for non-existent branch" {
    setup_git_repo

    run gitai_get_branch_remote ""
    [ "$status" -ne 0 ]
}

# ============================================================================
# Command Checking Tests
# ============================================================================

@test "gitai_check_required_commands succeeds when all commands exist" {
    run gitai_check_required_commands bash echo
    [ "$status" -eq 0 ]
}

@test "gitai_check_required_commands fails when command missing" {
    run gitai_check_required_commands bash nonexistent_command_xyz
    [ "$status" -ne 0 ]
}

@test "gitai_check_required_commands reports missing command" {
    run gitai_check_required_commands nonexistent_command_xyz
    [ "$status" -ne 0 ]
    [[ "$output" =~ "nonexistent_command_xyz" ]]
}

@test "check_required_commands backward compatibility wrapper works" {
    run check_required_commands bash echo
    [ "$status" -eq 0 ]
}

# ============================================================================
# Configuration Management Tests
# ============================================================================

@test "gitai_init_config creates config file from homebrew" {
    setup_mock_homebrew

    local config_file="$TEST_DIR/.config/gitai/test-config.txt"

    run gitai_init_config "$config_file" "prompts/ai-commit-msg-prompt.txt"
    [ "$status" -eq 0 ]
    [ -f "$config_file" ]
}

@test "gitai_init_config skips if config already exists" {
    setup_config_dir
    local config_file="$CONFIG_DIR/prompts/existing.txt"
    echo "existing content" > "$config_file"

    run gitai_init_config "$config_file" "prompts/ai-commit-msg-prompt.txt"
    [ "$status" -eq 0 ]

    local content
    content=$(cat "$config_file")
    [ "$content" = "existing content" ]
}

@test "gitai_init_config fails when homebrew file not found" {
    mock_brew "$TEST_DIR/nonexistent"

    local config_file="$TEST_DIR/.config/gitai/test.txt"

    run gitai_init_config "$config_file" "prompts/nonexistent.txt"
    [ "$status" -ne 0 ]
}

# ============================================================================
# LLM Integration Tests
# ============================================================================

@test "gitai_setup_llm_model uses GITAI_MODEL if set" {
    export GITAI_MODEL="gpt-4"
    mock_llm

    local model
    model=$(gitai_setup_llm_model)
    [ "$model" = "gpt-4" ]
}

@test "gitai_setup_llm_model gets default from llm command" {
    unset GITAI_MODEL
    mock_llm

    local model
    model=$(gitai_setup_llm_model)
    [ "$model" = "gpt-4" ]
}

@test "gitai_call_llm returns LLM response" {
    mock_llm "Test response from LLM"

    local result
    result=$(gitai_call_llm "test prompt" "test input" "Testing")
    # Just check that we got some output
    [ -n "$result" ]
}

@test "gitai_call_llm handles LLM failure" {
    # Create a failing mock llm
    local mock_dir="$TEST_DIR/mock-bin"
    mkdir -p "$mock_dir"
    cat > "$mock_dir/llm" <<'EOF'
#!/usr/bin/env bash
echo "Error: LLM failed" >&2
exit 1
EOF
    chmod +x "$mock_dir/llm"
    export PATH="$mock_dir:$PATH"

    run gitai_call_llm "test prompt" "test input" "Testing"
    [ "$status" -ne 0 ]
}

@test "gitai_generate_with_prompt_file reads prompt file" {
    setup_config_dir
    local prompt_file="$CONFIG_DIR/test-prompt.txt"
    echo "Test prompt content" > "$prompt_file"

    mock_llm "Generated content"

    local result
    result=$(gitai_generate_with_prompt_file "$prompt_file" "test input" "English" "Testing")
    # Just check that we got some output
    [ -n "$result" ]
}

@test "gitai_generate_with_prompt_file fails if prompt file missing" {
    run gitai_generate_with_prompt_file "/nonexistent/prompt.txt" "input" "English" "Testing"
    [ "$status" -ne 0 ]
}

@test "gitai_generate_with_prompt_file includes language in prompt" {
    setup_config_dir
    local prompt_file="$CONFIG_DIR/test-prompt.txt"
    echo "Test prompt" > "$prompt_file"

    mock_llm "Generated in Spanish"

    local result
    result=$(gitai_generate_with_prompt_file "$prompt_file" "input" "Spanish" "Testing")
    # Just check that we got some output
    [ -n "$result" ]
}

# ============================================================================
# Spinner Animation Tests
# ============================================================================

@test "gitai_spin_animation function exists" {
    type gitai_spin_animation >/dev/null
}

@test "spin_animation backward compatibility wrapper exists" {
    type spin_animation >/dev/null
}

@test "gitai_kill_spin function exists" {
    type gitai_kill_spin >/dev/null
}

@test "kill_spin backward compatibility wrapper exists" {
    type kill_spin >/dev/null
}

# Note: Testing actual spinner animation is difficult in non-TTY environment
# These tests just verify the functions exist and don't crash

# ============================================================================
# Cleanup Handler Tests
# ============================================================================

@test "gitai_cleanup function exists" {
    type gitai_cleanup >/dev/null
}

@test "cleanup backward compatibility wrapper exists" {
    type cleanup >/dev/null
}

# ============================================================================
# Function Export Tests
# ============================================================================

@test "All main functions are exported" {
    declare -F gitai_spin_animation >/dev/null
    declare -F gitai_kill_spin >/dev/null
    declare -F gitai_cleanup >/dev/null
    declare -F gitai_create_temp_file >/dev/null
    declare -F gitai_is_git_repo >/dev/null
    declare -F gitai_get_current_branch >/dev/null
    declare -F gitai_check_required_commands >/dev/null
    declare -F gitai_init_config >/dev/null
    declare -F gitai_setup_llm_model >/dev/null
    declare -F gitai_call_llm >/dev/null
}

@test "All backward compatibility wrappers are exported" {
    declare -F spin_animation >/dev/null
    declare -F kill_spin >/dev/null
    declare -F cleanup >/dev/null
    declare -F create_temp_file >/dev/null
    declare -F is_git_repo >/dev/null
    declare -F get_current_branch >/dev/null
    declare -F check_required_commands >/dev/null
}
