#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Header
section "Ending AIPM Session" "🛑"

# Get session info
SESSION_INFO=$(get_session_info)
[[ -z "$SESSION_INFO" ]] && die "No active session found"

IFS=':' read -r SESSION_ID CONTEXT PROJECT <<< "$SESSION_INFO"
info "Session: $SESSION_ID"
info "Context: $(format_context "$CONTEXT" "$PROJECT")"

# Calculate duration
start_time=$(get_value "runtime.session.startTime")
duration=$(format_duration "$start_time" "now")
info "Duration: $duration"
printf "\n"

# Save any uncommitted changes (stop = save + cleanup)
if ! is_working_directory_clean; then
    warn "You have uncommitted changes"
    if confirm "Save before stopping?"; then
        info "Saving your work..."
        "$SCRIPT_DIR/save.sh" "--$CONTEXT" ${PROJECT:+"$PROJECT"} "Session end: $SESSION_ID"
    fi
fi

# Handle session branch merge
if [[ "$(get_branch_type "$(get_current_branch)")" == "session" ]]; then
    if [[ "$(get_workflow_rule 'merging.sessionMerge')" != "never" ]]; then
        if confirm "Merge session branch back to parent?"; then
            execute_with_spinner "Merging session work" \
                "safe_merge '$(get_current_branch)' '$(get_upstream_branch)'"
        fi
    fi
fi

# Handle push workflow
if [[ "$(get_workflow_rule 'synchronization.pushOnStop')" != "never" ]]; then
    execute_with_spinner "Pushing to remote" push_to_remote
fi

# Cleanup
execute_with_spinner "Cleaning up session" "cleanup_session '$SESSION_ID'"
# Restore from workspace-relative backup path
backup_path="$(get_memory_path "$CONTEXT" "$PROJECT" | sed 's/local_memory.json/backup.json/')"
execute_with_spinner "Restoring memory" \
    "restore_memory '$backup_path' '.aipm/memory.json'"

# Farewell message
printf "\n"
success_box "Session Ended Successfully!"
info "Thanks for using AIPM!"
printf "\n"
warn "Please exit Claude Code manually (Ctrl+C)"