#!/opt/homebrew/bin/bash
#
# quick-test.sh - Quick focused test of version-control.sh critical functions
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIPM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

printf "${CYAN}=== Quick Version Control Test ===${NC}\n\n"

# Test in current AIPM directory
cd "$AIPM_ROOT"

# Source the scripts
printf "Loading scripts...\n"
export AIPM_COLOR=true
export AIPM_UNICODE=true
source scripts/shell-formatting.sh || { printf "${RED}Failed to load shell-formatting.sh${NC}\n"; exit 1; }
source scripts/version-control.sh || { printf "${RED}Failed to load version-control.sh${NC}\n"; exit 1; }

printf "${GREEN}✓ Scripts loaded successfully${NC}\n\n"

# Test 1: Check git repo
printf "${CYAN}Test 1: Check git repo${NC}\n"
if check_git_repo; then
    printf "${GREEN}✓ Git repo check passed${NC}\n"
else
    printf "${RED}✗ Git repo check failed${NC}\n"
fi

# Test 2: Get current branch
printf "\n${CYAN}Test 2: Get current branch${NC}\n"
branch=$(get_current_branch)
printf "Current branch: ${GREEN}%s${NC}\n" "$branch"

# Test 3: Memory initialization
printf "\n${CYAN}Test 3: Memory initialization${NC}\n"
initialize_memory_context --framework
printf "AIPM_CONTEXT: ${GREEN}%s${NC}\n" "${AIPM_CONTEXT:-unknown}"
printf "MEMORY_FILE_PATH: ${GREEN}%s${NC}\n" "${MEMORY_FILE_PATH:-unknown}"
printf "PROJECT_NAME: ${GREEN}%s${NC}\n" "${PROJECT_NAME:-unknown}"

# Test 4: Check working directory
printf "\n${CYAN}Test 4: Working directory status${NC}\n"
if is_working_directory_clean; then
    printf "${GREEN}✓ Working directory is clean${NC}\n"
else
    printf "${YELLOW}⚠ Working directory has changes${NC}\n"
fi

# Test 5: Show git status
printf "\n${CYAN}Test 5: Git status display${NC}\n"
show_git_status

# Test 6: Find memory files
printf "\n${CYAN}Test 6: Find memory files${NC}\n"
memory_files=$(find_all_memory_files)
if [[ -n "$memory_files" ]]; then
    printf "Found memory files:\n"
    echo "$memory_files" | while read -r file; do
        printf "  ${GREEN}%s${NC}\n" "$file"
    done
else
    printf "${YELLOW}No memory files found${NC}\n"
fi

# Test 7: Exit codes
printf "\n${CYAN}Test 7: Exit codes defined${NC}\n"
printf "EXIT_SUCCESS: ${GREEN}%s${NC}\n" "${EXIT_SUCCESS:-undefined}"
printf "EXIT_GENERAL_ERROR: ${GREEN}%s${NC}\n" "${EXIT_GENERAL_ERROR:-undefined}"
printf "EXIT_GIT_COMMAND_FAILED: ${GREEN}%s${NC}\n" "${EXIT_GIT_COMMAND_FAILED:-undefined}"
printf "EXIT_WORKING_DIR_NOT_CLEAN: ${GREEN}%s${NC}\n" "${EXIT_WORKING_DIR_NOT_CLEAN:-undefined}"
printf "EXIT_MERGE_CONFLICT: ${GREEN}%s${NC}\n" "${EXIT_MERGE_CONFLICT:-undefined}"
printf "EXIT_NETWORK_ERROR: ${GREEN}%s${NC}\n" "${EXIT_NETWORK_ERROR:-undefined}"

# Test 8: Security context
printf "\n${CYAN}Test 8: Security context${NC}\n"
printf "AIPM_NESTING_LEVEL: ${GREEN}%s${NC}\n" "${AIPM_NESTING_LEVEL:-0}"
get_project_context
printf "PROJECT_ROOT: ${GREEN}%s${NC}\n" "${PROJECT_ROOT:-unknown}"
printf "IS_SYMLINKED: ${GREEN}%s${NC}\n" "${IS_SYMLINKED:-unknown}"

printf "\n${CYAN}=== Quick Test Complete ===${NC}\n"