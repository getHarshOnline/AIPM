# AIPM Wrapper Scripts Hardening Plan

## Overview

This document outlines the comprehensive hardening plan for the AIPM wrapper scripts (start.sh, stop.sh, save.sh, revert.sh) based on thorough analysis of the implementation, documentation, and identified edge cases.

## Critical Missing Requirements (MUST ADDRESS)

### Protocol & Security Requirements

1. **Golden Rule Enforcement**
   - CRITICAL: Enforce "Do exactly what .gitignore says - everything else should be added"
   - Validate stage_all_changes() usage in save.sh
   - Ensure all untracked files are properly tracked

2. **Memory Entity Naming Conventions**
   - CRITICAL: Enforce strict prefix requirements (AIPM_ for framework, PROJECT_ for projects)
   - Validate entity names before ANY memory operation
   - Prevent cross-context contamination through naming

3. **Shell Integration Requirements**
   - CRITICAL: NEVER use echo/printf directly
   - CRITICAL: NEVER use git commands directly
   - All output through shell-formatting.sh functions only
   - All git operations through version-control.sh functions only

4. **Memory Schema Validation**
   - Validate NDJSON format (newline-delimited JSON)
   - Enforce required entity fields: type, name, entityType, observations
   - Enforce relation fields: type, from, to, relationType
   - Validate relation integrity (from/to entities must exist)

## Critical Areas for Hardening

### 1. Dynamic NPM Cache Detection (Priority: CRITICAL)

**Current Issue**: sync-memory.sh uses hardcoded paths that may fail with different npm versions
**Impact**: Complete failure to create memory symlink

**Hardening Tasks**:
- [ ] Implement dynamic npm cache detection using `npm config get cache`
- [ ] Add fallback detection for common paths
- [ ] Validate symlink target exists and is writable
- [ ] Handle npm workspace scenarios
- [ ] Add version-specific path patterns

**Implementation**:
```bash
# In sync-memory.sh
NPM_CACHE=$(npm config get cache 2>/dev/null || echo "$HOME/.npm")
MEMORY_PKG_PATH=$(find "$NPM_CACHE" -name "@modelcontextprotocol" -type d 2>/dev/null | head -1)
```

### 2. Concurrent Session Protection (Priority: HIGH)

**Current Issue**: Single backup.json could be corrupted by concurrent sessions
**Impact**: Memory loss or corruption

**Hardening Tasks**:
- [ ] Implement session-specific backup naming: `backup_${SESSION_ID}.json`
- [ ] Add file locking mechanism using flock or mkdir
- [ ] Detect and warn about concurrent sessions
- [ ] Implement PID-based session validation
- [ ] Add cleanup for stale sessions (PID no longer exists)

**Implementation**:
```bash
# In start.sh
BACKUP_FILE=".memory/backup_${SESSION_ID}.json"
if ! mkdir .memory/.lock 2>/dev/null; then
    warn "Another session may be active"
    # Check if PID still exists
fi
```

### 3. Memory File Validation (Priority: HIGH)

**Current Issue**: No validation of JSON structure before operations
**Impact**: Crashes or data loss with corrupted files

**Hardening Tasks**:
- [ ] Add JSON validation before all read operations
- [ ] Implement backup before any write operation
- [ ] Add recovery mechanism for corrupted files
- [ ] Validate entity/relation structure
- [ ] Add memory health check function

**Implementation**:
```bash
# Add to version-control.sh or new memory-utils.sh
validate_memory_file() {
    local file="$1"
    if ! jq empty "$file" 2>/dev/null; then
        error "Invalid JSON in $file"
        # Attempt recovery
        return 1
    fi
}
```

### 4. Platform Compatibility Enhancement (Priority: MEDIUM)

**Current Issue**: Incomplete handling of platform differences
**Impact**: Script failures on certain platforms

**Hardening Tasks**:
- [ ] Create comprehensive platform detection function
- [ ] Handle WSL (Windows Subsystem for Linux) specifically
- [ ] Abstract all platform-specific commands
- [ ] Add CI testing for multiple platforms
- [ ] Document platform requirements clearly

**Implementation**:
```bash
# Add to shell-formatting.sh or new platform-utils.sh
detect_platform() {
    case "$(uname -s)" in
        Linux*)     
            if [[ -f /proc/version ]] && grep -q Microsoft /proc/version; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*)    echo "macos";;
        *)          echo "unknown";;
    esac
}
```

### 5. Session Lifecycle Management (Priority: MEDIUM)

**Current Issue**: No automatic cleanup of stale sessions
**Impact**: Confusion and potential data issues

**Hardening Tasks**:
- [ ] Add session heartbeat mechanism
- [ ] Implement stale session detection on start
- [ ] Add session recovery options
- [ ] Create session list/status command
- [ ] Add forced cleanup option

### 6. Error Recovery Enhancement (Priority: HIGH)

**Current Issue**: Inconsistent error handling and recovery
**Impact**: Users stuck without clear path forward

**Hardening Tasks**:
- [ ] Standardize all error messages with recovery hints
- [ ] Add rollback mechanisms for failed operations
- [ ] Implement transaction-like operations
- [ ] Add diagnostic mode for troubleshooting
- [ ] Create recovery script for common issues

### 7. Git Integration Hardening (Priority: MEDIUM)

**Current Issue**: Some git edge cases not fully handled
**Impact**: Potential conflicts or data loss

**Hardening Tasks**:
- [ ] Handle detached HEAD state
- [ ] Improve merge conflict detection
- [ ] Add pre-flight checks for all git operations
- [ ] Handle missing upstream branches
- [ ] Add git hook integration for memory validation

### 8. Memory Performance Optimization (Priority: LOW)

**Current Issue**: Large memory files could impact performance
**Impact**: Slow operations with extensive memory

**Hardening Tasks**:
- [ ] Add memory size warnings
- [ ] Implement memory compaction
- [ ] Add memory archival for old entities
- [ ] Optimize entity counting with jq
- [ ] Add progress indicators for long operations

## Missing Workflow & Integration Requirements

### Session Management
- Session file format specification with all required fields
- Session archival as session_${SESSION_ID}_complete
- Session log handling and format
- DID_STASH tracking for safe operations

### Team Collaboration
- Memory merge capabilities for team synchronization
- Selective memory import/export
- Branch-specific memory isolation
- Memory diff between branches

### Documentation Structure
- Validate standardized project structure
- Check for required files: CLAUDE.md, README.md, etc.
- Enforce data/ directory for project files
- Project-specific CLAUDE.md protocol loading

## Script-Specific Hardening

### start.sh

1. **Symlink Validation**
   - [ ] Verify symlink points to correct npm package
   - [ ] Handle broken symlinks gracefully
   - [ ] Add symlink repair function

2. **Project Detection**
   - [ ] Handle nested project directories
   - [ ] Validate project structure before selection
   - [ ] Add project initialization for new projects

3. **Git Sync Enhancement**
   - [ ] Add timeout for fetch operations
   - [ ] Handle authentication failures
   - [ ] Improve offline mode detection

### stop.sh

1. **Session State Validation**
   - [ ] Verify all session components exist
   - [ ] Handle partial session states
   - [ ] Add emergency stop mode

2. **Save Integration**
   - [ ] Handle save.sh failures gracefully
   - [ ] Add retry mechanism
   - [ ] Preserve memory on critical failures

### save.sh

1. **Atomic Operations**
   - [ ] Implement two-phase commit pattern
   - [ ] Add verification after each step
   - [ ] Rollback on any failure

2. **Git Commit Enhancement**
   - [ ] Validate commit message format
   - [ ] Add commit hooks support
   - [ ] Handle large memory files in git

### revert.sh

1. **Safety Checks**
   - [ ] Add dry-run mode
   - [ ] Improve diff preview
   - [ ] Add multiple backup retention

2. **Commit Validation**
   - [ ] Verify commit has valid memory structure
   - [ ] Handle partial reverts
   - [ ] Add cherry-pick support

## Testing Strategy

### Unit Tests
- [ ] Create test framework using bats or similar
- [ ] Test each function in isolation
- [ ] Mock all external dependencies
- [ ] Test error paths explicitly

### Integration Tests
- [ ] Full workflow tests (start → save → stop)
- [ ] Multi-project scenarios
- [ ] Concurrent session tests
- [ ] Platform-specific tests

### Stress Tests
- [ ] Large memory files (>10MB)
- [ ] Many projects (>20)
- [ ] Rapid session creation/destruction
- [ ] Network failure scenarios

## Additional Hardening Requirements

### Memory Operations
- [ ] Atomic backup operations with verification
- [ ] Memory compaction before save
- [ ] Entity relationship integrity validation
- [ ] Memory migration for version incompatibility
- [ ] Bulk operations support

### Network & Authentication
- [ ] SSH key handling for private repos
- [ ] Authentication failure recovery
- [ ] Network timeout handling
- [ ] Offline mode improvements

### Advanced Features
- [ ] Memory analytics and health metrics
- [ ] Project template support
- [ ] Debug mode with diagnostic data
- [ ] Performance profiling hooks

## Implementation Priority

1. **Phase 0 - Critical Protocol Requirements** (Immediate)
   - Golden Rule enforcement
   - Entity naming validation
   - Shell integration compliance
   - Memory schema validation

2. **Phase 1 - Core Hardening** (Week 1)
   - Dynamic NPM cache detection
   - Concurrent session protection
   - Memory file validation
   - Session management requirements

3. **Phase 2 - Integration & Workflow** (Week 2)
   - Error recovery enhancement
   - Team collaboration features
   - Documentation structure validation
   - Branch-specific memory handling

4. **Phase 3 - Platform & Performance** (Week 3)
   - Platform compatibility
   - Performance optimization
   - Advanced git features
   - Network & authentication

5. **Phase 4 - Testing & Polish** (Week 4)
   - Comprehensive test suite
   - Memory analytics
   - Debug capabilities
   - User documentation

## Implementation Standards

### Function Patterns
- All functions must have explicit return statements
- Local variables must be declared with 'local'
- Original directory must be restored if changed
- Error codes must follow standardized set

### Testing Patterns  
- Follow component testing branch structure
- Each feature gets isolated test branch
- Full regression test suite required
- Test data generation strategies

### Code Patterns
```bash
# Example of required pattern
function_name() {
    local arg="$1"
    local original_dir=$(pwd)
    
    # Main logic
    
    # Restore directory
    [[ "$original_dir" != "$(pwd)" ]] && cd "$original_dir" >/dev/null
    
    return $EXIT_SUCCESS
}
```

## Success Metrics

- Golden Rule compliance: 100%
- Entity naming validation: 100%
- Zero data loss scenarios
- Clear error messages with recovery paths
- Platform compatibility (macOS, Linux, WSL)
- Session management reliability
- Performance with large memory files
- Team collaboration features
- Protocol compliance verification

## Related Documents

- AIPM_Design_Docs/memory-management.md
- scripts/test/workflow.md
- scripts/test/version-control.md
- AIPM.md
- current-focus.md