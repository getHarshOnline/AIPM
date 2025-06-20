#!/opt/homebrew/bin/bash
#
# run-tests.sh - Simple test runner for version-control.sh tests
#
# This script provides an easy way to run specific test categories
# and view results.
#
# Usage:
#   ./scripts/test/run-tests.sh                  # Run all tests
#   ./scripts/test/run-tests.sh stash           # Run stash tests
#   ./scripts/test/run-tests.sh golden-rule     # Run golden rule tests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Show available test categories
show_categories() {
    printf "${CYAN}Available test categories:${NC}\n"
    printf "  ${GREEN}all${NC}          - Run all tests (default)\n"
    printf "  ${GREEN}security${NC}     - Test security & context management\n"
    printf "  ${GREEN}memory${NC}       - Test memory management initialization\n"
    printf "  ${GREEN}git-config${NC}   - Test git configuration functions\n"
    printf "  ${GREEN}stash${NC}        - Test stash operations\n"
    printf "  ${GREEN}golden-rule${NC}  - Test golden rule functions\n"
    printf "  ${GREEN}sync${NC}         - Test sync functions\n"
    printf "  ${GREEN}commit${NC}       - Test commit functions\n"
    printf "  ${GREEN}branch${NC}       - Test branch functions\n"
    printf "  ${GREEN}advanced${NC}     - Test advanced operations\n"
    printf "  ${GREEN}conflicts${NC}    - Test conflict resolution\n"
    printf "  ${GREEN}integration${NC}  - Test full workflow integration\n"
}

# Main
main() {
    local category="${1:-}"
    
    if [[ "$category" == "help" ]] || [[ "$category" == "--help" ]] || [[ "$category" == "-h" ]]; then
        show_categories
        exit 0
    fi
    
    if [[ -z "$category" ]]; then
        printf "${YELLOW}No category specified, running all tests...${NC}\n\n"
        category="all"
    fi
    
    # Run the test suite
    "$SCRIPT_DIR/test-version-control.sh" "$category"
}

main "$@"