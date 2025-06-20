#!/opt/homebrew/bin/bash
#
# test-stash-ops.sh - Test stash operations with DID_STASH tracking
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIPM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Create test directory
TEST_DIR="$SCRIPT_DIR/stash-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEST_DIR"

printf "${MAGENTA}╔══════════════════════════════════════════╗${NC}\n"
printf "${MAGENTA}║         STASH OPERATIONS TEST            ║${NC}\n"
printf "${MAGENTA}╚══════════════════════════════════════════╝${NC}\n\n"

# Initialize test repo
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

# Source scripts
export AIPM_COLOR=true
export AIPM_UNICODE=true
source shell-formatting.sh
source version-control.sh

printf "${GREEN}✓ Test environment ready${NC}\n\n"

# Test results
PASSED=0
FAILED=0

# ============================================================================
# TEST 1: Basic stash and restore
# ============================================================================
printf "${CYAN}Test 1: Basic stash and restore${NC}\n"

# Create changes
echo "test content" > test-file.txt
echo "another file" > another.txt

# Check DID_STASH before
printf "DID_STASH before: %s\n" "${DID_STASH:-unset}"

# Stash changes
if stash_changes "Test stash message"; then
    printf "${GREEN}✓ Stash created${NC}\n"
    
    # Check DID_STASH
    if [[ "$DID_STASH" == "true" ]]; then
        printf "${GREEN}✓ DID_STASH correctly set to true${NC}\n"
        
        # Verify files are gone
        if [[ ! -f "test-file.txt" ]] && [[ ! -f "another.txt" ]]; then
            printf "${GREEN}✓ Files correctly stashed${NC}\n"
            
            # Restore stash
            if restore_stash; then
                printf "${GREEN}✓ Stash restored${NC}\n"
                
                # Check DID_STASH after restore
                if [[ "$DID_STASH" == "false" ]]; then
                    printf "${GREEN}✓ DID_STASH correctly reset to false${NC}\n"
                    
                    # Verify files are back
                    if [[ -f "test-file.txt" ]] && [[ -f "another.txt" ]]; then
                        printf "${GREEN}✓ Files correctly restored${NC}\n"
                        ((PASSED++))
                    else
                        printf "${RED}✗ Files not restored${NC}\n"
                        ((FAILED++))
                    fi
                else
                    printf "${RED}✗ DID_STASH not reset${NC}\n"
                    ((FAILED++))
                fi
            else
                printf "${RED}✗ Failed to restore stash${NC}\n"
                ((FAILED++))
            fi
        else
            printf "${RED}✗ Files not removed after stash${NC}\n"
            ((FAILED++))
        fi
    else
        printf "${RED}✗ DID_STASH not set${NC}\n"
        ((FAILED++))
    fi
else
    printf "${RED}✗ Failed to create stash${NC}\n"
    ((FAILED++))
fi

# Cleanup
rm -f test-file.txt another.txt

# ============================================================================
# TEST 2: Stash with untracked files
# ============================================================================
printf "${CYAN}Test 2: Stash with untracked files${NC}\n"

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
        printf "${GREEN}✓ Both tracked and untracked files stashed${NC}\n"
        
        # Check tracked file is at original state
        git checkout tracked.txt --quiet
        if grep -q "tracked" tracked.txt && ! grep -q "modified" tracked.txt; then
            printf "${GREEN}✓ Tracked file restored to committed state${NC}\n"
        fi
        
        # Restore
        restore_stash
        
        # Both should be back
        if [[ -f "tracked.txt" ]] && [[ -f "untracked.txt" ]]; then
            printf "${GREEN}✓ Both files restored${NC}\n"
            ((PASSED++))
        else
            printf "${RED}✗ Files not properly restored${NC}\n"
            ((FAILED++))
        fi
    else
        printf "${RED}✗ Files not properly stashed${NC}\n"
        ((FAILED++))
    fi
else
    printf "${RED}✗ Failed to stash with untracked${NC}\n"
    ((FAILED++))
fi

# Cleanup
git reset --hard --quiet
rm -f untracked.txt

# ============================================================================
# TEST 3: Multiple stashes
# ============================================================================
printf "${CYAN}Test 3: Multiple stashes and list${NC}\n"

# Create first stash
echo "stash 1" > file1.txt
stash_changes "First stash"

# Create second stash
echo "stash 2" > file2.txt
stash_changes "Second stash"

# List stashes
printf "Listing stashes:\n"
if list_stashes; then
    printf "${GREEN}✓ Stash list displayed${NC}\n"
    ((PASSED++))
else
    printf "${YELLOW}⚠ No stashes to list${NC}\n"
fi

# Clear stashes
git stash clear

# ============================================================================
# TEST 4: No changes to stash
# ============================================================================
printf "${CYAN}Test 4: No changes to stash${NC}\n"

# Reset DID_STASH
DID_STASH=false

# Try to stash with no changes
if stash_changes "Nothing to stash" 2>/dev/null; then
    printf "${RED}✗ Stash succeeded with no changes${NC}\n"
    ((FAILED++))
else
    printf "${GREEN}✓ Correctly failed with no changes${NC}\n"
    if [[ "$DID_STASH" == "false" ]]; then
        printf "${GREEN}✓ DID_STASH remained false${NC}\n"
        ((PASSED++))
    else
        printf "${RED}✗ DID_STASH incorrectly changed${NC}\n"
        ((FAILED++))
    fi
fi


# ============================================================================
# TEST 5: Restore without stash
# ============================================================================
printf "${CYAN}Test 5: Restore without stash${NC}\n"

# Reset DID_STASH
DID_STASH=false

# Try to restore without stashing first
if restore_stash 2>/dev/null; then
    printf "${RED}✗ Restore succeeded without stash${NC}\n"
    ((FAILED++))
else
    printf "${GREEN}✓ Correctly failed restore without stash${NC}\n"
    ((PASSED++))
fi


# ============================================================================
# SUMMARY
# ============================================================================

printf "${CYAN}╔══════════════════════════════════════════╗${NC}\n"
printf "${CYAN}║           TEST SUMMARY                   ║${NC}\n"
printf "${CYAN}╚══════════════════════════════════════════╝${NC}\n\n"

TOTAL=$((PASSED + FAILED))
printf "Total tests: ${CYAN}%d${NC}\n" "$TOTAL"
printf "Passed: ${GREEN}%d${NC}\n" "$PASSED"
printf "Failed: ${RED}%d${NC}\n" "$FAILED"

if [[ $FAILED -eq 0 ]]; then
    printf "\n${GREEN}✅ All stash tests passed!${NC}\n"
else
    printf "\n${RED}❌ Some tests failed!${NC}\n"
fi

# Cleanup
cd "$AIPM_ROOT"
rm -rf "$TEST_DIR"

exit $FAILED