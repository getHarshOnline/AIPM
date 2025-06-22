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
# CRITICAL LEARNINGS INCORPORATED:
# 1. Session Detection:
#    - Read session file to recover context
#    - Handle missing session gracefully
#    - Support explicit context override
#
# 2. MCP Coordination:
#    - Wait for MCP server to release memory file
#    - Use release_from_mcp with timeout
#    - Proceed anyway if timeout occurs
#
# 3. Memory Restoration:
#    - Always restore backup after save
#    - Clean up session artifacts
#    - Handle errors without data loss
#
# Created by: AIPM Framework
# License: Apache 2.0

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source dependencies with error handling
source "$SCRIPT_DIR/modules/shell-formatting.sh" || {
    printf "ERROR: Required file shell-formatting.sh not found\n" >&2
    exit 1
}

source "$SCRIPT_DIR/modules/version-control.sh" || {
    error "Required file version-control.sh not found"
    exit 1
}

source "$SCRIPT_DIR/modules/migrate-memories.sh" || {
    error "Required file migrate-memories.sh not found"
    exit 1
}

source "$SCRIPT_DIR/modules/opinions-state.sh" || {
    error "Required file opinions-state.sh not found"
    exit 1
}

# Initialize state
ensure_state || {
    error "Failed to initialize state"
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
# CRITICAL: Must recover session state to clean up properly
# LEARNING: Session file created by start.sh contains all metadata
step "Detecting active session..."

if [[ ! -f "$SESSION_FILE" ]]; then
    error "No active session found"
    info "Did you run ./scripts/start.sh first?"
    die "Cannot proceed without active session"
fi

# Read session metadata
# LEARNING: Parse session file line by line for robustness
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
# CRITICAL: MCP server may be actively using memory.json
# LEARNING: release_from_mcp waits up to 5 seconds
# - Checks file permissions and actual access
# - Timeout is not fatal - we proceed anyway
step "Waiting for safe memory access..."

# Ensure MCP server has released the memory file
if ! release_from_mcp; then
    warn "Timeout waiting for MCP server release"
    info "Proceeding anyway..."
fi

# TASK 3.5: Check workflow rules for session end
step "Checking workflow rules..."

# Begin atomic operation for session stop
begin_atomic_operation "stop:session:$SESSION_ID"

# Get current branch and check if it's a session branch
local current_branch=$(get_current_branch)
local branch_type=""
local branches=$(get_value "runtime.branches")

# Determine branch type
if [[ -n "$branches" ]] && [[ -n "$current_branch" ]]; then
    branch_type=$(printf "%s\n" "$branches" | jq -r --arg b "$current_branch" '.[$b].type // ""')
fi

# Check if we should merge session branch
local should_merge=false
local merge_target=""

if [[ "$branch_type" == "session" ]]; then
    local session_merge=$(get_value "computed.workflows.merging.sessionMerge")
    
    case "$session_merge" in
        "on-stop")
            should_merge=true
            info "Workflow rule: Merge session branch on stop"
            # Get merge target from state
            local parent_branch=$(printf "%s\n" "$branches" | jq -r --arg b "$current_branch" '.[$b].parent // ""')
            merge_target="${parent_branch:-main}"
            ;;
        "prompt")
            local prompt_text=$(get_value "computed.workflows.merging.prompts.sessionComplete")
            if confirm "${prompt_text:-Merge session branch to parent?}"; then
                should_merge=true
                local parent_branch=$(printf "%s\n" "$branches" | jq -r --arg b "$current_branch" '.[$b].parent // ""')
                merge_target="${parent_branch:-main}"
            fi
            ;;
        "never")
            info "Session branches are not merged automatically"
            ;;
    esac
fi

# Check if we have uncommitted changes that need saving
local uncommitted_count=$(count_uncommitted_files)
local should_save=true

if [[ $uncommitted_count -eq 0 ]]; then
    info "No uncommitted changes to save"
    should_save=false
else
    info "Found $uncommitted_count uncommitted files"
fi

# TASK 4: Call save.sh for Memory Persistence
if [[ "$should_save" == "true" ]]; then
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
fi

# Handle session merge if configured
if [[ "$should_merge" == "true" ]] && [[ -n "$merge_target" ]]; then
    step "Merging session branch to $merge_target..."
    
    # First checkout the target branch
    if checkout_branch "$merge_target"; then
        # Now merge the session branch
        if merge_branch "$current_branch"; then
            success "Session branch merged successfully"
            
            # Update state with merge info
            update_state "runtime.branches.merged[]" "$current_branch" && \
            update_state "runtime.lastMerge" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            
            # Check cleanup workflow
            local cleanup_after_merge=$(get_value "computed.workflows.cleanup.afterMerge")
            
            case "$cleanup_after_merge" in
                "immediate")
                    step "Cleaning up merged session branch..."
                    if delete_branch "$current_branch"; then
                        success "Session branch deleted"
                        update_state "runtime.branches.deleted[]" "$current_branch"
                    else
                        warn "Failed to delete session branch"
                    fi
                    ;;
                "prompt")
                    local prompt_text=$(get_value "computed.workflows.cleanup.prompts.afterMerge")
                    if confirm "${prompt_text:-Delete merged session branch?}"; then
                        if delete_branch "$current_branch"; then
                            success "Session branch deleted"
                            update_state "runtime.branches.deleted[]" "$current_branch"
                        fi
                    fi
                    ;;
                "never")
                    info "Keeping merged session branch"
                    ;;
            esac
        else
            error "Failed to merge session branch"
            warn "Session work remains on branch: $current_branch"
            # Switch back to session branch
            checkout_branch "$current_branch"
        fi
    else
        error "Failed to checkout merge target: $merge_target"
    fi
fi

# Check push on stop workflow
local push_on_stop=$(get_value "computed.workflows.synchronization.pushOnStop")
local should_push=false

case "$push_on_stop" in
    "always")
        should_push=true
        ;;
    "if-feature")
        if [[ "$branch_type" == "feature" ]] || [[ "$branch_type" == "bugfix" ]]; then
            should_push=true
        fi
        ;;
    "prompt")
        local prompt_text=$(get_value "computed.workflows.synchronization.prompts.pushOnStop")
        if confirm "${prompt_text:-Push changes to remote?}"; then
            should_push=true
        fi
        ;;
esac

if [[ "$should_push" == "true" ]]; then
    step "Pushing changes to remote..."
    if push_to_remote; then
        success "Changes pushed to remote"
        update_state "runtime.lastPush" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    else
        warn "Failed to push changes - they remain local only"
    fi
fi

# TASK 5: Restore Original Memory (Using migrate-memories.sh)
if ! restore_memory; then
    error "Failed to restore original memory"
    warn "Backup preserved at: .memory/backup.json"
    # Don't exit - continue cleanup
fi

# TASK 6: Clean Session Artifacts
# LEARNING: Clean up removes session lock and archives metadata
# - Session log preserved for debugging
# - Session file renamed to indicate completion
# - Temp files cleaned via migrate-memories.sh
step "Cleaning up session artifacts..."

# Update session log
SESSION_LOG=".memory/session_${SESSION_ID}.log"
if [[ -f "$SESSION_LOG" ]]; then
    # LEARNING: Append final entries to session log
    cat >> "$SESSION_LOG" <<EOF

[$(date +%H:%M:%S)] Session ending
[$(date +%H:%M:%S)] Memory saved to: $MEMORY_FILE
[$(date +%H:%M:%S)] Duration: $duration_str

# Session ended: $(date)
EOF
fi

# Archive session file
# LEARNING: mv is atomic - prevents partial state
if mv "$SESSION_FILE" ".memory/session_${SESSION_ID}_complete" 2>/dev/null; then
    success "Session artifacts cleaned"
else
    warn "Failed to archive session file"
fi

# Clean up temporary files created by memory operations
cleanup_temp_files

# Update final session state
update_state "runtime.session.active" "false" && \
update_state "runtime.session.endTime" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
update_state "runtime.session.duration" "$duration_str" && \
update_state "runtime.lastSync" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ $? -eq 0 ]]; then
    commit_atomic_operation
    success "Session state updated"
else
    rollback_atomic_operation
    warn "Failed to update session end state"
fi

# TASK 7: Exit Claude Code
section "Cleanup Complete"
success "Session ended successfully"
info "Thank you for using AIPM!"
# Final instructions to user
warn "Please exit Claude Code manually"
info "Use Ctrl+C or close the terminal window"
section_end

# Note: We cannot automatically kill Claude Code as it would terminate
# this script before completion. The user must exit manually.