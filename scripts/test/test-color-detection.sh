#!/opt/homebrew/bin/bash
#
# test-color-detection.sh - Test color detection in shell-formatting.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIPM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Testing color detection..."
echo

# Test 1: Default behavior
echo "Test 1: Default behavior (no environment variables)"
(
    cd "$AIPM_ROOT"
    source scripts/shell-formatting.sh
    echo "COLOR_SUPPORT: '$COLOR_SUPPORT'"
    echo "Output test:"
    success "This should show color if terminal supports it"
)
echo

# Test 2: AIPM_COLOR=true (string)
echo "Test 2: AIPM_COLOR=true (string)"
(
    cd "$AIPM_ROOT"
    export AIPM_COLOR=true
    source scripts/shell-formatting.sh
    echo "COLOR_SUPPORT: '$COLOR_SUPPORT'"
    echo "Output test:"
    success "This should show color"
)
echo

# Test 3: AIPM_COLOR=false (string)
echo "Test 3: AIPM_COLOR=false (string)"
(
    cd "$AIPM_ROOT"
    export AIPM_COLOR=false
    source scripts/shell-formatting.sh
    echo "COLOR_SUPPORT: '$COLOR_SUPPORT'"
    echo "Output test:"
    success "This should NOT show color"
)
echo

# Test 4: Direct check
echo "Test 4: Direct color check"
(
    cd "$AIPM_ROOT"
    export AIPM_COLOR=true
    source scripts/shell-formatting.sh
    echo "Checking COLOR_SUPPORT values:"
    echo "  COLOR_SUPPORT == true: $([[ "$COLOR_SUPPORT" == true ]] && echo "YES" || echo "NO")"
    echo "  COLOR_SUPPORT == 'true': $([[ "$COLOR_SUPPORT" == "true" ]] && echo "YES" || echo "NO")"
    echo "  COLOR_SUPPORT != true: $([[ "$COLOR_SUPPORT" != true ]] && echo "YES" || echo "NO")"
    echo "  COLOR_SUPPORT != 'true': $([[ "$COLOR_SUPPORT" != "true" ]] && echo "YES" || echo "NO")"
)