#!/opt/homebrew/bin/bash
#
# save.sh - AIPM Memory Checkpoint Creator (Thin Orchestration Layer)
#
# PURPOSE:
# --------
# Creates git commits for memory checkpoints with user-friendly workflow.
# This is a THIN WRAPPER that orchestrates existing module functions.
#
# ARCHITECTURE PRINCIPLES:
# -----------------------
# 1. NO BUSINESS LOGIC: All logic lives in modules, not here
# 2. ORCHESTRATION ONLY: We only coordinate module function calls
# 3. USER EXPERIENCE: Clear feedback about what's being saved
# 4. WORKFLOW AWARE: Respects branch protection and automation rules
# 5. ERROR HANDLING: Delegate to module functions
#
# WHAT THIS SCRIPT DOES:
# ---------------------
# - Parses command-line arguments for context
# - Shows what will be saved
# - Checks branch protection rules
# - Stages all changes including memory
# - Creates commit with meaningful message
# - Optionally pushes to remote
#
# WHAT THIS SCRIPT DOES NOT DO:
# -----------------------------
# - Direct git operations (use version-control.sh)
# - Memory file manipulation (use migrate-memories.sh)
# - Branch creation logic (use version-control.sh)
# - Protection checking (use opinions-state.sh)
# - Path resolution (use get_memory_path)
#
# USAGE EXAMPLES:
# --------------
# ./save.sh --framework "Add new feature"      # Save framework changes
# ./save.sh --project Product "Fix bug #123"   # Save project changes
# ./save.sh --framework                        # Auto-generated message
#
# CRITICAL LEARNINGS:
# ------------------
# 1. Branch Protection: Always check can_perform() before saving
# 2. Auto-backup: Respect workflow rules for synchronization
# 3. Memory Tracking: ensure_memory_tracked() is essential
# 4. Commit Messages: Default to timestamp if not provided
#
# MAINTENANCE NOTES:
# -----------------
# - Keep this script under 100 lines (currently ~81)
# - Don't add business logic - add to modules instead
# - Test with protected branches to ensure workflow works
# - Verify auto-backup behavior when configured
#
# WHY IT'S DONE THIS WAY:
# ----------------------
# Previous version had 315 lines with embedded logic for:
# - Branch protection checking
# - Memory file handling
# - Complex workflow decisions
# Now it's a clean orchestration that delegates everything.
#
# Dependencies: shell-formatting, version-control, migrate-memories, opinions-state
# Exit codes: 0 (success), 1 (error), uses die() for fatal errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/shell-formatting.sh" || exit 1
source "$SCRIPT_DIR/modules/version-control.sh" || exit 1
source "$SCRIPT_DIR/modules/migrate-memories.sh" || exit 1
source "$SCRIPT_DIR/modules/opinions-state.sh" || exit 1

# Parse arguments - Keep it simple
WORK_CONTEXT=""      # Will be "framework" or "project"
PROJECT_NAME=""      # Only used if context is "project"
COMMIT_MSG=""        # User's commit message

# LEARNING: Simple argument parsing with clear intent
while [[ $# -gt 0 ]]; do
    case $1 in
        --framework) WORK_CONTEXT="framework"; shift ;;
        --project) WORK_CONTEXT="project"; PROJECT_NAME="$2"; shift 2 ;;
        -h|--help) 
            show_help "save" "Save memory checkpoint" \
                "--framework:Save framework memory" \
                "--project NAME:Save project memory"
            exit 0 
            ;;
        *) COMMIT_MSG="$*"; break ;;  # Rest is commit message
    esac
done

# Validate context - Must specify where to save
[[ -z "$WORK_CONTEXT" ]] && die "Must specify --framework or --project NAME"

# Default commit message if not provided
# LEARNING: Always have sensible defaults
[[ -z "$COMMIT_MSG" ]] && COMMIT_MSG="Checkpoint: $(date +%Y-%m-%d\ %H:%M:%S)"

# Show what we're saving - User feedback is important
section "Creating Memory Checkpoint" "💾"
info "🤝 Saving your team's collective knowledge to git"
info "   Every insight preserved, every decision tracked"
printf "\n"
info "Context: $(format_context "$WORK_CONTEXT" "$PROJECT_NAME")"  # shell-formatting.sh
info "Message: $COMMIT_MSG"
printf "\n"

# Initialize and check permissions
# LEARNING: These two calls are essential setup
initialize_memory_context "$WORK_CONTEXT" "$PROJECT_NAME"  # migrate-memories.sh
ensure_state  # opinions-state.sh - loads state if needed

# Check if we can save to current branch
# LEARNING: Branch protection is enforced via opinions-state.sh
if ! can_perform "save" "$(get_current_branch)"; then
    # Get configured response for protected branches
    response=$(get_workflow_rule "branchCreation.protectionResponse")
    case "$response" in
        "prompt")
            # Ask user what to do
            warn "⚠️  You're on a protected branch: $(get_current_branch)"
            info "   Protected branches ensure team coordination"
            confirm "Continue anyway?" || die "Save cancelled"
            ;;
        "create-feature")
            # Auto-create feature branch
            info "🌱 Creating feature branch for safe collaboration..."
            create_branch "feature" "save-$(date +%Y%m%d-%H%M%S)"  # version-control.sh
            ;;
        *) 
            # Deny by default
            die "Cannot save to protected branch - team rules prevent this" 
            ;;
    esac
fi

# Get memory path and ensure it's tracked
# LEARNING: Memory files must be in git for AIPM to work
MEMORY_FILE=$(get_memory_path "$WORK_CONTEXT" "$PROJECT_NAME")  # Dynamic path!
ensure_memory_tracked  # version-control.sh - adds memory files if needed

# Stage all changes including memory files
# LEARNING: execute_with_spinner provides visual feedback
execute_with_spinner "📦 Staging all changes and memory updates" stage_all_changes true  # version-control.sh

# Get memory stats for reporting
# LEARNING: Show user what they're saving
stats=$(get_memory_stats "$MEMORY_FILE")  # migrate-memories.sh

# Commit changes - The main operation
if create_commit "$COMMIT_MSG" true; then  # version-control.sh
    # Report to state for audit trail
    report_git_operation "save-completed" "$(get_branch_commit HEAD)" "{\"stats\": \"$stats\"}"
    printf "\n"
    success_box "✨ Team Memory Checkpoint Created!"
    printf "\n"
    info "🧠 Saved: $stats"
    info "📍 Commit: $(get_branch_commit HEAD | cut -c1-7)"
    printf "\n"
    info "💡 Your teammates will get this knowledge when they pull"
    
    # Auto-backup if configured
    # LEARNING: Workflow rules control automation
    if [[ "$(get_workflow_rule "synchronization.autoBackup")" == "on-save" ]]; then
        printf "\n"
        execute_with_spinner "☁️  Syncing to cloud for team access" push_to_remote  # version-control.sh
        info "🌐 Team memory synchronized across all members!"
    fi
else
    die "Failed to create checkpoint - team memory not saved"
fi

# END OF SCRIPT - Clean, focused, maintainable!