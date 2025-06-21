# Current Focus - AIPM Framework

> **Context**: This document tracks AIPM framework development only. For product-specific tasks, see `./Product/current-focus.md`

## 🎯 IMMEDIATE PRIORITY: Cornerstone Implementation

### Critical Path (2025-06-21)
The following sequence MUST be followed for successful implementation:

1. **Perfect opinions.yaml** ✓
   - Deep consistency review completed
   - Critical issues documented in fix-opinions.md
   - Ready for surgical fixes

2. **Fix opinions.yaml consistency** ← CURRENT
   - Apply all fixes from fix-opinions.md
   - Add missing lifecycle rules
   - Complete parent tracking
   - Standardize option naming

3. **Implement opinions-loader.sh** (CORNERSTONE - 383 lines)
   - Deep integration with shell-formatting.sh
   - Deep integration with version-control.sh
   - Dynamic workspace detection
   - Validation and error handling
   - THIS IS THE KEY TO EVERYTHING

4. **Implement init.sh**
   - Deep integration with shell-formatting.sh
   - Deep integration with version-control.sh
   - Project initialization flow
   - Branch creation from opinions
   - Memory structure setup

5. **Revise wrapper-scripts-hardening-plan.md**
   - Update with opinions-loader.sh integration
   - Ensure all scripts use opinions
   - Complete architectural alignment

6. **Execute hardening plan**
   - Implement all wrapper script updates
   - Test branching architecture
   - Validate multi-workspace support

### Why This Order Matters
- **opinions.yaml** is the configuration cornerstone
- **opinions-loader.sh** makes the configuration actionable
- **init.sh** proves the architecture works
- **Then** we can properly harden all wrapper scripts

## 📋 Detailed Implementation Tasks

### Phase 0: opinions.yaml Perfection
- [ ] Apply all fixes from fix-opinions.md:
  - [ ] Add missing lifecycle rules (framework, refactor, docs, chore)
  - [ ] Fix session pattern redundancy
  - [ ] Document {mainBranch} construction
  - [ ] Complete parent tracking implementation
  - [ ] Standardize option naming to hyphen-case
  - [ ] Add circular reference protection
  - [ ] Fix time format inconsistencies
  - [ ] Add computed values section
  - [ ] Add cross-validation rules

### Phase 1: Cornerstone Implementation
- [ ] **opinions-loader.sh** (THE CORNERSTONE)
  - [ ] load_opinions() - Main entry point
  - [ ] validate_opinions() - Schema validation
  - [ ] get_branch_prefix() - Workspace prefix
  - [ ] get_main_branch() - Computed main branch
  - [ ] get_branch_pattern() - Type-based patterns
  - [ ] get_lifecycle_rules() - Branch lifecycle
  - [ ] is_protected_branch() - Protection checks
  - [ ] get_memory_prefix() - Memory entity prefix
  - [ ] get_workflow_rule() - Workflow automation
  - [ ] enforce_branch_operation() - Git integration

- [ ] **init.sh** Implementation
  - [ ] Project detection and validation
  - [ ] Symlink management (--link mode)
  - [ ] opinions.yaml template copying
  - [ ] Branch initialization from user branches
  - [ ] AIPM_INIT_HERE marker creation
  - [ ] Memory structure setup
  - [ ] Standard file creation (.agentrules, etc.)

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
- **fix-opinions.md** - Consistency issues to resolve
- **wrapper-scripts-hardening-plan.md** - Complete refactoring guide
- **opinions.yaml** - The configuration cornerstone
- **.agentrules** - AI behavior rules (was CLAUDE.md)

## 🔄 Next Commit
After updating current-focus.md:
1. Commit current state with comprehensive message
2. Begin applying fixes to opinions.yaml
3. Start opinions-loader.sh implementation

---

*The cornerstone is set. Now we build.*