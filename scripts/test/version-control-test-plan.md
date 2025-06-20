# Version Control Test Plan

## Overview

This document outlines the comprehensive test plan for `version-control.sh`, the core foundation of the AIPM framework. Every function is tested in isolation and as part of integrated workflows.

## Test Philosophy

1. **Isolation First**: Each function tested independently
2. **Non-Destructive**: Tests run in isolated test repositories
3. **Repeatable**: Tests can run multiple times with same results
4. **Comprehensive**: Cover success paths, failure paths, and edge cases
5. **Documented**: All test results logged for analysis

## Test Structure

```
scripts/test/
├── test-version-control.sh    # Main test suite
├── run-tests.sh               # Simple runner script
├── version-control-test-plan.md   # This document
├── test-repo-*/               # Temporary test repositories
└── test-results-*.log         # Test execution logs
```

## Test Categories

### 1. Security & Context Management
Tests the security features and context detection:
- **Nesting Level Detection**: Prevents recursive sourcing
- **Project Path Resolution**: Handles symlinks correctly
- **Project Context Detection**: Identifies framework vs project mode

### 2. Memory Management
Tests memory file initialization and configuration:
- **Framework Mode Init**: Correct paths for framework memory
- **Project Mode Init**: Correct paths for project memory
- **Re-initialization**: Dynamic context switching
- **Path Resolution**: Absolute paths and symlink handling

### 3. Git Configuration
Tests basic git operations:
- **Repository Detection**: Verify git repo checks
- **Branch Detection**: Current and default branch
- **Error Handling**: Behavior outside git repos

### 4. Stash Operations
Tests stash functionality:
- **Stash Changes**: Create stashes with tracking
- **Restore Stash**: Restore with DID_STASH flag
- **List Stashes**: Format stash listings
- **Multiple Stashes**: Handle stash stack

### 5. Golden Rule Functions
Tests AIPM's golden rule implementation:
- **Add Untracked**: Respects .gitignore strictly
- **Ensure Memory Tracked**: Memory files always staged
- **Stage All Changes**: Modified + untracked + memory
- **Safe Add**: Symlink and gitignore aware

### 6. Commit Functions
Tests commit creation:
- **Basic Commit**: Message and description
- **Commit with Stats**: Memory file statistics
- **Golden Rule Commit**: Auto-stage everything
- **AIPM Footer**: Proper commit formatting

### 7. Sync Functions
Tests repository synchronization:
- **Working Directory Status**: Clean/dirty detection
- **Status Display**: Formatted git status
- **Fetch/Pull**: Network operations (skipped in tests)

### 8. Branch Operations
Tests branch management:
- **Create Branch**: Valid names and base branches
- **List Branches**: Formatted branch display
- **Branch Validation**: Duplicate prevention

### 9. Advanced Operations
Tests advanced git features:
- **Backup Branches**: Safety before operations
- **Undo Commit**: Soft/hard reset with backup
- **Push Changes**: Upstream handling (skipped in tests)

### 10. Conflict Resolution
Tests merge conflict handling:
- **Conflict Detection**: Identify conflicted files
- **Resolution Helpers**: Interactive resolution

### 11. Integration Tests
Tests complete workflows:
- **Full Feature Workflow**: Branch → Change → Commit → Merge
- **Golden Rule Workflow**: Automatic staging integration
- **Memory Management Flow**: Memory file tracking

## Running Tests

### Run All Tests
```bash
./scripts/test/run-tests.sh
```

### Run Specific Category
```bash
./scripts/test/run-tests.sh golden-rule
./scripts/test/run-tests.sh stash
./scripts/test/run-tests.sh memory
```

### View Test Results
```bash
# Latest test results
ls -la scripts/test/test-results-*.log

# View specific results
cat scripts/test/test-results-[timestamp].log
```

## Test Environment

Each test run:
1. Creates isolated test repository
2. Copies required scripts (shell-formatting.sh, version-control.sh)
3. Sets up git configuration
4. Creates test structure (.memory, .gitignore)
5. Sources scripts with proper environment
6. Runs tests in isolation
7. Cleans up test repository

## Expected Results

### Success Criteria
- All core functions work as documented
- Golden rule properly implemented
- Memory files always tracked
- Exit codes used consistently
- Error messages helpful
- No echo statements (all printf)

### Known Limitations
- Network operations skipped (fetch, pull, push)
- Complex conflict scenarios not fully tested
- Remote branch operations limited
- Some platform-specific features need real environments

## Test Output

### Console Output
```
╔══════════════════════════════════════════╗
║     VERSION-CONTROL.SH TEST SUITE        ║
╚══════════════════════════════════════════╝

Test category: all
Test directory: /path/to/test-repo
Results file: /path/to/test-results.log

Setting up test environment...
✓ Test environment ready

=== SECURITY & CONTEXT MANAGEMENT TESTS ===

Running: Nesting level detection... PASSED
Running: Project path resolution... PASSED
Running: Project context detection... PASSED

[... more tests ...]

╔══════════════════════════════════════════╗
║              TEST SUMMARY                ║
╚══════════════════════════════════════════╝

Total tests run: 25
Tests passed: 23
Tests failed: 0
Tests skipped: 2
Success rate: 100%

All tests passed!
```

### Log File Format
```
=== TEST: Test name ===
Function: test_function_name
Result: 0
Output:
[detailed test output]

```

## Next Steps

1. Run full test suite
2. Document any failures
3. Fix issues in version-control.sh
4. Re-run tests until all pass
5. Create specific edge case tests
6. Test on different platforms
7. Performance testing for large repos

## Integration with CI/CD

Future enhancement: These tests can be integrated into CI/CD:
```yaml
test-version-control:
  script:
    - ./scripts/test/run-tests.sh all
  artifacts:
    paths:
      - scripts/test/test-results-*.log
```