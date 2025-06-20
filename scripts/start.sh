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
step "Checking memory symlink..."
if [[ ! -L ".claude/memory.json" ]]; then
    warn "Memory symlink missing, creating..."
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

# TASK 3: Git Synchronization Check
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
                    warn "You are $behind_count commits behind the remote"
                    if confirm "Pull latest changes?"; then
                        if ! pull_latest "$PROJECT_NAME"; then
                            warn "Pull failed - continuing anyway"
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

# TASK 4: Memory Backup
step "Backing up global memory..."
mkdir -p .memory

if [[ -f ".claude/memory.json" ]]; then
    if cp .claude/memory.json .memory/backup.json 2>/dev/null; then
        local backup_size=$(format_size $(stat -f%z .memory/backup.json 2>/dev/null || stat -c%s .memory/backup.json 2>/dev/null || echo "0"))
        success "Global memory backed up ($backup_size)"
    else
        warn "Failed to backup global memory"
    fi
else
    warn "No existing global memory - starting fresh"
    echo '{}' > .memory/backup.json
fi

# TASK 5: Load Context-Specific Memory
step "Loading $WORK_CONTEXT memory..."

# Determine memory file path
if [[ "$WORK_CONTEXT" == "framework" ]]; then
    MEMORY_FILE=".memory/local_memory.json"
else
    MEMORY_FILE="$PROJECT_NAME/.memory/local_memory.json"
    # Ensure project memory directory exists
    mkdir -p "$PROJECT_NAME/.memory"
fi

# Clear global memory first
echo '{}' > .claude/memory.json

# Load context-specific memory
if [[ -f "$MEMORY_FILE" ]]; then
    cp "$MEMORY_FILE" .claude/memory.json
    
    # Count entities and show stats
    local entity_count=$(grep -c '"type":"entity"' "$MEMORY_FILE" 2>/dev/null || echo "0")
    local memory_size=$(format_size $(stat -f%z "$MEMORY_FILE" 2>/dev/null || stat -c%s "$MEMORY_FILE" 2>/dev/null || echo "0"))
    
    success "Loaded $entity_count entities ($memory_size)"
else
    warn "No existing memory found, starting fresh"
    echo '{}' > "$MEMORY_FILE"
fi

# TASK 6: Create Session Metadata
step "Creating session metadata..."

# Create session file with all metadata
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

success "Session tracking initialized"

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
echo ""

# Add default model if not specified
if [[ ! " ${claude_args[@]} " =~ " --model " ]]; then
    claude_args+=("--model" "opus")
fi

# Launch Claude Code
claude code "${claude_args[@]}"