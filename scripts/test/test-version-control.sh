#!/opt/homebrew/bin/bash
#
# test-version-control.sh - Comprehensive test suite for version-control.sh
#
# This script tests ALL functions in version-control.sh to ensure they work correctly
# in isolation and together. Each test is designed to be non-destructive and can be
# run repeatedly.
#
# Usage:
#   ./scripts/test/test-version-control.sh [test_category]
#
# Categories:
#   all          - Run all tests (default)
#   security     - Test security & context management
#   memory       - Test memory management initialization
#   git-config   - Test git configuration functions
#   stash        - Test stash operations
#   golden-rule  - Test golden rule functions
#   sync         - Test sync functions
#   commit       - Test commit functions
#   branch       - Test branch functions
#   advanced     - Test advanced operations
#   conflicts    - Test conflict resolution
#
# Created by: AIPM Framework Testing
# Date: 2025-06-20

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR"
AIPM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Create test repository directory
TEST_REPO_DIR="$TEST_DIR/test-repo-$(date +%Y%m%d-%H%M%S)"
TEST_RESULTS_FILE="$TEST_DIR/test-results-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# ============================================================================
# TEST FRAMEWORK FUNCTIONS
# ============================================================================

# Initialize test environment
init_test_env() {
    printf "${CYAN}Setting up test environment...${NC}\n"
    
    # Create test repo
    mkdir -p "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR"
    
    # Initialize git repo
    git init --quiet
    git config user.name "AIPM Test"
    git config user.email "test@aipm.local"
    
    # Create initial commit
    echo "# Test Repository" > README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    
    # Set up test structure
    mkdir -p .memory
    echo '{"entities":[],"relations":[]}' > .memory/local_memory.json
    
    mkdir -p scripts
    cp "$AIPM_ROOT/scripts/shell-formatting.sh" scripts/
    cp "$AIPM_ROOT/scripts/version-control.sh" scripts/
    
    # Create .gitignore
    cat > .gitignore << 'EOF'
# Test files
*.tmp
*.log
test-output/
.test-cache/

# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
.vscode/
.idea/
EOF
    
    git add .
    git commit -m "Setup test structure" --quiet
    
    # Source the scripts
    export AIPM_COLOR=true
    export AIPM_UNICODE=true
    source scripts/shell-formatting.sh
    source scripts/version-control.sh
    
    printf "${GREEN}✓ Test environment ready${NC}\n\n"
}

# Cleanup test environment
cleanup_test_env() {
    cd "$AIPM_ROOT"
    if [[ -d "$TEST_REPO_DIR" ]]; then
        rm -rf "$TEST_REPO_DIR"
    fi
}

# Run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TESTS_RUN++))
    printf "${BLUE}Running: ${NC}%s... " "$test_name"
    
    # Capture output and result
    local output
    local result
    
    if output=$(eval "$test_function" 2>&1); then
        result=0
    else
        result=$?
    fi
    
    # Log to results file
    {
        echo "=== TEST: $test_name ==="
        echo "Function: $test_function"
        echo "Result: $result"
        echo "Output:"
        echo "$output"
        echo ""
    } >> "$TEST_RESULTS_FILE"
    
    if [[ $result -eq 0 ]]; then
        ((TESTS_PASSED++))
        printf "${GREEN}PASSED${NC}\n"
    else
        ((TESTS_FAILED++))
        printf "${RED}FAILED${NC}\n"
        printf "${YELLOW}Output:${NC}\n%s\n\n" "$output"
    fi
}

# Skip a test
skip_test() {
    local test_name="$1"
    local reason="$2"
    
    ((TESTS_SKIPPED++))
    printf "${BLUE}Skipping: ${NC}%s ${YELLOW}(%s)${NC}\n" "$test_name" "$reason"
}

# Assert functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        printf "Assertion failed: %s\n" "$message" >&2
        printf "Expected: '%s'\n" "$expected" >&2
        printf "Actual: '%s'\n" "$actual" >&2
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ ! -f "$file" ]]; then
        printf "Assertion failed: %s\n" "$message" >&2
        printf "File not found: %s\n" "$file" >&2
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="${3:-File should contain pattern}"
    
    if ! grep -q "$pattern" "$file"; then
        printf "Assertion failed: %s\n" "$message" >&2
        printf "Pattern '%s' not found in %s\n" "$pattern" "$file" >&2
        return 1
    fi
}

# ============================================================================
# SECURITY & CONTEXT MANAGEMENT TESTS
# ============================================================================

test_detect_nesting_level() {
    # Test nesting detection
    unset AIPM_NESTING_LEVEL
    detect_nesting_level
    assert_equals "1" "$AIPM_NESTING_LEVEL" "First level should be 1"
    
    detect_nesting_level
    assert_equals "2" "$AIPM_NESTING_LEVEL" "Second level should be 2"
    
    # Reset for other tests
    export AIPM_NESTING_LEVEL=0
}

test_resolve_project_path() {
    # Create a symlink
    local real_dir="$TEST_REPO_DIR/real-project"
    local link_dir="$TEST_REPO_DIR/link-project"
    
    mkdir -p "$real_dir"
    ln -s "$real_dir" "$link_dir"
    
    local resolved=$(resolve_project_path "$link_dir")
    assert_equals "$real_dir" "$resolved" "Should resolve symlink"
    
    rm -f "$link_dir"
}

test_get_project_context() {
    # Test in current directory
    get_project_context
    assert_equals "false" "$IS_SYMLINKED" "Should not be symlinked"
    assert_equals "$(pwd)" "$PROJECT_ROOT" "Project root should be current dir"
}

test_security_category() {
    printf "\n${CYAN}=== SECURITY & CONTEXT MANAGEMENT TESTS ===${NC}\n\n"
    
    run_test "Nesting level detection" test_detect_nesting_level
    run_test "Project path resolution" test_resolve_project_path
    run_test "Project context detection" test_get_project_context
}

# ============================================================================
# MEMORY MANAGEMENT TESTS
# ============================================================================

test_initialize_memory_context_framework() {
    # Test framework mode
    initialize_memory_context --framework
    
    assert_equals "framework" "$AIPM_CONTEXT" "Should be in framework mode"
    assert_equals ".memory" "$MEMORY_DIR" "Memory dir should be .memory"
    assert_equals "local_memory.json" "$MEMORY_FILE_NAME" "Memory file name should be standard"
}

test_initialize_memory_context_project() {
    # Test project mode
    mkdir -p TestProject
    initialize_memory_context --project TestProject
    
    assert_equals "project" "$AIPM_CONTEXT" "Should be in project mode"
    assert_equals "TestProject" "$PROJECT_NAME" "Project name should be TestProject"
    assert_file_contains <(echo "$MEMORY_FILE_PATH") "TestProject/.memory/local_memory.json"
}

test_reinit_memory_context() {
    # Test re-initialization
    initialize_memory_context --framework
    assert_equals "framework" "$AIPM_CONTEXT"
    
    reinit_memory_context --project TestProject
    assert_equals "project" "$AIPM_CONTEXT"
    assert_equals "TestProject" "$PROJECT_NAME"
}

test_memory_category() {
    printf "\n${CYAN}=== MEMORY MANAGEMENT TESTS ===${NC}\n\n"
    
    run_test "Initialize memory context - framework" test_initialize_memory_context_framework
    run_test "Initialize memory context - project" test_initialize_memory_context_project
    run_test "Re-initialize memory context" test_reinit_memory_context
}

# ============================================================================
# GIT CONFIGURATION TESTS
# ============================================================================

test_check_git_repo() {
    # Should succeed in git repo
    check_git_repo
    assert_equals "0" "$?" "Should succeed in git repo"
    
    # Test outside git repo
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    if check_git_repo 2>/dev/null; then
        cd "$TEST_REPO_DIR"
        rm -rf "$temp_dir"
        return 1
    fi
    cd "$TEST_REPO_DIR"
    rm -rf "$temp_dir"
}

test_get_current_branch() {
    local branch=$(get_current_branch)
    assert_equals "main" "$branch" "Should be on main branch"
    
    # Create and switch to new branch
    git checkout -b test-branch --quiet
    branch=$(get_current_branch)
    assert_equals "test-branch" "$branch" "Should be on test-branch"
    
    git checkout main --quiet
}

test_get_default_branch() {
    local default=$(get_default_branch)
    assert_equals "main" "$default" "Default branch should be main"
}

test_git_config_category() {
    printf "\n${CYAN}=== GIT CONFIGURATION TESTS ===${NC}\n\n"
    
    run_test "Check git repository" test_check_git_repo
    run_test "Get current branch" test_get_current_branch
    run_test "Get default branch" test_get_default_branch
}

# ============================================================================
# STASH TESTS
# ============================================================================

test_stash_changes() {
    # Create changes
    echo "test content" > test-file.txt
    
    # Test stashing
    DID_STASH=false
    stash_changes "Test stash"
    assert_equals "true" "$DID_STASH" "DID_STASH should be true"
    
    # Verify file is gone
    if [[ -f "test-file.txt" ]]; then
        return 1
    fi
    
    # Verify stash exists
    local stash_count=$(git stash list | wc -l)
    assert_equals "1" "$stash_count" "Should have one stash"
}

test_restore_stash() {
    # Restore the stash
    restore_stash
    assert_equals "false" "$DID_STASH" "DID_STASH should be false after restore"
    
    # Verify file is back
    assert_file_exists "test-file.txt"
    assert_file_contains "test-file.txt" "test content"
    
    # Clean up
    rm -f test-file.txt
}

test_list_stashes() {
    # Create multiple stashes
    echo "content 1" > file1.txt
    stash_changes "Stash 1"
    
    echo "content 2" > file2.txt
    stash_changes "Stash 2"
    
    # List should succeed
    list_stashes
    
    # Clean up stashes
    git stash clear
}

test_stash_category() {
    printf "\n${CYAN}=== STASH TESTS ===${NC}\n\n"
    
    run_test "Stash changes" test_stash_changes
    run_test "Restore stash" test_restore_stash
    run_test "List stashes" test_list_stashes
}

# ============================================================================
# GOLDEN RULE TESTS
# ============================================================================

test_add_all_untracked() {
    # Create untracked files
    echo "content" > untracked1.txt
    echo "content" > untracked2.txt
    mkdir -p subdir
    echo "content" > subdir/untracked3.txt
    
    # Create ignored file
    echo "ignored" > test.tmp
    
    # Add all untracked
    add_all_untracked
    
    # Check staged files
    local staged=$(git diff --cached --name-only | sort)
    assert_file_contains <(echo "$staged") "untracked1.txt"
    assert_file_contains <(echo "$staged") "untracked2.txt"
    assert_file_contains <(echo "$staged") "subdir/untracked3.txt"
    
    # Ignored file should not be staged
    if echo "$staged" | grep -q "test.tmp"; then
        return 1
    fi
    
    # Reset
    git reset --quiet
    rm -rf untracked*.txt subdir test.tmp
}

test_ensure_memory_tracked() {
    # Initialize memory context
    initialize_memory_context --framework
    
    # Modify memory file
    echo '{"entities":[{"id":"1"}],"relations":[]}' > .memory/local_memory.json
    
    # Ensure it's tracked
    ensure_memory_tracked
    
    # Check if staged
    local staged=$(git diff --cached --name-only)
    assert_file_contains <(echo "$staged") "local_memory.json"
    
    # Reset
    git reset --quiet
    git checkout .memory/local_memory.json --quiet
}

test_stage_all_changes() {
    # Create various changes
    echo "modified" >> README.md  # Modify existing
    echo "new file" > newfile.txt  # New untracked
    echo "ignored" > test.log  # Should be ignored
    
    # Stage all
    stage_all_changes
    
    # Verify staging
    local staged=$(git diff --cached --name-only | sort)
    assert_file_contains <(echo "$staged") "README.md"
    assert_file_contains <(echo "$staged") "newfile.txt"
    assert_file_contains <(echo "$staged") "local_memory.json"
    
    # Ignored file should not be staged
    if echo "$staged" | grep -q "test.log"; then
        return 1
    fi
    
    # Reset
    git reset --quiet
    git checkout README.md --quiet
    rm -f newfile.txt test.log
}

test_golden_rule_category() {
    printf "\n${CYAN}=== GOLDEN RULE TESTS ===${NC}\n\n"
    
    run_test "Add all untracked files" test_add_all_untracked
    run_test "Ensure memory tracked" test_ensure_memory_tracked
    run_test "Stage all changes" test_stage_all_changes
}

# ============================================================================
# COMMIT TESTS
# ============================================================================

test_create_commit() {
    # Create changes
    echo "test content" > test-commit.txt
    git add test-commit.txt
    
    # Create commit
    create_commit "Test commit" "Test description"
    
    # Verify commit
    local last_msg=$(git log -1 --pretty=%s)
    assert_equals "Test commit" "$last_msg" "Commit message should match"
    
    # Verify file in commit
    local files=$(git diff-tree --no-commit-id --name-only -r HEAD)
    assert_file_contains <(echo "$files") "test-commit.txt"
}

test_commit_with_stats() {
    # Modify memory file
    echo '{"entities":[{"id":"1"},{"id":"2"}],"relations":[{"id":"r1"}]}' > .memory/local_memory.json
    
    # Commit with stats
    commit_with_stats "Update memory with stats"
    
    # Verify commit message contains stats
    local commit_body=$(git log -1 --pretty=%b)
    assert_file_contains <(echo "$commit_body") "Entities: 2"
    assert_file_contains <(echo "$commit_body") "Relations: 1"
}

test_create_commit_golden_rule() {
    # Create unstaged changes
    echo "unstaged content" > unstaged.txt
    echo "modified content" >> README.md
    
    # Create commit with auto-stage (golden rule)
    create_commit "Test golden rule commit" "" false true
    
    # Verify both files were committed
    local files=$(git diff-tree --no-commit-id --name-only -r HEAD)
    assert_file_contains <(echo "$files") "unstaged.txt"
    assert_file_contains <(echo "$files") "README.md"
}

test_commit_category() {
    printf "\n${CYAN}=== COMMIT TESTS ===${NC}\n\n"
    
    run_test "Create commit" test_create_commit
    run_test "Commit with statistics" test_commit_with_stats
    run_test "Create commit with golden rule" test_create_commit_golden_rule
}

# ============================================================================
# SYNC TESTS
# ============================================================================

test_is_working_directory_clean() {
    # Should be clean initially
    is_working_directory_clean
    assert_equals "0" "$?" "Should be clean"
    
    # Create changes
    echo "changes" > dirty.txt
    
    # Should be dirty
    if is_working_directory_clean 2>/dev/null; then
        rm -f dirty.txt
        return 1
    fi
    
    # Clean up
    rm -f dirty.txt
}

test_show_git_status() {
    # Create various changes
    echo "modified" >> README.md
    echo "new" > new.txt
    git add new.txt
    echo "untracked" > untracked.txt
    
    # Show status should succeed
    show_git_status
    
    # Clean up
    git reset --quiet
    git checkout README.md --quiet
    rm -f new.txt untracked.txt
}

test_sync_category() {
    printf "\n${CYAN}=== SYNC TESTS ===${NC}\n\n"
    
    run_test "Check working directory clean" test_is_working_directory_clean
    run_test "Show git status" test_show_git_status
    
    # Skip network operations in test
    skip_test "Fetch remote" "Requires network"
    skip_test "Pull latest" "Requires network"
}

# ============================================================================
# BRANCH TESTS
# ============================================================================

test_create_branch() {
    # Create new branch
    create_branch "test-new-branch"
    
    # Verify we're on new branch
    local current=$(get_current_branch)
    assert_equals "test-new-branch" "$current" "Should be on new branch"
    
    # Try to create duplicate (should fail)
    if create_branch "test-new-branch" 2>/dev/null; then
        return 1
    fi
    
    # Switch back
    git checkout main --quiet
}

test_list_branches() {
    # Create multiple branches
    git branch test-branch-1 --quiet
    git branch test-branch-2 --quiet
    
    # List should succeed
    list_branches
    
    # Clean up
    git branch -d test-branch-1 --quiet
    git branch -d test-branch-2 --quiet
}

test_branch_category() {
    printf "\n${CYAN}=== BRANCH TESTS ===${NC}\n\n"
    
    run_test "Create branch" test_create_branch
    run_test "List branches" test_list_branches
}

# ============================================================================
# ADVANCED OPERATION TESTS
# ============================================================================

test_create_backup_branch() {
    # Create backup
    create_backup_branch "test-operation"
    
    # Verify backup branch exists
    local backup_branches=$(git branch | grep "backup/test-operation")
    if [[ -z "$backup_branches" ]]; then
        return 1
    fi
    
    # Clean up backup branches
    git branch -D $(git branch | grep "backup/" | tr -d ' *') --quiet
}

test_undo_last_commit() {
    # Create a commit to undo
    echo "to be undone" > undo-test.txt
    git add undo-test.txt
    git commit -m "Commit to undo" --quiet
    
    # Undo with keeping changes
    undo_last_commit true
    
    # File should still exist but not be committed
    assert_file_exists "undo-test.txt"
    
    # Check if file is staged
    local staged=$(git diff --cached --name-only)
    assert_file_contains <(echo "$staged") "undo-test.txt"
    
    # Clean up
    git reset --quiet
    rm -f undo-test.txt
}

test_advanced_category() {
    printf "\n${CYAN}=== ADVANCED OPERATION TESTS ===${NC}\n\n"
    
    run_test "Create backup branch" test_create_backup_branch
    run_test "Undo last commit" test_undo_last_commit
    
    # Skip push operations
    skip_test "Push changes" "Requires remote"
}

# ============================================================================
# CONFLICT RESOLUTION TESTS
# ============================================================================

test_check_conflicts() {
    # No conflicts initially
    check_conflicts
    assert_equals "0" "$?" "Should have no conflicts"
    
    # Simulate conflict (would need complex setup)
    skip_test "Resolve conflicts" "Complex setup required"
}

test_conflicts_category() {
    printf "\n${CYAN}=== CONFLICT RESOLUTION TESTS ===${NC}\n\n"
    
    run_test "Check conflicts" test_check_conflicts
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_full_workflow() {
    # 1. Create feature branch
    create_branch "feature-test"
    
    # 2. Make changes
    echo "feature content" > feature.txt
    echo "# Feature" >> README.md
    
    # 3. Stage all changes (golden rule)
    stage_all_changes
    
    # 4. Commit with stats
    commit_with_stats "Add feature"
    
    # 5. Switch back to main
    git checkout main --quiet
    
    # 6. Merge feature
    safe_merge "feature-test"
    
    # 7. Verify merge
    assert_file_exists "feature.txt"
    assert_file_contains "README.md" "# Feature"
    
    # 8. Clean up
    git branch -d feature-test --quiet
}

test_integration_category() {
    printf "\n${CYAN}=== INTEGRATION TESTS ===${NC}\n\n"
    
    run_test "Full workflow test" test_full_workflow
}

# ============================================================================
# MAIN TEST RUNNER
# ============================================================================

main() {
    local category="${1:-all}"
    
    printf "${MAGENTA}╔══════════════════════════════════════════╗${NC}\n"
    printf "${MAGENTA}║     VERSION-CONTROL.SH TEST SUITE        ║${NC}\n"
    printf "${MAGENTA}╚══════════════════════════════════════════╝${NC}\n\n"
    
    printf "Test category: ${CYAN}%s${NC}\n" "$category"
    printf "Test directory: ${CYAN}%s${NC}\n" "$TEST_REPO_DIR"
    printf "Results file: ${CYAN}%s${NC}\n\n" "$TEST_RESULTS_FILE"
    
    # Initialize test environment
    init_test_env
    
    # Run tests based on category
    case "$category" in
        all)
            test_security_category
            test_memory_category
            test_git_config_category
            test_stash_category
            test_golden_rule_category
            test_commit_category
            test_sync_category
            test_branch_category
            test_advanced_category
            test_conflicts_category
            test_integration_category
            ;;
        security) test_security_category ;;
        memory) test_memory_category ;;
        git-config) test_git_config_category ;;
        stash) test_stash_category ;;
        golden-rule) test_golden_rule_category ;;
        commit) test_commit_category ;;
        sync) test_sync_category ;;
        branch) test_branch_category ;;
        advanced) test_advanced_category ;;
        conflicts) test_conflicts_category ;;
        integration) test_integration_category ;;
        *)
            printf "${RED}Unknown category: %s${NC}\n" "$category"
            cleanup_test_env
            exit 1
            ;;
    esac
    
    # Summary
    printf "\n${CYAN}╔══════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║              TEST SUMMARY                ║${NC}\n"
    printf "${CYAN}╚══════════════════════════════════════════╝${NC}\n\n"
    
    printf "Total tests run: ${BLUE}%d${NC}\n" "$TESTS_RUN"
    printf "Tests passed: ${GREEN}%d${NC}\n" "$TESTS_PASSED"
    printf "Tests failed: ${RED}%d${NC}\n" "$TESTS_FAILED"
    printf "Tests skipped: ${YELLOW}%d${NC}\n" "$TESTS_SKIPPED"
    
    local success_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    printf "Success rate: ${MAGENTA}%d%%${NC}\n\n" "$success_rate"
    
    # Cleanup
    cleanup_test_env
    
    # Exit with failure if any tests failed
    if [[ $TESTS_FAILED -gt 0 ]]; then
        printf "${RED}Some tests failed! Check ${TEST_RESULTS_FILE} for details.${NC}\n"
        exit 1
    else
        printf "${GREEN}All tests passed!${NC}\n"
        exit 0
    fi
}

# Run main
main "$@"