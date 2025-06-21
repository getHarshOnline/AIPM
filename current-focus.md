# Current Focus - AIPM Framework

> **Context**: This document tracks AIPM framework development only. For product-specific tasks, see `./Product/current-focus.md`

## 🎯 IMMEDIATE PRIORITY: Cornerstone Implementation

### Critical Path (2025-06-21)
The following sequence MUST be followed for successful implementation:

1. **Perfect opinions.yaml** ✅ COMPLETE
   - Deep consistency review completed
   - All HIGH, MEDIUM, and LOW priority fixes applied
   - Every field marked as REQUIRED/OPTIONAL
   - All default values documented
   - Ready for implementation!

2. **Implement opinions-loader.sh** ← CURRENT (CORNERSTONE - 383 lines)
   - Deep integration with shell-formatting.sh
   - Deep integration with version-control.sh
   - Dynamic workspace detection
   - Validation and error handling
   - THIS IS THE KEY TO EVERYTHING

3. **Implement init.sh**
   - Deep integration with shell-formatting.sh
   - Deep integration with version-control.sh
   - Project initialization flow
   - Branch creation from opinions
   - Memory structure setup

4. **Revise wrapper-scripts-hardening-plan.md**
   - Update with opinions-loader.sh integration
   - Ensure all scripts use opinions
   - Complete architectural alignment

5. **Execute hardening plan**
   - Implement all wrapper script updates
   - Test branching architecture
   - Validate multi-workspace support

### Why This Order Matters
- **opinions.yaml** is the configuration cornerstone
- **opinions-loader.sh** makes the configuration actionable
- **init.sh** proves the architecture works
- **Then** we can properly harden all wrapper scripts

## 📋 Detailed Implementation Tasks

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
- **wrapper-scripts-hardening-plan.md** - Complete refactoring guide
- **opinions.yaml** - The configuration cornerstone (PERFECTED!)
- **.agentrules** - AI behavior rules (was CLAUDE.md)
- **workflow.md** - Implementation patterns and guardrails

## 🔄 Next Steps
1. Begin opinions-loader.sh implementation (CORNERSTONE)
2. Focus on load_opinions() and validate_opinions() first
3. Build incrementally with deep integration

---

*The cornerstone is set. Now we build.*