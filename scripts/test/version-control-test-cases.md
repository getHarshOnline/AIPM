# version-control.sh Test Cases

> ⚠️ **CRITICAL**: version-control.sh is the CORE FOUNDATION of the AIPM framework
> This implementation CANNOT be screwed up - it must be perfect, modular, and maintainable
> Each test will be executed in an isolated branch created from test_review
> Tests are designed to validate AIPM framework integration requirements

## 🚨 CRITICAL IMPLEMENTATION DIRECTIVE

### This is NOT just another script - This is THE FOUNDATION
1. **version-control.sh** provides core git functionality for the entire framework
2. **start/stop/save/revert** are thin wrappers that MUST leverage version-control.sh
3. **shell-formatting.sh** MUST be used consistently - NO EXCEPTIONS
4. **Single Source of Truth** - No duplicate implementations, no shortcuts
5. **Modularity is MANDATORY** - Each function must be testable in isolation
6. **Error handling must be PERFECT** - This is the foundation everything builds on

## AIPM Framework Context

### Critical Requirements
1. **Memory Isolation**: Maintain complete separation between framework and project memories
2. **Session Integrity**: Support atomic start/stop/save/revert workflow
3. **Multi-Project**: Handle multiple projects with independent .memory/ directories
4. **Team Collaboration**: Enable memory sharing through git
5. **Exit Codes**: Preserve standardized exit codes (0-5)
6. **No Global Config**: Never modify git global configuration
7. **Formatting Consistency**: ALL output MUST use shell-formatting.sh functions
8. **Modularity**: Every function must be independently callable and testable

## Test Branches and Scenarios

### 1. test_basic_operations
**Branch**: `test_basic_operations`
**Tests**:
- [ ] get_current_branch() - normal branch
- [ ] get_current_branch() - detached HEAD
- [ ] get_default_branch() - main
- [ ] get_default_branch() - master
- [ ] get_default_branch() - custom default
- [ ] is_git_repo() - in git repo
- [ ] is_git_repo() - not in git repo
- [ ] is_clean_working_tree() - clean
- [ ] is_clean_working_tree() - with changes
- [ ] has_uncommitted_changes() - no changes
- [ ] has_uncommitted_changes() - staged changes
- [ ] has_uncommitted_changes() - unstaged changes

### 2. test_branch_operations
**Branch**: `test_branch_operations`
**Tests**:
- [ ] create_branch() - new branch
- [ ] create_branch() - existing branch (should fail)
- [ ] switch_branch() - existing branch
- [ ] switch_branch() - non-existing branch
- [ ] switch_branch() - with uncommitted changes
- [ ] delete_branch() - merged branch
- [ ] delete_branch() - unmerged branch
- [ ] delete_branch() - current branch (should fail)
- [ ] rename_branch() - normal rename
- [ ] rename_branch() - to existing name (should fail)

### 3. test_status_display
**Branch**: `test_status_display`
**Tests**:
- [ ] show_status() - clean repo
- [ ] show_status() - staged files
- [ ] show_status() - modified files
- [ ] show_status() - untracked files
- [ ] show_status() - deleted files
- [ ] show_status() - renamed files
- [ ] show_status() - merge conflicts
- [ ] show_detailed_status() - all scenarios

### 4. test_stash_operations
**Branch**: `test_stash_operations`
**Tests**:
- [ ] stash_changes() - with message
- [ ] stash_changes() - without message
- [ ] stash_changes() - no changes to stash
- [ ] stash_changes() - include untracked
- [ ] pop_stash() - single stash
- [ ] pop_stash() - multiple stashes
- [ ] pop_stash() - empty stash
- [ ] pop_stash() - with conflicts
- [ ] Auto-stash in pull_changes()
- [ ] Auto-stash in switch_branch()
- [ ] DID_STASH variable tracking
- [ ] Stash recovery after failed operations
- [ ] Memory file handling during stash

### 5. test_commit_operations
**Branch**: `test_commit_operations`
**Tests**:
- [ ] create_commit() - normal commit
- [ ] create_commit() - empty message (should fail)
- [ ] create_commit() - no staged changes (should fail)
- [ ] create_commit() - with pre-commit hooks
- [ ] amend_last_commit() - change message
- [ ] amend_last_commit() - add files
- [ ] undo_last_commit() - soft reset
- [ ] undo_last_commit() - mixed reset
- [ ] undo_last_commit() - hard reset
- [ ] commit_with_stats() - memory file commits
  - [ ] File size calculation
  - [ ] Entity counting (grep "entityType")
  - [ ] Relation counting (grep "relationType")
  - [ ] Statistics formatting
  - [ ] Multi-file commits
- [ ] Commit message standards
  - [ ] Memory update commits
  - [ ] Session save commits

### 6. test_merge_operations
**Branch**: `test_merge_operations`
**Tests**:
- [ ] merge_branch() - fast-forward
- [ ] merge_branch() - recursive merge
- [ ] merge_branch() - with conflicts
- [ ] merge_branch() - abort merge
- [ ] has_merge_conflicts() - detection
- [ ] resolve_conflicts() - interactive resolution
- [ ] resolve_conflicts() - abort resolution
- [ ] resolve_conflicts() - automatic resolution

### 7. test_push_pull
**Branch**: `test_push_pull`
**Tests**:
- [ ] push_changes() - normal push
- [ ] push_changes() - set upstream
- [ ] push_changes() - force push
- [ ] push_changes() - rejected push
- [ ] pull_changes() - fast-forward
- [ ] pull_changes() - with merge
- [ ] pull_changes() - with auto-stash
- [ ] pull_changes() - with conflicts
- [ ] fetch_updates() - all remotes
- [ ] fetch_updates() - specific remote

### 8. test_history_operations
**Branch**: `test_history_operations`
**Tests**:
- [ ] show_log() - default view
- [ ] show_log() - with count limit
- [ ] show_log() - oneline format
- [ ] show_log() - graph view
- [ ] show_diff() - unstaged changes
- [ ] show_diff() - staged changes
- [ ] show_diff() - specific files
- [ ] show_diff() - between commits
- [ ] show_file_history() - single file
- [ ] show_file_history() - follow renames

### 9. test_rebase_cherry_pick
**Branch**: `test_rebase_cherry_pick`
**Tests**:
- [ ] rebase_branch() - simple rebase
- [ ] rebase_branch() - with conflicts
- [ ] rebase_branch() - abort rebase
- [ ] rebase_branch() - interactive rebase
- [ ] cherry_pick_commit() - single commit
- [ ] cherry_pick_commit() - range of commits
- [ ] cherry_pick_commit() - with conflicts
- [ ] cherry_pick_commit() - abort cherry-pick

### 10. test_tag_operations
**Branch**: `test_tag_operations`
**Tests**:
- [ ] create_tag() - lightweight tag
- [ ] create_tag() - annotated tag
- [ ] create_tag() - signed tag
- [ ] delete_tag() - local tag
- [ ] delete_tag() - remote tag
- [ ] push_tag() - single tag
- [ ] push_tag() - all tags
- [ ] list_tags() - with pattern

### 11. test_backup_recovery
**Branch**: `test_backup_recovery`
**Tests**:
- [ ] create_backup_branch() - from current
- [ ] create_backup_branch() - from specific commit
- [ ] create_backup_branch() - duplicate (should fail)
- [ ] restore_from_backup() - full restore
- [ ] restore_from_backup() - selective restore
- [ ] Emergency recovery scenarios

### 12. test_cleanup_operations
**Branch**: `test_cleanup_operations`
**Tests**:
- [ ] cleanup_merged_branches() - local cleanup
- [ ] cleanup_merged_branches() - with protected branches
- [ ] cleanup_merged_branches() - dry run
- [ ] prune_remote_branches() - deleted on remote
- [ ] garbage_collect() - repository optimization

### 13. test_edge_cases
**Branch**: `test_edge_cases`
**Tests**:
- [ ] Empty repository scenarios
- [ ] Bare repository handling
- [ ] Submodule operations
- [ ] Large file handling
- [ ] Binary file conflicts
- [ ] Symbolic links
- [ ] Case-sensitive filename issues
- [ ] Very long branch names
- [ ] Special characters in messages

### 14. test_integration
**Branch**: `test_integration`
**Tests**:
- [ ] Integration with start.sh
  - [ ] Git repo validation on start
  - [ ] Branch status checking
  - [ ] Auto-sync with remote
  - [ ] Dirty working directory handling
- [ ] Integration with stop.sh
  - [ ] Working directory status check
  - [ ] Optional save.sh integration
  - [ ] Session artifact cleanup
- [ ] Integration with save.sh
  - [ ] commit_with_stats() for memory files
  - [ ] Memory file size formatting
  - [ ] Entity/relation counting
  - [ ] push_changes() integration
- [ ] Integration with revert.sh
  - [ ] Interactive commit selection
  - [ ] Safe reversion with backups
  - [ ] Memory file checkout
- [ ] Memory backup/restore workflow
  - [ ] .memory/backup.json handling
  - [ ] Global to local transfer
  - [ ] Isolation verification
- [ ] Multi-project scenarios
  - [ ] Project switching
  - [ ] Concurrent project handling
  - [ ] Memory prefix preservation

### 15. test_error_handling
**Branch**: `test_error_handling`
**Tests**:
- [ ] Network failures during push/pull
- [ ] Disk full scenarios
- [ ] Permission denied errors
- [ ] Corrupted git objects
- [ ] Invalid input handling
- [ ] Timeout scenarios
- [ ] Signal interruption (Ctrl+C)
- [ ] Exit code validation (0-5)
- [ ] Error message clarity
- [ ] Recovery instructions

### 16. test_memory_operations
**Branch**: `test_memory_operations`
**Tests**:
- [ ] Memory file conflict resolution
  - [ ] NDJSON format preservation
  - [ ] Entity prefix handling (AIPM_ vs PROJECT_)
  - [ ] Duplicate entity resolution
  - [ ] Relation integrity
- [ ] Large memory file handling
  - [ ] Performance with >10MB files
  - [ ] Commit statistics accuracy
  - [ ] Diff visualization
- [ ] Memory file merging
  - [ ] Branch merges with memory changes
  - [ ] Three-way merge scenarios
  - [ ] Conflict markers in NDJSON
- [ ] Backup/restore operations
  - [ ] backup.json creation
  - [ ] Atomic restore process
  - [ ] Rollback on failure

### 17. test_team_collaboration
**Branch**: `test_team_collaboration`
**Tests**:
- [ ] Memory sharing workflow
  - [ ] Pull team memories
  - [ ] Merge memory conflicts
  - [ ] Push combined knowledge
- [ ] Concurrent editing
  - [ ] Two users, same project
  - [ ] Memory merge strategies
  - [ ] Protocol preservation
- [ ] Branch-based memory
  - [ ] Feature branch memories
  - [ ] Memory follows git flow
  - [ ] Clean memory merges

## Test Execution Plan

1. Create each test branch from test_review
2. Implement test scenarios in isolation
3. Document findings and required fixes
4. If tests pass, merge to Framework_version_control
5. If tests fail, fix in branch and retest
6. Never merge failing tests

### Test Environment Setup
- Run all tests from AIPM root directory
- Create test projects in temporary directories
- Use both --framework and --project contexts
- Verify memory isolation between contexts
- Test with real .memory/local_memory.json files

## Success Metrics

- All functions handle errors gracefully
- Clear user feedback for all operations
- No data loss scenarios
- Performance acceptable for large repos
- Cross-platform compatibility verified
- Integration with AIPM scripts seamless
- Memory isolation maintained
- Session integrity preserved
- Team collaboration workflows functional
- Exit codes consistent (0-5)
- No global git config modifications
- All operations atomic with rollback

## Notes

- Each test branch starts clean from test_review
- Use git worktrees for parallel testing if needed
- Document all edge cases discovered
- Create minimal reproduction cases for bugs
- Consider automation after manual verification

## Modularity and Maintainability Requirements

### Core Design Principles

1. **Function Independence**
   - Each function in version-control.sh must work standalone
   - No hidden dependencies between functions
   - Clear input/output contracts
   - Example:
     ```bash
     # BAD - Hidden dependency
     function commit_changes() {
         # Assumes some global state
     }
     
     # GOOD - Explicit parameters
     function commit_changes() {
         local message="$1"
         local files=("${@:2}")
         # Self-contained logic
     }
     ```

2. **Consistent Formatting**
   - EVERY output line must use shell-formatting.sh
   - NO raw echo/printf statements
   - Example:
     ```bash
     # BAD - Inconsistent formatting
     echo "Creating branch..."
     printf "\033[32mSuccess!\033[0m\n"
     
     # GOOD - Consistent formatting
     info "Creating branch..."
     success "Branch created successfully"
     ```

3. **Error Handling Pattern**
   - Every function must handle its own errors
   - Use consistent exit codes
   - Provide recovery instructions
   - Example:
     ```bash
     function create_branch() {
         local branch_name="$1"
         
         if [[ -z "$branch_name" ]]; then
             error "Branch name required"
             return 1
         fi
         
         if ! git branch "$branch_name" 2>/dev/null; then
             error "Failed to create branch: $branch_name"
             info "Branch may already exist. Use: git branch -a"
             return 2
         fi
         
         success "Created branch: $branch_name"
         return 0
     }
     ```

4. **Wrapper Script Integration**
   - start.sh, stop.sh, save.sh, revert.sh are THIN wrappers
   - They orchestrate calls to version-control.sh functions
   - No git logic in wrapper scripts
   - Example for save.sh:
     ```bash
     # save.sh should look like:
     source version-control.sh
     
     # Check working directory
     if ! is_clean_working_tree; then
         if ! stash_changes "Auto-stash before save"; then
             die "Failed to stash changes"
         fi
     fi
     
     # Commit with stats
     if ! commit_with_stats "$message" "${files[@]}"; then
         die "Failed to commit"
     fi
     ```

5. **Testing Each Function**
   - Every function gets its own test scenarios
   - Test success paths
   - Test failure paths
   - Test edge cases
   - Verify formatting output

## AIPM-Specific Test Scenarios

### Critical Workflows to Validate

1. **Full Session Lifecycle**
   ```bash
   ./scripts/start.sh --project TestProject
   # Make changes
   ./scripts/stop.sh --project TestProject
   ./scripts/save.sh --project TestProject "Test session"
   ```

2. **Memory Isolation Verification**
   ```bash
   # Framework memory should never contain PROJECT_ entities
   # Project memory should never contain AIPM_ entities
   ```

3. **Crash Recovery**
   ```bash
   # Simulate crash during session
   # Verify recovery with backup.json
   ```

4. **Multi-Project Switching**
   ```bash
   ./scripts/start.sh --project Project1
   ./scripts/stop.sh --project Project1
   ./scripts/start.sh --project Project2
   # Verify complete isolation
   ```

### Function-Specific Requirements

1. **commit_with_stats()**
   - Must calculate memory file statistics
   - Must format file sizes with format_size()
   - Must count entities and relations accurately
   - Must handle multiple memory files

2. **create_backup_branch()**
   - Must create before dangerous operations
   - Must use timestamp in branch name
   - Must preserve current state completely

3. **push_changes()**
   - Must handle --sync-team flag
   - Must set upstream for new branches
   - Must provide clear conflict resolution

4. **stash_changes()**
   - Must track state with DID_STASH
   - Must include untracked files when needed
   - Must provide recovery instructions

### Error Handling Standards

- Exit code 0: Success
- Exit code 1: General error
- Exit code 2: Git command failed
- Exit code 3: Working directory not clean
- Exit code 4: Merge conflict
- Exit code 5: Network/remote error

All errors must include:
- Clear description of what failed
- Current state information
- Recovery instructions
- No modifications to global git config