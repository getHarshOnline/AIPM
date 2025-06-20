# version-control.sh Test Cases

> This document defines all test scenarios for hardening version-control.sh
> Each test will be executed in an isolated branch created from test_review

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
- [ ] Commit statistics display

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
- [ ] Integration with stop.sh
- [ ] Integration with save.sh
- [ ] Integration with revert.sh
- [ ] Memory backup before operations
- [ ] Session state preservation

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

## Test Execution Plan

1. Create each test branch from test_review
2. Implement test scenarios in isolation
3. Document findings and required fixes
4. If tests pass, merge to Framework_version_control
5. If tests fail, fix in branch and retest
6. Never merge failing tests

## Success Metrics

- All functions handle errors gracefully
- Clear user feedback for all operations
- No data loss scenarios
- Performance acceptable for large repos
- Cross-platform compatibility verified
- Integration with AIPM scripts seamless

## Notes

- Each test branch starts clean from test_review
- Use git worktrees for parallel testing if needed
- Document all edge cases discovered
- Create minimal reproduction cases for bugs
- Consider automation after manual verification