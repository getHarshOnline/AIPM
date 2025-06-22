#!/opt/homebrew/bin/bash
#
# opinions-loader.sh - Transform opinions.yaml into strongly-typed shell exports
#
# SINGLE RESPONSIBILITY: Validate, Load and Export ONLY
# Pure transformation layer with validation and defaults
#
# Every value in opinions.yaml becomes an exported variable following pattern:
# AIPM_<SECTION>_<SUBSECTION>_<FIELD>
#
# Example:
#   workspace.type → AIPM_WORKSPACE_TYPE
#   branching.prefix → AIPM_BRANCHING_PREFIX
#   lifecycle.feature.deleteAfterMerge → AIPM_LIFECYCLE_FEATURE_DELETEAFTERMERGE
#
# Usage modes:
#   source opinions-loader.sh && load_and_export_opinions                  # Normal
#   source opinions-loader.sh && load_and_export_opinions --defaults-only  # Defaults only
#   source opinions-loader.sh && load_and_export_opinions --show-defaults  # Show defaults
#   source opinions-loader.sh && load_and_export_opinions --generate-template # Generate template
#
# Dependencies: yq (for YAML parsing), shell-formatting.sh (for output)

# Source only shell-formatting for output functions
OPINIONS_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$OPINIONS_LOADER_DIR/shell-formatting.sh"

# Global state
declare -g OPINIONS_YAML_CONTENT=""
declare -g OPINIONS_FILE_PATH=""
declare -g OPINIONS_LOADED="false"
declare -g OPINIONS_MODE="normal"  # normal | defaults-only | show-defaults | generate-template

# ============================================================================
# DEFAULT VALUES SYSTEM - Extracted from opinions.yaml documentation
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
    export AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION="interactive"  # Default: "interactive"
    export AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE="false"  # Default: false
    export AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY="true"  # Default: true
    export AIPM_LIFECYCLE_FEATURE_DELETEAFTERMERGE="false"  # Default: false
    export AIPM_LIFECYCLE_FEATURE_DAYSTOKEEP="30"  # Default: 30
    export AIPM_LIFECYCLE_SESSION_DELETEAFTERMERGE="true"  # Default: true
    export AIPM_LIFECYCLE_SESSION_DAYSTOKEEP="7"  # Default: 7
    export AIPM_LIFECYCLE_SESSION_MAXSESSIONS="5"  # Default: 5
    export AIPM_LIFECYCLE_TEST_DELETEAFTERMERGE="true"  # Default: true
    export AIPM_LIFECYCLE_TEST_DAYSTOKEEP="14"  # Default: 14
    export AIPM_LIFECYCLE_RELEASE_DELETEAFTERMERGE="false"  # Default: false
    export AIPM_LIFECYCLE_RELEASE_DAYSTOKEEP="never"  # Default: "never"
    export AIPM_LIFECYCLE_FRAMEWORK_DELETEAFTERMERGE="false"  # Default: false
    export AIPM_LIFECYCLE_FRAMEWORK_DAYSTOKEEP="90"  # Default: 90
    export AIPM_LIFECYCLE_REFACTOR_DELETEAFTERMERGE="true"  # Default: true
    export AIPM_LIFECYCLE_REFACTOR_DAYSTOKEEP="30"  # Default: 30
    export AIPM_LIFECYCLE_DOCS_DELETEAFTERMERGE="true"  # Default: true
    export AIPM_LIFECYCLE_DOCS_DAYSTOKEEP="60"  # Default: 60
    export AIPM_LIFECYCLE_CHORE_DELETEAFTERMERGE="true"  # Default: true
    export AIPM_LIFECYCLE_CHORE_DAYSTOKEEP="7"  # Default: 7
    export AIPM_LIFECYCLE_BUGFIX_DELETEAFTERMERGE="true"  # Default: true
    export AIPM_LIFECYCLE_BUGFIX_DAYSTOKEEP="14"  # Default: 14
    
    # Memory defaults
    export AIPM_MEMORY_CATEGORYRULES_STRICT="true"  # Default: true
    export AIPM_MEMORY_CATEGORYRULES_ALLOWDYNAMIC="false"  # Default: false
    export AIPM_MEMORY_CATEGORYRULES_UNCATEGORIZED="warn"  # Default: "warn"
    export AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE="true"  # Default: true
    
    # Team defaults
    export AIPM_TEAM_SYNCMODE="prompt"  # Default: "prompt"
    export AIPM_TEAM_FETCHONSTART="true"  # Default: true
    export AIPM_TEAM_WARNONDIVERGENCE="true"  # Default: true
    export AIPM_TEAM_REQUIREPULLREQUEST="false"  # Default: false
    export AIPM_TEAM_SYNC_PROMPT_TIMEOUT="30"  # Default: 30
    export AIPM_TEAM_SYNC_PROMPT_DEFAULT="fetch"  # Default: "fetch"
    export AIPM_TEAM_SYNC_DIVERGENCE_RESOLUTION="prompt"  # Default: "prompt"
    export AIPM_TEAM_SYNC_DIVERGENCE_SHOWDIFF="true"  # Default: true
    export AIPM_TEAM_SYNC_CONFLICTS_STRATEGY="manual"  # Default: "manual"
    export AIPM_TEAM_SYNC_CONFLICTS_BACKUP="true"  # Default: true
    export AIPM_TEAM_SYNC_CONFLICTS_ABORTONFAIL="false"  # Default: false
    
    # Sessions defaults
    export AIPM_SESSIONS_ENABLED="true"  # Default: true
    export AIPM_SESSIONS_AUTOCREATE="true"  # Default: true
    export AIPM_SESSIONS_AUTOMERGE="false"  # Default: false
    export AIPM_SESSIONS_ALLOWMULTIPLE="false"  # Default: false
    export AIPM_SESSIONS_PROMPTONCONFLICT="true"  # Default: true
    export AIPM_SESSIONS_CLEANUPONMERGE="true"  # Default: true
    
    # Validation defaults
    export AIPM_VALIDATION_MODE="strict"  # Default: "strict"
    export AIPM_VALIDATION_RULES_ENFORCENAMING="true"  # Default: true
    export AIPM_VALIDATION_RULES_BLOCKWRONGPREFIX="true"  # Default: true
    export AIPM_VALIDATION_RULES_REQUIRECLEANTREE="true"  # Default: true
    export AIPM_VALIDATION_RULES_VALIDATEMEMORY="true"  # Default: true
    export AIPM_VALIDATION_BLOCKERS_WRONGWORKSPACE="true"  # Default: true
    export AIPM_VALIDATION_BLOCKERS_INVALIDPREFIX="true"  # Default: true
    export AIPM_VALIDATION_BLOCKERS_CORRUPTMEMORY="true"  # Default: true
    
    # Initialization defaults
    export AIPM_INITIALIZATION_MARKER_TYPE="commit"  # Default: "commit"
    export AIPM_INITIALIZATION_MARKER_INCLUDEMETADATA="true"  # Default: true
    export AIPM_INITIALIZATION_MARKER_VERIFYONSTART="true"  # Default: true
    export AIPM_INITIALIZATION_BRANCHCREATION_REQUIRECLEAN="true"  # Default: true
    export AIPM_INITIALIZATION_BRANCHCREATION_BACKUPORIGINAL="true"  # Default: true
    export AIPM_INITIALIZATION_BRANCHCREATION_SHOWDIFF="true"  # Default: true
    export AIPM_INITIALIZATION_MAIN_SUFFIX="MAIN"  # Default: "MAIN"
    export AIPM_INITIALIZATION_MAIN_FROMCOMMIT="HEAD"  # Default: "HEAD"
    
    # Defaults defaults (meta!)
    export AIPM_DEFAULTS_TIMEOUTS_SESSIONSECONDS="3600"  # Default: 3600
    export AIPM_DEFAULTS_TIMEOUTS_OPERATIONSECONDS="30"  # Default: 30
    export AIPM_DEFAULTS_TIMEOUTS_GITSECONDS="120"  # Default: 120
    export AIPM_DEFAULTS_TIMEOUTS_PROMPTSECONDS="30"  # Default: 30
    export AIPM_DEFAULTS_LIMITS_MEMORYSIZE="10MB"  # Default: "10MB"
    export AIPM_DEFAULTS_LIMITS_BACKUPCOUNT="10"  # Default: 10
    export AIPM_DEFAULTS_LIMITS_SESSIONHISTORYDAYS="30"  # Default: 30
    export AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS="90"  # Default: 90
    export AIPM_DEFAULTS_LOGGING_LEVEL="info"  # Default: "info"
    export AIPM_DEFAULTS_LOGGING_LOCATION=".aipm/logs"  # Default: ".aipm/logs"
    export AIPM_DEFAULTS_LOGGING_ROTATE="true"  # Default: true
    export AIPM_DEFAULTS_LOGGING_RETAIN="7"  # Default: 7
    
    # Workflows defaults
    export AIPM_WORKFLOWS_BRANCHCREATION_STARTBEHAVIOR="prompt"  # Default: "prompt"
    export AIPM_WORKFLOWS_BRANCHCREATION_PROTECTIONRESPONSE="warn"  # Default: "warn"
    export AIPM_WORKFLOWS_BRANCHCREATION_AUTONAME="false"  # Default: false
    export AIPM_WORKFLOWS_BRANCHCREATION_DUPLICATESTRATEGY="suffix"  # Default: "suffix"
    export AIPM_WORKFLOWS_MERGETRIGGERS_FEATURECOMPLETE="manual"  # Default: "manual"
    export AIPM_WORKFLOWS_MERGETRIGGERS_CONFLICTHANDLING="prompt"  # Default: "prompt"
    export AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART="prompt"  # Default: "prompt"
    export AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP="prompt"  # Default: "prompt"
    export AIPM_WORKFLOWS_SYNCHRONIZATION_AUTOBACKUP="true"  # Default: true
    export AIPM_WORKFLOWS_CLEANUP_AFTERMERGE="prompt"  # Default: "prompt"
    export AIPM_WORKFLOWS_CLEANUP_STALEHANDLING="notify"  # Default: "notify"
    export AIPM_WORKFLOWS_CLEANUP_FAILEDWORK="archive"  # Default: "archive"
    export AIPM_WORKFLOWS_BRANCHFLOW_SOURCES_DEFAULT="{mainBranch}"  # Default: "{mainBranch}"
    export AIPM_WORKFLOWS_BRANCHFLOW_TARGETS_DEFAULT="{mainBranch}"  # Default: "{mainBranch}"
    export AIPM_WORKFLOWS_BRANCHFLOW_PARENTTRACKING="true"  # Default: true
    
    # Error handling defaults
    export AIPM_ERRORHANDLING_ONMISSINGBRANCHTYPE="use-feature"  # Default: "use-feature"
    export AIPM_ERRORHANDLING_ONINVALIDREFERENCE="fail"  # Default: "fail"
    export AIPM_ERRORHANDLING_ONCIRCULARREFERENCE="fail"  # Default: "fail"
    export AIPM_ERRORHANDLING_RECOVERY_AUTORECOVER="true"  # Default: true
    export AIPM_ERRORHANDLING_RECOVERY_CREATEBACKUP="true"  # Default: true
    export AIPM_ERRORHANDLING_RECOVERY_NOTIFYUSER="true"  # Default: true
    
    # Settings defaults
    export AIPM_SETTINGS_WORKFLOW_REQUIRETESTS="false"  # Default: false
    export AIPM_SETTINGS_WORKFLOW_REQUIREDOCS="false"  # Default: false
    export AIPM_SETTINGS_WORKFLOW_REQUIREREVIEW="false"  # Default: false
}

# Show all defaults (for --show-defaults mode)
show_defaults() {
    info "AIPM Default Values:"
    info "==================="
    
    # Initialize defaults to get values
    init_defaults
    
    # Dynamically show all exported AIPM_ variables grouped by section
    local current_section=""
    local section_map=(
        "LOADING:Loading Configuration"
        "WORKSPACE:Workspace Settings"
        "BRANCHING:Branching Rules"
        "NAMING:Naming Patterns"
        "LIFECYCLE:Lifecycle Management"
        "MEMORY:Memory Configuration"
        "TEAM:Team Collaboration"
        "SESSIONS:Session Management"
        "VALIDATION:Validation Rules"
        "INITIALIZATION:Initialization Settings"
        "DEFAULTS:Default Values"
        "WORKFLOWS:Workflow Automation"
        "ERRORHANDLING:Error Handling"
        "SETTINGS:Framework Settings"
        "METADATA:Metadata"
        "COMPUTED:Computed Values"
    )
    
    # Get all AIPM_ variables and sort them
    while IFS='=' read -r name value; do
        # Extract section from variable name (AIPM_SECTION_...)
        local var_section=$(printf "%s" "$name" | cut -d'_' -f2)
        
        # Find section title
        local section_title=""
        for mapping in "${section_map[@]}"; do
            local key="${mapping%%:*}"
            local title="${mapping#*:}"
            if [[ "$var_section" == "$key" ]]; then
                section_title="$title"
                break
            fi
        done
        
        # Print section header if changed
        if [[ "$var_section" != "$current_section" ]] && [[ -n "$section_title" ]]; then
            printf "\n%s:\n" "$section_title"
            current_section="$var_section"
        fi
        
        # Print the variable (indent sub-values)
        if [[ "$name" =~ ^AIPM_[^_]+_[^_]+_ ]]; then
            printf "    %s=%s\n" "$name" "$value"
        else
            printf "  %s=%s\n" "$name" "$value"
        fi
    done < <(compgen -A export | grep '^AIPM_' | while read var; do printf "%s=%s\n" "$var" "${!var}"; done | sort)
}

# Generate template with defaults (for --generate-template mode)
generate_template_with_defaults() {
    # Initialize defaults to get values
    init_defaults
    
    # Generate YAML dynamically from exported variables
    cat << EOF
# AIPM Opinions Configuration Template
# ====================================
# Generated dynamically from default values
# Customize for your workspace

loading:
  discovery:
    path: "./.aipm/opinions.yaml"  # REQUIRED
  
  validation:
    required: ["workspace", "branching", "memory", "lifecycle", "workflows"]  # REQUIRED
    recommended: ${AIPM_LOADING_VALIDATION_RECOMMENDED:-[]}  # Default: []
    strictMode: ${AIPM_LOADING_VALIDATION_STRICTMODE}  # Default: true
    hashCheck: ${AIPM_LOADING_VALIDATION_HASHCHECK}  # Default: true
    schemaVersion: "${AIPM_LOADING_VALIDATION_SCHEMAVERSION}"  # Default: "1.0"
    onError: "${AIPM_LOADING_VALIDATION_ONERROR}"  # Default: "fail"

  context:
    detectBy: "workspace.name"  # REQUIRED
    validatePrefix: ${AIPM_LOADING_CONTEXT_VALIDATEPREFIX}  # Default: true
    enforceIsolation: ${AIPM_LOADING_CONTEXT_ENFORCEISOLATION}  # Default: true

  inheritance:
    enabled: ${AIPM_LOADING_INHERITANCE_ENABLED}  # Default: false

workspace:
  type: "framework"  # REQUIRED: framework | project
  name: "AIPM"  # REQUIRED: Must match prefix pattern
  description: "AI Project Manager Framework"  # REQUIRED

branching:
  prefix: "AIPM_"  # REQUIRED: Must match entityPrefix
  mainBranchSuffix: "${AIPM_INITIALIZATION_MAIN_SUFFIX}"  # REQUIRED
  
  protectedBranches:
    userBranches: []  # REQUIRED
    aipmBranchSuffixes: []  # REQUIRED

naming:
  feature: "feature/{description}"  # REQUIRED
  bugfix: "bugfix/{issue-id}-{description}"  # REQUIRED
  test: "test/{scope}"  # REQUIRED
  session: "{naming.feature}"  # REQUIRED
  release: "release/{version}"  # REQUIRED
  framework: "framework/{component}"  # REQUIRED
  refactor: "refactor/{scope}"  # REQUIRED
  docs: "docs/{scope}"  # REQUIRED
  chore: "chore/{task}"  # REQUIRED

lifecycle:
  global:
    handleUncommitted: "${AIPM_LIFECYCLE_GLOBAL_HANDLEUNCOMMITTED}"  # Default: "stash"
    conflictResolution: "${AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION}"  # Default: "interactive"
    allowOverride: ${AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE}  # Default: false
    trackActivity: ${AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY}  # Default: true
  
  feature:
    deleteAfterMerge: ${AIPM_LIFECYCLE_FEATURE_DELETEAFTERMERGE}  # Default: false
    daysToKeep: ${AIPM_LIFECYCLE_FEATURE_DAYSTOKEEP}  # Default: 30
  
  session:
    deleteAfterMerge: ${AIPM_LIFECYCLE_SESSION_DELETEAFTERMERGE}  # Default: true
    daysToKeep: ${AIPM_LIFECYCLE_SESSION_DAYSTOKEEP}  # Default: 7
    maxSessions: ${AIPM_LIFECYCLE_SESSION_MAXSESSIONS}  # Default: 5
  
  test:
    deleteAfterMerge: ${AIPM_LIFECYCLE_TEST_DELETEAFTERMERGE}  # Default: true
    daysToKeep: ${AIPM_LIFECYCLE_TEST_DAYSTOKEEP}  # Default: 14
  
  release:
    deleteAfterMerge: ${AIPM_LIFECYCLE_RELEASE_DELETEAFTERMERGE}  # Default: false
    daysToKeep: "${AIPM_LIFECYCLE_RELEASE_DAYSTOKEEP}"  # Default: "never"
  
  framework:
    deleteAfterMerge: ${AIPM_LIFECYCLE_FRAMEWORK_DELETEAFTERMERGE}  # Default: false
    daysToKeep: ${AIPM_LIFECYCLE_FRAMEWORK_DAYSTOKEEP}  # Default: 90
  
  refactor:
    deleteAfterMerge: ${AIPM_LIFECYCLE_REFACTOR_DELETEAFTERMERGE}  # Default: true
    daysToKeep: ${AIPM_LIFECYCLE_REFACTOR_DAYSTOKEEP}  # Default: 30
  
  docs:
    deleteAfterMerge: ${AIPM_LIFECYCLE_DOCS_DELETEAFTERMERGE}  # Default: true
    daysToKeep: ${AIPM_LIFECYCLE_DOCS_DAYSTOKEEP}  # Default: 60
  
  chore:
    deleteAfterMerge: ${AIPM_LIFECYCLE_CHORE_DELETEAFTERMERGE}  # Default: true
    daysToKeep: ${AIPM_LIFECYCLE_CHORE_DAYSTOKEEP}  # Default: 7
  
  bugfix:
    deleteAfterMerge: ${AIPM_LIFECYCLE_BUGFIX_DELETEAFTERMERGE}  # Default: true
    daysToKeep: ${AIPM_LIFECYCLE_BUGFIX_DAYSTOKEEP}  # Default: 14

memory:
  entityPrefix: "AIPM_"  # REQUIRED: Must match branching.prefix
  categories: ["CONTEXT", "DECISION", "LEARNING", "TASK", "REVIEW"]  # REQUIRED
  
  categoryRules:
    strict: ${AIPM_MEMORY_CATEGORYRULES_STRICT}  # Default: true
    allowDynamic: ${AIPM_MEMORY_CATEGORYRULES_ALLOWDYNAMIC}  # Default: false
    uncategorized: "${AIPM_MEMORY_CATEGORYRULES_UNCATEGORIZED}"  # Default: "warn"
    caseInsensitive: ${AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE}  # Default: true

team:
  syncMode: "${AIPM_TEAM_SYNCMODE}"  # Default: "prompt"
  fetchOnStart: ${AIPM_TEAM_FETCHONSTART}  # Default: true
  warnOnDivergence: ${AIPM_TEAM_WARNONDIVERGENCE}  # Default: true
  requirePullRequest: ${AIPM_TEAM_REQUIREPULLREQUEST}  # Default: false
  
  sync:
    prompt:
      timeout: ${AIPM_TEAM_SYNC_PROMPT_TIMEOUT}  # Default: 30
      default: "${AIPM_TEAM_SYNC_PROMPT_DEFAULT}"  # Default: "fetch"
    
    divergence:
      resolution: "${AIPM_TEAM_SYNC_DIVERGENCE_RESOLUTION}"  # Default: "prompt"
      showDiff: ${AIPM_TEAM_SYNC_DIVERGENCE_SHOWDIFF}  # Default: true
    
    conflicts:
      strategy: "${AIPM_TEAM_SYNC_CONFLICTS_STRATEGY}"  # Default: "manual"
      backup: ${AIPM_TEAM_SYNC_CONFLICTS_BACKUP}  # Default: true
      abortOnFail: ${AIPM_TEAM_SYNC_CONFLICTS_ABORTONFAIL}  # Default: false

sessions:
  enabled: ${AIPM_SESSIONS_ENABLED}  # Default: true
  autoCreate: ${AIPM_SESSIONS_AUTOCREATE}  # Default: true
  autoMerge: ${AIPM_SESSIONS_AUTOMERGE}  # Default: false
  allowMultiple: ${AIPM_SESSIONS_ALLOWMULTIPLE}  # Default: false
  namePattern: "${AIPM_SESSIONS_NAMEPATTERN}"  # Default: "{naming.session}"
  promptOnConflict: ${AIPM_SESSIONS_PROMPTONCONFLICT}  # Default: true
  cleanupOnMerge: ${AIPM_SESSIONS_CLEANUPONMERGE}  # Default: true

validation:
  mode: "${AIPM_VALIDATION_MODE}"  # Default: "strict"
  
  rules:
    enforceNaming: ${AIPM_VALIDATION_RULES_ENFORCENAMING}  # Default: true
    blockWrongPrefix: ${AIPM_VALIDATION_RULES_BLOCKWRONGPREFIX}  # Default: true
    requireCleanTree: ${AIPM_VALIDATION_RULES_REQUIRECLEANTREE}  # Default: true
    validateMemory: ${AIPM_VALIDATION_RULES_VALIDATEMEMORY}  # Default: true
  
  blockers:
    wrongWorkspace: ${AIPM_VALIDATION_BLOCKERS_WRONGWORKSPACE}  # Default: true
    invalidPrefix: ${AIPM_VALIDATION_BLOCKERS_INVALIDPREFIX}  # Default: true
    corruptMemory: ${AIPM_VALIDATION_BLOCKERS_CORRUPTMEMORY}  # Default: true

initialization:
  marker:
    type: "${AIPM_INITIALIZATION_MARKER_TYPE}"  # Default: "commit"
    message: "${AIPM_INITIALIZATION_MARKER_MESSAGE}"  # Default: "AIPM_INIT_HERE"
    includeMetadata: ${AIPM_INITIALIZATION_MARKER_INCLUDEMETADATA}  # Default: true
    verifyOnStart: ${AIPM_INITIALIZATION_MARKER_VERIFYONSTART}  # Default: true
  
  branchCreation:
    requireClean: ${AIPM_INITIALIZATION_BRANCHCREATION_REQUIRECLEAN}  # Default: true
    backupOriginal: ${AIPM_INITIALIZATION_BRANCHCREATION_BACKUPORIGINAL}  # Default: true
    showDiff: ${AIPM_INITIALIZATION_BRANCHCREATION_SHOWDIFF}  # Default: true

defaults:
  timeouts:
    sessionSeconds: ${AIPM_DEFAULTS_TIMEOUTS_SESSIONSECONDS}  # Default: 3600
    operationSeconds: ${AIPM_DEFAULTS_TIMEOUTS_OPERATIONSECONDS}  # Default: 30
    gitSeconds: ${AIPM_DEFAULTS_TIMEOUTS_GITSECONDS}  # Default: 120
    promptSeconds: ${AIPM_DEFAULTS_TIMEOUTS_PROMPTSECONDS}  # Default: 30
  
  limits:
    memorySize: "${AIPM_DEFAULTS_LIMITS_MEMORYSIZE}"  # Default: "10MB"
    backupCount: ${AIPM_DEFAULTS_LIMITS_BACKUPCOUNT}  # Default: 10
    sessionHistoryDays: ${AIPM_DEFAULTS_LIMITS_SESSIONHISTORYDAYS}  # Default: 30
    branchAgeDays: ${AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS}  # Default: 90
  
  logging:
    level: "${AIPM_DEFAULTS_LOGGING_LEVEL}"  # Default: "info"
    location: "${AIPM_DEFAULTS_LOGGING_LOCATION}"  # Default: ".aipm/logs"
    rotate: ${AIPM_DEFAULTS_LOGGING_ROTATE}  # Default: true
    retain: ${AIPM_DEFAULTS_LOGGING_RETAIN}  # Default: 7

workflows:
  branchCreation:
    startBehavior: "${AIPM_WORKFLOWS_BRANCHCREATION_STARTBEHAVIOR}"  # Default: "prompt"
    protectionResponse: "${AIPM_WORKFLOWS_BRANCHCREATION_PROTECTIONRESPONSE}"  # Default: "warn"
    autoName: ${AIPM_WORKFLOWS_BRANCHCREATION_AUTONAME}  # Default: false
    duplicateStrategy: "${AIPM_WORKFLOWS_BRANCHCREATION_DUPLICATESTRATEGY}"  # Default: "suffix"
  
  mergeTriggers:
    featureComplete: "${AIPM_WORKFLOWS_MERGETRIGGERS_FEATURECOMPLETE}"  # Default: "manual"
    conflictHandling: "${AIPM_WORKFLOWS_MERGETRIGGERS_CONFLICTHANDLING}"  # Default: "prompt"
  
  synchronization:
    pullOnStart: "${AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART}"  # Default: "prompt"
    pushOnStop: "${AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP}"  # Default: "prompt"
    autoBackup: ${AIPM_WORKFLOWS_SYNCHRONIZATION_AUTOBACKUP}  # Default: true
  
  cleanup:
    afterMerge: "${AIPM_WORKFLOWS_CLEANUP_AFTERMERGE}"  # Default: "prompt"
    staleHandling: "${AIPM_WORKFLOWS_CLEANUP_STALEHANDLING}"  # Default: "notify"
    failedWork: "${AIPM_WORKFLOWS_CLEANUP_FAILEDWORK}"  # Default: "archive"
  
  branchFlow:
    sources:
      default: "${AIPM_WORKFLOWS_BRANCHFLOW_SOURCES_DEFAULT}"  # Default: "{mainBranch}"
    targets:
      default: "${AIPM_WORKFLOWS_BRANCHFLOW_TARGETS_DEFAULT}"  # Default: "{mainBranch}"
    parentTracking: ${AIPM_WORKFLOWS_BRANCHFLOW_PARENTTRACKING}  # Default: true

errorHandling:
  onMissingBranchType: "${AIPM_ERRORHANDLING_ONMISSINGBRANCHTYPE}"  # Default: "use-feature"
  onInvalidReference: "${AIPM_ERRORHANDLING_ONINVALIDREFERENCE}"  # Default: "fail"
  onCircularReference: "${AIPM_ERRORHANDLING_ONCIRCULARREFERENCE}"  # Default: "fail"
  
  recovery:
    autoRecover: ${AIPM_ERRORHANDLING_RECOVERY_AUTORECOVER}  # Default: true
    createBackup: ${AIPM_ERRORHANDLING_RECOVERY_CREATEBACKUP}  # Default: true
    notifyUser: ${AIPM_ERRORHANDLING_RECOVERY_NOTIFYUSER}  # Default: true

settings:
  schemaVersion: "${AIPM_SETTINGS_SCHEMAVERSION}"  # Default: "1.0"
  
  frameworkPaths:
    modules: "${AIPM_SETTINGS_FRAMEWORKPATHS_MODULES}"  # Default: ".aipm/scripts/modules"
    tests: "${AIPM_SETTINGS_FRAMEWORKPATHS_TESTS}"  # Default: ".aipm/scripts/test"
    docs: "${AIPM_SETTINGS_FRAMEWORKPATHS_DOCS}"  # Default: "AIPM_Design_Docs"
    templates: "${AIPM_SETTINGS_FRAMEWORKPATHS_TEMPLATES}"  # Default: ".aipm/templates"
  
  workflow:
    requireTests: ${AIPM_SETTINGS_WORKFLOW_REQUIRETESTS}  # Default: false
    requireDocs: ${AIPM_SETTINGS_WORKFLOW_REQUIREDOCS}  # Default: false
    requireReview: ${AIPM_SETTINGS_WORKFLOW_REQUIREREVIEW}  # Default: false

metadata:
  version: "${AIPM_METADATA_VERSION}"  # Default: "1.0.0"
  schema: "${AIPM_METADATA_SCHEMA}"  # Default: "1.0"
  lastModified: "${AIPM_METADATA_LASTMODIFIED}"  # Default: auto-generated
  compatibility: "${AIPM_METADATA_COMPATIBILITY}"  # Default: "^1.0.0"
EOF
}

# ============================================================================
# YAML PARSING WITH YQ
# ============================================================================

# Check for yq dependency
check_yq_installed() {
    if ! command -v yq &> /dev/null; then
        die "yq is required but not installed. Install with: brew install yq (macOS) or see https://github.com/mikefarah/yq"
    fi
    
    # Verify yq version (we need v4+)
    local yq_version=$(yq --version 2>/dev/null | grep -oE 'version [0-9]+' | awk '{print $2}')
    if [[ -z "$yq_version" ]] || [[ "$yq_version" -lt 4 ]]; then
        warn "yq version 4+ recommended for best performance"
    fi
}

# Extract value using yq
extract_yaml_value() {
    local path="$1"
    local yaml_file="${2:-$OPINIONS_FILE_PATH}"
    
    # If in defaults-only mode, return empty
    if [[ "$OPINIONS_MODE" == "defaults-only" ]]; then
        printf ""
        return 0
    fi
    
    # Convert dot notation to yq syntax (.path)
    local yq_path=".$path"
    
    # Use yq to extract value
    local value=$(yq eval "$yq_path // \"\"" "$yaml_file" 2>/dev/null)
    
    # Handle null/empty values
    if [[ "$value" == "null" ]] || [[ -z "$value" ]]; then
        printf ""
    else
        printf "%s" "$value"
    fi
}

# Extract array using yq
extract_yaml_array() {
    local path="$1"
    local yaml_file="${2:-$OPINIONS_FILE_PATH}"
    
    # If in defaults-only mode, return empty
    if [[ "$OPINIONS_MODE" == "defaults-only" ]]; then
        printf ""
        return 0
    fi
    
    # Convert dot notation to yq syntax
    local yq_path=".$path"
    
    # Use yq to extract array as space-separated string
    local array=$(yq eval "$yq_path | @csv" "$yaml_file" 2>/dev/null | tr ',' ' ' | tr -d '"')
    
    # Handle null/empty arrays
    if [[ "$array" == "null" ]] || [[ -z "$array" ]]; then
        printf ""
    else
        printf "%s" "$array"
    fi
}

# ============================================================================
# VALIDATION FUNCTIONS - Enforce rules from opinions.yaml
# ============================================================================

# Validate required sections exist
validate_required_sections() {
    local yaml_file="$1"
    local required_sections=$(yq eval '.loading.validation.required[]' "$yaml_file" 2>/dev/null)
    
    if [[ -z "$required_sections" ]]; then
        error "No required sections defined in loading.validation.required"
        return 1
    fi
    
    local missing_sections=()
    while IFS= read -r section; do
        if [[ -n "$section" ]]; then
            local exists=$(yq eval ".$section // \"\"" "$yaml_file" 2>/dev/null)
            if [[ -z "$exists" ]] || [[ "$exists" == "null" ]]; then
                missing_sections+=("$section")
            fi
        fi
    done <<< "$required_sections"
    
    if [[ ${#missing_sections[@]} -gt 0 ]]; then
        error "Missing required sections: ${missing_sections[*]}"
        return 1
    fi
    
    return 0
}

# Validate enum values
validate_enum() {
    local value="$1"
    local field="$2"
    shift 2
    local valid_values=("$@")
    
    if [[ -z "$value" ]]; then
        return 0  # Empty is ok for optional fields
    fi
    
    for valid in "${valid_values[@]}"; do
        if [[ "$value" == "$valid" ]]; then
            return 0
        fi
    done
    
    error "Invalid value '$value' for $field. Valid options: ${valid_values[*]}"
    return 1
}

# Validate prefix consistency
validate_prefix_consistency() {
    local yaml_file="$1"
    
    # Get the prefixes that must match
    local branching_prefix=$(yq eval '.branching.prefix // ""' "$yaml_file")
    local memory_prefix=$(yq eval '.memory.entityPrefix // ""' "$yaml_file")
    
    if [[ -n "$branching_prefix" ]] && [[ -n "$memory_prefix" ]]; then
        if [[ "$branching_prefix" != "$memory_prefix" ]]; then
            error "Prefix mismatch: branching.prefix ($branching_prefix) != memory.entityPrefix ($memory_prefix)"
            return 1
        fi
    fi
    
    # Validate prefix format
    local prefix_pattern="^[A-Z][A-Z0-9_]*_$"
    if [[ -n "$branching_prefix" ]] && ! [[ "$branching_prefix" =~ $prefix_pattern ]]; then
        error "Invalid prefix format: '$branching_prefix'. Must match pattern: $prefix_pattern"
        return 1
    fi
    
    return 0
}

# Validate branch types have lifecycle rules
validate_branch_lifecycle_consistency() {
    local yaml_file="$1"
    
    # Get all naming types
    local naming_types=$(yq eval '.naming | keys | .[]' "$yaml_file" 2>/dev/null)
    
    local missing_lifecycle=()
    while IFS= read -r type; do
        if [[ -n "$type" ]]; then
            local has_lifecycle=$(yq eval ".lifecycle.$type // \"\"" "$yaml_file")
            if [[ -z "$has_lifecycle" ]] || [[ "$has_lifecycle" == "null" ]]; then
                missing_lifecycle+=("$type")
            fi
        fi
    done <<< "$naming_types"
    
    if [[ ${#missing_lifecycle[@]} -gt 0 ]]; then
        warn "Branch types missing lifecycle rules: ${missing_lifecycle[*]}"
    fi
    
    return 0
}

# Main validation function
validate_opinions() {
    local yaml_file="$1"
    local strict_mode=$(yq eval '.loading.validation.strictMode // true' "$yaml_file")
    local on_error=$(yq eval '.loading.validation.onError // "fail"' "$yaml_file")
    
    info "Validating opinions.yaml..."
    
    local validation_failed=false
    
    # Check required sections
    if ! validate_required_sections "$yaml_file"; then
        validation_failed=true
    fi
    
    # Check prefix consistency
    if ! validate_prefix_consistency "$yaml_file"; then
        validation_failed=true
    fi
    
    # Check branch/lifecycle consistency
    if ! validate_branch_lifecycle_consistency "$yaml_file"; then
        validation_failed=true
    fi
    
    # Validate enum fields
    local workspace_type=$(yq eval '.workspace.type // ""' "$yaml_file")
    if ! validate_enum "$workspace_type" "workspace.type" "framework" "project"; then
        validation_failed=true
    fi
    
    local handle_uncommitted=$(yq eval '.lifecycle.global.handleUncommitted // ""' "$yaml_file")
    if ! validate_enum "$handle_uncommitted" "lifecycle.global.handleUncommitted" "stash" "commit" "fail"; then
        validation_failed=true
    fi
    
    # Handle validation result based on onError setting
    if [[ "$validation_failed" == "true" ]]; then
        case "$on_error" in
            "fail")
                die "Validation failed. Fix errors in opinions.yaml"
                ;;
            "warn")
                warn "Validation warnings found. Continuing..."
                ;;
            "use-defaults")
                warn "Validation failed. Using defaults only."
                OPINIONS_MODE="defaults-only"
                ;;
        esac
    else
        success "Validation passed"
    fi
    
    return 0
}

# Load the YAML file
load_opinions_file() {
    local yaml_path="${1:-./.aipm/opinions.yaml}"
    
    # Check yq is installed
    check_yq_installed
    
    if [[ ! -f "$yaml_path" ]]; then
        if [[ "$OPINIONS_MODE" == "defaults-only" ]]; then
            warn "opinions.yaml not found. Using defaults only."
            return 0
        else
            die "opinions.yaml not found at: $yaml_path"
        fi
    fi
    
    OPINIONS_FILE_PATH="$yaml_path"
    
    # Validate the file
    if [[ "$OPINIONS_MODE" != "defaults-only" ]]; then
        validate_opinions "$yaml_path"
    fi
    
    OPINIONS_LOADED="true"
}

# ============================================================================
# EXPORT FUNCTIONS - Transform YAML sections to shell exports
# ============================================================================

# Export workspace section
export_workspace_section() {
    local type=$(extract_yaml_value "workspace.type")
    local name=$(extract_yaml_value "workspace.name")
    local description=$(extract_yaml_value "workspace.description")
    
    # Use value or default
    export AIPM_WORKSPACE_TYPE="${type:-framework}"
    export AIPM_WORKSPACE_NAME="${name:-AIPM}"
    export AIPM_WORKSPACE_DESCRIPTION="${description:-AI Project Manager}"
}

# Export branching section
export_branching_section() {
    local prefix=$(extract_yaml_value "branching.prefix")
    local suffix=$(extract_yaml_value "branching.mainBranchSuffix")
    
    # Required fields - use workspace name for prefix if not set
    local workspace_name="${AIPM_WORKSPACE_NAME:-AIPM}"
    export AIPM_BRANCHING_PREFIX="${prefix:-${workspace_name}_}"
    export AIPM_BRANCHING_MAINBRANCHSUFFIX="${suffix:-MAIN}"
    
    # Computed value - the full main branch name
    export AIPM_BRANCHING_MAINBRANCH="${AIPM_BRANCHING_PREFIX}${AIPM_BRANCHING_MAINBRANCHSUFFIX}"
    
    # Protected branches
    local user_branches=$(extract_yaml_array "branching.protectedBranches.userBranches")
    export AIPM_BRANCHING_PROTECTEDBRANCHES_USER="${user_branches}"
    
    local aipm_suffixes=$(extract_yaml_array "branching.protectedBranches.aipmBranchSuffixes")
    export AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM="${aipm_suffixes}"
}

# Export naming patterns
export_naming_section() {
    # Define defaults for each type
    local defaults=(
        "feature:feature/{description}"
        "bugfix:bugfix/{issue-id}-{description}"
        "test:test/{scope}"
        "session:{naming.feature}"
        "release:release/{version}"
        "framework:framework/{component}"
        "refactor:refactor/{scope}"
        "docs:docs/{scope}"
        "chore:chore/{task}"
    )
    
    # Export each type with default fallback
    for default in "${defaults[@]}"; do
        local type="${default%%:*}"
        local default_pattern="${default#*:}"
        local pattern=$(extract_yaml_value "naming.$type")
        export "AIPM_NAMING_${type^^}"="${pattern:-$default_pattern}"
    done
}

# Export lifecycle rules
export_lifecycle_section() {
    # Global lifecycle settings with defaults
    local handle=$(extract_yaml_value "lifecycle.global.handleUncommitted")
    local conflict=$(extract_yaml_value "lifecycle.global.conflictResolution")
    local override=$(extract_yaml_value "lifecycle.global.allowOverride")
    local track=$(extract_yaml_value "lifecycle.global.trackActivity")
    
    export AIPM_LIFECYCLE_GLOBAL_HANDLEUNCOMMITTED="${handle:-stash}"
    export AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION="${conflict:-interactive}"
    export AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE="${override:-false}"
    export AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY="${track:-true}"
    
    # Per-type lifecycle rules with defaults
    local type_defaults=(
        "feature:false:30"
        "session:true:7"
        "test:true:14"
        "release:false:never"
        "framework:false:90"
        "refactor:true:30"
        "docs:true:60"
        "chore:true:7"
        "bugfix:true:14"
    )
    
    for default in "${type_defaults[@]}"; do
        IFS=':' read -r type default_delete default_days <<< "$default"
        
        local deleteAfterMerge=$(extract_yaml_value "lifecycle.$type.deleteAfterMerge")
        local daysToKeep=$(extract_yaml_value "lifecycle.$type.daysToKeep")
        
        export "AIPM_LIFECYCLE_${type^^}_DELETEAFTERMERGE"="${deleteAfterMerge:-$default_delete}"
        export "AIPM_LIFECYCLE_${type^^}_DAYSTOKEEP"="${daysToKeep:-$default_days}"
    done
    
    # Special case for session maxSessions
    local maxSessions=$(extract_yaml_value "lifecycle.session.maxSessions")
    export AIPM_LIFECYCLE_SESSION_MAXSESSIONS="${maxSessions:-5}"
}

# Export memory settings
export_memory_section() {
    local prefix=$(extract_yaml_value "memory.entityPrefix")
    local categories=$(extract_yaml_array "memory.categories")
    
    # Use branching prefix as default
    export AIPM_MEMORY_ENTITYPREFIX="${prefix:-${AIPM_BRANCHING_PREFIX}}"
    export AIPM_MEMORY_CATEGORIES="${categories:-CONTEXT DECISION LEARNING TASK REVIEW}"
    
    # Category rules with defaults
    local strict=$(extract_yaml_value "memory.categoryRules.strict")
    local dynamic=$(extract_yaml_value "memory.categoryRules.allowDynamic")
    local uncat=$(extract_yaml_value "memory.categoryRules.uncategorized")
    local case_insens=$(extract_yaml_value "memory.categoryRules.caseInsensitive")
    
    export AIPM_MEMORY_CATEGORYRULES_STRICT="${strict:-true}"
    export AIPM_MEMORY_CATEGORYRULES_ALLOWDYNAMIC="${dynamic:-false}"
    export AIPM_MEMORY_CATEGORYRULES_UNCATEGORIZED="${uncat:-warn}"
    export AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE="${case_insens:-true}"
}

# Export team settings
export_team_section() {
    local sync_mode=$(extract_yaml_value "team.syncMode")
    local fetch_start=$(extract_yaml_value "team.fetchOnStart")
    local warn_diverge=$(extract_yaml_value "team.warnOnDivergence")
    local require_pr=$(extract_yaml_value "team.requirePullRequest")
    
    export AIPM_TEAM_SYNCMODE="${sync_mode:-prompt}"
    export AIPM_TEAM_FETCHONSTART="${fetch_start:-true}"
    export AIPM_TEAM_WARNONDIVERGENCE="${warn_diverge:-true}"
    export AIPM_TEAM_REQUIREPULLREQUEST="${require_pr:-false}"
    
    # Sync details with defaults
    local timeout=$(extract_yaml_value "team.sync.prompt.timeout")
    local default_action=$(extract_yaml_value "team.sync.prompt.default")
    local diverge_res=$(extract_yaml_value "team.sync.divergence.resolution")
    local show_diff=$(extract_yaml_value "team.sync.divergence.showDiff")
    local conflict_strat=$(extract_yaml_value "team.sync.conflicts.strategy")
    local backup=$(extract_yaml_value "team.sync.conflicts.backup")
    local abort_fail=$(extract_yaml_value "team.sync.conflicts.abortOnFail")
    
    export AIPM_TEAM_SYNC_PROMPT_TIMEOUT="${timeout:-30}"
    export AIPM_TEAM_SYNC_PROMPT_DEFAULT="${default_action:-fetch}"
    export AIPM_TEAM_SYNC_DIVERGENCE_RESOLUTION="${diverge_res:-prompt}"
    export AIPM_TEAM_SYNC_DIVERGENCE_SHOWDIFF="${show_diff:-true}"
    export AIPM_TEAM_SYNC_CONFLICTS_STRATEGY="${conflict_strat:-manual}"
    export AIPM_TEAM_SYNC_CONFLICTS_BACKUP="${backup:-true}"
    export AIPM_TEAM_SYNC_CONFLICTS_ABORTONFAIL="${abort_fail:-false}"
}

# Export sessions settings
export_sessions_section() {
    local enabled=$(extract_yaml_value "sessions.enabled")
    local auto_create=$(extract_yaml_value "sessions.autoCreate")
    local auto_merge=$(extract_yaml_value "sessions.autoMerge")
    local allow_multi=$(extract_yaml_value "sessions.allowMultiple")
    local name_pattern=$(extract_yaml_value "sessions.namePattern")
    local prompt_conflict=$(extract_yaml_value "sessions.promptOnConflict")
    local cleanup_merge=$(extract_yaml_value "sessions.cleanupOnMerge")
    
    export AIPM_SESSIONS_ENABLED="${enabled:-true}"
    export AIPM_SESSIONS_AUTOCREATE="${auto_create:-true}"
    export AIPM_SESSIONS_AUTOMERGE="${auto_merge:-false}"
    export AIPM_SESSIONS_ALLOWMULTIPLE="${allow_multi:-false}"
    export AIPM_SESSIONS_NAMEPATTERN="${name_pattern:-{naming.session}}"
    export AIPM_SESSIONS_PROMPTONCONFLICT="${prompt_conflict:-true}"
    export AIPM_SESSIONS_CLEANUPONMERGE="${cleanup_merge:-true}"
}

# Export validation settings
export_validation_section() {
    local mode=$(extract_yaml_value "validation.mode")
    export AIPM_VALIDATION_MODE="${mode:-strict}"
    
    # Rules with defaults
    local enforce_naming=$(extract_yaml_value "validation.rules.enforceNaming")
    local block_prefix=$(extract_yaml_value "validation.rules.blockWrongPrefix")
    local clean_tree=$(extract_yaml_value "validation.rules.requireCleanTree")
    local validate_mem=$(extract_yaml_value "validation.rules.validateMemory")
    
    export AIPM_VALIDATION_RULES_ENFORCENAMING="${enforce_naming:-true}"
    export AIPM_VALIDATION_RULES_BLOCKWRONGPREFIX="${block_prefix:-true}"
    export AIPM_VALIDATION_RULES_REQUIRECLEANTREE="${clean_tree:-true}"
    export AIPM_VALIDATION_RULES_VALIDATEMEMORY="${validate_mem:-true}"
    
    # Blockers with defaults
    local wrong_ws=$(extract_yaml_value "validation.blockers.wrongWorkspace")
    local invalid_pref=$(extract_yaml_value "validation.blockers.invalidPrefix")
    local corrupt_mem=$(extract_yaml_value "validation.blockers.corruptMemory")
    
    export AIPM_VALIDATION_BLOCKERS_WRONGWORKSPACE="${wrong_ws:-true}"
    export AIPM_VALIDATION_BLOCKERS_INVALIDPREFIX="${invalid_pref:-true}"
    export AIPM_VALIDATION_BLOCKERS_CORRUPTMEMORY="${corrupt_mem:-true}"
}

# Export initialization settings
export_initialization_section() {
    # Marker settings with defaults
    local marker_type=$(extract_yaml_value "initialization.marker.type")
    local marker_msg=$(extract_yaml_value "initialization.marker.message")
    local include_meta=$(extract_yaml_value "initialization.marker.includeMetadata")
    local verify_start=$(extract_yaml_value "initialization.marker.verifyOnStart")
    
    export AIPM_INITIALIZATION_MARKER_TYPE="${marker_type:-commit}"
    export AIPM_INITIALIZATION_MARKER_MESSAGE="${marker_msg:-AIPM_INIT_HERE}"
    export AIPM_INITIALIZATION_MARKER_INCLUDEMETADATA="${include_meta:-true}"
    export AIPM_INITIALIZATION_MARKER_VERIFYONSTART="${verify_start:-true}"
    
    # Branch creation with defaults
    local require_clean=$(extract_yaml_value "initialization.branchCreation.requireClean")
    local backup_orig=$(extract_yaml_value "initialization.branchCreation.backupOriginal")
    local show_diff=$(extract_yaml_value "initialization.branchCreation.showDiff")
    
    export AIPM_INITIALIZATION_BRANCHCREATION_REQUIRECLEAN="${require_clean:-true}"
    export AIPM_INITIALIZATION_BRANCHCREATION_BACKUPORIGINAL="${backup_orig:-true}"
    export AIPM_INITIALIZATION_BRANCHCREATION_SHOWDIFF="${show_diff:-true}"
    
    # Main branch mapping with defaults
    local main_suffix=$(extract_yaml_value "branching.initialization.main.suffix")
    local from_commit=$(extract_yaml_value "branching.initialization.main.fromCommit")
    
    export AIPM_INITIALIZATION_MAIN_SUFFIX="${main_suffix:-MAIN}"
    export AIPM_INITIALIZATION_MAIN_FROMCOMMIT="${from_commit:-HEAD}"
}

# Export defaults section
export_defaults_section() {
    # Timeouts with defaults
    local session_sec=$(extract_yaml_value "defaults.timeouts.sessionSeconds")
    local op_sec=$(extract_yaml_value "defaults.timeouts.operationSeconds")
    local git_sec=$(extract_yaml_value "defaults.timeouts.gitSeconds")
    local prompt_sec=$(extract_yaml_value "defaults.timeouts.promptSeconds")
    
    export AIPM_DEFAULTS_TIMEOUTS_SESSIONSECONDS="${session_sec:-3600}"
    export AIPM_DEFAULTS_TIMEOUTS_OPERATIONSECONDS="${op_sec:-30}"
    export AIPM_DEFAULTS_TIMEOUTS_GITSECONDS="${git_sec:-120}"
    export AIPM_DEFAULTS_TIMEOUTS_PROMPTSECONDS="${prompt_sec:-30}"
    
    # Limits with defaults
    local mem_size=$(extract_yaml_value "defaults.limits.memorySize")
    local backup_cnt=$(extract_yaml_value "defaults.limits.backupCount")
    local hist_days=$(extract_yaml_value "defaults.limits.sessionHistoryDays")
    local branch_age=$(extract_yaml_value "defaults.limits.branchAgeDays")
    
    export AIPM_DEFAULTS_LIMITS_MEMORYSIZE="${mem_size:-10MB}"
    export AIPM_DEFAULTS_LIMITS_BACKUPCOUNT="${backup_cnt:-10}"
    export AIPM_DEFAULTS_LIMITS_SESSIONHISTORYDAYS="${hist_days:-30}"
    export AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS="${branch_age:-90}"
    
    # Logging with defaults
    local log_level=$(extract_yaml_value "defaults.logging.level")
    local log_loc=$(extract_yaml_value "defaults.logging.location")
    local log_rotate=$(extract_yaml_value "defaults.logging.rotate")
    local log_retain=$(extract_yaml_value "defaults.logging.retain")
    
    export AIPM_DEFAULTS_LOGGING_LEVEL="${log_level:-info}"
    export AIPM_DEFAULTS_LOGGING_LOCATION="${log_loc:-.aipm/logs}"
    export AIPM_DEFAULTS_LOGGING_ROTATE="${log_rotate:-true}"
    export AIPM_DEFAULTS_LOGGING_RETAIN="${log_retain:-7}"
}

# Export workflows section
export_workflows_section() {
    # Branch creation with defaults
    local start_behav=$(extract_yaml_value "workflows.branchCreation.startBehavior")
    local protect_resp=$(extract_yaml_value "workflows.branchCreation.protectionResponse")
    local auto_name=$(extract_yaml_value "workflows.branchCreation.autoName")
    local dup_strat=$(extract_yaml_value "workflows.branchCreation.duplicateStrategy")
    
    export AIPM_WORKFLOWS_BRANCHCREATION_STARTBEHAVIOR="${start_behav:-prompt}"
    export AIPM_WORKFLOWS_BRANCHCREATION_PROTECTIONRESPONSE="${protect_resp:-warn}"
    export AIPM_WORKFLOWS_BRANCHCREATION_AUTONAME="${auto_name:-false}"
    export AIPM_WORKFLOWS_BRANCHCREATION_DUPLICATESTRATEGY="${dup_strat:-suffix}"
    
    # Merge triggers with defaults
    local feat_complete=$(extract_yaml_value "workflows.mergeTriggers.featureComplete")
    local conflict_handle=$(extract_yaml_value "workflows.mergeTriggers.conflictHandling")
    
    export AIPM_WORKFLOWS_MERGETRIGGERS_FEATURECOMPLETE="${feat_complete:-manual}"
    export AIPM_WORKFLOWS_MERGETRIGGERS_CONFLICTHANDLING="${conflict_handle:-prompt}"
    
    # Synchronization with defaults
    local pull_start=$(extract_yaml_value "workflows.synchronization.pullOnStart")
    local push_stop=$(extract_yaml_value "workflows.synchronization.pushOnStop")
    local auto_backup=$(extract_yaml_value "workflows.synchronization.autoBackup")
    
    export AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART="${pull_start:-prompt}"
    export AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP="${push_stop:-prompt}"
    export AIPM_WORKFLOWS_SYNCHRONIZATION_AUTOBACKUP="${auto_backup:-true}"
    
    # Cleanup with defaults
    local after_merge=$(extract_yaml_value "workflows.cleanup.afterMerge")
    local stale_handle=$(extract_yaml_value "workflows.cleanup.staleHandling")
    local failed_work=$(extract_yaml_value "workflows.cleanup.failedWork")
    
    export AIPM_WORKFLOWS_CLEANUP_AFTERMERGE="${after_merge:-prompt}"
    export AIPM_WORKFLOWS_CLEANUP_STALEHANDLING="${stale_handle:-notify}"
    export AIPM_WORKFLOWS_CLEANUP_FAILEDWORK="${failed_work:-archive}"
    
    # Branch flow with defaults
    local src_default=$(extract_yaml_value "workflows.branchFlow.sources.default")
    local tgt_default=$(extract_yaml_value "workflows.branchFlow.targets.default")
    local parent_track=$(extract_yaml_value "workflows.branchFlow.parentTracking")
    
    export AIPM_WORKFLOWS_BRANCHFLOW_SOURCES_DEFAULT="${src_default:-{mainBranch}}"
    export AIPM_WORKFLOWS_BRANCHFLOW_TARGETS_DEFAULT="${tgt_default:-{mainBranch}}"
    export AIPM_WORKFLOWS_BRANCHFLOW_PARENTTRACKING="${parent_track:-true}"
}

# Export error handling settings
export_errorhandling_section() {
    local missing_type=$(extract_yaml_value "errorHandling.onMissingBranchType")
    local invalid_ref=$(extract_yaml_value "errorHandling.onInvalidReference")
    local circular_ref=$(extract_yaml_value "errorHandling.onCircularReference")
    local auto_recover=$(extract_yaml_value "errorHandling.recovery.autoRecover")
    local create_backup=$(extract_yaml_value "errorHandling.recovery.createBackup")
    local notify_user=$(extract_yaml_value "errorHandling.recovery.notifyUser")
    
    export AIPM_ERRORHANDLING_ONMISSINGBRANCHTYPE="${missing_type:-use-feature}"
    export AIPM_ERRORHANDLING_ONINVALIDREFERENCE="${invalid_ref:-fail}"
    export AIPM_ERRORHANDLING_ONCIRCULARREFERENCE="${circular_ref:-fail}"
    export AIPM_ERRORHANDLING_RECOVERY_AUTORECOVER="${auto_recover:-true}"
    export AIPM_ERRORHANDLING_RECOVERY_CREATEBACKUP="${create_backup:-true}"
    export AIPM_ERRORHANDLING_RECOVERY_NOTIFYUSER="${notify_user:-true}"
}

# Export settings section
export_settings_section() {
    local schema_ver=$(extract_yaml_value "settings.schemaVersion")
    export AIPM_SETTINGS_SCHEMAVERSION="${schema_ver:-1.0}"
    
    # Framework paths with defaults
    local modules_path=$(extract_yaml_value "settings.frameworkPaths.modules")
    local tests_path=$(extract_yaml_value "settings.frameworkPaths.tests")
    local docs_path=$(extract_yaml_value "settings.frameworkPaths.docs")
    local templates_path=$(extract_yaml_value "settings.frameworkPaths.templates")
    
    export AIPM_SETTINGS_FRAMEWORKPATHS_MODULES="${modules_path:-.aipm/scripts/modules}"
    export AIPM_SETTINGS_FRAMEWORKPATHS_TESTS="${tests_path:-.aipm/scripts/test}"
    export AIPM_SETTINGS_FRAMEWORKPATHS_DOCS="${docs_path:-AIPM_Design_Docs}"
    export AIPM_SETTINGS_FRAMEWORKPATHS_TEMPLATES="${templates_path:-.aipm/templates}"
    
    # Workflow settings with defaults
    local req_tests=$(extract_yaml_value "settings.workflow.requireTests")
    local req_docs=$(extract_yaml_value "settings.workflow.requireDocs")
    local req_review=$(extract_yaml_value "settings.workflow.requireReview")
    
    export AIPM_SETTINGS_WORKFLOW_REQUIRETESTS="${req_tests:-false}"
    export AIPM_SETTINGS_WORKFLOW_REQUIREDOCS="${req_docs:-false}"
    export AIPM_SETTINGS_WORKFLOW_REQUIREREVIEW="${req_review:-false}"
}

# Export metadata
export_metadata_section() {
    local version=$(extract_yaml_value "metadata.version")
    local schema=$(extract_yaml_value "metadata.schema")
    local last_mod=$(extract_yaml_value "metadata.lastModified")
    local compat=$(extract_yaml_value "metadata.compatibility")
    
    export AIPM_METADATA_VERSION="${version:-1.0.0}"
    export AIPM_METADATA_SCHEMA="${schema:-1.0}"
    export AIPM_METADATA_LASTMODIFIED="${last_mod:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
    export AIPM_METADATA_COMPATIBILITY="${compat:-^1.0.0}"
}

# Export computed values
export_computed_values() {
    # These are derived from other values
    export AIPM_COMPUTED_MAINBRANCH="${AIPM_BRANCHING_PREFIX}${AIPM_BRANCHING_MAINBRANCHSUFFIX}"
    export AIPM_COMPUTED_PREFIXPATTERN="^${AIPM_BRANCHING_PREFIX}"
    export AIPM_COMPUTED_ENTITYPATTERN="^${AIPM_MEMORY_ENTITYPREFIX}[A-Z]+_"
    
    # File hash for validation
    if [[ -n "$OPINIONS_FILE_PATH" ]]; then
        export AIPM_COMPUTED_FILEHASH=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
    fi
}

# ============================================================================
# LOOKUP FUNCTIONS - Clean API for accessing exports
# ============================================================================

# Get naming pattern for a branch type
aipm_get_naming_pattern() {
    local branch_type="$1"
    local var_name="AIPM_NAMING_${branch_type^^}"
    printf "%s" "${!var_name:-}"
}

# Get lifecycle rule for a branch type
aipm_get_lifecycle_rule() {
    local branch_type="$1"
    local rule="$2"  # deleteAfterMerge, daysToKeep
    local var_name="AIPM_LIFECYCLE_${branch_type^^}_${rule^^}"
    printf "%s" "${!var_name:-}"
}

# Get workflow setting
aipm_get_workflow() {
    local section="$1"  # branchCreation, synchronization, cleanup
    local field="$2"
    local var_name="AIPM_WORKFLOWS_${section^^}_${field^^}"
    printf "%s" "${!var_name:-}"
}

# Check if a branch is protected
aipm_is_protected_branch() {
    local branch="$1"
    
    # Check user branches
    if [[ " $AIPM_BRANCHING_PROTECTEDBRANCHES_USER " =~ " $branch " ]]; then
        printf "true"
        return 0
    fi
    
    # Check AIPM branches
    for suffix in $AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM; do
        if [[ "$branch" == "${AIPM_BRANCHING_PREFIX}${suffix}" ]]; then
            printf "true"
            return 0
        fi
    done
    
    printf "false"
    return 1
}

# Get branch flow source for a branch type
aipm_get_branch_source() {
    local branch_type="$1"
    local pattern="${branch_type}/*"
    
    # Check for specific override
    local override=$(extract_yaml_value "workflows.branchFlow.sources.byType.$pattern" "$OPINIONS_YAML_CONTENT")
    if [[ -n "$override" ]]; then
        printf "%s" "$override"
    else
        printf "%s" "$AIPM_WORKFLOWS_BRANCHFLOW_SOURCES_DEFAULT"
    fi
}

# Get branch flow target for a branch type
aipm_get_branch_target() {
    local branch_type="$1"
    local pattern="${branch_type}/*"
    
    # Check for specific override
    local override=$(extract_yaml_value "workflows.branchFlow.targets.byType.$pattern" "$OPINIONS_YAML_CONTENT")
    if [[ -n "$override" ]]; then
        printf "%s" "$override"
    else
        printf "%s" "$AIPM_WORKFLOWS_BRANCHFLOW_TARGETS_DEFAULT"
    fi
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

# Load and export all opinions
load_and_export_opinions() {
    local yaml_path="${1:-./.aipm/opinions.yaml}"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --defaults-only)
                OPINIONS_MODE="defaults-only"
                shift
                ;;
            --show-defaults)
                show_defaults
                return 0
                ;;
            --generate-template)
                generate_template_with_defaults
                return 0
                ;;
            *.yaml|*.yml)
                yaml_path="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Initialize defaults first (always)
    init_defaults
    
    # Load file (unless defaults-only mode)
    if [[ "$OPINIONS_MODE" != "defaults-only" ]]; then
        load_opinions_file "$yaml_path"
    fi
    
    # Export all sections (will use defaults if no YAML)
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
    
    # Success message (using shell-formatting)
    if [[ "$OPINIONS_MODE" == "defaults-only" ]]; then
        success "Loaded with defaults only (no opinions.yaml)"
    else
        success "Loaded opinions from: $yaml_path"
    fi
}

# ============================================================================
# CONVENIENCE FUNCTIONS - High-level accessors
# ============================================================================

# Get the main branch name for current workspace
get_main_branch() {
    printf "%s" "${AIPM_BRANCHING_MAINBRANCH:-AIPM_MAIN}"
}

# Get the workspace prefix
get_branch_prefix() {
    printf "%s" "${AIPM_BRANCHING_PREFIX:-AIPM_}"
}

# Check if opinions are loaded
opinions_loaded() {
    [[ "$AIPM_OPINIONS_LOADED" == "true" ]]
}

# Ensure opinions are loaded (lazy loading)
ensure_opinions_loaded() {
    if ! opinions_loaded; then
        load_and_export_opinions
    fi
}

# Auto-load if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Running as script, not sourced
    load_and_export_opinions "$@"
fi