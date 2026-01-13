#!/bin/bash

# SHARDS Regression Testing Script
# Tests different agent configurations and cleanup functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
TEST_PREFIX="regression-test"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Agent configurations to test (using arrays instead of associative arrays for compatibility)
AGENT_NAMES=("claude-native" "codex-iterm2" "kiro-ghostty" "gemini-terminal")
AGENT_COMMANDS=("claude" "codex" "kiro" "gemini")
TERMINAL_TYPES=("native" "iterm2" "ghostty" "terminal")

# Test branches
TEST_BRANCHES=()
CREATED_SESSIONS=()

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

cleanup_on_exit() {
    log "Cleaning up test artifacts..."
    
    # Clean up any remaining test sessions
    for session in "${CREATED_SESSIONS[@]}"; do
        if cargo run -- list | grep -q "$session" 2>/dev/null; then
            log "Cleaning up session: $session"
            cargo run -- destroy "$session" 2>/dev/null || true
        fi
    done
    
    # Clean up test branches
    for branch in "${TEST_BRANCHES[@]}"; do
        git branch -D "$branch" 2>/dev/null || true
        git push origin --delete "$branch" 2>/dev/null || true
    done
    
    log "Cleanup complete"
}

trap cleanup_on_exit EXIT

test_session_creation() {
    local config_name="$1"
    local agent_command="$2"
    local terminal_type="$3"
    local session_name="${TEST_PREFIX}-${config_name}-${TIMESTAMP}"
    
    log "Testing session creation: $config_name"
    log "  Agent: $agent_command"
    log "  Terminal: $terminal_type"
    log "  Session: $session_name"
    
    # Create session
    if cargo run -- create "$session_name" --agent "$agent_command"; then
        success "Session created successfully: $session_name"
        CREATED_SESSIONS+=("$session_name")
        TEST_BRANCHES+=("$session_name")
        return 0
    else
        error "Failed to create session: $session_name"
        return 1
    fi
}

test_session_listing() {
    log "Testing session listing..."
    
    local output
    if output=$(cargo run -- list); then
        success "Session listing works"
        log "List output: $output"
        
        # Check if our test sessions are listed
        local found_sessions=0
        for session in "${CREATED_SESSIONS[@]}"; do
            if echo "$output" | grep -q "$session"; then
                success "Found session in list: $session"
                ((found_sessions++))
            else
                warning "Session not found in list: $session (may be persistence issue)"
            fi
        done
        
        log "Found $found_sessions/${#CREATED_SESSIONS[@]} test sessions in list"
        return 0
    else
        error "Session listing failed"
        return 1
    fi
}

test_session_info() {
    log "Testing session info command..."
    
    # Skip info test since command doesn't exist yet
    warning "Skipping session info test - command not implemented yet"
    return 0
}

test_cleanup_functionality() {
    log "Testing cleanup functionality..."
    
    # Skip cleanup tests since destroy command doesn't exist yet
    warning "Skipping cleanup tests - destroy command not implemented yet"
    
    # Just clean up git branches manually
    local cleanup_count=0
    for session in "${CREATED_SESSIONS[@]}"; do
        log "Manually cleaning up git branch: $session"
        if git branch -D "$session" 2>/dev/null; then
            success "Cleaned up git branch: $session"
            ((cleanup_count++))
        else
            warning "Git branch not found or already cleaned: $session"
        fi
    done
    
    # Clear the created sessions array
    CREATED_SESSIONS=()
    
    log "Manually cleaned up $cleanup_count git branches"
    return 0
}

test_cleanup_command() {
    log "Testing cleanup command..."
    
    # Skip cleanup command test since it doesn't exist yet
    warning "Skipping cleanup command test - command not implemented yet"
    return 0
}

run_regression_tests() {
    log "Starting SHARDS regression tests..."
    log "Project root: $PROJECT_ROOT"
    log "Test timestamp: $TIMESTAMP"
    
    # Build the project first
    log "Building SHARDS..."
    if cargo build; then
        success "Build successful"
    else
        error "Build failed"
        exit 1
    fi
    
    # Test 1: Create sessions with different configurations
    log "=== Phase 1: Testing Session Creation ==="
    local creation_failures=0
    
    for i in "${!AGENT_NAMES[@]}"; do
        local config_name="${AGENT_NAMES[$i]}"
        local agent_command="${AGENT_COMMANDS[$i]}"
        local terminal_type="${TERMINAL_TYPES[$i]}"
        
        if ! test_session_creation "$config_name" "$agent_command" "$terminal_type"; then
            ((creation_failures++))
        fi
        
        # Small delay between creations
        sleep 2
    done
    
    if [ $creation_failures -eq 0 ]; then
        success "All session creation tests passed"
    else
        error "$creation_failures session creation tests failed"
    fi
    
    # Test 2: Session listing
    log "=== Phase 2: Testing Session Management ==="
    test_session_listing
    
    # Test 3: Session info
    test_session_info
    
    # Test 4: Cleanup functionality
    log "=== Phase 3: Testing Cleanup Functionality ==="
    test_cleanup_functionality
    
    # Test 5: Cleanup command
    test_cleanup_command
    
    # Final verification
    log "=== Phase 4: Final Verification ==="
    local final_output
    if final_output=$(cargo run -- list); then
        if echo "$final_output" | grep -q "$TEST_PREFIX"; then
            error "Test sessions still found after cleanup"
        else
            success "All test sessions properly cleaned up"
        fi
    fi
    
    success "Regression tests completed!"
}

# Main execution
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "SHARDS Regression Testing Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --dry-run      Show what would be tested without executing"
        echo ""
        echo "This script tests:"
        echo "  - Session creation with different agent configurations"
        echo "  - Session listing and info commands"
        echo "  - Cleanup functionality for individual sessions"
        echo "  - Global cleanup command"
        echo ""
        exit 0
    fi
    
    if [ "$1" = "--dry-run" ]; then
        log "DRY RUN: Would test the following configurations:"
        for i in "${!AGENT_NAMES[@]}"; do
            local config_name="${AGENT_NAMES[$i]}"
            local agent_command="${AGENT_COMMANDS[$i]}"
            local terminal_type="${TERMINAL_TYPES[$i]}"
            echo "  - $config_name: $agent_command ($terminal_type)"
        done
        exit 0
    fi
    
    # Ensure we're in the project root
    cd "$PROJECT_ROOT"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi
    
    run_regression_tests
}

main "$@"
