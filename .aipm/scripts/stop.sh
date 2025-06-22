#!/opt/homebrew/bin/bash
#
# stop.sh - AIPM Session Terminator (Thin Orchestration Layer)
#
# PURPOSE:
# --------
# Gracefully ends an AIPM session, saving work and cleaning up.
# This is a THIN WRAPPER that orchestrates existing module functions.
#
# ARCHITECTURE PRINCIPLES:
# -----------------------
# 1. NO BUSINESS LOGIC: All logic lives in modules, not here
# 2. ORCHESTRATION ONLY: We coordinate module function calls
# 3. RELATIONSHIP AWARE: stop = save + cleanup (calls save.sh)
# 4. WORKFLOW AWARE: Respects merge and push rules
# 5. USER FRIENDLY: Clear feedback about what's happening
#
# WHAT THIS SCRIPT DOES:
# ---------------------
# - Gets current session information
# - Shows session duration
# - Saves uncommitted changes (via save.sh)
# - Merges session branch if configured
# - Pushes to remote if configured
# - Cleans up session state
# - Restores memory from backup
#
# WHAT THIS SCRIPT DOES NOT DO:
# -----------------------------
# - Direct git operations (delegates to version-control.sh)
# - Session state management (delegates to opinions-state.sh)
# - Memory manipulation (delegates to migrate-memories.sh)
# - Save logic (delegates to save.sh)
#
# USAGE EXAMPLES:
# --------------
# ./stop.sh                    # Stop current session
#
# CRITICAL LEARNINGS:
# ------------------
# 1. Session Info: get_session_info() provides ID:context:project
# 2. Stop = Save: Always offer to save before stopping
# 3. Session Branches: May need merging based on workflow
# 4. Memory Restore: Restore from backup after session ends
# 5. Manual Exit: User must exit Claude Code separately
#
# MAINTENANCE NOTES:
# -----------------
# - Keep this script under 80 lines (currently ~62)
# - This is the shortest wrapper - keep it that way
# - Test with dirty working directory
# - Verify session branch merge behavior
# - Check memory restoration works properly
#
# WHY IT'S DONE THIS WAY:
# ----------------------
# Previous version had 410 lines with:
# - Duplicate save logic (now calls save.sh)
# - Complex session detection
# - Manual memory operations
# - Hardcoded paths
# Now it's the cleanest wrapper - just orchestration.
#
# RELATIONSHIP TO save.sh:
# -----------------------
# stop.sh = save.sh + cleanup
# We literally call save.sh for the save part!
# This avoids duplication and maintains consistency.
#
# Dependencies: shell-formatting, version-control, migrate-memories, opinions-state
# Exit codes: 0 (success), 1 (error), uses die() for fatal errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Header
section "Ending AIPM Session" "🛑"
info "🤝 Let's save your team's progress and sync everything"
printf "\n"

# Get session info - Must have active session
# LEARNING: get_session_info() returns ID:context:project format
SESSION_INFO=$(get_session_info)  # opinions-state.sh
[[ -z "$SESSION_INFO" ]] && die "No active session found"

# Parse session info
# LEARNING: IFS with read is clean way to split strings
IFS=':' read -r SESSION_ID CONTEXT PROJECT <<< "$SESSION_INFO"
info "Session: $SESSION_ID"
info "Context: $(format_context "$CONTEXT" "$PROJECT")"  # shell-formatting.sh

# Calculate and show duration
# LEARNING: format_duration() handles time display nicely
start_time=$(get_value "runtime.session.startTime")  # opinions-state.sh
duration=$(format_duration "$start_time" "now")  # shell-formatting.sh
info "Duration: $duration"
printf "\n"

# CRITICAL: Save any uncommitted changes
# LEARNING: stop = save + cleanup, so we call save.sh!
if ! is_working_directory_clean; then  # version-control.sh
    warn "⚠️  You have uncommitted changes"
    info "   Your team won't see this knowledge until it's saved!"
    if confirm "Save before stopping?"; then  # shell-formatting.sh
        info "💾 Saving your discoveries for the team..."
        # Delegate to save.sh with proper context
        "$SCRIPT_DIR/save.sh" "--$CONTEXT" ${PROJECT:+"$PROJECT"} "Session end: $SESSION_ID"
    fi
fi

# Handle session branch merge if needed
# LEARNING: Session branches may need merging back
if [[ "$(get_branch_type "$(get_current_branch)")" == "session" ]]; then  # version-control.sh
    if [[ "$(get_workflow_rule 'merging.sessionMerge')" != "never" ]]; then  # opinions-state.sh
        if confirm "Merge session branch back to parent?"; then
            execute_with_spinner "Merging session work" \
                "safe_merge '$(get_current_branch)' '$(get_upstream_branch)'"  # version-control.sh
        fi
    fi
fi

# Handle push workflow
# LEARNING: pushOnStop rule controls this behavior
if [[ "$(get_workflow_rule 'synchronization.pushOnStop')" != "never" ]]; then
    printf "\n"
    execute_with_spinner "☁️  Syncing team memory to cloud" push_to_remote  # version-control.sh
    info "🌐 Your insights are now available to the whole team!"
fi

# Cleanup session
# LEARNING: cleanup_session() handles all state cleanup
execute_with_spinner "Cleaning up session" "cleanup_session '$SESSION_ID'"  # opinions-state.sh

# Restore memory from backup
# CRITICAL: Restore from workspace-relative backup path
backup_path="$(get_memory_path "$CONTEXT" "$PROJECT" | sed 's/local_memory.json/backup.json/')"
printf "\n"
execute_with_spinner "🔄 Restoring global memory state" \
    "restore_memory '$backup_path' '.aipm/memory.json'"  # migrate-memories.sh

# Farewell message
printf "\n"
success_box "✨ Session Ended Successfully!"
printf "\n"
info "🙏 Thank you for contributing to your team's collective intelligence!"
printf "\n"
draw_line "=" 60
info "💙 Made with love by Harsh Joshi (https://getharsh.in)"
info "🌟 Consider supporting the project if you found it helpful!"
info "🌐 https://github.com/getHarshOnline/aipm"
draw_line "=" 60
printf "\n"

# LEARNING: Claude Code must be exited manually
warn "🚪 Please exit Claude Code manually (Ctrl+C)"

# END OF SCRIPT - The cleanest wrapper of all!