#!/usr/bin/env bats
# Simplified tests for aitag script

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

@test "aitag --help shows usage information" {
    run "$GITAI_ROOT/aitag" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: aitag" ]]
}

@test "aitag -h shows usage information" {
    run "$GITAI_ROOT/aitag" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: aitag" ]]
}

@test "aitag help shows FLAGS section" {
    run "$GITAI_ROOT/aitag" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FLAGS:" ]]
}

@test "aitag help shows EXAMPLES section" {
    run "$GITAI_ROOT/aitag" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "EXAMPLES:" ]]
}

@test "aitag help mentions --annotate flag" {
    run "$GITAI_ROOT/aitag" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "annotate" ]]
}

@test "aitag help mentions --sign flag" {
    run "$GITAI_ROOT/aitag" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "sign" ]]
}

@test "aitag help mentions --model flag" {
    run "$GITAI_ROOT/aitag" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--model" ]]
}

@test "aitag sources gitai-common.sh library" {
    [ -f "$GITAI_ROOT/lib/gitai-common.sh" ]
}

@test "aitag config file is initialized" {
    run "$GITAI_ROOT/aitag" --help
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/gitai/prompts/aitag-prompt.txt" ]
}
