#!/opt/homebrew/bin/bash
#
# test-stash-formatted.sh - Test stash operations with proper formatting
#

set -euo pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIPM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shell-formatting.sh FIRST
# Let environment detection decide colors - don't force them!
source "$AIPM_ROOT/scripts/shell-formatting.sh"

# Create test directory
TEST_DIR="$SCRIPT_DIR/stash-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEST_DIR"

printf "\n"
section "STASH OPERATIONS TEST"
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

# Initial commit
echo "# Stash Test" > README.md
git add README.md
git commit -m "Initial commit" --quiet

# Source scripts in test environment
source shell-formatting.sh
source version-control.sh

success "Test environment ready\n"

# Test results
PASSED=0
FAILED=0

# ============================================================================
# TEST 1: Basic stash and restore
# ============================================================================
section "Test 1: Basic stash and restore"

# Create changes
echo "test content" > test-file.txt
echo "another file" > another.txt

# Check DID_STASH before
debug "DID_STASH before: ${DID_STASH:-unset}"

# Stash changes
if stash_changes "Test stash message"; then
    success "Stash created"
    
    # Check DID_STASH
    if [[ "$DID_STASH" == "true" ]]; then
        success "DID_STASH correctly set to true"
        
        # Verify files are gone
        if [[ ! -f "test-file.txt" ]] && [[ ! -f "another.txt" ]]; then
            success "Files correctly stashed"
            
            # Restore stash
            if restore_stash; then
                success "Stash restored"
                
                # Check DID_STASH after restore
                if [[ "$DID_STASH" == "false" ]]; then
                    success "DID_STASH correctly reset to false"
                    
                    # Verify files are back
                    if [[ -f "test-file.txt" ]] && [[ -f "another.txt" ]]; then
                        success "Files correctly restored"
                        ((PASSED++))
                    else
                        error "Files not restored"
                        ((FAILED++))
                    fi
                else
                    error "DID_STASH not reset"
                    ((FAILED++))
                fi
            else
                error "Failed to restore stash"
                ((FAILED++))
            fi
        else
            error "Files not removed after stash"
            ((FAILED++))
        fi
    else
        error "DID_STASH not set"
        ((FAILED++))
    fi
else
    error "Failed to create stash"
    ((FAILED++))
fi

# Cleanup
rm -f test-file.txt another.txt

# ============================================================================
# TEST 2: Stash with untracked files
# ============================================================================
section "\nTest 2: Stash with untracked files"

# Create tracked and untracked files
echo "tracked" > tracked.txt
git add tracked.txt
git commit -m "Add tracked file" --quiet
echo "modified" >> tracked.txt  # Modify it

echo "untracked" > untracked.txt  # Create untracked

# Stash with untracked
if stash_changes "Stash with untracked" true; then
    # Both files should be gone
    if [[ ! -f "tracked.txt" ]] && [[ ! -f "untracked.txt" ]]; then
        success "Both tracked and untracked files stashed"
        
        # Check tracked file is at original state
        git checkout tracked.txt --quiet
        if grep -q "tracked" tracked.txt && ! grep -q "modified" tracked.txt; then
            success "Tracked file restored to committed state"
        fi
        
        # Restore
        restore_stash
        
        # Both should be back
        if [[ -f "tracked.txt" ]] && [[ -f "untracked.txt" ]]; then
            success "Both files restored"
            ((PASSED++))
        else
            error "Files not properly restored"
            ((FAILED++))
        fi
    else
        error "Files not properly stashed"
        ((FAILED++))
    fi
else
    error "Failed to stash with untracked"
    ((FAILED++))
fi

# Cleanup
git reset --hard --quiet
rm -f untracked.txt

# ============================================================================
# TEST 3: Multiple stashes and list
# ============================================================================
section "\nTest 3: Multiple stashes and list"

# Create first stash
echo "stash 1" > file1.txt
stash_changes "First stash"

# Create second stash
echo "stash 2" > file2.txt
stash_changes "Second stash"

# List stashes
step "Listing stashes"
if list_stashes; then
    success "Stash list displayed"
    ((PASSED++))
else
    warn "No stashes to list"
fi

# Clear stashes
git stash clear

# ============================================================================
# TEST 4: No changes to stash
# ============================================================================
section "\nTest 4: No changes to stash"

# Reset DID_STASH
DID_STASH=false

# Try to stash with no changes
if stash_changes "Nothing to stash" 2>/dev/null; then
    error "Stash succeeded with no changes"
    ((FAILED++))
else
    success "Correctly failed with no changes"
    if [[ "$DID_STASH" == "false" ]]; then
        success "DID_STASH remained false"
        ((PASSED++))
    else
        error "DID_STASH incorrectly changed"
        ((FAILED++))
    fi
fi

# ============================================================================
# TEST 5: Restore without stash
# ============================================================================
section "\nTest 5: Restore without stash"

# Reset DID_STASH
DID_STASH=false

# Try to restore without stashing first
if restore_stash 2>/dev/null; then
    error "Restore succeeded without stash"
    ((FAILED++))
else
    success "Correctly failed restore without stash"
    ((PASSED++))
fi

# ============================================================================
# SUMMARY
# ============================================================================
section "\nTEST SUMMARY"

TOTAL=$((PASSED + FAILED))
info "Total tests: $TOTAL"
success "Passed: $PASSED"
if [[ $FAILED -gt 0 ]]; then
    error "Failed: $FAILED"
else
    info "Failed: $FAILED"
fi

if [[ $FAILED -eq 0 ]]; then
    success "\nAll stash tests passed!"
else
    error "\nSome tests failed!"
fi

# Cleanup
cd "$AIPM_ROOT"
rm -rf "$TEST_DIR"

exit $FAILED