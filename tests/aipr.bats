#!/usr/bin/env bats
# Simplified tests for aipr script

load test_helper

setup() {
    setup_mock_environment
    setup_git_repo
    add_git_remote "origin" "https://github.com/testuser/testrepo.git"
}

teardown() {
    teardown_test_dir
}

# ============================================================================
# Basic Functionality Tests
# ============================================================================

@test "aipr --help shows usage information" {
    run "$GITAI_ROOT/aipr" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: aipr" ]]
}

@test "aipr -h shows usage information" {
    run "$GITAI_ROOT/aipr" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: aipr" ]]
}

@test "aipr help shows FLAGS section" {
    run "$GITAI_ROOT/aipr" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FLAGS:" ]]
}

@test "aipr help shows ENVIRONMENT VARIABLES section" {
    run "$GITAI_ROOT/aipr" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ENVIRONMENT VARIABLES:" ]]
}

@test "aipr help mentions --remote flag" {
    run "$GITAI_ROOT/aipr" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--remote" ]]
}

@test "aipr help mentions --base flag" {
    run "$GITAI_ROOT/aipr" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--base" ]]
}

@test "aipr help mentions --model flag" {
    run "$GITAI_ROOT/aipr" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--model" ]]
}

@test "aipr sources gitai-common.sh library" {
    [ -f "$GITAI_ROOT/lib/gitai-common.sh" ]
}

@test "aipr config files are initialized" {
    run "$GITAI_ROOT/aipr" --help
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/gitai/prompts/aipr-title-prompt.txt" ]
    [ -f "$HOME/.config/gitai/prompts/aipr-body-prompt.txt" ]
}
