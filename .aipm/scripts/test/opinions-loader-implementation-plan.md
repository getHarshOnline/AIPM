# opinions-loader.sh Implementation Plan

**Created**: 2025-06-21  
**Purpose**: Transform opinions.yaml into strongly-typed shell exports with validation  
**Principle**: Single Responsibility - Validate, Load and Export ONLY  
**Tool**: yq (lightweight YAML processor) - battle-tested, high-performance

## 🎯 Core Mission

opinions-loader.sh is a **validating transformation layer** that:
1. Reads opinions.yaml
2. **VALIDATES ALL RULES** defined in the file itself
3. Enforces enum-style type safety
4. Exports EVERYTHING as shell variables/functions
5. Provides type-safe accessors
6. NOTHING ELSE - no logic, no decisions, just validate and export

## 📐 Architecture Principles

### 1. Pure Exporter
```bash
# BAD - loader making decisions
get_branch_name() {
    if [[ "$1" == "feature" ]]; then
        echo "${AIPM_BRANCH_PREFIX}feature/new-thing"
    fi
}

# GOOD - loader just exports
export AIPM_NAMING_FEATURE="feature/{description}"
export AIPM_BRANCH_PREFIX="AIPM_"
```

### 2. Everything Becomes Export
Every single value in opinions.yaml becomes:
- An exported variable
- A lookup function
- Or an associative array

### 3. Type Safety
All exports are strongly typed:
- Strings → `export VAR="value"`
- Booleans → `export VAR="true"` (string "true"/"false")
- Numbers → `export VAR="30"` (string numbers)
- Arrays → `export VAR=("item1" "item2")`
- Maps → Associative arrays or prefixed exports

## 🛠️ Prerequisites

```bash
# Check for yq (required dependency)
if ! command -v yq &> /dev/null; then
    die "yq is required but not installed. Install with: brew install yq"
fi
```

## 📋 Usage Modes

The loader supports different modes for handling defaults:

```bash
# Mode 1: Normal loading (uses values from YAML, falls back to defaults)
./opinions-loader.sh

# Mode 2: Defaults only (ignores YAML, uses only defaults)
./opinions-loader.sh --defaults-only

# Mode 3: Show defaults (prints all defaults without loading)
./opinions-loader.sh --show-defaults

# Mode 4: Generate template with defaults
./opinions-loader.sh --generate-template > opinions-template.yaml
```

## 🏗️ Implementation Structure

### Phase 0: Default Values System (100 lines)

The loader must understand ALL defaults from opinions.yaml:

```bash
# ============================================================================
# DEFAULT VALUES - Extracted from opinions.yaml documentation
# ============================================================================

# Initialize all defaults (called before loading YAML)
init_defaults() {
    # Loading defaults
    export AIPM_LOADING_VALIDATION_RECOMMENDED=""  # Default: []
    export AIPM_LOADING_VALIDATION_STRICTMODE="true"  # Default: true
    export AIPM_LOADING_VALIDATION_HASHCHECK="true"  # Default: true
    export AIPM_LOADING_VALIDATION_SCHEMAVERSION="1.0"  # Default: "1.0"
    export AIPM_LOADING_VALIDATION_ONERROR="fail"  # Default: "fail"
    export AIPM_LOADING_CONTEXT_VALIDATEPREFIX="true"  # Default: true
    export AIPM_LOADING_CONTEXT_ENFORCEISOLATION="true"  # Default: true
    export AIPM_LOADING_CONTEXT_PREFIXRULES_RESERVED=""  # Default: []
    export AIPM_LOADING_INHERITANCE_ENABLED="false"  # Default: false
    
    # Lifecycle defaults
    export AIPM_LIFECYCLE_GLOBAL_HANDLEUNCOMMITTED="stash"  # Default: "stash"
    export AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION="prompt"  # Default: "prompt"
    export AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE="true"  # Default: true
    export AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY="true"  # Default: true
    
    # Memory defaults
    export AIPM_MEMORY_CATEGORYRULES_STRICT="true"  # Default: true
    export AIPM_MEMORY_CATEGORYRULES_ALLOWDYNAMIC="false"  # Default: false
    export AIPM_MEMORY_CATEGORYRULES_UNCATEGORIZED="block"  # Default: "block"
    export AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE="true"  # Default: true
    
    # Team defaults
    export AIPM_TEAM_FETCHONSTART="true"  # Default: true
    export AIPM_TEAM_WARNONDIVERGENCE="true"  # Default: true
    export AIPM_TEAM_REQUIREPULLREQUEST="false"  # Default: false
    export AIPM_TEAM_SYNC_PROMPT_TIMEOUT="30"  # Default: 30
    export AIPM_TEAM_SYNC_PROMPT_DEFAULT="skip"  # Default: "skip"
    export AIPM_TEAM_SYNC_DIVERGENCE_SHOWDIFF="true"  # Default: true
    export AIPM_TEAM_SYNC_CONFLICTS_BACKUP="true"  # Default: true
    export AIPM_TEAM_SYNC_CONFLICTS_ABORTONFAIL="true"  # Default: true
    
    # Sessions defaults
    export AIPM_SESSIONS_AUTOCREATE="false"  # Default: false
    export AIPM_SESSIONS_AUTOMERGE="false"  # Default: false
    export AIPM_SESSIONS_PROMPTONCONFLICT="true"  # Default: true
    export AIPM_SESSIONS_CLEANUPONMERGE="true"  # Default: true
    
    # Validation defaults
    export AIPM_VALIDATION_RULES_ENFORCENAMING="true"  # Default: true
    export AIPM_VALIDATION_RULES_BLOCKWRONGPREFIX="true"  # Default: true
    export AIPM_VALIDATION_RULES_REQUIRECLEANTREE="false"  # Default: false
    export AIPM_VALIDATION_RULES_VALIDATEMEMORY="true"  # Default: true
    export AIPM_VALIDATION_BLOCKERS_WRONGWORKSPACE="true"  # Default: true
    export AIPM_VALIDATION_BLOCKERS_INVALIDPREFIX="true"  # Default: true
    export AIPM_VALIDATION_BLOCKERS_CORRUPTMEMORY="true"  # Default: true
    export AIPM_VALIDATION_GRADUAL_PROGRESSION_WARNINGS="7"  # Default: 7
    
    # Initialization defaults
    export AIPM_INITIALIZATION_MARKER_INCLUDEMETADATA="true"  # Default: true
    export AIPM_INITIALIZATION_MARKER_VERIFYONSTART="true"  # Default: true
    export AIPM_INITIALIZATION_BRANCHCREATION_BACKUPORIGINAL="false"  # Default: false
    export AIPM_INITIALIZATION_BRANCHCREATION_SHOWDIFF="true"  # Default: true
    export AIPM_BRANCHING_INITIALIZATION_MAIN_FROMCOMMIT="HEAD"  # Default: HEAD
    
    # Defaults section defaults (meta!)
    export AIPM_DEFAULTS_TIMEOUTS_SESSIONSECONDS="3600"  # Default: 3600
    export AIPM_DEFAULTS_TIMEOUTS_OPERATIONSECONDS="30"  # Default: 30
    export AIPM_DEFAULTS_TIMEOUTS_GITSECONDS="60"  # Default: 60
    export AIPM_DEFAULTS_TIMEOUTS_PROMPTSECONDS="30"  # Default: 30
    export AIPM_DEFAULTS_LIMITS_MEMORYSIZE="10MB"  # Default: "10MB"
    export AIPM_DEFAULTS_LIMITS_BACKUPCOUNT="10"  # Default: 10
    export AIPM_DEFAULTS_LIMITS_SESSIONHISTORYDAYS="30"  # Default: 30
    export AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS="90"  # Default: 90
    export AIPM_DEFAULTS_LOGGING_LEVEL="info"  # Default: "info"
    export AIPM_DEFAULTS_LOGGING_LOCATION=".aipm/logs/"  # Default: ".aipm/logs/"
    export AIPM_DEFAULTS_LOGGING_ROTATE="daily"  # Default: "daily"
    export AIPM_DEFAULTS_LOGGING_RETAIN="7"  # Default: 7
    
    # Error handling defaults
    export AIPM_ERRORHANDLING_RECOVERY_AUTORECOVER="true"  # Default: true
    export AIPM_ERRORHANDLING_RECOVERY_CREATEBACKUP="true"  # Default: true
    export AIPM_ERRORHANDLING_RECOVERY_NOTIFYUSER="always"  # Default: "always"
    
    # Settings defaults
    export AIPM_SETTINGS_FRAMEWORKPATHS_TESTS=".aipm/scripts/test/"  # Default: ".aipm/scripts/test/"
    export AIPM_SETTINGS_FRAMEWORKPATHS_DOCS=".aipm/docs/"  # Default: ".aipm/docs/"
    export AIPM_SETTINGS_FRAMEWORKPATHS_TEMPLATES=".aipm/templates/"  # Default: ".aipm/templates/"
    export AIPM_SETTINGS_WORKFLOW_REQUIRETESTS="false"  # Default: false
    export AIPM_SETTINGS_WORKFLOW_REQUIREDOCS="false"  # Default: false
    export AIPM_SETTINGS_WORKFLOW_REQUIREREVIEW="false"  # Default: false
    
    # Metadata defaults
    export AIPM_METADATA_SCHEMA=""  # Default: none
    export AIPM_METADATA_LASTMODIFIED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"  # Default: auto-generated
    export AIPM_METADATA_COMPATIBILITY=">=1.0"  # Default: ">=1.0"
}

# Get value with default fallback
get_yaml_value_with_default() {
    local path="$1"
    local var_name="AIPM_${path^^}" # Convert to uppercase export name
    var_name="${var_name//./_}"     # Replace dots with underscores
    
    # Get value from YAML
    local value=$(get_yaml_value "$path" "")
    
    # If empty, use default from pre-initialized variable
    if [[ -z "$value" ]]; then
        value="${!var_name:-}"
    fi
    
    printf "%s\n" "$value"
}
```

### Phase 1: Core Loading and Validation Setup (80 lines)
```bash
#!/opt/homebrew/bin/bash
#
# opinions-loader.sh - Transform opinions.yaml to shell exports with validation
#
# SINGLE RESPONSIBILITY: Validate → Load → Export
# Dependencies: shell-formatting.sh, yq
# CRITICAL: NO echo - use printf or shell-formatting.sh functions ONLY

# Source only shell-formatting for errors
source "$(dirname "${BASH_SOURCE[0]}")/shell-formatting.sh"

# Global state
declare -g OPINIONS_FILE_PATH=""
declare -g OPINIONS_LOADED="false"
declare -g OPINIONS_VALID="false"

# Check dependencies
check_dependencies() {
    if ! command -v yq &> /dev/null; then
        die "yq is required but not installed. Install with: brew install yq"
    fi
}

# Load and validate YAML file exists
load_opinions_file() {
    local yaml_path="${1:-./.aipm/opinions.yaml}"
    
    if [[ ! -f "$yaml_path" ]]; then
        die "opinions.yaml not found at: $yaml_path"
    fi
    
    # Validate YAML syntax
    if ! yq eval '.' "$yaml_path" > /dev/null 2>&1; then
        die "Invalid YAML syntax in: $yaml_path"
    fi
    
    OPINIONS_FILE_PATH="$yaml_path"
    OPINIONS_LOADED="true"
}

# Helper: Extract value using yq
get_yaml_value() {
    local path="$1"
    local default="${2:-}"
    
    local value=$(yq eval ".${path} // \"${default}\"" "$OPINIONS_FILE_PATH" 2>/dev/null)
    
    # Handle null/empty
    if [[ "$value" == "null" ]] || [[ -z "$value" ]]; then
        echo "$default"
    else
        printf "%s\n" "$value"
    fi
}

# Helper: Check if path exists
yaml_path_exists() {
    local path="$1"
    
    local result=$(yq eval ".${path} | type" "$OPINIONS_FILE_PATH" 2>/dev/null)
    
    if [[ "$result" != "null" ]] && [[ -n "$result" ]]; then
        return 0
    else
        return 1
    fi
}

# Helper: Get array as space-separated string
get_yaml_array() {
    local path="$1"
    
    yq eval ".${path}[]" "$OPINIONS_FILE_PATH" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
}
```

### Phase 2: Comprehensive Validation Layer (250 lines)

Using yq for robust validation:

```bash
# ============================================================================
# VALIDATION FUNCTIONS - Enforce all rules from opinions.yaml
# ============================================================================

# Validate required sections exist
validate_required_sections() {
    info "Checking required sections..."
    
    # Get required sections from the file itself
    local required=$(get_yaml_array "loading.validation.required")
    
    for section in $required; do
        if ! yaml_path_exists "$section"; then
            die "Required section missing: $section"
        fi
    done
    
    success "All required sections present"
}

# Validate enum values (type safety)
validate_enum() {
    local value="$1"
    local field="$2"
    shift 2
    local allowed_values=("$@")
    
    # Skip if empty (will use default)
    if [[ -z "$value" ]]; then
        return 0
    fi
    
    # Check if value is in allowed list
    local found=false
    for allowed in "${allowed_values[@]}"; do
        if [[ "$value" == "$allowed" ]]; then
            found=true
            break
        fi
    done
    
    if [[ "$found" != "true" ]]; then
        die "Invalid value '$value' for $field. Allowed: ${allowed_values[*]}"
    fi
}

# Validate all enum fields
validate_all_enums() {
    info "Validating enum values..."
    
    # Workspace type
    local type=$(get_yaml_value "workspace.type")
    validate_enum "$type" "workspace.type" "framework" "project"
    
    # Validation mode
    local mode=$(get_yaml_value "validation.mode")
    validate_enum "$mode" "validation.mode" "strict" "relaxed" "gradual"
    
    # Loading error handling
    local on_error=$(get_yaml_value "loading.validation.onError" "fail")
    validate_enum "$on_error" "loading.validation.onError" "fail" "warn" "use-defaults"
    
    # Team sync mode
    local sync_mode=$(get_yaml_value "team.syncMode")
    validate_enum "$sync_mode" "team.syncMode" "manual" "prompt" "auto"
    
    # Lifecycle global settings
    local handle=$(get_yaml_value "lifecycle.global.handleUncommitted")
    validate_enum "$handle" "lifecycle.global.handleUncommitted" "stash" "block" "warn"
    
    local conflict=$(get_yaml_value "lifecycle.global.conflictResolution")
    validate_enum "$conflict" "lifecycle.global.conflictResolution" "prompt" "newest" "fail"
    
    # Memory category rules
    local uncategorized=$(get_yaml_value "memory.categoryRules.uncategorized")
    validate_enum "$uncategorized" "memory.categoryRules.uncategorized" "block" "warn" "allow"
    
    # Sessions settings
    local name_pattern=$(get_yaml_value "sessions.namePattern")
    if [[ "$name_pattern" == "{naming.session}" ]]; then
        # Validate the reference exists
        if ! yaml_path_exists "naming.session"; then
            die "sessions.namePattern references {naming.session} but naming.session doesn't exist"
        fi
    fi
    
    # Workflows
    local start_behavior=$(get_yaml_value "workflows.branchCreation.startBehavior")
    validate_enum "$start_behavior" "workflows.branchCreation.startBehavior" "always" "check-first" "manual"
    
    # Continue for all other enums...
    
    success "All enum values valid"
}

# Validate boolean values
validate_boolean() {
    local value="$1"
    local field="$2"
    
    # Skip if empty
    if [[ -z "$value" ]]; then
        return 0
    fi
    
    if [[ "$value" != "true" ]] && [[ "$value" != "false" ]]; then
        die "Invalid boolean value '$value' for $field. Must be 'true' or 'false'"
    fi
}

# Validate all boolean fields
validate_all_booleans() {
    info "Validating boolean values..."
    
    # Loading validation
    validate_boolean "$(get_yaml_value "loading.validation.strictMode")" "loading.validation.strictMode"
    validate_boolean "$(get_yaml_value "loading.validation.hashCheck")" "loading.validation.hashCheck"
    validate_boolean "$(get_yaml_value "loading.context.validatePrefix")" "loading.context.validatePrefix"
    validate_boolean "$(get_yaml_value "loading.context.enforceIsolation")" "loading.context.enforceIsolation"
    validate_boolean "$(get_yaml_value "loading.inheritance.enabled")" "loading.inheritance.enabled"
    
    # Lifecycle
    validate_boolean "$(get_yaml_value "lifecycle.global.allowOverride")" "lifecycle.global.allowOverride"
    validate_boolean "$(get_yaml_value "lifecycle.global.trackActivity")" "lifecycle.global.trackActivity"
    
    # Memory
    validate_boolean "$(get_yaml_value "memory.categoryRules.strict")" "memory.categoryRules.strict"
    validate_boolean "$(get_yaml_value "memory.categoryRules.allowDynamic")" "memory.categoryRules.allowDynamic"
    validate_boolean "$(get_yaml_value "memory.categoryRules.caseInsensitive")" "memory.categoryRules.caseInsensitive"
    
    # Continue for all boolean fields...
    
    success "All boolean values valid"
}

# Cross-validation rules from loading.validation comments
validate_cross_references() {
    info "Validating cross-references..."
    
    # 1. All naming types must have lifecycle rules
    local naming_types=$(yq eval '.naming | keys | .[]' "$OPINIONS_FILE_PATH" 2>/dev/null)
    for type in $naming_types; do
        if ! yaml_path_exists "lifecycle.$type"; then
            warn "Branch type '$type' has naming pattern but no lifecycle rules"
        fi
    done
    
    # 2. All lifecycle types must exist in naming
    local lifecycle_types=$(yq eval '.lifecycle | keys | .[]' "$OPINIONS_FILE_PATH" 2>/dev/null | grep -v "global")
    for type in $lifecycle_types; do
        if ! yaml_path_exists "naming.$type"; then
            warn "Branch type '$type' has lifecycle rules but no naming pattern"
        fi
    done
    
    # 3. branching.prefix must match memory.entityPrefix
    local branch_prefix=$(get_yaml_value "branching.prefix")
    local memory_prefix=$(get_yaml_value "memory.entityPrefix")
    if [[ -n "$branch_prefix" ]] && [[ -n "$memory_prefix" ]] && [[ "$branch_prefix" != "$memory_prefix" ]]; then
        die "branching.prefix ($branch_prefix) must match memory.entityPrefix ($memory_prefix)"
    fi
    
    # 4. Validate prefix format
    local prefix_pattern=$(get_yaml_value "loading.context.prefixRules.pattern" "^[A-Z][A-Z0-9_]*_$")
    if [[ -n "$branch_prefix" ]] && ! [[ "$branch_prefix" =~ $prefix_pattern ]]; then
        die "branching.prefix '$branch_prefix' doesn't match required pattern: $prefix_pattern"
    fi
    
    # 5. Check reserved prefixes
    local reserved=$(get_yaml_array "loading.context.prefixRules.reserved")
    for reserved_prefix in $reserved; do
        if [[ "$branch_prefix" == "$reserved_prefix" ]]; then
            die "branching.prefix '$branch_prefix' uses reserved prefix"
        fi
    done
    
    # 6. Validate protected branches
    local user_branches=$(get_yaml_array "branching.protectedBranches.userBranches")
    local aipm_suffixes=$(get_yaml_array "branching.protectedBranches.aipmBranchSuffixes")
    
    # Ensure main branch suffix is protected
    local main_suffix=$(get_yaml_value "branching.mainBranchSuffix")
    if [[ -n "$main_suffix" ]] && ! [[ " $aipm_suffixes " =~ " $main_suffix " ]]; then
        warn "Main branch suffix '$main_suffix' not in protected branches list"
    fi
    
    success "Cross-references valid"
}

# Validate schema version
validate_schema_version() {
    local file_version=$(get_yaml_value "metadata.version" "1.0")
    local min_version=$(get_yaml_value "loading.validation.schemaVersion" "1.0")
    
    # Simple version comparison (assumes X.Y format)
    if [[ "$(printf '%s\n' "$min_version" "$file_version" | sort -V | head -n1)" != "$min_version" ]]; then
        die "Schema version $file_version is less than required minimum $min_version"
    fi
}

# Main validation entry point
validate_opinions() {
    section "Validating opinions.yaml"
    
    # Get validation mode
    local strict_mode=$(get_yaml_value "loading.validation.strictMode" "true")
    local on_error=$(get_yaml_value "loading.validation.onError" "fail")
    
    # Schema version check
    validate_schema_version
    
    # Required sections
    validate_required_sections
    
    # Type validations
    validate_all_enums
    validate_all_booleans
    
    # Cross-validation
    validate_cross_references
    
    # Validate hash hasn't changed
    if [[ "$(get_yaml_value "loading.validation.hashCheck" "true")" == "true" ]]; then
        export AIPM_INITIAL_HASH=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
    fi
    
    OPINIONS_VALID="true"
    success "All validations passed"
```

### Phase 3: Export Generation (300 lines)

Transform all YAML values into strongly-typed shell exports:

```bash
# ============================================================================
# EXPORT FUNCTIONS - Transform YAML sections to shell exports
# ============================================================================

# Export workspace section
export_workspace_section() {
    # Required fields (no defaults)
    if [[ "$AIPM_DEFAULTS_ONLY" != "true" ]]; then
        export AIPM_WORKSPACE_TYPE=$(get_yaml_value "workspace.type")
        export AIPM_WORKSPACE_NAME=$(get_yaml_value "workspace.name") 
        export AIPM_WORKSPACE_DESCRIPTION=$(get_yaml_value "workspace.description")
    else
        # In defaults-only mode, use framework defaults
        export AIPM_WORKSPACE_TYPE="framework"
        export AIPM_WORKSPACE_NAME="AIPM"
        export AIPM_WORKSPACE_DESCRIPTION="AI Project Manager Framework"
    fi
}

# Export branching section
export_branching_section() {
    export AIPM_BRANCHING_PREFIX=$(get_yaml_value "branching.prefix")
    export AIPM_BRANCHING_MAINBRANCHSUFFIX=$(get_yaml_value "branching.mainBranchSuffix")
    
    # Computed value - the full main branch name
    export AIPM_BRANCHING_MAINBRANCH="${AIPM_BRANCHING_PREFIX}${AIPM_BRANCHING_MAINBRANCHSUFFIX}"
    
    # Initialization mappings
    export AIPM_BRANCHING_INITIALIZATION_MAIN_SUFFIX=$(get_yaml_value "branching.initialization.main.suffix")
    export AIPM_BRANCHING_INITIALIZATION_MAIN_FROMCOMMIT=$(get_yaml_value "branching.initialization.main.fromCommit" "HEAD")
    
    # Protected branches (as space-separated strings)
    export AIPM_BRANCHING_PROTECTEDBRANCHES_USER=$(get_yaml_array "branching.protectedBranches.userBranches")
    export AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM=$(get_yaml_array "branching.protectedBranches.aipmBranchSuffixes")
}

# Export naming patterns
export_naming_section() {
    # Export each naming pattern
    for type in feature bugfix test session release framework refactor docs chore; do
        local pattern=$(get_yaml_value "naming.$type")
        if [[ -n "$pattern" ]]; then
            export "AIPM_NAMING_${type^^}"="$pattern"
        fi
    done
}

# Export lifecycle rules
export_lifecycle_section() {
    # Global lifecycle settings
    export AIPM_LIFECYCLE_GLOBAL_HANDLEUNCOMMITTED=$(get_yaml_value "lifecycle.global.handleUncommitted" "stash")
    export AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION=$(get_yaml_value "lifecycle.global.conflictResolution" "prompt")
    export AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE=$(get_yaml_value "lifecycle.global.allowOverride" "true")
    export AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY=$(get_yaml_value "lifecycle.global.trackActivity" "true")
    
    # Per-type lifecycle rules
    for type in feature session test release framework refactor docs chore bugfix; do
        if yaml_path_exists "lifecycle.$type"; then
            export "AIPM_LIFECYCLE_${type^^}_DELETEAFTERMERGE"=$(get_yaml_value "lifecycle.$type.deleteAfterMerge")
            export "AIPM_LIFECYCLE_${type^^}_DAYSTOKEEP"=$(get_yaml_value "lifecycle.$type.daysToKeep")
            
            # Special fields
            if [[ "$type" == "session" ]]; then
                export AIPM_LIFECYCLE_SESSION_MAXSESSIONS=$(get_yaml_value "lifecycle.session.maxSessions")
            fi
        fi
    done
}

# Export memory settings
export_memory_section() {
    export AIPM_MEMORY_ENTITYPREFIX=$(get_yaml_value "memory.entityPrefix")
    export AIPM_MEMORY_CATEGORIES=$(get_yaml_array "memory.categories")
    
    # Category rules
    export AIPM_MEMORY_CATEGORYRULES_STRICT=$(get_yaml_value "memory.categoryRules.strict" "true")
    export AIPM_MEMORY_CATEGORYRULES_ALLOWDYNAMIC=$(get_yaml_value "memory.categoryRules.allowDynamic" "false")
    export AIPM_MEMORY_CATEGORYRULES_UNCATEGORIZED=$(get_yaml_value "memory.categoryRules.uncategorized" "block")
    export AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE=$(get_yaml_value "memory.categoryRules.caseInsensitive" "true")
}

# Export all other sections similarly...
# (team, sessions, validation, initialization, defaults, workflows, errorHandling, settings, metadata)

# Export computed values
export_computed_values() {
    # Main branch (already computed in branching)
    export AIPM_COMPUTED_MAINBRANCH="${AIPM_BRANCHING_PREFIX}${AIPM_BRANCHING_MAINBRANCHSUFFIX}"
    
    # Prefix patterns for validation
    export AIPM_COMPUTED_PREFIXPATTERN="^${AIPM_BRANCHING_PREFIX}"
    export AIPM_COMPUTED_ENTITYPATTERN="^${AIPM_MEMORY_ENTITYPREFIX}[A-Z]+_"
    
    # File hash for integrity check
    export AIPM_COMPUTED_FILEHASH=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
    
    # Timestamp of loading
    export AIPM_COMPUTED_LOADTIME=$(date +%s)
}

### Phase 4: Lookup Functions (100 lines)

Provide clean API for accessing exports:

```bash
# ============================================================================
# LOOKUP FUNCTIONS - Clean API for accessing exports
# ============================================================================

# Get naming pattern for a branch type
aipm_get_naming_pattern() {
    local branch_type="$1"
    local var_name="AIPM_NAMING_${branch_type^^}"
    echo "${!var_name:-}"
}

# Get lifecycle rule for a branch type
aipm_get_lifecycle_rule() {
    local branch_type="$1"
    local rule="$2"  # deleteAfterMerge, daysToKeep
    local var_name="AIPM_LIFECYCLE_${branch_type^^}_${rule^^}"
    echo "${!var_name:-}"
}

# Get workflow setting
aipm_get_workflow() {
    local section="$1"  # branchCreation, synchronization, cleanup
    local field="$2"
    local var_name="AIPM_WORKFLOWS_${section^^}_${field^^}"
    echo "${!var_name:-}"
}

# Check if a branch is protected
aipm_is_protected_branch() {
    local branch="$1"
    
    # Check user branches
    if [[ " $AIPM_BRANCHING_PROTECTEDBRANCHES_USER " =~ " $branch " ]]; then
        echo "true"
        return 0
    fi
    
    # Check AIPM branches
    for suffix in $AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM; do
        if [[ "$branch" == "${AIPM_BRANCHING_PREFIX}${suffix}" ]]; then
            echo "true"
            return 0
        fi
    done
    
    echo "false"
    return 1
}

# Get branch flow source for a branch type
aipm_get_branch_source() {
    local branch_type="$1"
    local pattern="${branch_type}/*"
    
    # Check for specific override
    local override=$(get_yaml_value "workflows.branchFlow.sources.byType.${pattern}" "")
    if [[ -n "$override" ]]; then
        # Resolve references like {mainBranch}
        override="${override//\{mainBranch\}/$AIPM_COMPUTED_MAINBRANCH}"
        echo "$override"
    else
        echo "$AIPM_WORKFLOWS_BRANCHFLOW_SOURCES_DEFAULT"
    fi
}

# Get branch flow target
aipm_get_branch_target() {
    local branch_type="$1"
    local pattern="${branch_type}/*"
    
    # Check for specific override
    local override=$(get_yaml_value "workflows.branchFlow.targets.byType.${pattern}" "")
    if [[ -n "$override" ]]; then
        # Resolve references
        override="${override//\{mainBranch\}/$AIPM_COMPUTED_MAINBRANCH}"
        echo "$override"
    else
        echo "$AIPM_WORKFLOWS_BRANCHFLOW_TARGETS_DEFAULT"
    fi
}

# Check if memory category is allowed
aipm_is_valid_category() {
    local category="$1"
    
    # Handle case sensitivity
    if [[ "$AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE" == "true" ]]; then
        category="${category^^}"
    fi
    
    # Check if in allowed list
    if [[ " $AIPM_MEMORY_CATEGORIES " =~ " $category " ]]; then
        echo "true"
        return 0
    fi
    
    echo "false"
    return 1
}
```

### Phase 5: Main Entry Point (50 lines)

```bash
# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

# Load and export all opinions
load_and_export_opinions() {
    local yaml_path="${1:-./.aipm/opinions.yaml}"
    
    # Always initialize defaults first
    init_defaults
    
    # Check dependencies
    check_dependencies
    
    # Load and validate file (unless defaults-only mode)
    if [[ "$AIPM_DEFAULTS_ONLY" != "true" ]]; then
        load_opinions_file "$yaml_path"
        validate_opinions
    fi
    
    # Export all sections
    info "Exporting all configuration values..."
    
    export_workspace_section
    export_branching_section  
    export_naming_section
    export_lifecycle_section
    export_memory_section
    export_team_section
    export_sessions_section
    export_validation_section
    export_initialization_section
    export_defaults_section
    export_workflows_section
    export_errorhandling_section
    export_settings_section
    export_metadata_section
    
    # Export computed values
    export_computed_values
    
    # Mark as loaded
    export AIPM_OPINIONS_LOADED="true"
    export AIPM_OPINIONS_PATH="${OPINIONS_FILE_PATH:-defaults}"
    
    # Show summary
    if [[ "$AIPM_DEFAULTS_ONLY" == "true" ]]; then
        success "Loaded default opinions (no YAML file)"
    else
        success "Loaded and exported opinions from: $yaml_path"
    fi
    info "Workspace: $AIPM_WORKSPACE_NAME ($AIPM_WORKSPACE_TYPE)"
    info "Branch prefix: $AIPM_BRANCHING_PREFIX"
    info "Main branch: $AIPM_COMPUTED_MAINBRANCH"
}

# Handle command line arguments
main() {
    case "${1:-}" in
        --defaults-only)
            export AIPM_DEFAULTS_ONLY="true"
            load_and_export_opinions
            ;;
        --show-defaults)
            init_defaults
            env | grep "^AIPM_" | sort
            ;;
        --generate-template)
            generate_template_with_defaults
            ;;
        *)
            load_and_export_opinions "$@"
            ;;
    esac
}

# Auto-load if sourced directly (not in test mode)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ -z "$AIPM_TEST_MODE" ]]; then
    main "$@"
fi
```

## 🧪 Testing Strategy

### 1. Unit Tests for Validation
```bash
test_validation() {
    # Test enum validation
    validate_enum "strict" "validation.mode" "strict" "relaxed" "gradual" || die "Failed valid enum"
    
    # Test invalid enum
    if validate_enum "invalid" "test.field" "valid1" "valid2" 2>/dev/null; then
        die "Failed to catch invalid enum"
    fi
    
    # Test boolean validation
    validate_boolean "true" "test.field" || die "Failed valid boolean"
    validate_boolean "false" "test.field" || die "Failed valid boolean"
    
    # Test invalid boolean
    if validate_boolean "yes" "test.field" 2>/dev/null; then
        die "Failed to catch invalid boolean"
    fi
}
```

### 2. Unit Tests for Each Export
```bash
test_exports() {
    # Load test opinions file
    load_and_export_opinions "test-opinions.yaml"
    
    # Verify exports
    [[ "$AIPM_WORKSPACE_TYPE" == "framework" ]] || die "Wrong workspace type"
    [[ "$AIPM_WORKSPACE_NAME" == "AIPM" ]] || die "Wrong workspace name"
    [[ "$AIPM_BRANCHING_PREFIX" == "AIPM_" ]] || die "Wrong prefix"
    [[ "$AIPM_COMPUTED_MAINBRANCH" == "AIPM_MAIN" ]] || die "Wrong main branch"
    
    # Test lookup functions
    local pattern=$(aipm_get_naming_pattern "feature")
    [[ "$pattern" == "feature/{description}" ]] || die "Wrong naming pattern"
    
    local protected=$(aipm_is_protected_branch "main")
    [[ "$protected" == "true" ]] || die "main should be protected"
}
```

### 3. Integration Test
```bash
test_full_integration() {
    # Set test mode
    export AIPM_TEST_MODE=1
    
    # Source the loader
    source opinions-loader.sh
    
    # Load opinions
    load_and_export_opinions
    
    # Verify all exports exist
    env | grep "^AIPM_" | wc -l | grep -q "100" || die "Missing exports"
    
    # Test cross-references
    [[ "$AIPM_BRANCHING_PREFIX" == "$AIPM_MEMORY_ENTITYPREFIX" ]] || die "Prefix mismatch"
}
```

## 📊 Complete Export Reference

Every field in opinions.yaml maps to an export:

```bash
# Loading
AIPM_LOADING_DISCOVERY_PATH
AIPM_LOADING_VALIDATION_REQUIRED
AIPM_LOADING_VALIDATION_RECOMMENDED
AIPM_LOADING_VALIDATION_STRICTMODE
AIPM_LOADING_VALIDATION_HASHCHECK
AIPM_LOADING_VALIDATION_SCHEMAVERSION
AIPM_LOADING_VALIDATION_ONERROR
AIPM_LOADING_CONTEXT_DETECTBY
AIPM_LOADING_CONTEXT_VALIDATEPREFIX
AIPM_LOADING_CONTEXT_ENFORCEISOLATION
AIPM_LOADING_CONTEXT_PREFIXRULES_MUSTMATCH
AIPM_LOADING_CONTEXT_PREFIXRULES_PATTERN
AIPM_LOADING_CONTEXT_PREFIXRULES_RESERVED
AIPM_LOADING_INHERITANCE_ENABLED

# Workspace
AIPM_WORKSPACE_TYPE
AIPM_WORKSPACE_NAME  
AIPM_WORKSPACE_DESCRIPTION

# Branching
AIPM_BRANCHING_PREFIX
AIPM_BRANCHING_MAINBRANCHSUFFIX
AIPM_BRANCHING_MAINBRANCH  # Computed
AIPM_BRANCHING_INITIALIZATION_MAIN_SUFFIX
AIPM_BRANCHING_INITIALIZATION_MAIN_FROMCOMMIT
AIPM_BRANCHING_PROTECTEDBRANCHES_USER
AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM

# Naming (for each type)
AIPM_NAMING_FEATURE
AIPM_NAMING_BUGFIX
AIPM_NAMING_TEST
AIPM_NAMING_SESSION
AIPM_NAMING_RELEASE
AIPM_NAMING_FRAMEWORK
AIPM_NAMING_REFACTOR
AIPM_NAMING_DOCS
AIPM_NAMING_CHORE

# Lifecycle (for each type)
AIPM_LIFECYCLE_GLOBAL_HANDLEUNCOMMITTED
AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION
AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE
AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY
AIPM_LIFECYCLE_<TYPE>_DELETEAFTERMERGE
AIPM_LIFECYCLE_<TYPE>_DAYSTOKEEP
AIPM_LIFECYCLE_SESSION_MAXSESSIONS

# Memory
AIPM_MEMORY_ENTITYPREFIX
AIPM_MEMORY_CATEGORIES
AIPM_MEMORY_CATEGORYRULES_STRICT
AIPM_MEMORY_CATEGORYRULES_ALLOWDYNAMIC
AIPM_MEMORY_CATEGORYRULES_UNCATEGORIZED
AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE

# Team
AIPM_TEAM_SYNCMODE
AIPM_TEAM_FETCHONSTART
AIPM_TEAM_WARNONDIVERGENCE
AIPM_TEAM_REQUIREPULLREQUEST
AIPM_TEAM_SYNC_PROMPT_TIMEOUT
AIPM_TEAM_SYNC_PROMPT_DEFAULT
AIPM_TEAM_SYNC_DIVERGENCE_RESOLUTION
AIPM_TEAM_SYNC_DIVERGENCE_SHOWDIFF
AIPM_TEAM_SYNC_CONFLICTS_STRATEGY
AIPM_TEAM_SYNC_CONFLICTS_BACKUP
AIPM_TEAM_SYNC_CONFLICTS_ABORTONFAIL

# Sessions
AIPM_SESSIONS_ENABLED
AIPM_SESSIONS_AUTOCREATE
AIPM_SESSIONS_AUTOMERGE
AIPM_SESSIONS_ALLOWMULTIPLE
AIPM_SESSIONS_NAMEPATTERN
AIPM_SESSIONS_PROMPTONCONFLICT
AIPM_SESSIONS_CLEANUPONMERGE

# Validation
AIPM_VALIDATION_MODE
AIPM_VALIDATION_GRADUAL_STARTLEVEL
AIPM_VALIDATION_GRADUAL_ENDLEVEL
AIPM_VALIDATION_GRADUAL_PROGRESSION_TRIGGER
AIPM_VALIDATION_GRADUAL_PROGRESSION_VALUE
AIPM_VALIDATION_GRADUAL_PROGRESSION_WARNINGS
AIPM_VALIDATION_RULES_ENFORCENAMING
AIPM_VALIDATION_RULES_BLOCKWRONGPREFIX
AIPM_VALIDATION_RULES_REQUIRECLEANTREE
AIPM_VALIDATION_RULES_VALIDATEMEMORY
AIPM_VALIDATION_BLOCKERS_WRONGWORKSPACE
AIPM_VALIDATION_BLOCKERS_INVALIDPREFIX
AIPM_VALIDATION_BLOCKERS_CORRUPTMEMORY

# Initialization
AIPM_INITIALIZATION_MARKER_TYPE
AIPM_INITIALIZATION_MARKER_MESSAGE
AIPM_INITIALIZATION_MARKER_INCLUDEMETADATA
AIPM_INITIALIZATION_MARKER_VERIFYONSTART
AIPM_INITIALIZATION_BRANCHCREATION_REQUIRECLEAN
AIPM_INITIALIZATION_BRANCHCREATION_BACKUPORIGINAL
AIPM_INITIALIZATION_BRANCHCREATION_SHOWDIFF

# Defaults
AIPM_DEFAULTS_TIMEOUTS_SESSIONSECONDS
AIPM_DEFAULTS_TIMEOUTS_OPERATIONSECONDS
AIPM_DEFAULTS_TIMEOUTS_GITSECONDS
AIPM_DEFAULTS_TIMEOUTS_PROMPTSECONDS
AIPM_DEFAULTS_LIMITS_MEMORYSIZE
AIPM_DEFAULTS_LIMITS_BACKUPCOUNT
AIPM_DEFAULTS_LIMITS_SESSIONHISTORYDAYS
AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS
AIPM_DEFAULTS_LOGGING_LEVEL
AIPM_DEFAULTS_LOGGING_LOCATION
AIPM_DEFAULTS_LOGGING_ROTATE
AIPM_DEFAULTS_LOGGING_RETAIN

# Error Handling
AIPM_ERRORHANDLING_ONMISSINGBRANCHTYPE
AIPM_ERRORHANDLING_ONINVALIDREFERENCE
AIPM_ERRORHANDLING_ONCIRCULARREFERENCE
AIPM_ERRORHANDLING_RECOVERY_AUTORECOVER
AIPM_ERRORHANDLING_RECOVERY_CREATEBACKUP
AIPM_ERRORHANDLING_RECOVERY_NOTIFYUSER

# Workflows
AIPM_WORKFLOWS_BRANCHCREATION_STARTBEHAVIOR
AIPM_WORKFLOWS_BRANCHCREATION_PROTECTIONRESPONSE
AIPM_WORKFLOWS_BRANCHCREATION_AUTONAME
AIPM_WORKFLOWS_BRANCHCREATION_DUPLICATESTRATEGY
AIPM_WORKFLOWS_MERGETRIGGERS_FEATURECOMPLETE
AIPM_WORKFLOWS_MERGETRIGGERS_CONFLICTHANDLING
AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART
AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP
AIPM_WORKFLOWS_SYNCHRONIZATION_AUTOBACKUP
AIPM_WORKFLOWS_CLEANUP_AFTERMERGE
AIPM_WORKFLOWS_CLEANUP_STALEHANDLING
AIPM_WORKFLOWS_CLEANUP_FAILEDWORK
AIPM_WORKFLOWS_BRANCHFLOW_SOURCES_DEFAULT
AIPM_WORKFLOWS_BRANCHFLOW_TARGETS_DEFAULT
AIPM_WORKFLOWS_BRANCHFLOW_PARENTTRACKING

# Settings
AIPM_SETTINGS_SCHEMAVERSION
AIPM_SETTINGS_FRAMEWORKPATHS_MODULES
AIPM_SETTINGS_FRAMEWORKPATHS_TESTS
AIPM_SETTINGS_FRAMEWORKPATHS_DOCS
AIPM_SETTINGS_FRAMEWORKPATHS_TEMPLATES
AIPM_SETTINGS_WORKFLOW_REQUIRETESTS
AIPM_SETTINGS_WORKFLOW_REQUIREDOCS
AIPM_SETTINGS_WORKFLOW_REQUIREREVIEW

# Metadata
AIPM_METADATA_VERSION
AIPM_METADATA_SCHEMA
AIPM_METADATA_LASTMODIFIED
AIPM_METADATA_COMPATIBILITY

# Computed
AIPM_COMPUTED_MAINBRANCH
AIPM_COMPUTED_PREFIXPATTERN
AIPM_COMPUTED_ENTITYPATTERN
AIPM_COMPUTED_FILEHASH
AIPM_COMPUTED_LOADTIME

# Loader state
AIPM_OPINIONS_LOADED
AIPM_OPINIONS_PATH
AIPM_OPINIONS_VALID
AIPM_INITIAL_HASH
```

## 🚀 Implementation Summary

The opinions-loader.sh is a **pure transformation layer** that:

1. **Validates** all rules defined in opinions.yaml itself
2. **Enforces** enum-style type safety
3. **Exports** EVERYTHING as strongly-typed shell variables
4. **Provides** clean lookup functions
5. **Uses** yq for robust YAML parsing
6. **Leverages** shell-formatting.sh for all output

Total estimated lines: ~800-900 lines of robust, validated code.

#### Naming Convention
All exports follow strict pattern:
```
AIPM_<SECTION>_<SUBSECTION>_<FIELD>
```

Examples:
- `AIPM_WORKSPACE_TYPE="framework"`
- `AIPM_BRANCHING_PREFIX="AIPM_"`
- `AIPM_LIFECYCLE_FEATURE_DELETEAFTERMERGE="true"`

#### Export Functions
```bash
# Export all workspace settings
export_workspace_section() {
    export AIPM_WORKSPACE_TYPE=$(extract_yaml_value "workspace.type" "$OPINIONS_YAML_CONTENT")
    export AIPM_WORKSPACE_NAME=$(extract_yaml_value "workspace.name" "$OPINIONS_YAML_CONTENT")
    export AIPM_WORKSPACE_DESCRIPTION=$(extract_yaml_value "workspace.description" "$OPINIONS_YAML_CONTENT")
}

# Export all branching settings
export_branching_section() {
    export AIPM_BRANCHING_PREFIX=$(extract_yaml_value "branching.prefix" "$OPINIONS_YAML_CONTENT")
    export AIPM_BRANCHING_MAINBRANCHSUFFIX=$(extract_yaml_value "branching.mainBranchSuffix" "$OPINIONS_YAML_CONTENT")
    
    # Computed value
    export AIPM_BRANCHING_MAINBRANCH="${AIPM_BRANCHING_PREFIX}${AIPM_BRANCHING_MAINBRANCHSUFFIX}"
}

# Export naming patterns
export_naming_section() {
    export AIPM_NAMING_FEATURE=$(extract_yaml_value "naming.feature" "$OPINIONS_YAML_CONTENT")
    export AIPM_NAMING_BUGFIX=$(extract_yaml_value "naming.bugfix" "$OPINIONS_YAML_CONTENT")
    export AIPM_NAMING_TEST=$(extract_yaml_value "naming.test" "$OPINIONS_YAML_CONTENT")
    export AIPM_NAMING_SESSION=$(extract_yaml_value "naming.session" "$OPINIONS_YAML_CONTENT")
    export AIPM_NAMING_RELEASE=$(extract_yaml_value "naming.release" "$OPINIONS_YAML_CONTENT")
    export AIPM_NAMING_FRAMEWORK=$(extract_yaml_value "naming.framework" "$OPINIONS_YAML_CONTENT")
    export AIPM_NAMING_REFACTOR=$(extract_yaml_value "naming.refactor" "$OPINIONS_YAML_CONTENT")
    export AIPM_NAMING_DOCS=$(extract_yaml_value "naming.docs" "$OPINIONS_YAML_CONTENT")
    export AIPM_NAMING_CHORE=$(extract_yaml_value "naming.chore" "$OPINIONS_YAML_CONTENT")
}

# Export lifecycle rules
export_lifecycle_section() {
    # Global settings
    export AIPM_LIFECYCLE_GLOBAL_HANDLEUNCOMMITTED=$(extract_yaml_value "lifecycle.global.handleUncommitted" "$OPINIONS_YAML_CONTENT")
    export AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION=$(extract_yaml_value "lifecycle.global.conflictResolution" "$OPINIONS_YAML_CONTENT")
    export AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE=$(extract_yaml_value "lifecycle.global.allowOverride" "$OPINIONS_YAML_CONTENT")
    export AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY=$(extract_yaml_value "lifecycle.global.trackActivity" "$OPINIONS_YAML_CONTENT")
    
    # Per-type rules (iterate through all types)
    for type in feature session test release framework refactor docs chore bugfix; do
        local TYPE_UPPER=$(echo "$type" | tr '[:lower:]' '[:upper:]')
        export "AIPM_LIFECYCLE_${TYPE_UPPER}_DELETEAFTERMERGE"=$(extract_yaml_value "lifecycle.$type.deleteAfterMerge" "$OPINIONS_YAML_CONTENT")
        export "AIPM_LIFECYCLE_${TYPE_UPPER}_DAYSTOKEEP"=$(extract_yaml_value "lifecycle.$type.daysToKeep" "$OPINIONS_YAML_CONTENT")
    done
}
```

### Phase 4: Lookup Functions (50 lines)
Provide clean accessors for complex lookups:

```bash
# Get naming pattern for branch type
aipm_get_naming_pattern() {
    local branch_type="$1"
    local var_name="AIPM_NAMING_${branch_type^^}"
    echo "${!var_name:-}"
}

# Get lifecycle rule for branch type
aipm_get_lifecycle_rule() {
    local branch_type="$1"
    local rule="$2"  # deleteAfterMerge, daysToKeep
    local var_name="AIPM_LIFECYCLE_${branch_type^^}_${rule^^}"
    echo "${!var_name:-}"
}

# Get workflow setting
aipm_get_workflow() {
    local section="$1"  # branchCreation, synchronization, cleanup
    local field="$2"
    local var_name="AIPM_WORKFLOWS_${section^^}_${field^^}"
    echo "${!var_name:-}"
}
```

### Phase 5: Validation Exports (30 lines)
```bash
# Export validation results
export_validation_status() {
    export AIPM_VALIDATION_MODE=$(extract_yaml_value "validation.mode" "$OPINIONS_YAML_CONTENT")
    export AIPM_VALIDATION_RULES_ENFORCENAMING=$(extract_yaml_value "validation.rules.enforceNaming" "$OPINIONS_YAML_CONTENT")
    export AIPM_VALIDATION_RULES_BLOCKWRONGPREFIX=$(extract_yaml_value "validation.rules.blockWrongPrefix" "$OPINIONS_YAML_CONTENT")
    
    # Validation state
    export AIPM_OPINIONS_VALID="true"
    export AIPM_OPINIONS_HASH=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
}
```

### Phase 6: Main Export Function (30 lines)
```bash
# Main entry point - loads and exports everything
load_and_export_opinions() {
    local yaml_path="${1:-./.aipm/opinions.yaml}"
    
    # Load file
    load_opinions_file "$yaml_path"
    
    # Export all sections
    export_workspace_section
    export_branching_section
    export_naming_section
    export_lifecycle_section
    export_memory_section
    export_team_section
    export_sessions_section
    export_validation_section
    export_initialization_section
    export_defaults_section
    export_workflows_section
    export_metadata_section
    
    # Export computed values
    export_computed_values
    
    # Export validation status
    export_validation_status
    
    # Mark as loaded
    export AIPM_OPINIONS_LOADED="true"
}
```

## 🧪 Testing Strategy

### 1. Unit Tests for Each Export
```bash
test_workspace_exports() {
    load_and_export_opinions "test-opinions.yaml"
    
    assert_equals "$AIPM_WORKSPACE_TYPE" "framework"
    assert_equals "$AIPM_WORKSPACE_NAME" "AIPM"
    assert_not_empty "$AIPM_WORKSPACE_DESCRIPTION"
}
```

### 2. Type Safety Tests
```bash
test_type_safety() {
    # Booleans are strings
    assert_matches "$AIPM_LIFECYCLE_FEATURE_DELETEAFTERMERGE" "^(true|false)$"
    
    # Numbers are strings
    assert_matches "$AIPM_DEFAULTS_TIMEOUTS_SESSIONSECONDS" "^[0-9]+$"
}
```

### 3. Lookup Function Tests
```bash
test_lookup_functions() {
    local pattern=$(aipm_get_naming_pattern "feature")
    assert_equals "$pattern" "feature/{description}"
    
    local delete=$(aipm_get_lifecycle_rule "feature" "deleteAfterMerge")
    assert_equals "$delete" "true"
}
```

## 📊 Export Reference

### Complete Export List
Every field in opinions.yaml maps to an export:

```bash
# Workspace
AIPM_WORKSPACE_TYPE
AIPM_WORKSPACE_NAME
AIPM_WORKSPACE_DESCRIPTION

# Branching
AIPM_BRANCHING_PREFIX
AIPM_BRANCHING_MAINBRANCHSUFFIX
AIPM_BRANCHING_MAINBRANCH  # Computed

# Naming (for each type)
AIPM_NAMING_FEATURE
AIPM_NAMING_BUGFIX
AIPM_NAMING_TEST
...

# Lifecycle (for each type and rule)
AIPM_LIFECYCLE_FEATURE_DELETEAFTERMERGE
AIPM_LIFECYCLE_FEATURE_DAYSTOKEEP
...

# Memory
AIPM_MEMORY_ENTITYPREFIX
AIPM_MEMORY_CATEGORIES  # Array as string

# Workflows
AIPM_WORKFLOWS_BRANCHCREATION_STARTBEHAVIOR
AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART
...

# And so on for EVERY field
```

## 🔒 Critical Rules

1. **NO External Dependencies**: Only shell-formatting.sh
2. **NO Logic**: Just load and export
3. **NO Decisions**: Other scripts make decisions
4. **Everything Exported**: Every field becomes a variable
5. **Strongly Typed**: Consistent string representations
6. **Prefix Everything**: AIPM_ prefix prevents conflicts
7. **Upper Case Exports**: Standard shell convention

## 📈 Success Metrics

1. **Complete Coverage**: Every field in opinions.yaml has an export
2. **Type Safety**: All exports have predictable types
3. **Fast Loading**: < 100ms to load and export
4. **Zero Dependencies**: Only shell-formatting.sh
5. **Clean API**: Simple lookup functions
6. **Testable**: Every export can be verified

## 🚀 Implementation Order

1. Create basic file structure
2. Implement YAML parser functions
3. Add workspace and branching exports
4. Add naming and lifecycle exports
5. Add remaining section exports
6. Create lookup functions
7. Add validation and computed values
8. Write comprehensive tests
9. Document all exports

This creates a **pure transformation layer** that other scripts can rely on completely.