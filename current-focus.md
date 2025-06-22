# Current Focus - AIPM Framework

> **Context**: This document tracks AIPM framework development only. For product-specific tasks, see `./Product/current-focus.md`

## 🚨 CRITICAL DISCOVERY: Fundamental Architecture Violations

### Session Date: 2025-06-22
During state management implementation, discovered **CRITICAL** architectural violations that must be fixed before proceeding:

1. **Git Command Violations** (20+ instances)
   - opinions-state.sh calls git directly instead of using version-control.sh
   - Violates single source of truth principle
   - version-control.sh missing 16 essential functions

2. **State Management Issues**
   - No bidirectional updates (state becomes stale)
   - Missing comprehensive documentation (28% undocumented)
   - Some functions exceed 200+ lines (violates SOLID)

3. **Incomplete Refactoring**
   - opinions-state.sh: 72% documented, needs completion
   - Architecture compliance fixed but needs verification
   - Test coverage incomplete

### Analysis Documents Created (2025-06-22)
1. **State Management**:
   - `state-management-audit.md` - Critical findings, score 4.5/10
   - `state-management-architecture.md` - Bidirectional update design
   - `state-management-fixes-summary.md` - What was fixed
   - `opinions-state-refactoring-plan.md` - 7-week improvement plan
   - `opinions-state-documentation-summary.md` - Documentation status

2. **Git Architecture Violations**:
   - `git-calls-violation-audit.md` - 20+ direct git calls found
   - `version-control-missing-functions.md` - 16 functions to add
   - `git-architecture-fix-plan.md` - How to fix violations
   - `complete-git-violations-audit.md` - All modules audited

## 🎯 REVISED IMMEDIATE PRIORITY: Fix Architecture First

### New Critical Path (2025-06-22)
**MUST fix architectural violations before ANY other work:**

1. **Fix version-control.sh** (ADD 16 MISSING FUNCTIONS)
   - `get_git_config()`, `get_status_porcelain()`, `get_branch_commit()`
   - `get_upstream_branch()`, `list_merged_branches()`, `count_stashes()`
   - `get_branch_log()`, `show_file_history()`, etc.
   - This is THE single source of truth for git operations

2. **Fix opinions-state.sh** (REMOVE ALL GIT CALLS)
   - Replace 20+ direct git calls with version-control.sh functions
   - Remove ALL fallback patterns (no bypassing!)
   - Complete documentation for remaining 28% functions
   - Decompose large functions (make_complete_decisions 276 lines)

3. **Fix Other Violations**
   - revert.sh has 1 git call to fix
   - Audit migrate-memories.sh for violations
   - Add enforcement to prevent future violations

4. **THEN Continue Original Plan**
   - Complete state management implementation
   - Revise wrapper-scripts-hardening-plan.md
   - Execute hardening with proper architecture

### Why This Changes Everything
- **Single Source of Truth**: version-control.sh must be THE ONLY module calling git
- **No Fallbacks**: If function missing from version-control.sh, that's a FATAL ERROR
- **Architecture Purity**: This is non-negotiable for maintainability

## 📋 Implementation Status Update

### Completed (2025-06-21 to 2025-06-22)
1. **opinions.yaml** ✅ COMPLETE
   - All fixes applied, ready for implementation

2. **opinions-loader.sh** ✅ IMPLEMENTED (1,283 lines)
   - Pure YAML to shell transformation
   - Complete validation and defaults
   - Already architecturally compliant

3. **opinions-state.sh** ⚠️ PARTIALLY COMPLETE (2,611 lines)
   - Core functionality implemented
   - Bidirectional updates added
   - 72% documented
   - **CRITICAL**: Contains 20+ git violations to fix

### Current Status Summary
- **Architecture Violations**: CRITICAL - Must fix first
- **State Management**: 80% complete, needs git fixes
- **Documentation**: 72% complete, needs finishing
- **Test Coverage**: Basic tests created, needs expansion

## 🔍 ACTIVE INVESTIGATION: Complete Git Isolation & Bidirectional State Integration

### Investigation Directive (2025-06-22)
**EXHAUSTIVE REVIEW** of all .sh files to ensure:
1. **Git Isolation**: Find ALL direct git calls across entire codebase
2. **Version Control Gaps**: Identify what's missing in version-control.sh
3. **Bidirectional Integration**: Ensure version-control.sh updates state after operations
4. **Atomic Operations**: Wrap all git operations with state updates
5. **State Sync**: Eliminate all state desync errors by design

**Scope**:
- Read ALL .sh files in scripts/ and modules/
- Read ALL documentation in docs/
- Map every git operation to version-control.sh function
- Identify missing atomic wrappers
- Document bidirectional update requirements

**Output**:
- Surgically update state-management-fix-plan.md
- Update state-management.md with integration patterns
- Update workflow.md with proper usage examples
- NO new files - enhance existing documentation

## 📚 Key Analysis Documents (MUST READ)

### Architecture Violations
1. **git-architecture-fix-plan.md** - The complete fix strategy
2. **complete-git-violations-audit.md** - All violations found
3. **version-control-missing-functions.md** - 16 functions to add

### State Management 
1. **state-management-architecture.md** - Bidirectional update design
2. **opinions-state-refactoring-plan.md** - Complete improvement plan
3. **state-management-audit.md** - Critical findings

## 🔧 ACTIVE IMPLEMENTATION: State Management Fix Plan

### Implementation Directive (2025-06-22)
**SURGICAL EXECUTION** of state-management-fix-plan.md:
- Implement the entire plan step-by-step WITHOUT creating any new files
- Track all progress directly in state-management-fix-plan.md
- Follow the exact implementation order specified
- Commit frequently to prevent file reversion issues

### CRITICAL ARCHITECTURAL PRINCIPLES:
1. **Single Responsibility Enforcement**:
   - **version-control.sh**: THE ONLY module that calls git commands
   - **shell-formatting.sh**: THE ONLY module that calls echo/printf
   - **opinions-loader.sh**: THE ONLY module that parses opinions.yaml
   - **opinions-state.sh**: Manages all state and pre-computation
   - **migrate-memories.sh**: THE ONLY module that touches memory files

2. **Bidirectional Integration**:
   - version-control.sh MUST call opinions-state.sh for state updates
   - opinions-state.sh MUST call version-control.sh for git operations
   - All operations MUST be atomic (git + state succeed or fail together)
   - NO FALLBACKS - missing functions are FATAL ERRORS

3. **Implementation Rules**:
   - PRESERVE all existing learning in version-control.sh (already hardened)
   - Make surgical in-place modifications with inline documentation
   - version-control.sh will expose final functions that call opinions-state.sh
   - Wrapper scripts NOT touched in this phase (refer to wrapper-fix-plan only if needed)

### Current Implementation Focus: Phase 0 - Foundation Infrastructure
1. **Lock Management System** (In Progress)
2. **Atomic Operation Framework** (Pending)
3. **State Refresh Architecture** (Pending)

## ✅ COMPLETED: Wrapper Scripts Surgical Fix Plan (2025-06-22)

### Achievements:
1. **Complete Function Inventory** (_functions.md in docs/)
   - Documented ALL 256 functions across 6 modules
   - Serves as authoritative reference for AI/LLM
   - Complete with purpose, parameters, returns, examples

2. **Wrapper Scripts Fix Plan** (wrapper-scripts-fix-plan.md)
   - Identified ~900 lines of business logic violations
   - Showed how to reduce 1,649 lines to 330 lines (80% reduction)
   - Only 7 new functions needed (not hundreds!)
   - Preserved wrapper relationships (init→start, stop→save)
   - Focus on user experience with rich shell output

3. **Architectural Understanding**:
   - Wrappers = User Interface (guide, educate, feedback)
   - Modules = Business Logic (all decisions)
   - stop.sh calls save.sh internally (stop = save + cleanup)
   - init.sh prepares then optionally calls start.sh

### Note: Memory Management Integration
- Memory path resolution needs review for nuanced cases
- Will be addressed after state management implementation

## ✅ COMPLETED: Final Wrapper Scripts Fix Plan (2025-06-22)

### Achievements
**wrapper-scripts-fix-plan.md** has been surgically updated with:

1. **Fixed ALL echo usage** 
   - Replaced with `printf` or shell-formatting functions
   - No more `echo` anywhere in the plan

2. **Fixed memory.json path**
   - Changed from `.claude/memory.json` to `.aipm/memory.json`
   - Reflects new MCP symlink location at workspace root

3. **Fixed configuration paths**
   - Corrected `.aipm/config/opinions.yaml` to `.aipm/opinions.yaml`

4. **Reduced functions from 7 to 3**
   - `create_session()` - opinions-state.sh
   - `cleanup_session()` - opinions-state.sh  
   - `revert_memory_partial()` - migrate-memories.sh
   - Removed unnecessary functions

5. **Path-agnostic architecture preserved**
   - All paths resolved dynamically via functions
   - Only `.aipm/memory.json` at fixed location
   - Memory directories vary by context

### Stable Commit: `4826efb`
All changes committed before implementation phase.

## 🚀 ACTIVE IMPLEMENTATION: Execute Wrapper Scripts Fix Plan (2025-06-22)

### Implementation Order

#### Phase 1: Add 3 Missing Functions ✅ COMPLETE
1. **Add to opinions-state.sh** ✅:
   - `create_session()` - Full session lifecycle management ✅
   - `cleanup_session()` - Clean session termination ✅
   
2. **Add to migrate-memories.sh** ✅:
   - `revert_memory_partial()` - Filtered memory restoration ✅

3. **Updated _functions.md** ✅:
   - Added export pattern documentation
   - Added all new functions with complete documentation
   - Total: 259 documented functions

#### Phase 2: Refactor Wrapper Scripts ✅ COMPLETE
1. **revert.sh** - Reduced from 466 to 114 lines (75% reduction) ✅
2. **save.sh** - Reduced from 315 to 81 lines (74% reduction) ✅
3. **start.sh** - Reduced from 454 to 88 lines (81% reduction) ✅
4. **stop.sh** - Reduced from 410 to 62 lines (85% reduction) ✅

**Total**: Reduced wrapper scripts from 1,645 lines to 345 lines (79% reduction!)

### Critical Implementation Rules
1. **Use existing functions** - 256 already available
2. **No business logic in wrappers** - Only orchestration
3. **Rich user experience** - Use shell-formatting.sh
4. **Path-agnostic** - No hardcoded paths
5. **Test after each script** - Ensure nothing breaks

#### init.sh Implementation ✅ COMPLETE
- Created comprehensive init.sh (210 lines)
- Thin orchestration layer with rich UX
- Supports --reinit and --start options
- Detects existing projects
- Future-ready for project installation

## ✅ COMPLETED: Documentation Alignment & UX Enhancement (2025-06-22)

### Achievements:
1. **Enhanced UX for all wrapper scripts** ✓
   - Added team memory synchronization messaging
   - Thoughtful emoji usage throughout
   - "Made with love by Harsh Joshi" in stop.sh
   - Messages explain AIPM's core value proposition

2. **Critical initialization prompt in start.sh** ✓
   - Hardened prompt with mandatory directives
   - Dynamic path resolution for all documentation
   - Uses proper shell-formatting.sh functions
   - Requires Claude confirmation

3. **Documentation surgical improvements** ✓
   - README.md: Added MCP prerequisites, magic formula
   - AIPM.md: Fixed doc paths, added git isolation rule
   - .agentrules: Fixed workflow.md path, added git warning
   - workflow.md: Added comprehensive usage examples
   - DOCS.md: Added version-control.md, updated descriptions
   - memory-management.md: Added sync-memory.sh section

4. **Fixed all path inconsistencies** ✓
   - Corrected .aipm/scripts/test/ to .aipm/docs/
   - Fixed "aipm" commands to "./script.sh" format
   - Verified all cross-references work correctly

### Documentation Status:
- All user-facing documentation aligned with implementation
- Technical documentation accurately reflects architecture
- Wrapper scripts provide excellent user experience
- Foundation is rock solid!

## 🔄 Next Session Plan

### 1. Continue State Management Implementation
- Complete Phase 0: Foundation Infrastructure
- Implement lock management system
- Add atomic operation framework
- Create state refresh architecture

### 2. Fix Architecture Violations
- Add 16 missing functions to version-control.sh
- Remove all git calls from opinions-state.sh
- Fix revert.sh violation
- Add enforcement mechanisms

### 3. Complete State Management
- Finish documenting remaining 28% functions
- Decompose large functions
- Complete test coverage
- Verify bidirectional updates work

### 4. Implement Wrapper Scripts Refactoring
- Add only 3 truly needed functions to modules
- Solve memory path resolution for path-agnostic design
- Refactor wrapper scripts to use existing functions
- Test end-to-end workflows with symlinked projects
- Ensure init.sh alignment

## 📋 Original Implementation Tasks (PAUSED)

### Phase 0: opinions.yaml Perfection ✅ COMPLETE
- [x] Applied all fixes from fix-opinions.md:
  - [x] Added missing lifecycle rules (framework, refactor, docs, chore, bugfix)
  - [x] Fixed session pattern redundancy (references {naming.session})
  - [x] Documented {mainBranch} construction
  - [x] Completed parent tracking implementation
  - [x] Verified option naming already hyphen-case
  - [x] Added circular reference protection
  - [x] Fixed time format inconsistencies (sessionSeconds, etc.)
  - [x] Added computed values section
  - [x] Added cross-validation rules (as comments)
  - [x] Added errorHandling section
  - [x] Marked ALL fields as REQUIRED/OPTIONAL
  - [x] Documented ALL default values

### Phase 1: Cornerstone Implementation (PARTIALLY COMPLETE)
- [x] **opinions-loader.sh** ✅ IMPLEMENTED
  - [x] load_and_export_opinions() - Main entry point
  - [x] validate_opinions_structure() - Schema validation
  - [x] Complete export system for all values
  - [x] Default values system
  - [x] Cross-reference validation
  
- [x] **opinions-state.sh** ⚠️ NEEDS FIXES
  - [x] Core state management implemented
  - [x] Bidirectional updates added
  - [ ] Remove 20+ git violations
  - [ ] Complete documentation (28% remaining)
  - [ ] Decompose large functions

- [ ] **init.sh** Implementation (PENDING)
  - [ ] Will implement after architecture fixes

### Phase 2: Integration Updates
- [ ] Update version-control.sh:
  - [ ] Source opinions-loader.sh
  - [ ] Remove hardcoded patterns
  - [ ] Use dynamic branch rules
  - [ ] Integrate workspace detection

- [ ] Update all wrapper scripts:
  - [ ] Source opinions-loader.sh
  - [ ] Use get_main_branch() everywhere
  - [ ] Apply workflow automation rules
  - [ ] Remove hardcoded assumptions

### Phase 3: Hardening Execution
- [ ] Revise wrapper-scripts-hardening-plan.md
- [ ] Implement all architectural improvements
- [ ] Test with multiple workspaces
- [ ] Validate branching isolation

## 🚀 Framework Implementation Phase

### Recently Completed (2025-06-21)
- [x] Deep review of opinions.yaml consistency
- [x] Documented all issues in fix-opinions.md
- [x] Created comprehensive workflow automation section
- [x] Added branch flow rules to workflows
- [x] Established clear implementation path
- [x] Applied ALL fixes to perfect opinions.yaml
- [x] Added REQUIRED/OPTIONAL markers throughout
- [x] Documented all default values
- [x] opinions.yaml is now COMPLETE and ready!

### Core Modules Status
- [x] **shell-formatting.sh** - Complete and hardened
- [x] **version-control.sh** - 100% test coverage achieved
- [x] **migrate-memories.sh** - Core complete, needs 5 atomic functions
- [ ] **opinions-loader.sh** - To be implemented (CORNERSTONE)
- [ ] **config-manager.sh** - Designed, not implemented
- [ ] **session-manager.sh** - Designed, not implemented

### Wrapper Scripts Status
- [x] All scripts have basic implementation
- [ ] Need opinions-loader.sh integration
- [ ] Need architectural refactoring per hardening plan
- [ ] Critical violation in start.sh needs fixing

## 🎯 Success Criteria for Current Phase
1. **opinions.yaml** has zero consistency issues
2. **opinions-loader.sh** successfully loads and validates configurations
3. **init.sh** can initialize a new project with proper branching
4. All scripts respect workspace opinions
5. Complete workspace isolation verified

## 📚 Key Documents
- **.aipm/scripts/test/wrapper-scripts-fix-plan.md** - Complete refactoring guide
- **.aipm/opinions.yaml** - The configuration cornerstone (PERFECTED!)
- **.agentrules** - AI behavior rules (was CLAUDE.md)
- **.aipm/docs/workflow.md** - Implementation patterns and guardrails

## 🔄 Next Steps
1. Begin opinions-loader.sh implementation (CORNERSTONE)
2. Focus on load_opinions() and validate_opinions() first
3. Build incrementally with deep integration

---

*The cornerstone is set. Now we build.*