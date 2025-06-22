#!/opt/homebrew/bin/bash
#
# Test script for bidirectional state updates

# Move to repository root
cd "$(dirname "$0")/../../.." || exit 1

# Source shell formatting first
source ./.aipm/scripts/modules/shell-formatting.sh

section "Testing Bidirectional State Updates"

# Initialize state
info "1. Initializing state..."
./.aipm/scripts/modules/opinions-state.sh init || die "Failed to initialize state"

# Source the state module for function access
source ./.aipm/scripts/modules/opinions-state.sh

# Test single update
info "2. Testing single update..."
update_state "runtime.test" '"test-value"'
result=$(get_value "runtime.test")
success "Updated runtime.test, got: $result"

# Test batch update
info "3. Testing batch update..."
declare -a updates=(
    'runtime.batchTest1:"value1"'
    'runtime.batchTest2:"value2"'
    'runtime.batchTest3:123'
)
update_state_batch updates
plain "Batch test 1: $(get_value runtime.batchTest1)"
plain "Batch test 2: $(get_value runtime.batchTest2)"
plain "Batch test 3: $(get_value runtime.batchTest3)"

# Test increment
info "4. Testing increment..."
update_state "runtime.counter" "10"
increment_state "runtime.counter" 5
success "Counter after increment: $(get_value runtime.counter)"

# Test append to array
info "5. Testing append to array..."
update_state "runtime.testArray" '[]'
append_state "runtime.testArray" '"item1"'
append_state "runtime.testArray" '"item2"'
plain "Array contents: $(get_value runtime.testArray)"

# Test git operation reporting
info "6. Testing git operation reporting..."
report_git_operation "branch-created" "feature/test" "main"
plain "Current branch: $(get_value runtime.currentBranch)"
plain "Branch exists: $(get_value runtime.branches.feature/test.exists)"

# Test state removal
info "7. Testing state removal..."
remove_state "runtime.test"
removed_value=$(get_value "runtime.test" 2>&1)
if [[ -z "$removed_value" ]]; then
    success "Value successfully removed"
else
    error "Value still exists: $removed_value"
fi

section "All tests completed!"