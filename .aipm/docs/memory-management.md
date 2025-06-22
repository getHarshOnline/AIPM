# AIPM Memory Management Architecture

## Overview

AIPM implements a sophisticated **backup-restore memory isolation** pattern that ensures complete workspace separation while enabling team collaboration. This architecture solves the critical limitation of the MCP memory server storing all memories globally.

## The Problem: Global Memory Contamination

The MCP (Model Context Protocol) memory server has a fundamental limitation:
- All memories stored in a single global location
- No project isolation - all projects share the same memory space
- Memory persists across git branches and projects
- Creates security risks and context confusion

## The Solution: Session-Based Memory Isolation

AIPM implements a three-stage memory flow:

```
START SESSION                    DURING WORK                    END SESSION
-------------                    -----------                    -----------
1. Backup global memory     →    Work with isolated      →    1. Save to local
2. Load context memory           context memory               2. Restore backup
3. Create session marker                                      3. Clean up session
```

## Implementation Architecture

### Memory Files

```
AIPM/
├── .aipm/
│   ├── memory.json               # Symlink to MCP global memory
│   └── memory/
│       ├── local_memory.json      # Framework persistent memory (git-tracked)
│       ├── backup.json           # Session backup (gitignored)
│       └── session_active        # Lock file with metadata
│
└── YourProject/
    └── .aipm/
        ├── memory.json           # Symlink to MCP global memory
        └── memory/
            └── local_memory.json  # Project persistent memory (git-tracked)
```

### Session Flow Details

#### 1. Session Start (`start.sh`)

```bash
# Step 1: Verify memory symlink (lines 82-92)
.aipm/memory.json → MCP server's global memory

# Step 2: Backup current memory (lines 196-203)
cp .aipm/memory.json .aipm/memory/backup.json

# Step 3: Load context memory (lines 205-265)
if [[ "$WORK_CONTEXT" == "framework" ]]; then
    LOCAL_MEMORY=".aipm/memory/local_memory.json"
else
    LOCAL_MEMORY="$PROJECT_NAME/.aipm/memory/local_memory.json"
fi
cp "$LOCAL_MEMORY" .aipm/memory.json

# Step 4: Create session lock (lines 270-301)
cat > .aipm/memory/session_active <<EOF
Session: $SESSION_ID
Context: $WORK_CONTEXT
Project: ${PROJECT_NAME:-N/A}
Started: $(date)
Branch: $(get_current_branch)
PID: $$
EOF
```

#### 2. During Work

- All Claude operations use the loaded context memory
- Changes accumulate in the global memory file
- Session lock prevents concurrent sessions
- Memory is completely isolated from other contexts

#### 3. Session End (`stop.sh`)

```bash
# Step 1: Detect session context (lines 88-123)
WORK_CONTEXT=$(grep "Context:" .aipm/memory/session_active | cut -d' ' -f2-)

# Step 2: Save memory via save.sh (lines 174-195)
if [[ "$WORK_CONTEXT" == "framework" ]]; then
    ./save.sh --framework "Session end"
else
    ./save.sh --project "$PROJECT_NAME" "Session end"
fi

# Step 3: Restore original memory (lines 197-202)
cp .aipm/memory/backup.json .aipm/memory.json
rm -f .aipm/memory/backup.json

# Step 4: Archive session (lines 204-243)
mv .aipm/memory/session_active .aipm/memory/session_${SESSION_ID}_complete
```

#### 4. Memory Save (`save.sh`)

```bash
# Step 1: Save current to local (lines 130-141)
cp .aipm/memory.json "$LOCAL_MEMORY"

# Step 2: Restore backup (lines 142-151)
if [[ -f ".aipm/memory/backup.json" ]]; then
    cp ".aipm/memory/backup.json" .aipm/memory.json
    rm -f ".aipm/memory/backup.json"
fi

# Step 3: Optional git commit (lines 153-186)
if [[ -n "$COMMIT_MSG" ]]; then
    stage_all_changes
    commit_with_stats "$COMMIT_MSG" "$LOCAL_MEMORY"
fi
```

## Team Collaboration Features

### Automatic Memory Sync

Even without explicit git pull, `start.sh` checks for team memory updates:

```bash
# From start.sh lines 237-260
if git_has_remote; then
    # Try to get remote version
    local remote_memory=$(git show origin/$(get_current_branch):"$memory_path" 2>/dev/null)
    
    if [[ -n "$remote_memory" ]]; then
        # Merge remote memories with local
        local merged=$(merge_memories "$local_memory" "$remote_memory" "remote-wins")
        echo "$merged" > "$MEMORY_FILE"
    fi
fi
```

### Memory Merge Strategy

The `merge_memories` function (from migrate-memories.sh) implements:
- **Entity-level merging**: Each memory entity is atomic
- **Conflict resolution**: "remote-wins" ensures team updates take precedence
- **Relation preservation**: Maintains knowledge graph integrity

## Memory Categories

Defined in `opinions.yaml` (lines 414-421):

```yaml
memory:
  entityPrefix: AIPM_  # Ensures workspace isolation
  categories:
    - PROTOCOL      # How AIPM works
    - WORKFLOW      # Usage patterns
    - DESIGN        # Architecture decisions
    - SCRIPT        # Script implementations
    - MODULE        # Module interfaces
    - TEST          # Testing strategies
    - LEARNING      # Implementation insights
```

## Entity Naming Convention

All memory entities follow strict prefixing:

```
Framework: AIPM_PROTOCOL_SESSION_INIT
Project:   PRODUCT_FEATURE_SHOPPING_CART
           ^^^^^^^ 
           Workspace prefix prevents contamination
```

## Session Management

### Lock File Prevention

Only one session can be active at a time. Session locks coordinate with state locks:

```bash
# session_active file contains:
Session: aipm_20240622_143022
Context: framework
Project: N/A
Started: Sat Jun 22 14:30:22 PDT 2024
Branch: AIPM_MAIN
PID: 12345
```

**Lock Hierarchy**:
1. **State Lock** (.aipm/state/.workspace.lock) - For state operations
2. **Session Lock** (.aipm/memory/session_active) - For session exclusivity
3. **Memory operations require BOTH locks** to ensure consistency

### Session Recovery

If a session crashes, the next start detects the stale lock:
- Checks if PID is still running
- Offers to recover or clean up
- Preserves memory data

## Integration with State Management

Memory operations MUST be atomic with state updates per [state-management-fix-plan.md](../scripts/test/state-management-fix-plan.md):

```bash
# WRONG: Separate operations can fail partially
cp .aipm/memory.json .aipm/memory/local_memory.json
update_state "runtime.memory.lastSave" "$(date -u)"

# CORRECT: Atomic operation with rollback
begin_atomic_operation "memory:save"
if backup_memory && save_local_memory; then
    update_state "runtime.memory.lastSave" "$(date -u)" && \
    update_state "runtime.memory.entityCount" "$entity_count" && \
    update_state "runtime.memory.size" "$(stat -f%z .aipm/memory.json)"
    
    if [[ $? -eq 0 ]]; then
        commit_atomic_operation
    else
        rollback_atomic_operation
        restore_memory_backup
    fi
else
    rollback_atomic_operation
fi
```

### Lock Coordination
Memory operations require lock coordination with state:
```bash
# Memory operations need state lock
acquire_state_lock || die "Cannot save memory"
perform_memory_operations
update_related_state
release_state_lock
```

See [state-management.md](state-management.md) and [version-control.md](version-control.md) for details.

## Integration with Version Control

Memory changes follow the "Golden Rule":

```bash
# From save.sh
stage_all_changes     # Stage everything
commit_with_stats "$message" "$memory_file"
```

Memory commits include statistics:
```
Save memory: Updated architecture decisions

Memory Statistics:
- Total Entities: 42
- Total Relations: 18
- File: .aipm/memory/local_memory.json
```

## Best Practices

### 1. Always Use Session Commands
```bash
# Good
aipm start --project MyProject
# ... work ...
aipm stop

# Bad
# Working without session management
```

### 2. Regular Memory Saves
```bash
# Save important decisions immediately
aipm save -d "Chose PostgreSQL for JSON support"
```

### 3. Clean Session Exits
```bash
# Always run stop to ensure memory saved
aipm stop
```

### 4. Memory Categories
Use appropriate categories for organization:
- `PROTOCOL`: How things work
- `WORKFLOW`: Usage patterns
- `DESIGN`: Architecture choices
- `LEARNING`: Insights gained

## Troubleshooting

### Session Won't Start
```bash
# Check for stale lock
cat .aipm/memory/session_active

# Manual cleanup if needed
rm -f .aipm/memory/session_active
```

### Memory Not Saved
```bash
# Check backup exists
ls -la .aipm/memory/backup.json

# Manually save if needed
cp .aipm/memory.json .aipm/memory/local_memory.json
```

### Memory Conflicts
```bash
# View conflict
git diff .aipm/memory/local_memory.json

# Accept team version
git checkout --theirs .aipm/memory/local_memory.json
```

## Security Benefits

1. **Complete Isolation**: Each workspace has separate memory
2. **No Cross-Contamination**: Backup/restore ensures clean separation
3. **Git Integration**: All memories version controlled
4. **Audit Trail**: Session files track all access

## Performance Considerations

- Memory file size monitored (10MB default limit)
- JSON format enables quick entity counting
- Merge operations optimized for speed
- Lock timeout prevents hanging (30s default)

## Future Enhancements

1. **Memory Compression**: For large knowledge bases
2. **Selective Loading**: Load only relevant categories
3. **Memory Search**: Full-text search across memories
4. **Memory Visualization**: Knowledge graph display
5. **Cross-Project Insights**: Controlled memory sharing

## Summary

AIPM's memory management provides:
- **Complete Isolation**: No memory contamination between projects
- **Team Collaboration**: Automatic memory sync without explicit pulls
- **Session Safety**: Lock-based concurrency control
- **Git Integration**: Full version control of organizational knowledge

The backup-restore pattern elegantly solves the global memory problem while maintaining the benefits of the MCP memory system.