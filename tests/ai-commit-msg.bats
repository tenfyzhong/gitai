#!/usr/bin/env bats
# Simplified tests for ai-commit-msg script

load test_helper

setup() {
    setup_mock_environment
    setup_git_repo
}

teardown() {
    teardown_test_dir
}

# ============================================================================
# Basic Functionality Tests
# ============================================================================

@test "ai-commit-msg --help shows usage information" {
    run "$GITAI_ROOT/ai-commit-msg" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "ai-commit-msg -h shows usage information" {
    run "$GITAI_ROOT/ai-commit-msg" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "ai-commit-msg help shows Options section" {
    run "$GITAI_ROOT/ai-commit-msg" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Options:" ]]
}

@test "ai-commit-msg help shows Environment Variables section" {
    run "$GITAI_ROOT/ai-commit-msg" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Environment Variables:" ]]
}

@test "ai-commit-msg help mentions GITAI_SKIP_AI_COMMIT_MSG_HOOK" {
    run "$GITAI_ROOT/ai-commit-msg" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "GITAI_SKIP_AI_COMMIT_MSG_HOOK" ]]
}

@test "ai-commit-msg exits early when GITAI_SKIP_AI_COMMIT_MSG_HOOK is set" {
    export GITAI_SKIP_AI_COMMIT_MSG_HOOK=1

    local commit_msg_file="$TEST_DIR/COMMIT_EDITMSG"
    echo "# Please enter the commit message" > "$commit_msg_file"

    run "$GITAI_ROOT/ai-commit-msg" "$commit_msg_file"
    [ "$status" -eq 0 ]
}

@test "ai-commit-msg sources gitai-common.sh library" {
    [ -f "$GITAI_ROOT/lib/gitai-common.sh" ]
}

@test "ai-commit-msg config file is initialized" {
    run "$GITAI_ROOT/ai-commit-msg" --help
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/gitai/prompts/ai-commit-msg-prompt.txt" ]
}
