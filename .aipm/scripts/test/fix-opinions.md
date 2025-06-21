# Fix opinions.yaml - Critical Consistency Issues

**Created**: 2025-06-21  
**Purpose**: Deep review findings and required fixes for opinions.yaml consistency
**Updated**: 2025-06-21 - Complete rewrite after thorough multi-pass analysis

## 🔴 CRITICAL ISSUES REQUIRING IMMEDIATE FIXES

### 1. Inconsistent Branch Type References
**Problem**: Branch types defined in naming section not consistently used across file
- `naming.bugfix` defines pattern as `"fix/{description}"` 
- `workflows.branchFlow` references as `"fix/*"`
- `lifecycle` section missing rules for: framework, refactor, docs, chore

**Required Fix**:
```yaml
# Add to lifecycle section:
framework:
  deleteAfterMerge: true
  daysToKeep: 7
  # Example: AIPM_framework/opinions-loader merged → deleted after 7 days

refactor:
  deleteAfterMerge: true
  daysToKeep: 3
  # Example: AIPM_refactor/modularize-scripts merged → deleted after 3 days

docs:
  deleteAfterMerge: true
  daysToKeep: 0
  # Example: AIPM_docs/update-readme merged → deleted immediately

chore:
  deleteAfterMerge: true
  daysToKeep: 0
  # Example: AIPM_chore/cleanup-logs merged → deleted immediately
```

### 2. Session Pattern Redundancy
**Problem**: Session naming pattern defined in two places
- Line 240: `naming.session: "session/{timestamp}"`
- Line 458: `sessions.namePattern: "session/{timestamp}"`

**Required Fix**:
```yaml
# In sessions section, change:
namePattern: "session/{timestamp}"
# To:
namePattern: "{naming.session}"  # Reference naming section pattern
```

### 3. Missing {mainBranch} Construction
**Problem**: `{mainBranch}` used throughout but never explicitly defined
- Used in: workflows, initialization, everywhere
- Should be: `{branching.prefix} + {branching.mainBranchSuffix}`

**Required Fix**:
```yaml
# Add to branching section after mainBranchSuffix:
# COMPUTED: Full main branch name
# {mainBranch} = {prefix} + {mainBranchSuffix}
# Example: AIPM_ + MAIN = AIPM_MAIN
# This computed value is used throughout the configuration
```

### 4. Wrong Prefix Definition Missing
**Problem**: `validation.rules.blockWrongPrefix: true` but "wrong" never defined
- Should reference prefix validation rules from loading section

**Required Fix**:
```yaml
# In validation.rules, update:
blockWrongPrefix: true  # Can't use PRODUCT_ in AIPM
# To include reference:
blockWrongPrefix: true  # Enforces loading.context.prefixRules
```

### 5. Inconsistent Option Naming Convention
**Problem**: Mixed naming styles for option values
- Hyphenated: "check-first", "on-stop", "if-clean"
- CamelCase: Used for field names but not option values
- Will cause parsing inconsistencies

**Required Fix**: Standardize all option values to hyphen-case
```yaml
# Examples of changes needed:
- autoCreate → auto-create
- deleteAfterMerge → delete-after-merge
- allowMultiple → allow-multiple
```

### 6. Parent Tracking Incomplete Loop
**Problem**: Parent tracking mentioned but not fully implemented
- `workflows.branchFlow.parentTracking: "init-commit"`
- But `initialization.marker.message` doesn't include parent info

**Required Fix**:
```yaml
# In initialization.marker:
message: "AIPM_INIT_HERE: Initialize {workspace.name} workspace"
# Change to:
message: "AIPM_INIT_HERE: Initialize {workspace.name} workspace from {parent.branch}"
```

### 7. Circular Reference Risk
**Problem**: `workflows.branchFlow.sources.default: "current"` with no fallback
- What if no current branch exists?
- Could cause infinite loop or crash

**Required Fix**:
```yaml
# Add fallback chain to workflows.branchFlow.sources:
fallback: "{mainBranch}"  # If no current branch, use main
# Or make it explicit in documentation:
# Note: If no current branch exists, falls back to {mainBranch}
```

### 8. Time Format Inconsistency
**Problem**: Mixed time value formats
- Numbers: `daysToKeep: 7`
- Strings: `"7 days"` in some comments
- Unclear units in some places

**Required Fix**: Standardize all time values as numbers with clear units
```yaml
# All time values should specify units in field name:
- timeouts.sessionSeconds: 3600  # not just "session"
- limits.sessionHistoryDays: 30  # not just "sessionHistory"
```

## 🟡 CONSISTENCY IMPROVEMENTS NEEDED

### 1. Documentation Verbosity Mismatch
**Issue**: Early sections have extensive docs, later sections terse
- Example: `lifecycle.global` (lines 257-261) lacks detail

**Fix**: Add same level of documentation throughout

### 2. Required Field Marking
**Issue**: Inconsistent REQUIRED/OPTIONAL marking
- Some sections mark every field
- Others (team.sync) don't mark subfields

**Fix**: Every configurable field needs REQUIRED/OPTIONAL marker

### 3. Default Value Documentation
**Issue**: Some options show defaults, others don't
- User doesn't know what happens if field omitted

**Fix**: Document default behavior for all optional fields

## 🔧 RECOMMENDED ADDITIONS

### 1. Computed Values Section
Add new section to make implicit values explicit:
```yaml
# COMPUTED VALUES (for script reference)
computed:
  mainBranch: "{branching.prefix}{branching.mainBranchSuffix}"
  currentBranch: "$(git rev-parse --abbrev-ref HEAD)"
  parentBranch: "extracted from AIPM_INIT_HERE commit message"
  workspacePath: "$(pwd)"  # Always workspace root
```

### 2. Cross-Validation Rules
Add to loading.validation:
```yaml
crossChecks:
  - "all naming types have lifecycle rules"
  - "all lifecycle types exist in naming"
  - "branching.prefix matches memory.entityPrefix"
  - "all workflow branch patterns exist in naming"
```

### 3. Missing Error Handling
Add section for error scenarios:
```yaml
errorHandling:
  onMissingBranchType: "use-default"  # or "fail"
  onInvalidReference: "fail"          # for {unknown.field}
  onCircularReference: "fail"         # for self-references
```

## 📋 Implementation Checklist

1. [ ] Add missing lifecycle rules for new branch types
2. [ ] Remove session pattern redundancy
3. [ ] Document {mainBranch} construction
4. [ ] Define "wrong prefix" validation
5. [ ] Standardize all options to hyphen-case
6. [ ] Complete parent tracking in initialization
7. [ ] Add circular reference protection
8. [ ] Fix all time format inconsistencies
9. [ ] Equalize documentation verbosity
10. [ ] Mark all fields as REQUIRED/OPTIONAL
11. [ ] Document all default values
12. [ ] Add computed values section
13. [ ] Add cross-validation rules
14. [ ] Add error handling section

## Priority Order

**HIGH** (Blocks implementation):
- Items 1, 2, 3, 6, 7 (branch flow breaks without these)

**MEDIUM** (Causes confusion):
- Items 4, 5, 8, 9 (inconsistency issues)

**LOW** (Nice to have):
- Items 10-14 (improvements for robustness)

---

*This review represents a deep, multi-pass analysis with focus on implementation success*