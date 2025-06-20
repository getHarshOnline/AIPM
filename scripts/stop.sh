#!/opt/homebrew/bin/bash
#
# stop.sh - End AIPM session with backup-restore memory cleanup
#
# Reference: AIPM_Design_Docs/memory-management.md - "Memory Flow - Session End"
#
# This script implements the session cleanup flow:
# 1. Detects active session context from start.sh
# 2. Calls save.sh to handle memory persistence
# 3. Restores original memory from backup
# 4. Cleans up session artifacts
# 5. Exits Claude Code session gracefully
#
# Usage: 
#   ./scripts/stop.sh                    # Auto-detect from session
#   ./scripts/stop.sh --framework        # Explicit framework context
#   ./scripts/stop.sh --project Product  # Explicit project context
#
# Created by: AIPM Framework
# License: Apache 2.0

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# TODO: source "$SCRIPT_DIR/shell-formatting.sh"
# TODO: source "$SCRIPT_DIR/version-control.sh"

# Colors for output (temporary until shell-formatting.sh)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       AIPM Session Cleanup               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"

# TODO: Implementation Tasks
# Reference: AIPM_Design_Docs/memory-management.md - "Session End" section

# TASK 1: Detect Session Context
# - Check for active session file (.memory/session_active)
# - Read context from session metadata
# - Allow override with command line args
# - Validate context matches start.sh context
# Implementation:
# SESSION_FILE=".memory/session_active"
# if [[ ! -f "$SESSION_FILE" ]]; then
#     echo -e "${RED}No active session found${NC}"
#     echo -e "${YELLOW}Did you run ./scripts/start.sh first?${NC}"
#     exit 1
# fi
# WORK_CONTEXT=$(grep "Context:" "$SESSION_FILE" | cut -d' ' -f2)
# PROJECT_NAME=$(grep "Project:" "$SESSION_FILE" | cut -d' ' -f2)

# TASK 2: Show Session Summary
# - Calculate session duration
# - Show memory statistics (entities/relations added)
# - Display context information
# Implementation:
# SESSION_START=$(grep "Started:" "$SESSION_FILE" | cut -d' ' -f2-)
# DURATION=$(($(date +%s) - $(date -d "$SESSION_START" +%s)))
# echo -e "${BLUE}Session Summary:${NC}"
# echo -e "  Context: ${MAGENTA}$WORK_CONTEXT${NC}"
# echo -e "  Project: ${MAGENTA}${PROJECT_NAME:-Framework}${NC}"
# echo -e "  Duration: ${MAGENTA}$(printf '%02d:%02d:%02d' $((DURATION/3600)) $((DURATION%3600/60)) $((DURATION%60)))${NC}"

# TASK 3: Call save.sh for Memory Persistence
# Reference: AIPM_Design_Docs/memory-management.md - "save.sh integration"
# - Pass context to save.sh
# - This handles the actual memory save to local_memory.json
# - Wait for save.sh to complete
# - Check exit status
# Implementation:
# echo -e "${YELLOW}Saving memory changes...${NC}"
# if [[ "$WORK_CONTEXT" == "framework" ]]; then
#     "$SCRIPT_DIR/save.sh" --framework "Session end: $(date +%Y-%m-%d_%H:%M:%S)" || {
#         echo -e "${RED}Failed to save memory changes${NC}"
#         exit 1
#     }
# else
#     "$SCRIPT_DIR/save.sh" --project "$PROJECT_NAME" "Session end: $(date +%Y-%m-%d_%H:%M:%S)" || {
#         echo -e "${RED}Failed to save memory changes${NC}"
#         exit 1
#     }
# fi

# TASK 4: Restore Original Memory
# Reference: AIPM_Design_Docs/memory-management.md - "Single backup location"
# - Check if backup exists at .memory/backup.json
# - Restore backup to .claude/memory.json
# - Delete backup after successful restore
# - Handle missing backup gracefully
# Implementation:
# BACKUP_FILE=".memory/backup.json"
# if [[ -f "$BACKUP_FILE" ]]; then
#     echo -e "${BLUE}Restoring original memory...${NC}"
#     cp "$BACKUP_FILE" .claude/memory.json || {
#         echo -e "${RED}Failed to restore backup${NC}"
#         exit 1
#     }
#     rm -f "$BACKUP_FILE"
#     echo -e "${GREEN}✓ Original memory restored${NC}"
# else
#     echo -e "${YELLOW}⚠️  No backup found to restore${NC}"
# fi

# TASK 5: Clean Session Artifacts
# - Move active session file to archived with timestamp
# - Update session log with end time
# - Clean any temporary files
# Implementation:
# SESSION_ID=$(grep "Session:" "$SESSION_FILE" | cut -d' ' -f2)
# SESSION_LOG=".memory/session_${SESSION_ID}.log"
# echo "Ended: $(date)" >> "$SESSION_LOG"
# echo "Memory saved to: $MEMORY_FILE" >> "$SESSION_LOG"
# mv "$SESSION_FILE" ".memory/session_${SESSION_ID}_complete"

# TASK 6: Exit Claude Code
# - Send termination signal to Claude Code process
# - Or provide instructions for manual exit
# - Show farewell message
# Implementation:
# echo -e "${GREEN}✓ Session cleanup complete${NC}"
# echo -e "${CYAN}════════════════════════════════════════════${NC}"
# echo -e "${MAGENTA}Thank you for using AIPM!${NC}"
# echo -e "${YELLOW}Please exit Claude Code manually (Ctrl+C or close terminal)${NC}"
# # Alternative: kill Claude Code process if we tracked PID

# TEMPORARY: Placeholder implementation
echo -e "${YELLOW}⚠️  Warning: Session management not yet implemented${NC}"
echo -e "${BLUE}ℹ️  See AIPM_Design_Docs/memory-management.md for design${NC}"
echo -e ""
echo -e "Expected flow:"
echo -e "  1. ${CYAN}Detect active session context${NC}"
echo -e "  2. ${CYAN}Call save.sh to persist memory${NC}"
echo -e "  3. ${CYAN}Restore backup to global memory${NC}"
echo -e "  4. ${CYAN}Clean up session artifacts${NC}"
echo -e "  5. ${CYAN}Exit Claude Code${NC}"
echo -e ""
echo -e "${CYAN}Please implement based on TODO comments above${NC}"