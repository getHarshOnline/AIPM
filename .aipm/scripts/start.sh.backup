#!/opt/homebrew/bin/bash
#
# start.sh - Initialize AIPM session with backup-restore memory isolation
#
# Reference: AIPM_Design_Docs/memory-management.md - "Backup-Restore Memory Isolation"
#
# This script implements the session initialization flow:
# 1. Ensures .claude/memory.json symlink exists (calls sync-memory.sh if needed)
# 2. Prompts for context (--framework or --project NAME) with smart detection
# 3. Checks project git status and offers sync options
# 4. Backs up global memory to .memory/backup.json
# 5. Loads context-specific local_memory.json into global
# 6. Launches Claude Code with proper context
#
# Usage: 
#   ./scripts/start.sh                    # Interactive mode
#   ./scripts/start.sh --framework        # Framework development
#   ./scripts/start.sh --project Product  # Project work
#
# CRITICAL LEARNINGS INCORPORATED:
# 1. Session Management:
#    - Create session lock file to detect active sessions
#    - Track session metadata for debugging
#    - Handle interruptions gracefully
#
# 2. Memory Symlink:
#    - Must verify symlink before any operations
#    - Dynamic NPM cache detection
#    - Handle MCP server installation
#
# 3. Git Synchronization:
#    - Check for uncommitted changes
#    - Offer team sync options
#    - Use version-control.sh functions exclusively
#
# 4. Memory Loading:
#    - Backup global memory first (atomic)
#    - Load context-specific memory
#    - Validate all operations
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
section "AIPM Session Initialization"

# Session tracking variables
SESSION_ID="$(date +%Y%m%d_%H%M%S)_$$"
SESSION_FILE=".memory/session_active"
SESSION_LOG=".memory/session_${SESSION_ID}.log"

# Context variables
WORK_CONTEXT=""
PROJECT_NAME=""

# Claude args collection
declare -a claude_args=()

# TASK 1: Verify/Create Memory Symlink
# CRITICAL: Without this symlink, MCP server cannot function
# LEARNING: sync-memory.sh handles dynamic NPM cache detection
step "Checking memory symlink..."
if [[ ! -L ".claude/memory.json" ]]; then
    warn "Memory symlink missing, creating..."
    # LEARNING: sync-memory.sh will offer to install MCP if needed
    if ! "$SCRIPT_DIR/sync-memory.sh"; then
        die "Failed to create memory symlink"
    fi
    success "Memory symlink created"
else
    success "Memory symlink verified"
fi

# TASK 2: Context Detection and Selection
step "Parsing context..."

# Parse command line arguments
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
        --model)
            claude_args+=("--model" "$2")
            shift 2
            ;;
        *)
            # Pass through to Claude Code
            claude_args+=("$1")
            shift
            ;;
    esac
done

# Interactive mode if no context specified
if [[ -z "$WORK_CONTEXT" ]]; then
    info "Available contexts:"
    info "  1) Framework Development"
    
    # Project detection
    local project_num=2
    declare -A project_map
    
    for dir in */; do
        if [[ -f "${dir}.memory/local_memory.json" ]]; then
            project_map[$project_num]="${dir%/}"
            info "  $project_num) Project: ${dir%/}"
            ((project_num++))
        fi
    done
    
    # Get selection
    read -p "$(format_prompt "Select context (1-$((project_num-1)))")" selection
    
    if [[ "$selection" == "1" ]]; then
        WORK_CONTEXT="framework"
    elif [[ -n "${project_map[$selection]}" ]]; then
        WORK_CONTEXT="project"
        PROJECT_NAME="${project_map[$selection]}"
    else
        die "Invalid selection"
    fi
fi

success "Context: $WORK_CONTEXT${PROJECT_NAME:+ - $PROJECT_NAME}"

# TASK 3: Git Synchronization Check with Team Memory Sync
if [[ "$WORK_CONTEXT" == "project" ]]; then
    step "Checking project git status..."
    
    # Initialize version control context
    initialize_memory_context "--project" "$PROJECT_NAME"
    
    # Check if it's a git repo
    if ! check_git_repo "$PROJECT_NAME"; then
        warn "Project is not a git repository - skipping sync"
    else
        # Fetch remote updates
        info "Fetching remote updates..."
        if fetch_remote "$PROJECT_NAME"; then
            # Check if behind
            local status=$(get_commits_ahead_behind)
            if [[ "$status" =~ behind:[[:space:]]*([0-9]+) ]]; then
                local behind_count="${BASH_REMATCH[1]}"
                if [[ "$behind_count" -gt 0 ]]; then
                    success "Found $behind_count new memory updates from team"
                    if confirm "Pull latest changes?"; then
                        if pull_latest "$PROJECT_NAME"; then
                            success "Synchronized with team repository"
                        else
                            warn "Pull failed - continuing with local version"
                        fi
                    fi
                fi
            fi
        else
            warn "Failed to fetch remote - continuing offline"
        fi
    fi
else
    # Framework mode - check AIPM repo
    step "Checking framework git status..."
    initialize_memory_context "--framework"
    
    if check_git_repo; then
        show_git_status
    fi
fi

# TASK 3.5: Check workflow rules for branch creation
step "Checking workflow rules..."

# Get current branch info
local current_branch=$(get_current_branch)
local decisions=$(get_value "decisions")
local start_behavior=$(get_value "computed.workflows.branchCreation.startBehavior")

# Check if we should create a session branch
local should_create_branch=false
local branch_name=""

if [[ "$start_behavior" == "always" ]]; then
    should_create_branch=true
    info "Workflow rule: Always create session branch on start"
elif [[ "$start_behavior" == "check-first" ]]; then
    # Check if we're on main/protected branch
    local is_protected=false
    local protected_branches=$(get_value "computed.protectedBranches.all")
    
    if [[ -n "$protected_branches" ]]; then
        while IFS= read -r pattern; do
            if [[ "$current_branch" =~ $pattern ]]; then
                is_protected=true
                break
            fi
        done < <(printf '%s\n' "$protected_branches" | jq -r '.[]')
    fi
    
    if [[ "$is_protected" == "true" ]]; then
        should_create_branch=true
        info "On protected branch - will create session branch"
    fi
elif [[ "$start_behavior" == "prompt" ]]; then
    local prompt_text=$(get_value "computed.workflows.branchCreation.prompts.sessionStart")
    if confirm "${prompt_text:-Create a new session branch?}"; then
        should_create_branch=true
    fi
fi

# Create session branch if needed
if [[ "$should_create_branch" == "true" ]]; then
    # Get next session name from decisions
    branch_name=$(jq -r '.nextSessionName // ""' <<< "$decisions")
    if [[ -z "$branch_name" ]]; then
        # Fallback to generating name
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local prefix=$(get_value "raw_exports.AIPM_BRANCHING_PREFIX")
        branch_name="${prefix}session/${timestamp}"
    fi
    
    step "Creating session branch: $branch_name"
    if ! create_branch "session" "$branch_name"; then
        error "Failed to create session branch"
        # Check if we should continue anyway
        local creation_failure=$(get_value "computed.workflows.branchCreation.creationFailure")
        if [[ "$creation_failure" == "continue" ]]; then
            warn "Continuing on current branch: $current_branch"
        else
            die "Cannot proceed without session branch"
        fi
    else
        success "Session branch created and checked out"
        current_branch="$branch_name"
    fi
fi

# Check if we should pull/fetch
local pull_on_start=$(get_value "computed.workflows.synchronization.pullOnStart")
local working_tree_clean=$(is_working_tree_clean && echo "true" || echo "false")

if [[ "$pull_on_start" == "always" ]] || 
   ([[ "$pull_on_start" == "if-clean" ]] && [[ "$working_tree_clean" == "true" ]]); then
    step "Fetching remote changes..."
    if fetch_remote; then
        success "Remote changes fetched"
        
        # Check if we should pull
        local behind_count=$(get_commits_behind)
        if [[ $behind_count -gt 0 ]]; then
            if [[ "$pull_on_start" == "always" ]] || 
               ([[ "$pull_on_start" == "if-clean" ]] && [[ "$working_tree_clean" == "true" ]]); then
                step "Pulling remote changes..."
                if pull_changes; then
                    success "Pulled $behind_count commits from remote"
                else
                    warn "Pull failed - continuing with local state"
                fi
            fi
        fi
    fi
elif [[ "$pull_on_start" == "prompt" ]]; then
    local prompt_text=$(get_value "computed.workflows.synchronization.prompts.pullOnStart")
    if confirm "${prompt_text:-Check for remote updates?}"; then
        step "Fetching remote changes..."
        fetch_remote
    fi
fi

# Begin atomic operation for session start
begin_atomic_operation "start:session:$SESSION_ID"

# TASK 4: Memory Backup (Using migrate-memories.sh)
# CRITICAL: This is the cornerstone of memory isolation
# - Preserves current global state before loading context memory
# - Enables restoration at session end
# LEARNING: backup_memory uses atomic operations
if ! backup_memory; then
    rollback_atomic_operation
    die "Failed to backup global memory"
fi

# TASK 5: Load Context-Specific Memory with Team Merge
# LEARNING: Context-specific memory contains relevant knowledge
# - Framework: AIPM_ prefixed entities
# - Project: PROJECT_ prefixed entities
step "Loading $WORK_CONTEXT memory..."

# Determine memory file path
if [[ "$WORK_CONTEXT" == "framework" ]]; then
    MEMORY_FILE=".memory/local_memory.json"
else
    MEMORY_FILE="$PROJECT_NAME/.memory/local_memory.json"
    # Ensure project memory directory exists
    mkdir -p "$PROJECT_NAME/.memory"
fi

# Check if we need to merge team changes
# LEARNING: Team collaboration via memory merge
# - ALWAYS check for remote memory updates (automatic sync)
# - Uses "remote-wins" strategy for team contributions
# - Preserves local work if merge fails
if [[ -f "$MEMORY_FILE" ]]; then
    # Always check for remote memory updates regardless of git pull
    REMOTE_MEMORY="${MEMORY_FILE}.remote"
    
    # Try to get the latest version from git origin
    # LEARNING: Check origin/HEAD for team updates even without pull
    step "Checking for team memory updates..."
    if extract_memory_from_git "origin/HEAD" "$MEMORY_FILE" "$REMOTE_MEMORY" 2>/dev/null || \
       extract_memory_from_git "origin/main" "$MEMORY_FILE" "$REMOTE_MEMORY" 2>/dev/null || \
       extract_memory_from_git "origin/master" "$MEMORY_FILE" "$REMOTE_MEMORY" 2>/dev/null; then
        
        # Check if remote is different from local
        if ! memory_changed "$MEMORY_FILE" "$REMOTE_MEMORY"; then
            info "Local memory already up to date"
            rm -f "$REMOTE_MEMORY"
        else
            # Merge team changes automatically
            # LEARNING: merge_memories handles entity-level deduplication
            step "Merging team memory updates..."
            local remote_count=$(count_entities_stream "$REMOTE_MEMORY")
            local local_count=$(count_entities_stream "$MEMORY_FILE")
            info "Remote: $remote_count entities, Local: $local_count entities"
            
            if merge_memories "$MEMORY_FILE" "$REMOTE_MEMORY" "$MEMORY_FILE" "remote-wins"; then
                local merged_count=$(count_entities_stream "$MEMORY_FILE")
                success "Team memories merged successfully ($merged_count entities)"
            else
                warn "Memory merge failed - using local version"
            fi
            rm -f "$REMOTE_MEMORY"
        fi
    else
        # No remote memory found or fetch failed - continue with local
        debug "No remote memory updates found or fetch failed"
    fi
fi

# Load the (possibly merged) memory
if ! load_memory "$MEMORY_FILE"; then
    die "Failed to load project memory"
fi

# Prepare environment for MCP server
prepare_for_mcp

# TASK 6: Create Session Metadata
# LEARNING: Session tracking enables recovery and debugging
# - SESSION_FILE acts as a lock to prevent concurrent sessions
# - Contains all metadata needed to understand session state
# - Used by stop.sh to detect active sessions
step "Creating session metadata..."

# Create session file with all metadata
# LEARNING: Using heredoc preserves formatting
cat > "$SESSION_FILE" <<EOF
Session: $SESSION_ID
Context: $WORK_CONTEXT
Project: ${PROJECT_NAME:-N/A}
Started: $(date)
Branch: $(get_current_branch 2>/dev/null || echo "unknown")
Memory: $MEMORY_FILE
Backup: .memory/backup.json
PID: $$
EOF

# Create session log
cat > "$SESSION_LOG" <<EOF
# AIPM Session Log
# ID: $SESSION_ID
# Started: $(date)

[$(date +%H:%M:%S)] Session initialized
[$(date +%H:%M:%S)] Context: $WORK_CONTEXT
[$(date +%H:%M:%S)] Memory loaded from: $MEMORY_FILE
EOF

# Update state with session information
update_state "runtime.session.active" "true" && \
update_state "runtime.session.id" "$SESSION_ID" && \
update_state "runtime.session.context" "$WORK_CONTEXT" && \
update_state "runtime.session.startTime" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
update_state "runtime.currentBranch" "$(get_current_branch)" && \
update_state "runtime.session.project" "${PROJECT_NAME:-none}" && \
update_state "runtime.session.pid" "$$"

if [[ $? -eq 0 ]]; then
    commit_atomic_operation
    success "Session tracking initialized and state updated"
else
    rollback_atomic_operation
    # Clean up session files on failure
    rm -f "$SESSION_FILE" "$SESSION_LOG"
    die "Failed to update session state"
fi

# TASK 7: Launch Claude Code
section_end

# Show session summary
section "Session Ready"
info "Session ID: $SESSION_ID"
info "Context: $WORK_CONTEXT${PROJECT_NAME:+ - $PROJECT_NAME}"
info "Memory: $MEMORY_FILE"
info "Branch: $(get_current_branch 2>/dev/null || echo "unknown")"
section_end

# Final instructions
info "Launching Claude Code..."
info "When done, run: ./scripts/stop.sh"

# Add default model if not specified
if [[ ! " ${claude_args[@]} " =~ " --model " ]]; then
    claude_args+=("--model" "opus")
fi

# Launch Claude Code
claude code "${claude_args[@]}"