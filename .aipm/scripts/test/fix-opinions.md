# Fix opinions.yaml - Standardization Requirements

**Created**: 2025-06-21  
**Purpose**: Capture all missing elements and clarifications needed for opinions.yaml

## 🔴 Critical Missing Elements

### 1. opinions-loader.sh Integration
The file doesn't explain how the cornerstone module will use this configuration.

**Need to add**:
- How opinions-loader.sh discovers opinions.yaml files
- Validation rules and error handling
- Inheritance model between framework and project opinions
- Context detection mechanism

**Proposed addition**:
```yaml
# How is this file loaded?
loading:
  # Discovery order
  discovery:
    - "./.aipm/opinions.yaml"        # Current directory first
    - "../.aipm/opinions.yaml"       # Parent directory
    - "$AIPM_ROOT/.aipm/opinions.yaml"  # Framework fallback
  
  # Validation
  validation:
    required: ["workspace", "branching", "memory"]
    schema: ".aipm/schemas/opinions-v1.yaml"
  
  # Inheritance
  inheritance:
    mode: "override"  # project overrides framework
    merge: ["protectedBranches", "categories"]  # these merge instead
```

### 2. Missing Branch Type: 'framework'
The naming patterns don't include framework-specific work.

**Current**:
- feature, bugfix, test, session, release

**Missing**:
- framework: For AIPM framework improvements
- refactor: For code reorganization
- docs: For documentation updates
- chore: For maintenance tasks

**Add to naming section**:
```yaml
framework: "framework/{description}"  # AIPM_framework/opinions-loader
refactor: "refactor/{description}"    # AIPM_refactor/modularize-scripts
docs: "docs/{description}"            # AIPM_docs/update-readme
chore: "chore/{description}"          # AIPM_chore/cleanup-logs
```

### 3. Session Branch Handling
Session branches are mentioned but not fully specified.

**Questions to answer**:
- Are session branches optional or mandatory?
- When are they created (start.sh)?
- Do they auto-merge to main branch?
- Can multiple sessions exist?

**Proposed addition**:
```yaml
sessions:
  enabled: true                    # Can be disabled
  autoCreate: false               # Create on start.sh
  autoMerge: false               # Merge on stop.sh
  allowMultiple: false           # One session at a time
  namePattern: "session/{timestamp}"
```

### 4. The AIPM_INIT_HERE Tag
Line 97 mentions this but doesn't specify details.

**Need to clarify**:
- Is it a git tag or commit message?
- Exact format and content
- How it's used by the system

**Proposed addition**:
```yaml
initialization:
  marker:
    type: "commit"  # or "tag"
    message: "AIPM_INIT_HERE: Initialize {workspace.name} workspace"
    tag: "aipm-init-{workspace.name}-{timestamp}"
    includeMetadata: true  # Add opinions.yaml hash to commit
```

## 🟡 Needs Clarification

### 5. Template System Reality
Templates section references non-existent files.

**Options**:
1. Comment out until templates exist
2. Create minimal stub templates
3. Remove from framework opinions, add when ready

**Recommendation**: Option 3 - Remove now, add when implemented

### 6. Missing Configurations

**Add new section**:
```yaml
# System defaults
defaults:
  timeouts:
    session: 3600              # 1 hour
    operation: 30              # 30 seconds
    git: 60                    # 1 minute for git operations
  
  limits:
    memorySize: "10MB"         # Max memory file size
    backupCount: 10            # Max backups to keep
    sessionHistory: 30         # Days to keep session logs
  
  logging:
    level: "info"              # debug, info, warn, error
    location: ".aipm/logs/"
    rotate: "daily"
    retain: 7
```

### 7. Branch Lifecycle Gaps

**Missing rules**:
```yaml
lifecycle:
  # Global settings
  global:
    handleUncommitted: "stash"    # or "block", "warn"
    conflictResolution: "newest"  # or "prompt", "fail"
    allowOverride: true           # User can override per branch
  
  # Per-type settings (existing)
  feature:
    deleteAfterMerge: true
    # ... existing rules ...
```

### 8. Team Sync Details

**Clarify team section**:
```yaml
team:
  syncMode: manual
  
  # NEW: Detailed sync behavior
  sync:
    prompt:
      triggers: ["remote-ahead", "diverged"]
      timeout: 30
      default: "skip"
    
    divergence:
      definition: "local and remote have different commits"
      resolution: "prompt"  # or "merge", "rebase", "fail"
    
    conflicts:
      strategy: "prompt"    # or "ours", "theirs"
      backup: true
```

### 9. Validation Gradual Mode

**Explain gradual progression**:
```yaml
validation:
  mode: gradual
  
  # NEW: Gradual mode settings
  gradual:
    startLevel: "relaxed"
    endLevel: "strict"
    progression:
      trigger: "days"       # or "commits", "merges"
      value: 30            # After 30 days
      warnings: 7          # Warn for 7 days before enforcing
```

### 10. Memory Categories Validation

**Clarify enforcement**:
```yaml
memory:
  categories:
    # Existing categories...
  
  # NEW: Category rules
  categoryRules:
    strict: true           # Only allow defined categories
    allowDynamic: false    # Can't add new ones on the fly
    uncategorized: "block" # or "warn", "allow"
    caseInsensitive: true  # PROTOCOL = protocol
```

## 🟢 New Sections to Add

### 1. Metadata Section
```yaml
# File metadata
metadata:
  version: "1.0"
  schema: "https://aipm.dev/schemas/opinions/v1"
  lastModified: "2025-06-21T19:30:00Z"
  compatibility: ">=1.0"
```

### 2. Hooks Section
```yaml
# Extensibility hooks
hooks:
  # Script hooks
  scripts:
    preStart: []           # Run before start.sh
    postStop: []           # Run after stop.sh
    preSave: []           # Run before save.sh
    postSave: []          # Run after save.sh
  
  # Validation hooks
  validation:
    branch: []            # Custom branch validators
    memory: []            # Custom memory validators
```

### 3. Error Handling Section
```yaml
# Error handling behavior
errorHandling:
  onInvalidOpinions: "fail"      # or "warn", "use-defaults"
  onMissingDependency: "prompt"  # or "fail", "skip"
  onConflict: "prompt"           # or "abort", "merge", "ours", "theirs"
  onCorruption: "backup-restore" # or "fail", "rebuild"
```

### 4. Platform-Specific Settings
```yaml
# Platform overrides
platforms:
  darwin:  # macOS
    timeouts:
      git: 30  # Faster on macOS
  
  linux:
    paths:
      temp: "/tmp/aipm/"
  
  wsl:
    warnings:
      - "Performance may be slower in WSL"
```

## 🔧 Implementation Priority

1. **High Priority** (Block implementation):
   - opinions-loader.sh integration
   - Session branch handling
   - AIPM_INIT_HERE clarification

2. **Medium Priority** (Can work around):
   - Missing branch types
   - Team sync details
   - Default configurations

3. **Low Priority** (Nice to have):
   - Hooks system
   - Platform-specific settings
   - Gradual validation mode

## Next Steps

1. Decide on each issue above
2. Update opinions.yaml with agreed changes
3. Create minimal template files or remove section
4. Document decisions in changelog.md
5. Update wrapper-scripts-hardening-plan.md with new requirements

---

*This document captures all standardization needs for opinions.yaml as of 2025-06-21*