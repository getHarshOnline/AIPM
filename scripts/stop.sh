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
# Source dependencies with error handling
source "$SCRIPT_DIR/shell-formatting.sh" || {
    printf "ERROR: Required file shell-formatting.sh not found\n" >&2
    exit 1
}

source "$SCRIPT_DIR/version-control.sh" || {
    error "Required file version-control.sh not found"
    exit 1
}

source "$SCRIPT_DIR/migrate-memories.sh" || {
    error "Required file migrate-memories.sh not found"
    exit 1
}

# Start visual section
section "AIPM Session Cleanup"

# Session tracking variables
SESSION_FILE=".memory/session_active"
WORK_CONTEXT=""
PROJECT_NAME=""
SESSION_ID=""
SESSION_START=""
MEMORY_FILE=""

# Parse command line arguments for override
while [[ $# -gt 0 ]]; do
    case $1 in
        --framework)
            WORK_CONTEXT="framework"
            shift
            ;;
        --project)
            WORK_CONTEXT="project"
            PROJECT_NAME="$2"
            shift 2
            ;;
        *)
            warn "Unknown argument: $1"
            shift
            ;;
    esac
done

# TASK 1: Detect Session Context
step "Detecting active session..."

if [[ ! -f "$SESSION_FILE" ]]; then
    error "No active session found"
    info "Did you run ./scripts/start.sh first?"
    die "Cannot proceed without active session"
fi

# Read session metadata
SESSION_ID=$(grep "Session:" "$SESSION_FILE" | cut -d' ' -f2-)
SESSION_CONTEXT=$(grep "Context:" "$SESSION_FILE" | cut -d' ' -f2-)
SESSION_PROJECT=$(grep "Project:" "$SESSION_FILE" | cut -d' ' -f2-)
SESSION_START=$(grep "Started:" "$SESSION_FILE" | cut -d' ' -f2-)
MEMORY_FILE=$(grep "Memory:" "$SESSION_FILE" | cut -d' ' -f2-)

# Use session context if no override provided
if [[ -z "$WORK_CONTEXT" ]]; then
    WORK_CONTEXT="$SESSION_CONTEXT"
    if [[ "$SESSION_PROJECT" != "N/A" ]] && [[ "$WORK_CONTEXT" == "project" ]]; then
        PROJECT_NAME="$SESSION_PROJECT"
    fi
else
    # Validate override matches session
    if [[ "$WORK_CONTEXT" != "$SESSION_CONTEXT" ]]; then
        warn "Context override ($WORK_CONTEXT) differs from session ($SESSION_CONTEXT)"
        if ! confirm "Continue with override?"; then
            die "Aborted by user"
        fi
    fi
fi

success "Session detected: $SESSION_ID"

# TASK 2: Show Session Summary
step "Calculating session statistics..."

# Calculate duration
local start_epoch
if command -v gdate >/dev/null 2>&1; then
    # macOS with GNU coreutils
    start_epoch=$(gdate -d "$SESSION_START" +%s 2>/dev/null || date +%s)
else
    # Linux or fallback
    start_epoch=$(date -d "$SESSION_START" +%s 2>/dev/null || date +%s)
fi
local current_epoch=$(date +%s)
local duration=$((current_epoch - start_epoch))

# Format duration
local hours=$((duration / 3600))
local minutes=$(( (duration % 3600) / 60 ))
local seconds=$((duration % 60))
local duration_str=$(printf '%02d:%02d:%02d' $hours $minutes $seconds)

section "Session Summary"
info "Session ID: $SESSION_ID"
info "Context: $WORK_CONTEXT${PROJECT_NAME:+ - $PROJECT_NAME}"
info "Duration: $duration_str"
info "Memory file: $MEMORY_FILE"

# Show memory changes if file exists
if [[ -f "$MEMORY_FILE" ]]; then
    local stats=$(get_memory_stats "$MEMORY_FILE")
    info "Current state: $stats"
fi

section_end

# TASK 3: Wait for MCP Server Release
step "Waiting for safe memory access..."

# Ensure MCP server has released the memory file
if ! release_from_mcp; then
    warn "Timeout waiting for MCP server release"
    info "Proceeding anyway..."
fi

# TASK 4: Call save.sh for Memory Persistence
step "Saving memory changes..."

# Build save command with context
local save_message="Session end: $(date +%Y-%m-%d_%H:%M:%S)"

if [[ "$WORK_CONTEXT" == "framework" ]]; then
    if "$SCRIPT_DIR/save.sh" --framework "$save_message"; then
        success "Memory changes saved"
    else
        error "Failed to save memory changes"
        warn "Memory may be lost - backup available at .memory/backup.json"
        # Continue anyway to clean up session
    fi
else
    if "$SCRIPT_DIR/save.sh" --project "$PROJECT_NAME" "$save_message"; then
        success "Memory changes saved"
    else
        error "Failed to save memory changes"
        warn "Memory may be lost - backup available at .memory/backup.json"
        # Continue anyway to clean up session
    fi
fi

# TASK 5: Restore Original Memory (Using migrate-memories.sh)
if ! restore_memory; then
    error "Failed to restore original memory"
    warn "Backup preserved at: .memory/backup.json"
    # Don't exit - continue cleanup
fi

# TASK 6: Clean Session Artifacts
step "Cleaning up session artifacts..."

# Update session log
SESSION_LOG=".memory/session_${SESSION_ID}.log"
if [[ -f "$SESSION_LOG" ]]; then
    cat >> "$SESSION_LOG" <<EOF

[$(date +%H:%M:%S)] Session ending
[$(date +%H:%M:%S)] Memory saved to: $MEMORY_FILE
[$(date +%H:%M:%S)] Duration: $duration_str

# Session ended: $(date)
EOF
fi

# Archive session file
if mv "$SESSION_FILE" ".memory/session_${SESSION_ID}_complete" 2>/dev/null; then
    success "Session artifacts cleaned"
else
    warn "Failed to archive session file"
fi

# Clean up temporary files created by memory operations
cleanup_temp_files

# TASK 7: Exit Claude Code
section "Cleanup Complete"
success "Session ended successfully"
info "Thank you for using AIPM!"
info ""
warn "Please exit Claude Code manually"
info "Use Ctrl+C or close the terminal window"
section_end

# Note: We cannot automatically kill Claude Code as it would terminate
# this script before completion. The user must exit manually.