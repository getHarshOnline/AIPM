#!/opt/homebrew/bin/bash
#
# revert.sh - AIPM Memory Time Machine (Thin Orchestration Layer)
#
# PURPOSE:
# --------
# Provides a user-friendly interface to revert memory to previous git states.
# This is a THIN WRAPPER that orchestrates existing module functions.
#
# ARCHITECTURE PRINCIPLES:
# -----------------------
# 1. NO BUSINESS LOGIC: All logic lives in modules, not here
# 2. ORCHESTRATION ONLY: We only coordinate module function calls
# 3. USER EXPERIENCE: Rich feedback using shell-formatting.sh
# 4. PATH AGNOSTIC: All paths resolved dynamically via functions
# 5. ERROR HANDLING: Delegate to module functions, don't duplicate
#
# WHAT THIS SCRIPT DOES:
# ---------------------
# - Parses command-line arguments for context and options
# - Checks for active sessions (safety first!)
# - Shows memory history or revert preview
# - Orchestrates the revert operation
# - Provides clear user feedback
#
# WHAT THIS SCRIPT DOES NOT DO:
# -----------------------------
# - Direct git operations (use version-control.sh)
# - Memory file manipulation (use migrate-memories.sh)
# - State management (use opinions-state.sh)
# - Path resolution (use get_memory_path)
# - Business rule decisions (modules handle all logic)
#
# USAGE EXAMPLES:
# --------------
# ./revert.sh --list                    # Show memory history
# ./revert.sh --framework abc123        # Revert framework memory
# ./revert.sh --project Product def456  # Revert project memory
# ./revert.sh --partial "AIPM_" HEAD~3  # Partial revert with filter
#
# CRITICAL LEARNINGS:
# ------------------
# 1. Active Session Protection: Always check for active sessions first
# 2. Memory Path Resolution: NEVER hardcode paths, use get_memory_path()
# 3. Partial Reverts: New capability via revert_memory_partial()
# 4. User Guidance: Clear previews and confirmations prevent mistakes
#
# MAINTENANCE NOTES:
# -----------------
# - If adding new features, implement in modules first
# - Keep this script under 150 lines (currently ~115)
# - Maintain consistent error handling patterns
# - Test with both framework and project contexts
#
# WHY IT'S DONE THIS WAY:
# ----------------------
# Previous version had 466 lines with tons of business logic.
# This violated Single Responsibility Principle badly.
# Now it's a clean orchestration layer that's easy to understand.
#
# Dependencies: shell-formatting, version-control, migrate-memories, opinions-state
# Exit codes: 0 (success), 1 (error), uses die() for fatal errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Header - Visual indication of what script does
section "AIPM Memory Time Machine" "↶"
info "🕰️  Browse and restore your team's shared memory from any point in time"
info "🔍  Every decision, every context, perfectly preserved in git"
printf "\n"

# Parse arguments - Simple state tracking, no business logic
WORK_CONTEXT=""      # Will be "framework" or "project"
PROJECT_NAME=""      # Only used if context is "project"
COMMIT_REF=""        # Git commit to revert to
LIST_MODE=false      # Show history instead of reverting
PARTIAL_MODE=false   # Filter entities during revert
ENTITY_FILTER=""     # Regex pattern for partial mode

# LEARNING: Argument parsing should be simple and clear
# We don't validate here - that's the job of module functions
while [[ $# -gt 0 ]]; do
    case $1 in
        --framework) WORK_CONTEXT="framework"; shift ;;
        --project) WORK_CONTEXT="project"; PROJECT_NAME="$2"; shift 2 ;;
        --list) LIST_MODE=true; shift ;;
        --partial) PARTIAL_MODE=true; ENTITY_FILTER="${2:-}"; shift; shift ;;
        -h|--help) 
            # Use shell-formatting.sh for consistent help display
            show_help "revert" "Revert memory to previous state" \
                "--framework:Revert framework memory" \
                "--project NAME:Revert project memory" \
                "--list:Show memory history" \
                "--partial FILTER:Revert only matching entities"
            exit 0 
            ;;
        *) COMMIT_REF="$1"; shift ;;  # Positional arg is commit ref
    esac
done

# CRITICAL: Check for active session - Safety first!
# LEARNING: Always protect user from accidental data loss
# We use opinions-state.sh to check session status
if [[ "$(get_value 'runtime.session.active')" == "true" ]]; then
    error "Active session detected!"
    info "🚨 Your team member is currently working with shared memory"
    info "   We need to handle this carefully to prevent data loss"
    printf "\n"
    
    # LEARNING: Use select_with_default for consistent user prompts
    # This function is from shell-formatting.sh
    choice=$(select_with_default "Choose action" \
        "Abort this operation" \
        "Save and stop the session first" \
        "Force continue (may lose changes)")
    
    # Handle user choice - notice we delegate all operations
    case "$choice" in
        "Abort this operation")
            die "Operation aborted"  # die() from shell-formatting.sh
            ;;
        "Save and stop the session first")
            info "Saving current session..."
            # Delegate to version-control.sh for commit
            create_commit "Auto-save before revert" true && success "Changes saved"
            info "Stopping session..."
            # Delegate to opinions-state.sh for cleanup
            cleanup_session "$(get_value 'runtime.session.id')"
            ;;
        "Force continue (may lose changes)")
            warn "Proceeding without saving..."
            ;;
    esac
fi

# Auto-detect context if not specified
# LEARNING: get_project_context() provides interactive selection
if [[ -z "$WORK_CONTEXT" ]]; then
    WORK_CONTEXT=$(get_project_context)  # From version-control.sh
    [[ -z "$WORK_CONTEXT" ]] && die "No context selected"
fi

# Initialize memory context - CRITICAL for path resolution
# LEARNING: This sets up the correct memory paths based on context
# NEVER skip this step or paths will be wrong!
initialize_memory_context "$WORK_CONTEXT" "$PROJECT_NAME"  # From migrate-memories.sh
MEMORY_FILE=$(get_memory_path "$WORK_CONTEXT" "$PROJECT_NAME")  # Dynamic path!

# Handle list mode - Show history instead of reverting
if [[ "$LIST_MODE" == "true" ]]; then
    subsection "📜 Team Memory History"
    info "Each entry represents a moment when knowledge was captured:"
    printf "\n"
    # Delegate to version-control.sh for git history
    show_file_history "$MEMORY_FILE" "--oneline --no-merges" | head -20
    printf "\n"
    # format_command() from shell-formatting.sh for consistent display
    info "💡 To restore any previous state: $(format_command "./revert.sh HASH")"
    exit 0
fi

# Validate commit - Let module functions handle validation
# LEARNING: Always validate inputs using module functions
[[ -z "$COMMIT_REF" ]] && die "Commit reference required. Use --list to see history."
validate_commit "$COMMIT_REF" || die "Invalid commit: $COMMIT_REF"  # version-control.sh
file_exists_in_commit "$COMMIT_REF" "$MEMORY_FILE" || die "No memory file in commit $COMMIT_REF"

# Show preview - User should see what will happen
# LEARNING: Clear previews prevent accidental reverts
subsection "🔄 Revert Preview"
info "You're about to restore your team's collective memory to:"
printf "\n"
draw_line "-" 60  # shell-formatting.sh for visual separation
info "📌 Commit: $(get_commit_info "$COMMIT_REF" "%h - %s")"
info "👤 Author: $(get_commit_info "$COMMIT_REF" "%an")"
info "📅 Date: $(get_commit_info "$COMMIT_REF" "%ar")"
# Memory stats from migrate-memories.sh
info "🧠 Memory: $(get_file_from_commit "$COMMIT_REF" "$MEMORY_FILE" | get_memory_stats)"
draw_line "-" 60

# Confirm with clear consequences
# LEARNING: Always confirm destructive operations
printf "\n"
warn "⚠️  This will replace your team's current shared memory!"
info "   All AI assistants will immediately see this historical state"
confirm "Proceed with revert?" || die "Revert cancelled"  # shell-formatting.sh

# Perform revert - The actual operation
# LEARNING: execute_with_spinner provides visual feedback during operations
if [[ "$PARTIAL_MODE" == "true" ]]; then
    # NEW: Partial revert using our new function from Phase 1
    execute_with_spinner "🔍 Extracting filtered entities: $ENTITY_FILTER" \
        revert_memory_partial "$COMMIT_REF" "$MEMORY_FILE" "$ENTITY_FILTER" "$MEMORY_FILE"
else
    # Full revert - note the shell redirection, not direct file manipulation
    execute_with_spinner "⏮️  Restoring team memory from $COMMIT_REF" \
        "get_file_from_commit '$COMMIT_REF' '$MEMORY_FILE' > '$MEMORY_FILE'"
fi

# Report success - Update state and show results
# LEARNING: Always report operations for audit trail
report_git_operation "memory-reverted" "$COMMIT_REF"  # opinions-state.sh
printf "\n"
success_box "✨ Team Memory Successfully Restored!"
printf "\n"
info "🧠 Your team's shared context is now:"
info "   $(get_memory_stats "$MEMORY_FILE")"  # migrate-memories.sh
printf "\n"
info "💡 All team members will see this restored knowledge"
info "   when they start their next AIPM session"

# END OF SCRIPT - Clean, focused, maintainable!