#!/opt/homebrew/bin/bash
#
# test-golden-rule.sh - Focused test of golden rule implementation
#

set -euo pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIPM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Create test directory
TEST_DIR="$SCRIPT_DIR/golden-rule-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEST_DIR"

# Source shell-formatting.sh FIRST for all output functions
# Let environment detection decide colors - don't force them!
source "$AIPM_ROOT/scripts/shell-formatting.sh"

# Use shell-formatting functions for output
printf "\n"
section "GOLDEN RULE TEST SUITE"
printf "\n"

# Initialize test repo
step "Setting up test repository"
cd "$TEST_DIR"
git init --quiet
git config user.name "AIPM Test"
git config user.email "test@aipm.local"

# Copy scripts
cp "$AIPM_ROOT/scripts/shell-formatting.sh" .
cp "$AIPM_ROOT/scripts/version-control.sh" .

# Create initial structure
cat > .gitignore << 'EOF'
# Test ignores
*.tmp
*.log
test-output/
.DS_Store
EOF

echo "# Test Repo" > README.md
mkdir -p .memory
echo '{"entities":[],"relations":[]}' > .memory/local_memory.json

git add .
git commit -m "Initial test commit" --quiet

# Source scripts
# Already sourced shell-formatting.sh above, source again in test environment
source shell-formatting.sh
source version-control.sh --framework

success "Test environment ready\n"

# Test counters
PASSED=0
FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    info "Test: $test_name"
    if eval "$test_cmd"; then
        ((PASSED++))
        success "PASSED\n"
    else
        ((FAILED++))
        error "FAILED\n"
    fi
}

# ============================================================================
# GOLDEN RULE TEST 1: Respecting .gitignore
# ============================================================================
test_gitignore_respect() {
    step "Creating test files"
    
    # Files that should be added
    echo "content" > should-add-1.txt
    echo "content" > should-add-2.txt
    mkdir -p subdir
    echo "content" > subdir/should-add-3.txt
    
    # Files that should be ignored
    echo "ignored" > test.tmp
    echo "ignored" > test.log
    mkdir -p test-output
    echo "ignored" > test-output/data.txt
    
    # Run golden rule function
    add_all_untracked
    
    # Check results
    local staged=$(git diff --cached --name-only)
    local expected_count=3
    local actual_count=$(echo "$staged" | grep -E "(should-add-[123]\.txt)" | wc -l)
    
    info "Expected files staged: $expected_count"
    info "Actual files staged: $actual_count"
    
    # Verify ignored files NOT staged
    if echo "$staged" | grep -E "(\.tmp|\.log|test-output)"; then
        error "Ignored files were staged!"
        return 1
    fi
    
    # Reset for next test
    git reset --quiet
    rm -rf should-add-*.txt subdir test.tmp test.log test-output
    
    [[ $actual_count -eq $expected_count ]]
}

# ============================================================================
# GOLDEN RULE TEST 2: Memory file tracking
# ============================================================================
test_memory_tracking() {
    step "Testing memory file tracking"
    
    # Modify memory file
    echo '{"entities":[{"id":"e1"}],"relations":[]}' > .memory/local_memory.json
    
    # Ensure it's tracked
    ensure_memory_tracked
    
    # Check if staged
    local staged=$(git diff --cached --name-only)
    if echo "$staged" | grep -q "local_memory.json"; then
        success "Memory file correctly staged"
        git reset --quiet
        return 0
    else
        error "Memory file NOT staged"
        return 1
    fi
}

# ============================================================================
# GOLDEN RULE TEST 3: Stage all changes
# ============================================================================
test_stage_all_changes() {
    step "Testing comprehensive staging"
    
    # Create various changes
    echo "modified" >> README.md  # Modify tracked
    echo "new file" > new-file.txt  # Untracked
    echo '{"entities":[{"id":"e2"}],"relations":[{"id":"r1"}]}' > .memory/local_memory.json  # Memory
    echo "ignored" > should-ignore.tmp  # Should be ignored
    
    # Stage all
    stage_all_changes
    
    # Check results
    local staged=$(git diff --cached --name-only | sort)
    debug "Staged files:\n$staged"
    
    # Verify correct files staged
    local checks=0
    echo "$staged" | grep -q "README.md" && ((checks++))
    echo "$staged" | grep -q "new-file.txt" && ((checks++))
    echo "$staged" | grep -q "local_memory.json" && ((checks++))
    
    # Verify ignored file NOT staged
    if echo "$staged" | grep -q "should-ignore.tmp"; then
        error "Ignored file was staged!"
        return 1
    fi
    
    # Reset
    git reset --quiet
    git checkout README.md --quiet
    rm -f new-file.txt should-ignore.tmp
    git checkout .memory/local_memory.json --quiet
    
    [[ $checks -eq 3 ]]
}

# ============================================================================
# GOLDEN RULE TEST 4: Commit with auto-staging
# ============================================================================
test_commit_auto_stage() {
    step "Testing commit with auto-staging"
    
    # Create unstaged changes
    echo "auto stage test" > auto-stage.txt
    echo "modified for auto" >> README.md
    
    # Get initial commit count
    local initial_commits=$(git rev-list --count HEAD)
    
    # Create commit with auto-stage (golden rule)
    create_commit "Test auto-stage commit" "Testing golden rule" false true
    
    # Verify commit created
    local new_commits=$(git rev-list --count HEAD)
    if [[ $new_commits -gt $initial_commits ]]; then
        success "Commit created successfully"
        
        # Check committed files
        local committed=$(git diff-tree --no-commit-id --name-only -r HEAD)
        debug "Committed files:\n$committed"
        
        # Both files should be in commit
        local checks=0
        echo "$committed" | grep -q "auto-stage.txt" && ((checks++))
        echo "$committed" | grep -q "README.md" && ((checks++))
        
        [[ $checks -eq 2 ]]
    else
        error "No commit created"
        return 1
    fi
}

# ============================================================================
# GOLDEN RULE TEST 5: Safe add with symlinks
# ============================================================================
test_safe_add() {
    step "Testing safe add function"
    
    # Create test file
    echo "safe content" > safe-file.txt
    
    # Test safe add
    if safe_add "safe-file.txt"; then
        # Verify staged
        local staged=$(git diff --cached --name-only)
        if echo "$staged" | grep -q "safe-file.txt"; then
            success "File safely added"
            git reset --quiet
            rm -f safe-file.txt
            return 0
        fi
    fi
    
    return 1
}

# ============================================================================
# GOLDEN RULE TEST 6: Find all memory files
# ============================================================================
test_find_memory_files() {
    step "Testing memory file discovery"
    
    # Create additional project structure
    mkdir -p TestProject/.memory
    echo '{"entities":[],"relations":[]}' > TestProject/.memory/local_memory.json
    
    # Find all memory files
    local found_files=$(find_all_memory_files | sort)
    debug "Found memory files:\n$found_files"
    
    # Should find at least the main memory file
    local count=$(echo "$found_files" | grep -c "local_memory.json")
    
    # Clean up
    rm -rf TestProject
    
    [[ $count -ge 1 ]]
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

run_test "Respecting .gitignore" test_gitignore_respect
run_test "Memory file tracking" test_memory_tracking
run_test "Stage all changes" test_stage_all_changes
run_test "Commit with auto-staging" test_commit_auto_stage
run_test "Safe add function" test_safe_add
run_test "Find memory files" test_find_memory_files

# ============================================================================
# SUMMARY
# ============================================================================

section "TEST SUMMARY"

TOTAL=$((PASSED + FAILED))
info "Total tests: $TOTAL"
success "Passed: $PASSED"
if [[ $FAILED -gt 0 ]]; then
    error "Failed: $FAILED"
else
    info "Failed: $FAILED"
fi

if [[ $FAILED -eq 0 ]]; then
    success "\nAll golden rule tests passed!"
else
    error "\nSome tests failed!"
fi

# Cleanup
cd "$AIPM_ROOT"
rm -rf "$TEST_DIR"

exit $FAILED