# AIPM Wrapper Scripts Implementation Workflow

## Overview

This document serves as the **single source of truth** for implementing the AIPM wrapper scripts (start.sh, stop.sh, save.sh, revert.sh). It provides exact file references, function mappings, and implementation guardrails to ensure consistency with the AIPM vision.

## Table of Contents

1. [Core Design Principles](#core-design-principles)
2. [File References & Dependencies](#file-references--dependencies)
3. [Function Mapping Reference](#function-mapping-reference)
4. [Implementation Workflow](#implementation-workflow)
5. [Script-by-Script Implementation](#script-by-script-implementation)
6. [Testing Workflow](#testing-workflow)
7. [Common Patterns & Guardrails](#common-patterns--guardrails)

## Core Design Principles

### CRITICAL RULES - NEVER VIOLATE

1. **NO DIRECT OUTPUT**
   - ❌ NEVER use: `echo`, `printf`, `print`
   - ✅ ALWAYS use: shell-formatting.sh functions
   - Reference: `scripts/shell-formatting.sh` lines 246-376

2. **NO DIRECT GIT**
   - ❌ NEVER use: `git add`, `git commit`, `git push`
   - ✅ ALWAYS use: version-control.sh functions
   - Reference: `scripts/version-control.sh` lines 290-1669

3. **MEMORY ISOLATION**
   - Single backup location: `.memory/backup.json`
   - Reference: `AIPM_Design_Docs/memory-management.md` lines 36-103

4. **ERROR HANDLING**
   - Always use `die()` for fatal errors
   - Reference: `scripts/shell-formatting.sh` lines 385-390

## File References & Dependencies

### Primary Implementation Files
```
scripts/
├── start.sh          # Lines 1-174 contain detailed TODOs
├── stop.sh           # Lines 1-141 contain detailed TODOs
├── save.sh           # Lines 1-161 contain detailed TODOs
├── revert.sh         # Lines 1-179 contain detailed TODOs
├── shell-formatting.sh    # REQUIRED - Output functions
├── version-control.sh     # REQUIRED - Git wrapper functions
└── sync-memory.sh         # CALLED BY - start.sh for symlink
```

### Documentation References
```
AIPM_Design_Docs/
└── memory-management.md   # Lines 36-103: Backup-Restore Flow
                          # Lines 107-123: Script Usage Examples
                          # Lines 212-219: Core Scripts Section

scripts/test/
├── version-control.md     # Lines 547-693: Integration Patterns
└── workflow.md           # THIS FILE - Implementation Guide

current-focus.md          # Lines 30-76: Implementation Sprint Details
```

## Function Mapping Reference

### From shell-formatting.sh (USE THESE ONLY)

| Function | Line | Purpose | Usage Example |
|----------|------|---------|---------------|
| `section()` | 297-304 | Start visual section | `section "AIPM Session Init"` |
| `section_end()` | 308-313 | End section | `section_end` |
| `step()` | 317-322 | Show progress step | `step "Loading memory..."` |
| `info()` | 326-329 | Information message | `info "Session ID: $id"` |
| `success()` | 333-336 | Success message | `success "Memory loaded"` |
| `warn()` | 340-343 | Warning message | `warn "No backup found"` |
| `error()` | 347-350 | Error message | `error "Failed to load"` |
| `die()` | 385-390 | Fatal error + exit | `die "Cannot continue"` |
| `confirm()` | 394-412 | User confirmation | `if confirm "Continue?"; then` |
| `execute_with_spinner()` | 587-626 | Long operations | `execute_with_spinner "Fetching" "cmd" 30` |
| `format_size()` | 729-751 | Format bytes | `format_size 1024` |

### From version-control.sh (USE THESE ONLY)

| Function | Line | Purpose | Usage Example |
|----------|------|---------|---------------|
| `initialize_memory_context()` | 212-264 | Setup memory paths | `initialize_memory_context "--framework"` |
| `check_git_repo()` | 299-315 | Validate repo | `check_git_repo || die "Not a repo"` |
| `get_current_branch()` | 321-340 | Get branch name | `branch=$(get_current_branch)` |
| `is_working_directory_clean()` | 362-388 | Check for changes | `if ! is_working_directory_clean; then` |
| `fetch_remote()` | 598-640 | Fetch updates | `fetch_remote "$PROJECT_NAME"` |
| `pull_latest()` | 649-729 | Pull with stash | `pull_latest "$PROJECT_NAME"` |
| `get_commits_ahead_behind()` | 394-408 | Sync status | `status=$(get_commits_ahead_behind)` |
| `stage_all_changes()` | 987-1021 | Golden rule | `stage_all_changes || die` |
| `commit_with_stats()` | 814-865 | Commit + stats | `commit_with_stats "$msg" "$file"` |
| `show_log()` | 1241-1269 | Display history | `show_log 10 "$MEMORY_FILE"` |
| `show_git_status()` | 414-476 | Pretty status | `show_git_status` |

## Implementation Workflow

### Phase 1: Setup & Dependencies
```bash
#!/opt/homebrew/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CRITICAL: Source with error handling
source "$SCRIPT_DIR/shell-formatting.sh" || {
    printf "ERROR: Required file shell-formatting.sh not found\n" >&2
    exit 1
}

source "$SCRIPT_DIR/version-control.sh" || {
    error "Required file version-control.sh not found"
    exit 1
}
```

### Phase 2: Argument Parsing Pattern
```bash
# Standard argument parsing for context
WORK_CONTEXT=""
PROJECT_NAME=""

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
            # Script-specific handling
            ;;
    esac
done
```

### Phase 3: Context Detection Pattern
```bash
# Interactive mode if no arguments
if [[ -z "$WORK_CONTEXT" ]]; then
    section "Select Work Context"
    info "Available contexts:"
    info "  1) Framework Development"
    
    # Project detection
    local project_num=2
    declare -A project_map
    
    for dir in */; do
        if [[ -f "$dir/.memory/local_memory.json" ]]; then
            project_map[$project_num]="${dir%/}"
            info "  $project_num) Project: ${dir%/}"
            ((project_num++))
        fi
    done
    
    # Selection handling...
fi
```

## Script-by-Script Implementation

### 1. start.sh Implementation

Reference: `scripts/start.sh` lines 45-174 for detailed TODOs

#### Task Flow:
1. **Memory Symlink** (lines 45-53)
   ```bash
   if [[ ! -L ".claude/memory.json" ]]; then
       warn "Memory symlink missing, creating..."
       if ! "$SCRIPT_DIR/sync-memory.sh"; then
           die "Failed to create memory symlink"
       fi
   fi
   ```

2. **Context Selection** (lines 55-73)
   - Parse args or show interactive menu
   - Store in `WORK_CONTEXT` and `PROJECT_NAME`

3. **Git Sync** (lines 75-90)
   ```bash
   if [[ "$WORK_CONTEXT" == "project" ]]; then
       step "Checking project git status..."
       
       # Initialize for version-control.sh
       initialize_memory_context "--project" "$PROJECT_NAME"
       
       if ! check_git_repo "$PROJECT_NAME"; then
           die "Project is not a git repository"
       fi
       
       # Check sync status
       local status=$(get_commits_ahead_behind)
       # ... handle behind commits
   fi
   ```

4. **Memory Backup** (lines 92-106)
   ```bash
   step "Backing up global memory..."
   mkdir -p .memory
   
   if cp .claude/memory.json .memory/backup.json 2>/dev/null; then
       success "Global memory backed up"
   else
       warn "No existing global memory - starting fresh"
       echo '{}' > .memory/backup.json
   fi
   ```

5. **Load Context Memory** (lines 108-129)
   ```bash
   # Determine path
   if [[ "$WORK_CONTEXT" == "framework" ]]; then
       MEMORY_FILE=".memory/local_memory.json"
   else
       MEMORY_FILE="$PROJECT_NAME/.memory/local_memory.json"
   fi
   
   # Clear and load
   echo '{}' > .claude/memory.json
   if [[ -f "$MEMORY_FILE" ]]; then
       cp "$MEMORY_FILE" .claude/memory.json
       # Count entities...
   fi
   ```

6. **Session Metadata** (lines 131-147)
   ```bash
   cat > "$SESSION_FILE" <<EOF
   Session: $SESSION_ID
   Context: $WORK_CONTEXT
   Project: ${PROJECT_NAME:-N/A}
   Started: $(date)
   Branch: $(get_current_branch)
   Memory: $MEMORY_FILE
   EOF
   ```

7. **Launch Claude** (lines 149-174)
   ```bash
   info "Launching Claude Code..."
   section_end
   
   claude code "${claude_args[@]}"
   ```

### 2. stop.sh Implementation

Reference: `scripts/stop.sh` lines 45-141 for detailed TODOs

#### Task Flow:
1. **Session Detection** (lines 45-58)
   ```bash
   SESSION_FILE=".memory/session_active"
   if [[ ! -f "$SESSION_FILE" ]]; then
       error "No active session found"
       die "Did you run ./scripts/start.sh first?"
   fi
   
   # Read metadata
   WORK_CONTEXT=$(grep "Context:" "$SESSION_FILE" | cut -d' ' -f2-)
   ```

2. **Session Summary** (lines 60-70)
   ```bash
   # Calculate duration
   local duration=$(($(date +%s) - start_epoch))
   
   section "Session Summary"
   info "Duration: $(printf '%02d:%02d:%02d' ...)"
   ```

3. **Call save.sh** (lines 72-90)
   ```bash
   step "Saving memory changes..."
   
   if [[ "$WORK_CONTEXT" == "framework" ]]; then
       "$SCRIPT_DIR/save.sh" --framework "Session end: $(date +%Y-%m-%d_%H:%M:%S)"
   else
       "$SCRIPT_DIR/save.sh" --project "$PROJECT_NAME" "Session end: $(date +%Y-%m-%d_%H:%M:%S)"
   fi
   ```

4. **Restore Backup** (lines 92-107)
   ```bash
   BACKUP_FILE=".memory/backup.json"
   if [[ -f "$BACKUP_FILE" ]]; then
       cp "$BACKUP_FILE" .claude/memory.json
       rm -f "$BACKUP_FILE"
   fi
   ```

5. **Cleanup** (lines 109-141)
   ```bash
   # Archive session file
   mv "$SESSION_FILE" ".memory/session_${SESSION_ID}_complete"
   
   section "Cleanup Complete"
   warn "Please exit Claude Code manually"
   ```

### 3. save.sh Implementation

Reference: `scripts/save.sh` lines 45-161 for detailed TODOs

#### Task Flow:
1. **Parse Arguments** (lines 45-73)
   - Extract context and optional commit message

2. **Determine Paths** (lines 75-92)
   ```bash
   # Initialize for version-control.sh
   initialize_memory_context "--$WORK_CONTEXT" ${PROJECT_NAME:+"$PROJECT_NAME"}
   
   if [[ "$WORK_CONTEXT" == "framework" ]]; then
       LOCAL_MEMORY=".memory/local_memory.json"
   else
       LOCAL_MEMORY="$PROJECT_NAME/.memory/local_memory.json"
   fi
   ```

3. **Save Memory** (lines 94-114)
   ```bash
   cp .claude/memory.json "$LOCAL_MEMORY"
   
   # Statistics
   ENTITY_COUNT=$(grep -c '"type":"entity"' "$LOCAL_MEMORY" 2>/dev/null || echo "0")
   ```

4. **Restore Backup** (lines 116-127)
   ```bash
   if [[ -f ".memory/backup.json" ]]; then
       cp ".memory/backup.json" .claude/memory.json
       rm -f ".memory/backup.json"
   fi
   ```

5. **Git Commit** (lines 129-161)
   ```bash
   if [[ -n "$COMMIT_MSG" ]]; then
       # Use version-control.sh
       if ! stage_all_changes; then
           die "Failed to stage changes"
       fi
       
       if ! commit_with_stats "$COMMIT_MSG" "$LOCAL_MEMORY"; then
           die "Commit failed"
       fi
   fi
   ```

### 4. revert.sh Implementation

Reference: `scripts/revert.sh` lines 45-179 for detailed TODOs

#### Task Flow:
1. **Active Session Check** (lines 45-67)
   ```bash
   if [[ -f ".memory/session_active" ]]; then
       error "Active session detected!"
       # Offer choices...
   fi
   ```

2. **Context Selection** (lines 95-115)
   - Interactive if no args

3. **Show History** (lines 117-135)
   ```bash
   section "Memory History for $CONTEXT_DISPLAY"
   show_log 10 "$MEMORY_FILE"
   ```

4. **Commit Selection** (lines 137-151)
   ```bash
   if [[ -z "$COMMIT_REF" ]]; then
       read -p "Commit: " COMMIT_REF
   fi
   
   # Validate
   if ! git cat-file -e "$COMMIT_REF" 2>/dev/null; then
       die "Invalid commit"
   fi
   ```

5. **Preview & Revert** (lines 153-179)
   ```bash
   # Preview
   git diff HEAD "$COMMIT_REF" -- "$MEMORY_FILE"
   
   if confirm "Proceed?"; then
       # Backup
       cp "$MEMORY_FILE" "$MEMORY_FILE.backup-$(date +%Y%m%d-%H%M%S)"
       
       # Revert
       git checkout "$COMMIT_REF" -- "$MEMORY_FILE"
   fi
   ```

## Testing Workflow

### Component Testing Branch Structure
Reference: `current-focus.md` lines 77-161

```
test_review
├── test_start_sh_core
│   └── test_start_sh_implementation
├── test_stop_sh_core
│   └── test_stop_sh_cleanup
├── test_save_sh_core
│   └── test_save_sh_golden_rule
└── test_revert_sh_core
    └── test_revert_sh_safety
```

### Test Categories

1. **Unit Tests per Script**
   - Each major section independently
   - Mock dependencies
   - Error paths
   - Session files

2. **Integration Tests**
   - Full workflow: start → save → stop
   - Context switching
   - Git conflicts
   - Memory isolation

3. **Edge Cases**
   - No memory exists
   - Corrupted session
   - Missing backup
   - Permission issues

### Test Execution Pattern
```bash
# Create test branch
git checkout -b test_start_sh_implementation

# Implement section by section
# Test each section before proceeding
# Document findings

# When complete
git checkout test_start_sh_core
git merge test_start_sh_implementation
```

## Common Patterns & Guardrails

### GUARDRAIL 1: Output Functions
```bash
# ❌ WRONG
echo "Starting session..."
printf "Error: %s\n" "$msg"

# ✅ CORRECT
step "Starting session..."
error "$msg"
```

### GUARDRAIL 2: Git Operations
```bash
# ❌ WRONG
git add .
git commit -m "Save"
git fetch

# ✅ CORRECT
stage_all_changes
commit_with_stats "$msg" "$file"
fetch_remote
```

### GUARDRAIL 3: Error Handling
```bash
# ❌ WRONG
if [[ ! -f "$file" ]]; then
    echo "File not found"
    exit 1
fi

# ✅ CORRECT
if [[ ! -f "$file" ]]; then
    die "File not found: $file"
fi
```

### GUARDRAIL 4: Memory Paths
```bash
# ❌ WRONG
MEMORY_FILE="$PROJECT/.memory/memory.json"

# ✅ CORRECT
MEMORY_FILE="$PROJECT/.memory/local_memory.json"
```

### GUARDRAIL 5: Session Management
```bash
# Always use these paths:
SESSION_FILE=".memory/session_active"
SESSION_LOG=".memory/session_${SESSION_ID}.log"
BACKUP_FILE=".memory/backup.json"
```

## Implementation Checklist

### Pre-Implementation
- [ ] Read this entire workflow.md
- [ ] Read version-control.md integration patterns (lines 547-693)
- [ ] Read memory-management.md backup flow (lines 36-103)
- [ ] Understand all shell-formatting.sh functions
- [ ] Understand all version-control.sh functions

### During Implementation
- [ ] Follow exact line references in TODOs
- [ ] Use ONLY approved functions
- [ ] Test each section before proceeding
- [ ] Document any deviations
- [ ] Create test branches per component

### Post-Implementation
- [ ] All scripts executable (chmod +x)
- [ ] All dependencies sourced correctly
- [ ] All error paths handled
- [ ] Integration tests pass
- [ ] Documentation updated

## Quick Reference Card

### Essential Functions
```bash
# Output
section "Title"         # Start section
step "Doing..."        # Progress step
info "Message"         # Information
success "Done"         # Success
warn "Careful"         # Warning
error "Failed"         # Error
die "Cannot continue"  # Fatal + exit

# Git
initialize_memory_context "--framework"
check_git_repo || die "Not a repo"
stage_all_changes || die "Failed"
commit_with_stats "$msg" "$file"
show_log 10 "$file"

# Prompts
if confirm "Continue?"; then
    # proceed
fi
```

### Standard Paths
```bash
# Memory
.memory/local_memory.json      # Framework memory
Product/.memory/local_memory.json  # Project memory
.memory/backup.json           # Single backup location

# Session
.memory/session_active        # Current session
.memory/session_*.log         # Session logs
```

---

**Remember**: This workflow.md is your implementation bible. Refer to it constantly. Never deviate from the patterns. Always use the exact functions specified. The AIPM vision depends on this consistency.