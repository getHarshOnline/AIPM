# Current Focus - AIPM Framework

> **Context**: This document tracks AIPM framework development only. For product-specific tasks, see `./Product/current-focus.md`

## 🎯 ACTIVE PRIORITY: Fix Architecture Violations

### Critical Git Command Isolation Issue
**20+ direct git calls found in opinions-state.sh** violating the fundamental architecture principle:
- ONLY version-control.sh may call git commands
- All other modules MUST use version-control.sh functions
- This causes state desynchronization between git and AIPM

### Immediate Actions Required:
1. **Add 16 missing functions to version-control.sh**
2. **Remove ALL direct git calls from opinions-state.sh** 
3. **Implement bidirectional state updates**
4. **Complete remaining 28% documentation in opinions-state.sh**

## 📚 Key Analysis Documents (MUST READ)

### Architecture Violations
- **git-architecture-fix-plan.md** - Complete fix strategy
- **complete-git-violations-audit.md** - All violations found
- **version-control-missing-functions.md** - 16 functions to add

### State Management
- **state-management-architecture.md** - Bidirectional update design
- **state-management-fix-plan.md** - Implementation roadmap
- **opinions-state-refactoring-plan.md** - 7-week improvement plan

## ✅ Recent Achievements (2025-06-22)

### Documentation & UX Enhancement ✓
- Enhanced all wrapper scripts with team-friendly messaging
- Added critical initialization prompt in start.sh
- Fixed all documentation path inconsistencies
- Added comprehensive wrapper script usage examples
- Foundation is now rock solid!

### Wrapper Scripts Refactoring ✓
- Reduced wrapper scripts from 1,645 to 345 lines (79% reduction!)
- Implemented init.sh for framework initialization
- All scripts now follow thin orchestration pattern
- Added session management functions to modules

### State Management Progress
- Implemented 80% of state management system
- Added bidirectional update mechanisms
- Created atomic operation framework
- 72% of functions documented

## 🔧 Next Implementation Phase

### Phase 1: Fix Version Control (CRITICAL)
Add these 16 missing functions to version-control.sh:
- `get_git_config()`, `get_status_porcelain()`, `get_branch_commit()`
- `get_upstream_branch()`, `list_merged_branches()`, `count_stashes()`
- `get_branch_log()`, `show_file_history()`, `get_file_from_commit()`
- `file_exists_in_commit()`, `get_commit_info()`, `validate_commit()`
- `get_branch_type()`, `is_working_directory_clean()`, `safe_merge()`
- `report_git_operation()`

### Phase 2: Fix opinions-state.sh
- Replace 20+ direct git calls with version-control.sh functions
- Complete documentation for remaining 28% functions
- Decompose large functions (make_complete_decisions: 276 lines)
- Ensure all state updates are bidirectional

### Phase 3: Complete State Management
- Implement lock management system
- Add atomic operation framework
- Create state refresh architecture
- Full integration testing

## 🚀 Long-term Vision

See [broad-focus.md](./broad-focus.md) for:
- NPM package distribution plans
- AI-agnostic architecture evolution
- Enterprise features roadmap
- Multi-project management improvements

## 📋 Pending Tasks

1. **CRITICAL**: Fix git command isolation violations
2. **HIGH**: Complete state management implementation
3. **MEDIUM**: Add comprehensive error recovery
4. **LOW**: Optimize performance for large repositories

---

*Focus: Architecture purity → State consistency → User experience*