#!/opt/homebrew/bin/bash
#
# opinions-state.sh - Complete runtime state management with full pre-computation
#
# This module manages the complete runtime state of AIPM, capturing EVERYTHING
# from opinions.yaml and pre-computing all possible values for zero runtime computation.
#
# State includes:
# - All raw configuration exports from opinions-loader.sh
# - All computed patterns, rules, matrices, and workflows
# - Current git branch states and runtime information
# - All pre-made decisions for every possible operation
# - Complete prompt structures for user interactions
#
# State is stored in .aipm/state/workspace.json for instant access
# 
# Usage:
#   source opinions-state.sh
#   initialize_state              # First time or full refresh
#   get_value "path.to.value"     # Get any value from state (instant!)
#   refresh_state "branches"      # Selective refresh
#
# Dependencies: opinions-loader.sh, version-control.sh, shell-formatting.sh, jq

# Source dependencies
OPINIONS_STATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$OPINIONS_STATE_DIR/shell-formatting.sh"
source "$OPINIONS_STATE_DIR/opinions-loader.sh"
source "$OPINIONS_STATE_DIR/version-control.sh"

# State file locations
declare -g STATE_DIR=".aipm/state"
declare -g STATE_FILE="$STATE_DIR/workspace.json"
declare -g STATE_LOCK="$STATE_DIR/workspace.lock"
declare -g STATE_HASH="$STATE_DIR/workspace.hash"

# Global state cache (for performance)
declare -g STATE_CACHE=""
declare -g STATE_LOADED="false"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if jq is installed
check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        die "jq is required for state management. Install with: brew install jq"
    fi
}

# Create state directory if needed
ensure_state_dir() {
    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR" || die "Failed to create state directory"
    fi
}

# Acquire lock for state operations
acquire_state_lock() {
    local timeout=30
    local elapsed=0
    
    while [[ -f "$STATE_LOCK" ]] && [[ $elapsed -lt $timeout ]]; do
        sleep 0.5
        ((elapsed++))
    done
    
    if [[ -f "$STATE_LOCK" ]]; then
        warn "State lock timeout - forcing unlock"
        rm -f "$STATE_LOCK"
    fi
    
    echo $$ > "$STATE_LOCK"
}

# Release state lock
release_state_lock() {
    rm -f "$STATE_LOCK"
}

# Read state file safely
read_state_file() {
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi
    
    STATE_CACHE=$(cat "$STATE_FILE" 2>/dev/null)
    if [[ -z "$STATE_CACHE" ]]; then
        return 1
    fi
    
    # Validate JSON
    if ! echo "$STATE_CACHE" | jq empty 2>/dev/null; then
        error "Invalid state file format"
        return 1
    fi
    
    STATE_LOADED="true"
    return 0
}

# Write state file atomically
write_state_file() {
    local content="$1"
    local temp_file="$STATE_FILE.tmp"
    
    # Validate JSON before writing
    if ! echo "$content" | jq empty 2>/dev/null; then
        error "Invalid JSON content"
        return 1
    fi
    
    # Pretty print and write
    echo "$content" | jq '.' > "$temp_file" || die "Failed to write state file"
    mv "$temp_file" "$STATE_FILE" || die "Failed to update state file"
    
    # Update cache
    STATE_CACHE="$content"
    STATE_LOADED="true"
    
    # Update hash
    sha256sum "$STATE_FILE" | cut -d' ' -f1 > "$STATE_HASH"
}

# ============================================================================
# COMPLETE COMPUTATION FUNCTIONS - Pre-compute EVERYTHING from opinions.yaml
# ============================================================================

# Resolve pattern variables
resolve_pattern_variables() {
    local pattern="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local date=$(date +%Y%m%d)
    local user=$(git config user.name 2>/dev/null | tr ' ' '_' | tr -cd '[:alnum:]_-' || echo "user")
    
    # Replace all variables
    pattern="${pattern//\{timestamp\}/$timestamp}"
    pattern="${pattern//\{date\}/$date}"
    pattern="${pattern//\{user\}/$user}"
    # {description}, {version}, {environment} are runtime values, keep as-is
    
    echo "$pattern"
}

# Compute all branch patterns with full resolution
compute_all_branch_patterns() {
    local prefix="${AIPM_BRANCHING_PREFIX}"
    local patterns='{}'
    
    # Get all naming patterns from exports
    local types=()
    while IFS='=' read -r name value; do
        if [[ "$name" =~ ^AIPM_NAMING_([A-Z]+)$ ]]; then
            local type="${BASH_REMATCH[1],,}"  # lowercase
            types+=("$type")
        fi
    done < <(compgen -A export | while read var; do printf "%s=%s\n" "$var" "${!var}"; done | grep "^AIPM_NAMING_")
    
    # Process each type
    for type in "${types[@]}"; do
        local pattern_var="AIPM_NAMING_${type^^}"
        local pattern="${!pattern_var}"
        
        if [[ -n "$pattern" ]]; then
            # Resolve cross-references like {naming.session}
            if [[ "$pattern" =~ \{naming\.([^}]+)\} ]]; then
                local ref_type="${BASH_REMATCH[1]}"
                local ref_var="AIPM_NAMING_${ref_type^^}"
                local ref_pattern="${!ref_var}"
                pattern="${pattern//\{naming.$ref_type\}/$ref_pattern}"
            fi
            
            # Create patterns for matching
            local full_pattern="${prefix}${pattern}"
            local glob_pattern="${full_pattern//\{*\}/*}"
            local regex_pattern="^${prefix}${pattern//\{[^}]+\}/(.+)}\$"
            
            patterns=$(echo "$patterns" | jq --arg k "$type" \
                --arg orig "$pattern" \
                --arg full "$full_pattern" \
                --arg glob "$glob_pattern" \
                --arg regex "$regex_pattern" \
                '.[$k] = {
                    original: $orig,
                    full: $full,
                    glob: $glob,
                    regex: $regex
                }')
        fi
    done
    
    echo "$patterns"
}

# Compute complete protected branches list
compute_protected_branches_list() {
    local protected='{
        "userBranches": [],
        "aipmBranches": [],
        "all": []
    }'
    
    # Add user branches
    if [[ -n "$AIPM_BRANCHING_PROTECTEDBRANCHES_USER" ]]; then
        for branch in $AIPM_BRANCHING_PROTECTEDBRANCHES_USER; do
            protected=$(echo "$protected" | jq --arg b "$branch" '
                .userBranches += [$b] |
                .all += [$b]
            ')
        done
    fi
    
    # Add AIPM branches with prefix
    if [[ -n "$AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM" ]]; then
        for suffix in $AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM; do
            local full_branch="${AIPM_BRANCHING_PREFIX}${suffix}"
            protected=$(echo "$protected" | jq --arg b "$full_branch" --arg s "$suffix" '
                .aipmBranches += [{suffix: $s, full: $b}] |
                .all += [$b]
            ')
        done
    fi
    
    echo "$protected"
}

# Compute complete lifecycle matrix with all rules
compute_complete_lifecycle_matrix() {
    local matrix='{}'
    
    # Get all branch types that have lifecycle rules
    local types=()
    while IFS='=' read -r name value; do
        if [[ "$name" =~ ^AIPM_LIFECYCLE_([A-Z]+)_DELETEAFTERMERGE$ ]]; then
            local type="${BASH_REMATCH[1],,}"
            types+=("$type")
        fi
    done < <(compgen -A export | while read var; do printf "%s=%s\n" "$var" "${!var}"; done | grep "^AIPM_LIFECYCLE_")
    
    # Process each type
    for type in "${types[@]}"; do
        local delete_var="AIPM_LIFECYCLE_${type^^}_DELETEAFTERMERGE"
        local days_var="AIPM_LIFECYCLE_${type^^}_DAYSTOKEEP"
        local max_var="AIPM_LIFECYCLE_${type^^}_MAXSESSIONS"
        
        local delete_after_merge="${!delete_var:-false}"
        local days_to_keep="${!days_var:-30}"
        local max_count="${!max_var:-}"
        
        # Compute delete timing
        local delete_timing="never"
        local delete_after_days=""
        if [[ "$days_to_keep" == "-1" ]] || [[ "$days_to_keep" == "never" ]]; then
            delete_timing="never"
        elif [[ "$days_to_keep" == "0" ]]; then
            delete_timing="immediate"
            delete_after_days=0
        else
            delete_timing="scheduled"
            delete_after_days="$days_to_keep"
        fi
        
        # Determine what triggers deletion
        local delete_trigger="lastCommit"
        if [[ "$delete_after_merge" == "true" ]]; then
            delete_trigger="mergeDate"
        fi
        
        # Build complete lifecycle entry
        local entry=$(jq -n \
            --arg dam "$delete_after_merge" \
            --arg dtk "$days_to_keep" \
            --arg dt "$delete_timing" \
            --arg dad "$delete_after_days" \
            --arg dtr "$delete_trigger" \
            --arg mc "$max_count" \
            '{
                deleteAfterMerge: ($dam == "true"),
                daysToKeep: ($dtk | tonumber? // $dtk),
                deleteTiming: $dt,
                deleteAfterDays: (if $dad != "" then ($dad | tonumber) else null end),
                deleteTrigger: $dtr,
                maxCount: (if $mc != "" then ($mc | tonumber) else null end),
                description: (
                    if $dt == "never" then "Keep forever"
                    elif $dt == "immediate" then 
                        if $dam == "true" then "Delete immediately after merge"
                        else "Delete immediately after last commit"
                        end
                    else
                        if $dam == "true" then "Delete \($dad) days after merge"
                        else "Delete \($dad) days after last commit"
                        end
                    end
                )
            }')
        
        matrix=$(echo "$matrix" | jq --arg k "$type" --argjson v "$entry" '.[$k] = $v')
    done
    
    # Add global lifecycle settings
    matrix=$(echo "$matrix" | jq --arg hu "$AIPM_LIFECYCLE_GLOBAL_HANDLEUNCOMMITTED" \
        --arg cr "$AIPM_LIFECYCLE_GLOBAL_CONFLICTRESOLUTION" \
        --arg ao "$AIPM_LIFECYCLE_GLOBAL_ALLOWOVERRIDE" \
        --arg ta "$AIPM_LIFECYCLE_GLOBAL_TRACKACTIVITY" \
        '.global = {
            handleUncommitted: $hu,
            conflictResolution: $cr,
            allowOverride: ($ao == "true"),
            trackActivity: ($ta == "true")
        }')
    
    echo "$matrix"
}

# Compute complete workflow rules
compute_complete_workflow_rules() {
    local workflows=$(jq -n '{
        branchCreation: {},
        merging: {},
        synchronization: {},
        cleanup: {},
        branchFlow: {}
    }')
    
    # Branch creation workflows
    workflows=$(echo "$workflows" | jq \
        --arg sb "$AIPM_WORKFLOWS_BRANCHCREATION_STARTBEHAVIOR" \
        --arg pr "$AIPM_WORKFLOWS_BRANCHCREATION_PROTECTIONRESPONSE" \
        --arg ts "${AIPM_WORKFLOWS_BRANCHCREATION_TYPESELECTION:-prompt}" \
        '.branchCreation = {
            startBehavior: $sb,
            protectionResponse: $pr,
            typeSelection: $ts,
            prompts: {
                protected: {
                    message: "You'\''re trying to save to main branch. What would you like to do?",
                    options: [
                        {key: "1", text: "Create feature branch", action: "create-feature"},
                        {key: "2", text: "Create session branch", action: "create-session"},
                        {key: "3", text: "Cancel", action: "cancel"}
                    ]
                },
                typeSelection: {
                    message: "What type of work is this?",
                    options: [
                        {key: "1", text: "Feature - New functionality", value: "feature"},
                        {key: "2", text: "Bug Fix - Fixing an issue", value: "bugfix"},
                        {key: "3", text: "Documentation - Docs only", value: "docs"},
                        {key: "4", text: "Experiment - Just trying", value: "test"}
                    ]
                }
            }
        }')
    
    # Merging workflows
    workflows=$(echo "$workflows" | jq \
        --arg sm "${AIPM_WORKFLOWS_MERGING_SESSIONMERGE:-on-stop}" \
        --arg fc "${AIPM_WORKFLOWS_MERGING_FEATURECOMPLETE:-prompt}" \
        --arg ch "${AIPM_WORKFLOWS_MERGING_CONFLICTHANDLING:-interactive}" \
        '.merging = {
            sessionMerge: $sm,
            featureComplete: $fc,
            conflictHandling: $ch,
            prompts: {
                featureComplete: {
                    message: "Is this feature complete and ready to merge?",
                    options: [
                        {key: "1", text: "Yes, merge now", action: "merge"},
                        {key: "2", text: "No, keep working", action: "continue"},
                        {key: "3", text: "Create PR for review", action: "pr"}
                    ]
                },
                mergeConflict: {
                    message: "Merge conflict detected. How to resolve?",
                    options: [
                        {key: "1", text: "Open editor to resolve", action: "editor"},
                        {key: "2", text: "Keep local version", action: "local"},
                        {key: "3", text: "Keep remote version", action: "remote"},
                        {key: "4", text: "Abort operation", action: "abort"}
                    ]
                }
            }
        }')
    
    # Synchronization workflows
    workflows=$(echo "$workflows" | jq \
        --arg pos "$AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART" \
        --arg pos2 "$AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP" \
        --arg ab "$AIPM_WORKFLOWS_SYNCHRONIZATION_AUTOBACKUP" \
        '.synchronization = {
            pullOnStart: $pos,
            pushOnStop: $pos2,
            autoBackup: $ab,
            prompts: {
                pullOnStart: {
                    message: "Remote has new changes. Update now?",
                    options: [
                        {key: "1", text: "Yes, update", action: "pull"},
                        {key: "2", text: "No, work offline", action: "skip"},
                        {key: "3", text: "View changes first", action: "diff"}
                    ]
                },
                pushOnStop: {
                    message: "You have unpushed changes. Share them?",
                    options: [
                        {key: "1", text: "Yes, push all", action: "push-all"},
                        {key: "2", text: "Push some", action: "push-select"},
                        {key: "3", text: "No, keep local", action: "skip"}
                    ]
                }
            }
        }')
    
    # Cleanup workflows
    workflows=$(echo "$workflows" | jq \
        --arg am "$AIPM_WORKFLOWS_CLEANUP_AFTERMERGE" \
        --arg sh "$AIPM_WORKFLOWS_CLEANUP_STALEHANDLING" \
        --arg fw "$AIPM_WORKFLOWS_CLEANUP_FAILEDWORK" \
        '.cleanup = {
            afterMerge: $am,
            staleHandling: $sh,
            failedWork: $fw,
            prompts: {
                afterMerge: {
                    message: "Branch merged successfully. Delete it?",
                    options: [
                        {key: "1", text: "Yes, delete now", action: "delete"},
                        {key: "2", text: "Keep for now", action: "keep"},
                        {key: "3", text: "Archive it", action: "archive"}
                    ]
                }
            }
        }')
    
    # Branch flow rules with complete resolution
    local main_branch="${AIPM_COMPUTED_MAINBRANCH}"
    workflows=$(echo "$workflows" | jq \
        --arg sd "$AIPM_WORKFLOWS_BRANCHFLOW_SOURCES_DEFAULT" \
        --arg td "$AIPM_WORKFLOWS_BRANCHFLOW_TARGETS_DEFAULT" \
        --arg pt "$AIPM_WORKFLOWS_BRANCHFLOW_PARENTTRACKING" \
        --arg mb "$main_branch" \
        '.branchFlow = {
            sources: {
                default: ($sd | gsub("\\{mainBranch\\}"; $mb)),
                byType: {}
            },
            targets: {
                default: ($td | gsub("\\{mainBranch\\}"; $mb)),
                byType: {}
            },
            parentTracking: $pt,
            prompts: {
                selectSource: {
                    message: "Create new branch from:",
                    options: [
                        {key: "1", text: "Current branch", value: "current"},
                        {key: "2", text: "Main branch", value: $mb},
                        {key: "3", text: "Other branch", value: "select"}
                    ]
                },
                selectTarget: {
                    message: "Merge this branch to:",
                    options: [
                        {key: "1", text: "Parent branch", value: "parent"},
                        {key: "2", text: "Main branch", value: $mb},
                        {key: "3", text: "Other branch", value: "select"}
                    ]
                }
            }
        }')
    
    # Add per-type overrides for branch flow
    local flow_types=("feature/*:$main_branch" "fix/*:$main_branch" "session/*:current" "test/*:current" "release/*:$main_branch")
    for flow in "${flow_types[@]}"; do
        local pattern="${flow%%:*}"
        local source="${flow#*:}"
        source="${source//\{mainBranch\}/$main_branch}"
        workflows=$(echo "$workflows" | jq --arg p "$pattern" --arg s "$source" '.branchFlow.sources.byType[$p] = $s')
    done
    
    # Add per-type targets
    local target_types=("feature/*:$main_branch" "fix/*:$main_branch" "session/*:parent" "test/*:parent" "release/*:none")
    for flow in "${target_types[@]}"; do
        local pattern="${flow%%:*}"
        local target="${flow#*:}"
        target="${target//\{mainBranch\}/$main_branch}"
        workflows=$(echo "$workflows" | jq --arg p "$pattern" --arg t "$target" '.branchFlow.targets.byType[$p] = $t')
    done
    
    echo "$workflows"
}

# Compute complete validation rules
compute_complete_validation_rules() {
    local validation=$(jq -n \
        --arg mode "$AIPM_VALIDATION_MODE" \
        --arg en "$AIPM_VALIDATION_RULES_ENFORCENAMING" \
        --arg bp "$AIPM_VALIDATION_RULES_BLOCKWRONGPREFIX" \
        --arg ct "$AIPM_VALIDATION_RULES_REQUIRECLEANTREE" \
        --arg vm "$AIPM_VALIDATION_RULES_VALIDATEMEMORY" \
        --arg ww "$AIPM_VALIDATION_BLOCKERS_WRONGWORKSPACE" \
        --arg ip "$AIPM_VALIDATION_BLOCKERS_INVALIDPREFIX" \
        --arg cm "$AIPM_VALIDATION_BLOCKERS_CORRUPTMEMORY" \
        '{
            mode: $mode,
            rules: {
                enforceNaming: ($en == "true"),
                blockWrongPrefix: ($bp == "true"),
                requireCleanTree: ($ct == "true"),
                validateMemory: ($vm == "true")
            },
            blockers: {
                wrongWorkspace: ($ww == "true"),
                invalidPrefix: ($ip == "true"),
                corruptMemory: ($cm == "true")
            }
        }')
    
    # Add gradual mode settings if applicable
    if [[ "$AIPM_VALIDATION_MODE" == "gradual" ]]; then
        validation=$(echo "$validation" | jq \
            --arg sl "${AIPM_VALIDATION_GRADUAL_STARTLEVEL:-relaxed}" \
            --arg el "${AIPM_VALIDATION_GRADUAL_ENDLEVEL:-strict}" \
            --arg tr "${AIPM_VALIDATION_GRADUAL_PROGRESSION_TRIGGER:-days}" \
            --arg tv "${AIPM_VALIDATION_GRADUAL_PROGRESSION_VALUE:-30}" \
            --arg w "${AIPM_VALIDATION_GRADUAL_PROGRESSION_WARNINGS:-7}" \
            '.gradual = {
                startLevel: $sl,
                endLevel: $el,
                progression: {
                    trigger: $tr,
                    value: ($tv | tonumber),
                    warnings: ($w | tonumber)
                },
                currentLevel: $sl
            }')
    fi
    
    echo "$validation"
}

# Compute complete memory configuration
compute_complete_memory_config() {
    local memory=$(jq -n \
        --arg ep "$AIPM_MEMORY_ENTITYPREFIX" \
        --arg cats "$AIPM_MEMORY_CATEGORIES" \
        --arg regex "$AIPM_COMPUTED_ENTITYPATTERN" \
        --arg strict "$AIPM_MEMORY_CATEGORYRULES_STRICT" \
        --arg dynamic "$AIPM_MEMORY_CATEGORYRULES_ALLOWDYNAMIC" \
        --arg uncat "$AIPM_MEMORY_CATEGORYRULES_UNCATEGORIZED" \
        --arg case "$AIPM_MEMORY_CATEGORYRULES_CASEINSENSITIVE" \
        --arg size "$AIPM_DEFAULTS_LIMITS_MEMORYSIZE" \
        '{
            entityPrefix: $ep,
            categories: ($cats | split(" ")),
            entityRegex: $regex,
            maxSize: $size,
            categoryRules: {
                strict: ($strict == "true"),
                allowDynamic: ($dynamic == "true"),
                uncategorized: $uncat,
                caseInsensitive: ($case == "true")
            },
            examples: []
        }')
    
    # Add examples for each category
    local categories=($AIPM_MEMORY_CATEGORIES)
    for cat in "${categories[@]}"; do
        local example="${AIPM_MEMORY_ENTITYPREFIX}${cat}_DESCRIPTION"
        memory=$(echo "$memory" | jq --arg ex "$example" '.examples += [$ex]')
    done
    
    echo "$memory"
}

# Compute complete team configuration
compute_complete_team_config() {
    local team=$(jq -n \
        --arg sm "$AIPM_TEAM_SYNCMODE" \
        --arg fos "$AIPM_TEAM_FETCHONSTART" \
        --arg wod "$AIPM_TEAM_WARNONDIVERGENCE" \
        --arg rpr "$AIPM_TEAM_REQUIREPULLREQUEST" \
        --arg pto "$AIPM_TEAM_SYNC_PROMPT_TIMEOUT" \
        --arg ptd "$AIPM_TEAM_SYNC_PROMPT_DEFAULT" \
        --arg dr "$AIPM_TEAM_SYNC_DIVERGENCE_RESOLUTION" \
        --arg dd "$AIPM_TEAM_SYNC_DIVERGENCE_SHOWDIFF" \
        --arg cs "$AIPM_TEAM_SYNC_CONFLICTS_STRATEGY" \
        --arg cb "$AIPM_TEAM_SYNC_CONFLICTS_BACKUP" \
        --arg ca "$AIPM_TEAM_SYNC_CONFLICTS_ABORTONFAIL" \
        '{
            syncMode: $sm,
            fetchOnStart: ($fos == "true"),
            warnOnDivergence: ($wod == "true"),
            requirePullRequest: ($rpr == "true"),
            sync: {
                prompt: {
                    triggers: ["remote-ahead", "diverged", "merge-conflicts"],
                    timeout: ($pto | tonumber),
                    default: $ptd,
                    messages: {
                        remoteAhead: "Remote has updates. Sync now?",
                        diverged: "Your branch and remote have diverged. How to proceed?",
                        mergeConflicts: "Merge conflicts detected during sync."
                    }
                },
                divergence: {
                    definition: "local and remote have different commits",
                    resolution: $dr,
                    showDiff: ($dd == "true"),
                    prompts: {
                        resolve: {
                            message: "Your branch and remote have diverged. How to proceed?",
                            options: [
                                {key: "1", text: "Merge remote changes", action: "merge"},
                                {key: "2", text: "Rebase onto remote", action: "rebase"},
                                {key: "3", text: "Keep mine only", action: "force"},
                                {key: "4", text: "View differences", action: "diff"}
                            ]
                        }
                    }
                },
                conflicts: {
                    strategy: $cs,
                    backup: ($cb == "true"),
                    abortOnFail: ($ca == "true"),
                    prompts: {
                        resolve: {
                            message: "Merge conflict detected. How to resolve?",
                            options: [
                                {key: "1", text: "Keep my version", action: "ours"},
                                {key: "2", text: "Take their version", action: "theirs"},
                                {key: "3", text: "Manual merge", action: "manual"},
                                {key: "4", text: "Abort operation", action: "abort"}
                            ]
                        }
                    }
                }
            }
        }')
    
    echo "$team"
}

# Compute complete session configuration
compute_complete_session_config() {
    local sessions=$(jq -n \
        --arg en "$AIPM_SESSIONS_ENABLED" \
        --arg ac "$AIPM_SESSIONS_AUTOCREATE" \
        --arg am "$AIPM_SESSIONS_AUTOMERGE" \
        --arg mul "$AIPM_SESSIONS_ALLOWMULTIPLE" \
        --arg np "$AIPM_SESSIONS_NAMEPATTERN" \
        --arg poc "$AIPM_SESSIONS_PROMPTONCONFLICT" \
        --arg com "$AIPM_SESSIONS_CLEANUPONMERGE" \
        '{
            enabled: ($en == "true"),
            autoCreate: ($ac == "true"),
            autoMerge: ($am == "true"),
            allowMultiple: ($mul == "true"),
            namePattern: $np,
            promptOnConflict: ($poc == "true"),
            cleanupOnMerge: ($com == "true"),
            prompts: {
                conflict: {
                    message: "Session has conflicts with parent branch. Continue?",
                    options: [
                        {key: "1", text: "Merge anyway", action: "merge"},
                        {key: "2", text: "Keep session separate", action: "keep"},
                        {key: "3", text: "Discard session", action: "discard"}
                    ]
                }
            }
        }')
    
    # Resolve namePattern references
    local resolved_pattern="$AIPM_SESSIONS_NAMEPATTERN"
    if [[ "$resolved_pattern" =~ \{naming\.([^}]+)\} ]]; then
        local ref_type="${BASH_REMATCH[1]}"
        local ref_var="AIPM_NAMING_${ref_type^^}"
        local ref_pattern="${!ref_var}"
        resolved_pattern="${resolved_pattern//\{naming.$ref_type\}/$ref_pattern}"
    fi
    
    sessions=$(echo "$sessions" | jq --arg rp "$resolved_pattern" '.resolvedNamePattern = $rp')
    
    echo "$sessions"
}

# Compute all loading configuration
compute_loading_config() {
    local loading=$(jq -n \
        --arg path "${AIPM_LOADING_DISCOVERY_PATH:-./.aipm/opinions.yaml}" \
        --arg req "${AIPM_LOADING_VALIDATION_REQUIRED:-workspace branching memory lifecycle workflows}" \
        --arg rec "$AIPM_LOADING_VALIDATION_RECOMMENDED" \
        --arg sm "$AIPM_LOADING_VALIDATION_STRICTMODE" \
        --arg hc "$AIPM_LOADING_VALIDATION_HASHCHECK" \
        --arg sv "$AIPM_LOADING_VALIDATION_SCHEMAVERSION" \
        --arg oe "$AIPM_LOADING_VALIDATION_ONERROR" \
        --arg db "$AIPM_LOADING_CONTEXT_DETECTBY" \
        --arg vp "$AIPM_LOADING_CONTEXT_VALIDATEPREFIX" \
        --arg ei "$AIPM_LOADING_CONTEXT_ENFORCEISOLATION" \
        --arg mm "${AIPM_LOADING_CONTEXT_PREFIXRULES_MUSTMATCH:-branching.prefix memory.entityPrefix}" \
        --arg pat "${AIPM_LOADING_CONTEXT_PREFIXRULES_PATTERN:-^[A-Z][A-Z0-9_]*_$}" \
        --arg res "$AIPM_LOADING_CONTEXT_PREFIXRULES_RESERVED" \
        --arg inh "$AIPM_LOADING_INHERITANCE_ENABLED" \
        '{
            discovery: {
                path: $path
            },
            validation: {
                required: ($req | split(" ")),
                recommended: (if $rec != "" then ($rec | split(" ")) else [] end),
                strictMode: ($sm == "true"),
                hashCheck: ($hc == "true"),
                schemaVersion: $sv,
                onError: $oe,
                crossValidationRules: [
                    "All naming types must have lifecycle rules",
                    "All lifecycle types must exist in naming",
                    "branching.prefix must match memory.entityPrefix",
                    "All workflow branch patterns must exist in naming",
                    "Protected branches must use valid patterns",
                    "session namePattern must reference valid naming field"
                ]
            },
            context: {
                detectBy: ($db // "workspace.name"),
                validatePrefix: ($vp == "true"),
                enforceIsolation: ($ei == "true"),
                prefixRules: {
                    mustMatch: ($mm | split(" ")),
                    pattern: $pat,
                    reserved: (if $res != "" then ($res | split(" ")) else [] end)
                }
            },
            inheritance: {
                enabled: ($inh == "true")
            }
        }')
    
    echo "$loading"
}

# Compute initialization configuration
compute_initialization_config() {
    local init=$(jq -n \
        --arg mt "$AIPM_INITIALIZATION_MARKER_TYPE" \
        --arg mm "${AIPM_INITIALIZATION_MARKER_MESSAGE:-AIPM_INIT_HERE: Initialize {workspace.name} workspace from {parent.branch}}" \
        --arg im "$AIPM_INITIALIZATION_MARKER_INCLUDEMETADATA" \
        --arg vs "$AIPM_INITIALIZATION_MARKER_VERIFYONSTART" \
        --arg rc "$AIPM_INITIALIZATION_BRANCHCREATION_REQUIRECLEAN" \
        --arg bo "$AIPM_INITIALIZATION_BRANCHCREATION_BACKUPORIGINAL" \
        --arg sd "$AIPM_INITIALIZATION_BRANCHCREATION_SHOWDIFF" \
        --arg ms "$AIPM_INITIALIZATION_MAIN_SUFFIX" \
        --arg fc "$AIPM_INITIALIZATION_MAIN_FROMCOMMIT" \
        '{
            marker: {
                type: $mt,
                message: $mm,
                includeMetadata: ($im == "true"),
                verifyOnStart: ($vs == "true")
            },
            branchCreation: {
                requireClean: ($rc == "true"),
                backupOriginal: ($bo == "true"),
                showDiff: ($sd == "true")
            },
            mappings: {
                main: {
                    suffix: $ms,
                    fromCommit: $fc
                }
            }
        }')
    
    # TODO: Add support for additional branch mappings (develop, staging, etc.)
    
    echo "$init"
}

# Compute all defaults and limits
compute_defaults_and_limits() {
    local defaults=$(jq -n \
        --arg ss "$AIPM_DEFAULTS_TIMEOUTS_SESSIONSECONDS" \
        --arg os "$AIPM_DEFAULTS_TIMEOUTS_OPERATIONSECONDS" \
        --arg gs "$AIPM_DEFAULTS_TIMEOUTS_GITSECONDS" \
        --arg ps "$AIPM_DEFAULTS_TIMEOUTS_PROMPTSECONDS" \
        --arg ms "$AIPM_DEFAULTS_LIMITS_MEMORYSIZE" \
        --arg bc "$AIPM_DEFAULTS_LIMITS_BACKUPCOUNT" \
        --arg shd "$AIPM_DEFAULTS_LIMITS_SESSIONHISTORYDAYS" \
        --arg bad "$AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS" \
        --arg ll "$AIPM_DEFAULTS_LOGGING_LEVEL" \
        --arg loc "$AIPM_DEFAULTS_LOGGING_LOCATION" \
        --arg rot "$AIPM_DEFAULTS_LOGGING_ROTATE" \
        --arg ret "$AIPM_DEFAULTS_LOGGING_RETAIN" \
        '{
            timeouts: {
                sessionSeconds: ($ss | tonumber),
                operationSeconds: ($os | tonumber),
                gitSeconds: ($gs | tonumber),
                promptSeconds: ($ps | tonumber)
            },
            limits: {
                memorySize: $ms,
                memorySizeBytes: 0,
                backupCount: ($bc | tonumber),
                sessionHistoryDays: ($shd | tonumber),
                branchAgeDays: ($bad | tonumber)
            },
            logging: {
                level: $ll,
                location: $loc,
                rotate: $rot,
                retain: ($ret | tonumber)
            }
        }')
    
    # Convert memory size to bytes
    local size_bytes=0
    if [[ "$AIPM_DEFAULTS_LIMITS_MEMORYSIZE" =~ ^([0-9]+)(MB|KB|GB)?$ ]]; then
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]:-MB}"
        case "$unit" in
            KB) size_bytes=$((num * 1024)) ;;
            MB) size_bytes=$((num * 1024 * 1024)) ;;
            GB) size_bytes=$((num * 1024 * 1024 * 1024)) ;;
        esac
    fi
    
    defaults=$(echo "$defaults" | jq --arg sb "$size_bytes" '.limits.memorySizeBytes = ($sb | tonumber)')
    
    echo "$defaults"
}

# Compute error handling configuration
compute_error_handling_config() {
    local error_handling=$(jq -n \
        --arg mbt "$AIPM_ERRORHANDLING_ONMISSINGBRANCHTYPE" \
        --arg ir "$AIPM_ERRORHANDLING_ONINVALIDREFERENCE" \
        --arg cr "$AIPM_ERRORHANDLING_ONCIRCULARREFERENCE" \
        --arg ar "$AIPM_ERRORHANDLING_RECOVERY_AUTORECOVER" \
        --arg cb "$AIPM_ERRORHANDLING_RECOVERY_CREATEBACKUP" \
        --arg nu "$AIPM_ERRORHANDLING_RECOVERY_NOTIFYUSER" \
        '{
            onMissingBranchType: $mbt,
            onInvalidReference: $ir,
            onCircularReference: $cr,
            recovery: {
                autoRecover: ($ar == "true"),
                createBackup: ($cb == "true"),
                notifyUser: $nu
            },
            prompts: {
                missingBranchType: {
                    message: "Unknown branch type. How to handle?",
                    options: [
                        {key: "1", text: "Use default rules", action: "default"},
                        {key: "2", text: "Skip this branch", action: "skip"},
                        {key: "3", text: "Abort operation", action: "abort"}
                    ]
                }
            }
        }')
    
    echo "$error_handling"
}

# Compute settings configuration
compute_settings_config() {
    local settings=$(jq -n \
        --arg sv "${AIPM_SETTINGS_SCHEMAVERSION:-1.0}" \
        --arg mp "${AIPM_SETTINGS_FRAMEWORKPATHS_MODULES:-.aipm/scripts/modules/}" \
        --arg tp "${AIPM_SETTINGS_FRAMEWORKPATHS_TESTS:-.aipm/scripts/test/}" \
        --arg dp "${AIPM_SETTINGS_FRAMEWORKPATHS_DOCS:-.aipm/docs/}" \
        --arg tmp "${AIPM_SETTINGS_FRAMEWORKPATHS_TEMPLATES:-.aipm/templates/}" \
        --arg rt "$AIPM_SETTINGS_WORKFLOW_REQUIRETESTS" \
        --arg rd "$AIPM_SETTINGS_WORKFLOW_REQUIREDOCS" \
        --arg rr "$AIPM_SETTINGS_WORKFLOW_REQUIREREVIEW" \
        '{
            schemaVersion: $sv,
            frameworkPaths: {
                modules: $mp,
                tests: $tp,
                docs: $dp,
                templates: $tmp
            },
            workflow: {
                requireTests: ($rt == "true"),
                requireDocs: ($rd == "true"),
                requireReview: ($rr == "true")
            }
        }')
    
    echo "$settings"
}

# ============================================================================
# RUNTIME STATE FUNCTIONS - Query actual git state
# ============================================================================

# Get complete branch information
get_complete_runtime_branches() {
    local branches='{}'
    local prefix="${AIPM_BRANCHING_PREFIX}"
    
    # Get all branches (local and remote)
    local all_branches=$(git branch -a --no-color | sed 's/^[* ]*//' | grep -v " -> " | sort -u)
    
    while IFS= read -r branch; do
        [[ -z "$branch" ]] && continue
        
        # Skip if not our prefix (unless it's a protected user branch)
        local is_our_branch=false
        if [[ "$branch" =~ ^${prefix} ]]; then
            is_our_branch=true
        else
            # Check if it's a protected user branch
            for pb in $AIPM_BRANCHING_PROTECTEDBRANCHES_USER; do
                if [[ "$branch" == "$pb" ]]; then
                    is_our_branch=true
                    break
                fi
            done
        fi
        
        [[ "$is_our_branch" == "false" ]] && continue
        
        # Get branch existence and head
        local exists="true"
        local head=$(git rev-parse "$branch" 2>/dev/null || echo "")
        if [[ -z "$head" ]]; then
            exists="false"
            continue
        fi
        
        # Find AIPM_INIT_HERE marker for AIPM branches
        local init_marker=""
        local parent=""
        if [[ "$branch" =~ ^${prefix} ]]; then
            init_marker=$(git log --format="%H %s" "$branch" 2>/dev/null | grep "AIPM_INIT_HERE" | head -1 | awk '{print $1}')
            
            # Extract parent from init message
            if [[ -n "$init_marker" ]]; then
                parent=$(git log -1 --format="%s" "$init_marker" 2>/dev/null | sed -n 's/.*from \([^ ]*\).*/\1/p')
            fi
        fi
        
        # Get dates
        local created=$(git log --format="%aI" --reverse "$branch" 2>/dev/null | head -1)
        local last_commit=$(git log -1 --format="%aI" "$branch" 2>/dev/null || echo "")
        
        # Check if merged to any branch
        local merge_date=""
        local merged_to=""
        local merge_info=$(git branch --merged | grep -v "^[* ]*$branch$" | head -1)
        if [[ -n "$merge_info" ]]; then
            # Find actual merge commit
            local merge_commit=$(git log --merges --format="%H %s %aI" | grep "$branch" | head -1)
            if [[ -n "$merge_commit" ]]; then
                merge_date=$(echo "$merge_commit" | awk '{print $NF}')
                # TODO: Extract merged_to branch
            fi
        fi
        
        # Determine branch type
        local type="unknown"
        if [[ "$branch" =~ ^${prefix} ]]; then
            # It's an AIPM branch - determine type
            for t in feature bugfix test session release framework refactor docs chore; do
                local pattern_var="AIPM_NAMING_${t^^}"
                local pattern="${!pattern_var}"
                if [[ -n "$pattern" ]]; then
                    # Simple pattern matching
                    local simple_pattern="${pattern//\{*\}/}"
                    if [[ "$branch" =~ ^${prefix}${simple_pattern} ]]; then
                        type="$t"
                        break
                    fi
                fi
            done
            
            # Special case for main branch
            if [[ "$branch" == "${AIPM_COMPUTED_MAINBRANCH}" ]]; then
                type="main"
            fi
        else
            # User branch
            type="user"
        fi
        
        # Check if protected
        local is_protected="false"
        local protection_reason=""
        
        # Check user protected branches
        for pb in $AIPM_BRANCHING_PROTECTEDBRANCHES_USER; do
            if [[ "$branch" == "$pb" ]]; then
                is_protected="true"
                protection_reason="user_protected"
                break
            fi
        done
        
        # Check AIPM protected branches
        if [[ "$is_protected" == "false" ]]; then
            for suffix in $AIPM_BRANCHING_PROTECTEDBRANCHES_AIPM; do
                if [[ "$branch" == "${prefix}${suffix}" ]]; then
                    is_protected="true"
                    protection_reason="aipm_protected"
                    break
                fi
            done
        fi
        
        # Get remote tracking info
        local upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null || echo "")
        local has_remote="false"
        if [[ -n "$upstream" ]]; then
            has_remote="true"
        fi
        
        # Calculate deletion info
        local scheduled_delete="never"
        local delete_reason=""
        local delete_date=""
        
        if [[ "$is_protected" == "false" ]] && [[ "$type" != "unknown" ]] && [[ "$type" != "user" ]]; then
            local lifecycle_var_dam="AIPM_LIFECYCLE_${type^^}_DELETEAFTERMERGE"
            local lifecycle_var_dtk="AIPM_LIFECYCLE_${type^^}_DAYSTOKEEP"
            local delete_after_merge="${!lifecycle_var_dam:-false}"
            local days_to_keep="${!lifecycle_var_dtk:-30}"
            
            if [[ "$days_to_keep" != "-1" ]] && [[ "$days_to_keep" != "never" ]]; then
                local reference_date="$last_commit"
                local delete_trigger="lastCommit"
                
                if [[ "$delete_after_merge" == "true" ]] && [[ -n "$merge_date" ]]; then
                    reference_date="$merge_date"
                    delete_trigger="merge"
                fi
                
                if [[ -n "$reference_date" ]]; then
                    if [[ "$days_to_keep" == "0" ]]; then
                        scheduled_delete="immediate"
                        delete_reason="Immediate deletion after $delete_trigger"
                    else
                        # Calculate future delete date
                        local ref_epoch=$(date -d "$reference_date" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${reference_date%%.*}" +%s 2>/dev/null || echo 0)
                        local delete_epoch=$((ref_epoch + (days_to_keep * 86400)))
                        delete_date=$(date -d "@$delete_epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -r "$delete_epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
                        scheduled_delete="scheduled"
                        delete_reason="Delete $days_to_keep days after $delete_trigger"
                    fi
                fi
            fi
        fi
        
        # Build complete branch entry
        local entry=$(jq -n \
            --arg exists "$exists" \
            --arg head "$head" \
            --arg parent "$parent" \
            --arg init "$init_marker" \
            --arg created "$created" \
            --arg last "$last_commit" \
            --arg merge "$merge_date" \
            --arg merged_to "$merged_to" \
            --arg sched "$scheduled_delete" \
            --arg del_date "$delete_date" \
            --arg del_reason "$delete_reason" \
            --arg prot "$is_protected" \
            --arg prot_reason "$protection_reason" \
            --arg type "$type" \
            --arg upstream "$upstream" \
            --arg remote "$has_remote" \
            '{
                exists: ($exists == "true"),
                head: $head,
                parent: (if $parent != "" then $parent else null end),
                initMarker: (if $init != "" then $init else null end),
                created: $created,
                lastCommit: $last,
                mergeDate: (if $merge != "" then $merge else null end),
                mergedTo: (if $merged_to != "" then $merged_to else null end),
                scheduledDelete: $sched,
                deleteDate: (if $del_date != "" then $del_date else null end),
                deleteReason: (if $del_reason != "" then $del_reason else null end),
                isProtected: ($prot == "true"),
                protectionReason: (if $prot_reason != "" then $prot_reason else null end),
                type: $type,
                upstream: (if $upstream != "" then $upstream else null end),
                hasRemote: ($remote == "true")
            }')
        
        branches=$(echo "$branches" | jq --arg k "$branch" --argjson v "$entry" '.[$k] = $v')
    done <<< "$all_branches"
    
    echo "$branches"
}

# Get complete git runtime state
get_complete_runtime_state() {
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    local working_tree_clean="true"
    local uncommitted_changes='[]'
    
    # Check working tree status
    local status_output=$(git status --porcelain 2>/dev/null)
    if [[ -n "$status_output" ]]; then
        working_tree_clean="false"
        
        # Parse uncommitted changes
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local status="${line:0:2}"
            local file="${line:3}"
            local change_type="unknown"
            
            case "$status" in
                "??") change_type="untracked" ;;
                "M "|" M") change_type="modified" ;;
                "A "|" A") change_type="added" ;;
                "D "|" D") change_type="deleted" ;;
                "R "|" R") change_type="renamed" ;;
                *) change_type="other" ;;
            esac
            
            uncommitted_changes=$(echo "$uncommitted_changes" | jq --arg f "$file" --arg t "$change_type" \
                '. += [{file: $f, type: $t}]')
        done <<< "$status_output"
    fi
    
    # Get stash count
    local stash_count=$(git stash list 2>/dev/null | wc -l || echo 0)
    
    # Get remote status
    local ahead=0
    local behind=0
    local diverged="false"
    local upstream=""
    
    if [[ -n "$current_branch" ]]; then
        upstream=$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            ahead=$(git rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)
            behind=$(git rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)
            if [[ $ahead -gt 0 ]] && [[ $behind -gt 0 ]]; then
                diverged="true"
            fi
        fi
    fi
    
    # Get repository info
    local repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    local git_dir=$(git rev-parse --git-dir 2>/dev/null || echo ".git")
    
    # Check for rebase/merge in progress
    local operation_in_progress=""
    if [[ -d "$git_dir/rebase-merge" ]] || [[ -d "$git_dir/rebase-apply" ]]; then
        operation_in_progress="rebase"
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
        operation_in_progress="merge"
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
        operation_in_progress="cherry-pick"
    fi
    
    # Build complete runtime state
    jq -n \
        --arg cb "$current_branch" \
        --arg clean "$working_tree_clean" \
        --argjson uc "$uncommitted_changes" \
        --arg sc "$stash_count" \
        --arg ahead "$ahead" \
        --arg behind "$behind" \
        --arg div "$diverged" \
        --arg up "$upstream" \
        --arg root "$repo_root" \
        --arg op "$operation_in_progress" \
        '{
            currentBranch: $cb,
            workingTreeClean: ($clean == "true"),
            uncommittedChanges: $uc,
            uncommittedCount: ($uc | length),
            stashCount: ($sc | tonumber),
            remoteStatus: {
                ahead: ($ahead | tonumber),
                behind: ($behind | tonumber),
                diverged: ($div == "true"),
                upstream: (if $up != "" then $up else null end)
            },
            repository: {
                root: $root,
                currentPath: (env.PWD // "")
            },
            operationInProgress: (if $op != "" then $op else null end)
        }'
}

# ============================================================================
# COMPLETE DECISION MAKING - Pre-compute ALL possible decisions
# ============================================================================

# Make all possible decisions based on current state
make_complete_decisions() {
    local runtime="$1"
    local computed="$2"
    
    local current_branch=$(echo "$runtime" | jq -r '.currentBranch')
    local working_tree_clean=$(echo "$runtime" | jq -r '.workingTreeClean')
    local branches=$(echo "$runtime" | jq '.branches')
    local operation_in_progress=$(echo "$runtime" | jq -r '.operationInProgress')
    
    # Initialize decisions object
    local decisions='{}'
    
    # Can create branch?
    local can_create="true"
    local cannot_create_reasons='[]'
    
    if [[ "$operation_in_progress" != "null" ]] && [[ -n "$operation_in_progress" ]]; then
        can_create="false"
        cannot_create_reasons=$(echo "$cannot_create_reasons" | jq --arg r "Operation in progress: $operation_in_progress" '. += [$r]')
    fi
    
    if [[ "$AIPM_VALIDATION_RULES_REQUIRECLEANTREE" == "true" ]] && [[ "$working_tree_clean" == "false" ]]; then
        can_create="false"
        cannot_create_reasons=$(echo "$cannot_create_reasons" | jq '. += ["Working tree has uncommitted changes"]')
    fi
    
    # Suggested branch type
    local suggested_type="feature"
    local type_suggestion_reason="Default type for new work"
    
    if [[ "$AIPM_SESSIONS_ENABLED" == "true" ]]; then
        # Check if session already exists
        local session_count=$(echo "$branches" | jq '[to_entries[] | select(.value.type == "session")] | length')
        if [[ "$AIPM_SESSIONS_ALLOWMULTIPLE" == "false" ]] && [[ $session_count -eq 0 ]]; then
            suggested_type="session"
            type_suggestion_reason="No active session exists"
        elif [[ "$AIPM_SESSIONS_AUTOCREATE" == "true" ]] && [[ $session_count -eq 0 ]]; then
            suggested_type="session"
            type_suggestion_reason="Auto-create session enabled"
        fi
    fi
    
    # Can merge current branch?
    local can_merge="false"
    local cannot_merge_reasons='[]'
    local merge_target=""
    local merge_strategy=""
    
    if [[ -n "$current_branch" ]] && [[ "$current_branch" != "HEAD" ]]; then
        local branch_info=$(echo "$branches" | jq -r --arg b "$current_branch" '.[$b]')
        
        if [[ -n "$branch_info" ]] && [[ "$branch_info" != "null" ]]; then
            local branch_type=$(echo "$branch_info" | jq -r '.type')
            local is_protected=$(echo "$branch_info" | jq -r '.isProtected')
            
            if [[ "$branch_type" != "main" ]] && [[ "$branch_type" != "user" ]]; then
                can_merge="true"
                
                # Determine merge target from workflow rules
                local workflow_targets=$(echo "$computed" | jq '.workflows.branchFlow.targets')
                local type_pattern="${branch_type}/*"
                local target_rule=$(echo "$workflow_targets" | jq -r --arg p "$type_pattern" '.byType[$p] // .default')
                
                if [[ "$target_rule" == "parent" ]]; then
                    merge_target=$(echo "$branch_info" | jq -r '.parent // ""')
                    if [[ -z "$merge_target" ]] || [[ "$merge_target" == "null" ]]; then
                        merge_target="${AIPM_COMPUTED_MAINBRANCH}"
                    fi
                elif [[ "$target_rule" == "none" ]]; then
                    can_merge="false"
                    cannot_merge_reasons=$(echo "$cannot_merge_reasons" | jq '. += ["Branch type does not merge back"]')
                else
                    merge_target="$target_rule"
                fi
                
                # Determine merge strategy
                if [[ "$branch_type" == "session" ]]; then
                    merge_strategy="${AIPM_WORKFLOWS_MERGING_SESSIONMERGE:-on-stop}"
                else
                    merge_strategy="${AIPM_WORKFLOWS_MERGING_FEATURECOMPLETE:-prompt}"
                fi
            else
                if [[ "$branch_type" == "main" ]]; then
                    cannot_merge_reasons=$(echo "$cannot_merge_reasons" | jq '. += ["Cannot merge main branch"]')
                elif [[ "$is_protected" == "true" ]]; then
                    cannot_merge_reasons=$(echo "$cannot_merge_reasons" | jq '. += ["Branch is protected"]')
                fi
            fi
        fi
    else
        cannot_merge_reasons=$(echo "$cannot_merge_reasons" | jq '. += ["No current branch"]')
    fi
    
    # Stale branches detection
    local stale_branches='[]'
    local current_epoch=$(date +%s)
    local stale_days="${AIPM_DEFAULTS_LIMITS_BRANCHAGEDAYS:-90}"
    
    echo "$branches" | jq -r 'to_entries[] | @json' | while IFS= read -r entry; do
        local branch_name=$(echo "$entry" | jq -r '.key')
        local branch_data=$(echo "$entry" | jq -r '.value')
        
        local is_protected=$(echo "$branch_data" | jq -r '.isProtected')
        local type=$(echo "$branch_data" | jq -r '.type')
        local last_commit=$(echo "$branch_data" | jq -r '.lastCommit')
        
        if [[ "$is_protected" == "false" ]] && [[ "$type" != "main" ]] && [[ "$type" != "user" ]]; then
            if [[ -n "$last_commit" ]] && [[ "$last_commit" != "null" ]]; then
                local last_epoch=$(date -d "$last_commit" +%s 2>/dev/null || echo 0)
                if [[ $last_epoch -gt 0 ]]; then
                    local days_old=$(( (current_epoch - last_epoch) / 86400 ))
                    if [[ $days_old -gt $stale_days ]]; then
                        stale_branches=$(echo "$stale_branches" | jq --arg b "$branch_name" --arg d "$days_old" \
                            '. += [{branch: $b, daysOld: ($d | tonumber), reason: "No activity for \($d) days"}]')
                    fi
                fi
            fi
        fi
    done
    
    # Branches ready for cleanup
    local cleanup_branches='[]'
    
    echo "$branches" | jq -r 'to_entries[] | @json' | while IFS= read -r entry; do
        local branch_name=$(echo "$entry" | jq -r '.key')
        local branch_data=$(echo "$entry" | jq -r '.value')
        
        local scheduled_delete=$(echo "$branch_data" | jq -r '.scheduledDelete')
        local delete_date=$(echo "$branch_data" | jq -r '.deleteDate // ""')
        
        if [[ "$scheduled_delete" == "immediate" ]]; then
            cleanup_branches=$(echo "$cleanup_branches" | jq --arg b "$branch_name" \
                '. += [{branch: $b, reason: "Scheduled for immediate deletion"}]')
        elif [[ "$scheduled_delete" == "scheduled" ]] && [[ -n "$delete_date" ]]; then
            local delete_epoch=$(date -d "$delete_date" +%s 2>/dev/null || echo 0)
            if [[ $delete_epoch -gt 0 ]] && [[ $delete_epoch -le $current_epoch ]]; then
                cleanup_branches=$(echo "$cleanup_branches" | jq --arg b "$branch_name" \
                    '. += [{branch: $b, reason: "Deletion date reached"}]')
            fi
        fi
    done
    
    # Session count check for max sessions
    if [[ -n "$AIPM_LIFECYCLE_SESSION_MAXSESSIONS" ]]; then
        local session_branches=$(echo "$branches" | jq '[to_entries[] | select(.value.type == "session") | {branch: .key, lastCommit: .value.lastCommit}] | sort_by(.lastCommit)')
        local session_count=$(echo "$session_branches" | jq 'length')
        local max_sessions="${AIPM_LIFECYCLE_SESSION_MAXSESSIONS}"
        
        if [[ $session_count -gt $max_sessions ]]; then
            local excess=$((session_count - max_sessions))
            local old_sessions=$(echo "$session_branches" | jq --arg e "$excess" '.[:($e | tonumber)]')
            
            echo "$old_sessions" | jq -r '.[] | .branch' | while read -r old_session; do
                cleanup_branches=$(echo "$cleanup_branches" | jq --arg b "$old_session" \
                    '. += [{branch: $b, reason: "Exceeds max session count"}]')
            done
        fi
    fi
    
    # Next session name
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local session_pattern="${AIPM_SESSIONS_NAMEPATTERN:-session/{timestamp}}"
    session_pattern="${session_pattern//\{timestamp\}/$timestamp}"
    local next_session="${AIPM_BRANCHING_PREFIX}${session_pattern}"
    
    # Should perform sync operations
    local should_fetch="false"
    local fetch_reason=""
    
    if [[ "$AIPM_TEAM_FETCHONSTART" == "true" ]]; then
        if [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART" == "always" ]]; then
            should_fetch="true"
            fetch_reason="Always fetch on start"
        elif [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART" == "if-clean" ]] && [[ "$working_tree_clean" == "true" ]]; then
            should_fetch="true"
            fetch_reason="Fetch when working tree is clean"
        elif [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PULLONSTART" == "prompt" ]]; then
            should_fetch="prompt"
            fetch_reason="User will be prompted"
        fi
    fi
    
    local should_push="false"
    local push_reason=""
    
    if [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP" == "always" ]]; then
        should_push="true"
        push_reason="Always push on stop"
    elif [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP" == "if-feature" ]]; then
        if [[ -n "$current_branch" ]]; then
            local current_type=$(echo "$branches" | jq -r --arg b "$current_branch" '.[$b].type // "unknown"')
            if [[ "$current_type" == "feature" ]] || [[ "$current_type" == "bugfix" ]]; then
                should_push="true"
                push_reason="Push feature/bugfix branches"
            fi
        fi
    elif [[ "$AIPM_WORKFLOWS_SYNCHRONIZATION_PUSHONSTOP" == "prompt" ]]; then
        should_push="prompt"
        push_reason="User will be prompted"
    fi
    
    # Build complete decisions object
    decisions=$(jq -n \
        --arg cc "$can_create" \
        --argjson ccr "$cannot_create_reasons" \
        --arg st "$suggested_type" \
        --arg str "$type_suggestion_reason" \
        --arg cm "$can_merge" \
        --argjson cmr "$cannot_merge_reasons" \
        --arg mt "$merge_target" \
        --arg ms "$merge_strategy" \
        --argjson sb "$stale_branches" \
        --argjson cb "$cleanup_branches" \
        --arg ns "$next_session" \
        --arg vm "$AIPM_VALIDATION_MODE" \
        --arg sf "$should_fetch" \
        --arg sfr "$fetch_reason" \
        --arg sp "$should_push" \
        --arg spr "$push_reason" \
        '{
            canCreateBranch: ($cc == "true"),
            cannotCreateReasons: $ccr,
            suggestedBranchType: $st,
            typeSuggestionReason: $str,
            canMergeCurrentBranch: ($cm == "true"),
            cannotMergeReasons: $cmr,
            mergeTarget: (if $mt != "" then $mt else null end),
            mergeStrategy: (if $ms != "" then $ms else null end),
            staleBranches: $sb,
            branchesForCleanup: $cb,
            nextSessionName: $ns,
            validationMode: $vm,
            shouldFetchOnStart: $sf,
            fetchReason: (if $sfr != "" then $sfr else null end),
            shouldPushOnStop: $sp,
            pushReason: (if $spr != "" then $spr else null end)
        }')
    
    # Add all relevant prompts based on workflows
    local prompts='{}'
    
    # Add branch creation prompts
    if [[ "$AIPM_WORKFLOWS_BRANCHCREATION_PROTECTIONRESPONSE" == "prompt" ]]; then
        prompts=$(echo "$prompts" | echo "$computed" | jq '.workflows.branchCreation.prompts.protected as $p | {protectedBranch: $p}')
    fi
    
    if [[ "$AIPM_WORKFLOWS_BRANCHCREATION_TYPESELECTION" == "prompt" ]]; then
        prompts=$(echo "$prompts" | echo "$computed" | jq '.workflows.branchCreation.prompts.typeSelection as $p | . + {branchType: $p}')
    fi
    
    # Add merge prompts
    if [[ "$AIPM_WORKFLOWS_MERGING_FEATURECOMPLETE" == "prompt" ]]; then
        prompts=$(echo "$prompts" | echo "$computed" | jq '.workflows.merging.prompts.featureComplete as $p | . + {featureComplete: $p}')
    fi
    
    if [[ "$AIPM_WORKFLOWS_MERGING_CONFLICTHANDLING" == "interactive" ]]; then
        prompts=$(echo "$prompts" | echo "$computed" | jq '.workflows.merging.prompts.mergeConflict as $p | . + {mergeConflict: $p}')
    fi
    
    # Add sync prompts
    if [[ "$should_fetch" == "prompt" ]]; then
        prompts=$(echo "$prompts" | echo "$computed" | jq '.workflows.synchronization.prompts.pullOnStart as $p | . + {pullOnStart: $p}')
    fi
    
    if [[ "$should_push" == "prompt" ]]; then
        prompts=$(echo "$prompts" | echo "$computed" | jq '.workflows.synchronization.prompts.pushOnStop as $p | . + {pushOnStop: $p}')
    fi
    
    # Add cleanup prompts
    if [[ "$AIPM_WORKFLOWS_CLEANUP_AFTERMERGE" == "prompt" ]]; then
        prompts=$(echo "$prompts" | echo "$computed" | jq '.workflows.cleanup.prompts.afterMerge as $p | . + {afterMerge: $p}')
    fi
    
    decisions=$(echo "$decisions" | jq --argjson p "$prompts" '.prompts = $p')
    
    echo "$decisions"
}

# ============================================================================
# MAIN STATE MANAGEMENT FUNCTIONS
# ============================================================================

# Initialize complete state from scratch
initialize_state() {
    section "Initializing Complete AIPM State"
    
    # Check dependencies
    check_jq_installed
    ensure_state_dir
    
    # Acquire lock
    acquire_state_lock
    
    # Ensure opinions are loaded
    if ! opinions_loaded; then
        info "Loading opinions..."
        load_and_export_opinions || die "Failed to load opinions"
    fi
    
    info "Building complete state with all pre-computations..."
    
    # Get opinions hash
    local opinions_hash=""
    if [[ -f "$OPINIONS_FILE_PATH" ]]; then
        opinions_hash=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
    fi
    
    # Build metadata
    local metadata=$(jq -n \
        --arg v "1.0" \
        --arg g "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg h "$opinions_hash" \
        --arg ws "$AIPM_WORKSPACE_NAME" \
        --arg wt "$AIPM_WORKSPACE_TYPE" \
        '{
            version: $v,
            generated: $g,
            opinionsHash: $h,
            lastRefresh: $g,
            workspace: {
                name: $ws,
                type: $wt
            }
        }')
    
    # Collect ALL raw exports
    info "Collecting all raw exports..."
    local raw_exports='{}'
    while IFS='=' read -r name value; do
        if [[ "$name" =~ ^AIPM_ ]]; then
            raw_exports=$(echo "$raw_exports" | jq --arg k "$name" --arg v "$value" '.[$k] = $v')
        fi
    done < <(compgen -A export | while read var; do printf "%s=%s\n" "$var" "${!var}"; done)
    
    # Compute ALL derived values
    info "Computing all derived values..."
    local computed=$(jq -n \
        --arg mb "${AIPM_COMPUTED_MAINBRANCH}" \
        --argjson bp "$(compute_all_branch_patterns)" \
        --argjson pb "$(compute_protected_branches_list)" \
        --argjson lm "$(compute_complete_lifecycle_matrix)" \
        --argjson wf "$(compute_complete_workflow_rules)" \
        --argjson val "$(compute_complete_validation_rules)" \
        --argjson mem "$(compute_complete_memory_config)" \
        --argjson team "$(compute_complete_team_config)" \
        --argjson sess "$(compute_complete_session_config)" \
        --argjson load "$(compute_loading_config)" \
        --argjson init "$(compute_initialization_config)" \
        --argjson def "$(compute_defaults_and_limits)" \
        --argjson err "$(compute_error_handling_config)" \
        --argjson set "$(compute_settings_config)" \
        '{
            mainBranch: $mb,
            branchPatterns: $bp,
            protectedBranches: $pb,
            lifecycleMatrix: $lm,
            workflows: $wf,
            validation: $val,
            memory: $mem,
            team: $team,
            sessions: $sess,
            loading: $load,
            initialization: $init,
            defaults: $def,
            errorHandling: $err,
            settings: $set
        }')
    
    # Get complete runtime state
    info "Querying complete git state..."
    local runtime_branches=$(get_complete_runtime_branches)
    local runtime_state=$(get_complete_runtime_state)
    local runtime=$(echo "$runtime_state" | jq --argjson b "$runtime_branches" '.branches = $b')
    
    # Make ALL decisions
    info "Pre-computing all decisions..."
    local decisions=$(make_complete_decisions "$runtime" "$computed")
    
    # Build complete state
    local state=$(jq -n \
        --argjson meta "$metadata" \
        --argjson raw "$raw_exports" \
        --argjson comp "$computed" \
        --argjson run "$runtime" \
        --argjson dec "$decisions" \
        '{
            metadata: $meta,
            raw_exports: $raw,
            computed: $comp,
            runtime: $run,
            decisions: $dec
        }')
    
    # Write state file
    write_state_file "$state"
    
    # Release lock
    release_state_lock
    
    success "Complete state initialized successfully"
    info "State file: $STATE_FILE"
}

# Get value from state (instant lookup!)
get_value() {
    local path="$1"
    
    # Ensure state is loaded
    if [[ "$STATE_LOADED" != "true" ]]; then
        if ! read_state_file; then
            warn "State not initialized, initializing now..."
            initialize_state
        fi
    fi
    
    # Extract value using jq path
    echo "$STATE_CACHE" | jq -r ".$path // empty"
}

# Get value with default
get_value_or_default() {
    local path="$1"
    local default="$2"
    
    local value=$(get_value "$path")
    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Refresh specific part of state
refresh_state() {
    local what="${1:-all}"
    
    info "Refreshing state: $what"
    
    acquire_state_lock
    
    # Read current state
    if ! read_state_file; then
        release_state_lock
        initialize_state
        return
    fi
    
    local state="$STATE_CACHE"
    
    case "$what" in
        branches|runtime)
            # Refresh runtime state only
            info "Refreshing runtime branches and git state..."
            local runtime_branches=$(get_complete_runtime_branches)
            local runtime_state=$(get_complete_runtime_state)
            local runtime=$(echo "$runtime_state" | jq --argjson b "$runtime_branches" '.branches = $b')
            
            # Update runtime in state
            state=$(echo "$state" | jq --argjson r "$runtime" '.runtime = $r')
            
            # Recompute decisions with new runtime
            local computed=$(echo "$state" | jq '.computed')
            local decisions=$(make_complete_decisions "$runtime" "$computed")
            state=$(echo "$state" | jq --argjson d "$decisions" '.decisions = $d')
            ;;
            
        decisions)
            # Recompute decisions only
            info "Recomputing all decisions..."
            local runtime=$(echo "$state" | jq '.runtime')
            local computed=$(echo "$state" | jq '.computed')
            local decisions=$(make_complete_decisions "$runtime" "$computed")
            state=$(echo "$state" | jq --argjson d "$decisions" '.decisions = $d')
            ;;
            
        computed)
            # Refresh computed values (if opinions changed)
            info "Recomputing all derived values..."
            ensure_opinions_loaded
            
            # Recompute everything
            local computed=$(jq -n \
                --arg mb "${AIPM_COMPUTED_MAINBRANCH}" \
                --argjson bp "$(compute_all_branch_patterns)" \
                --argjson pb "$(compute_protected_branches_list)" \
                --argjson lm "$(compute_complete_lifecycle_matrix)" \
                --argjson wf "$(compute_complete_workflow_rules)" \
                --argjson val "$(compute_complete_validation_rules)" \
                --argjson mem "$(compute_complete_memory_config)" \
                --argjson team "$(compute_complete_team_config)" \
                --argjson sess "$(compute_complete_session_config)" \
                --argjson load "$(compute_loading_config)" \
                --argjson init "$(compute_initialization_config)" \
                --argjson def "$(compute_defaults_and_limits)" \
                --argjson err "$(compute_error_handling_config)" \
                --argjson set "$(compute_settings_config)" \
                '{
                    mainBranch: $mb,
                    branchPatterns: $bp,
                    protectedBranches: $pb,
                    lifecycleMatrix: $lm,
                    workflows: $wf,
                    validation: $val,
                    memory: $mem,
                    team: $team,
                    sessions: $sess,
                    loading: $load,
                    initialization: $init,
                    defaults: $def,
                    errorHandling: $err,
                    settings: $set
                }')
            
            state=$(echo "$state" | jq --argjson c "$computed" '.computed = $c')
            
            # Recompute decisions with new computed values
            local runtime=$(echo "$state" | jq '.runtime')
            local decisions=$(make_complete_decisions "$runtime" "$computed")
            state=$(echo "$state" | jq --argjson d "$decisions" '.decisions = $d')
            ;;
            
        all|*)
            # Full refresh
            release_state_lock
            initialize_state
            return
            ;;
    esac
    
    # Update metadata
    state=$(echo "$state" | jq --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.metadata.lastRefresh = $t')
    
    # Write updated state
    write_state_file "$state"
    
    release_state_lock
    
    success "State refreshed: $what"
}

# Check if state needs refresh
needs_state_refresh() {
    # Check if state file exists
    if [[ ! -f "$STATE_FILE" ]]; then
        return 0
    fi
    
    # Check opinions.yaml hash
    if [[ -f "$OPINIONS_FILE_PATH" ]]; then
        local current_hash=$(sha256sum "$OPINIONS_FILE_PATH" | cut -d' ' -f1)
        local stored_hash=$(get_value "metadata.opinionsHash")
        
        if [[ "$current_hash" != "$stored_hash" ]]; then
            info "Opinions file has changed"
            return 0
        fi
    fi
    
    # Check age (refresh if older than 5 minutes)
    local last_refresh=$(get_value "metadata.lastRefresh")
    if [[ -n "$last_refresh" ]]; then
        local last_epoch=$(date -d "$last_refresh" +%s 2>/dev/null || echo 0)
        local now_epoch=$(date +%s)
        local age_minutes=$(( (now_epoch - last_epoch) / 60 ))
        
        if [[ $age_minutes -gt 5 ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Ensure state is valid and current
ensure_state() {
    if needs_state_refresh; then
        initialize_state
    elif [[ "$STATE_LOADED" != "true" ]]; then
        read_state_file || initialize_state
    fi
}

# ============================================================================
# CONVENIENCE FUNCTIONS - Easy access to common values
# ============================================================================

# Get current branch info
get_current_branch_info() {
    ensure_state
    local current=$(get_value "runtime.currentBranch")
    if [[ -n "$current" ]]; then
        get_value "runtime.branches.$current"
    fi
}

# Check if can perform operation
can_perform() {
    local operation="$1"
    ensure_state
    
    case "$operation" in
        create-branch)
            get_value "decisions.canCreateBranch"
            ;;
        merge)
            get_value "decisions.canMergeCurrentBranch"
            ;;
        push)
            local should_push=$(get_value "decisions.shouldPushOnStop")
            [[ "$should_push" == "true" ]] && echo "true" || echo "false"
            ;;
        fetch)
            local should_fetch=$(get_value "decisions.shouldFetchOnStart")
            [[ "$should_fetch" == "true" ]] && echo "true" || echo "false"
            ;;
        *)
            echo "false"
            ;;
    esac
}

# Get branches for cleanup
get_cleanup_branches() {
    ensure_state
    get_value "decisions.branchesForCleanup"
}

# Get prompt for operation
get_prompt() {
    local operation="$1"
    ensure_state
    get_value "decisions.prompts.$operation"
}

# Get workflow rule
get_workflow_rule() {
    local path="$1"
    ensure_state
    get_value "computed.workflows.$path"
}

# Get validation rule
get_validation_rule() {
    local path="$1"
    ensure_state
    get_value "computed.validation.$path"
}

# ============================================================================
# TESTING AND DEBUGGING
# ============================================================================

# Dump current state (for debugging)
dump_state() {
    ensure_state
    echo "$STATE_CACHE" | jq '.'
}

# Validate state integrity
validate_state() {
    if ! read_state_file; then
        error "No state file found"
        return 1
    fi
    
    # Check required sections
    for section in metadata raw_exports computed runtime decisions; do
        if ! echo "$STATE_CACHE" | jq -e ".$section" >/dev/null 2>&1; then
            error "Missing required section: $section"
            return 1
        fi
    done
    
    # Check computed has all required subsections
    local computed_sections=(mainBranch branchPatterns protectedBranches lifecycleMatrix workflows validation memory team sessions loading initialization defaults errorHandling settings)
    for section in "${computed_sections[@]}"; do
        if ! echo "$STATE_CACHE" | jq -e ".computed.$section" >/dev/null 2>&1; then
            error "Missing computed section: $section"
            return 1
        fi
    done
    
    success "State validation passed"
    return 0
}

# Show state summary
show_state_summary() {
    ensure_state
    
    info "State Summary:"
    info "============="
    info "Workspace: $(get_value 'metadata.workspace.name') ($(get_value 'metadata.workspace.type'))"
    info "Main Branch: $(get_value 'computed.mainBranch')"
    info "Current Branch: $(get_value 'runtime.currentBranch')"
    info "Working Tree Clean: $(get_value 'runtime.workingTreeClean')"
    info "Can Create Branch: $(get_value 'decisions.canCreateBranch')"
    info "Can Merge: $(get_value 'decisions.canMergeCurrentBranch')"
    info "Validation Mode: $(get_value 'computed.validation.mode')"
    info "Total Branches: $(echo "$STATE_CACHE" | jq '.runtime.branches | length')"
    info "Stale Branches: $(echo "$STATE_CACHE" | jq '.decisions.staleBranches | length')"
    info "Cleanup Candidates: $(echo "$STATE_CACHE" | jq '.decisions.branchesForCleanup | length')"
}

# Auto-initialize if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init|initialize)
            initialize_state
            ;;
        refresh)
            refresh_state "${2:-all}"
            ;;
        get)
            get_value "$2"
            ;;
        dump)
            dump_state
            ;;
        validate)
            validate_state
            ;;
        summary)
            show_state_summary
            ;;
        *)
            info "Usage: $0 {init|refresh|get|dump|validate|summary}"
            info ""
            info "Commands:"
            info "  init      - Initialize state from scratch"
            info "  refresh   - Refresh state (all|branches|decisions|computed)"
            info "  get PATH  - Get value at path (e.g., decisions.canCreateBranch)"
            info "  dump      - Dump entire state as JSON"
            info "  validate  - Validate state integrity"
            info "  summary   - Show state summary"
            ;;
    esac
fi