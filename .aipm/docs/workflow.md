# AIPM Workflow Architecture

## Overview

AIPM workflows are defined in `opinions.yaml` and orchestrate WHEN wrapper scripts perform git operations. The `workflows` section (lines 787-985) defines automation rules that make AIPM work seamlessly for non-technical users.

## Core Concept: Workflow Automation

AIPM workflows answer the question: **"When should scripts automatically perform git operations?"**

Instead of users manually managing branches, merges, and syncs, AIPM's workflow rules automate these decisions based on context and user preferences.

## CRITICAL: Git Operation Architecture

**EXHAUSTIVE INVESTIGATION FINDING**: ALL git operations MUST go through version-control.sh functions. Direct git calls violate architecture and cause state desync.

### Correct Usage Pattern
```bash
# ❌ WRONG - Direct git call
git checkout "$branch"
update_state "runtime.currentBranch" "$branch"  # Separate = can fail

# ✅ CORRECT - Atomic operation through version-control.sh
checkout_branch "$branch"  # Handles git + state atomically
```

### Architecture Details
For complete git operations architecture including:
- Required functions and their state updates
- Lock management for atomic operations  
- Bidirectional integration patterns
- Implementation requirements

**See: [Version Control Architecture](version-control.md)** - The single source of truth for git operations.

## Workflow Categories

### 1. Branch Creation Triggers (`workflows.branchCreation`)

Controls when and how branches are created automatically.

#### `startBehavior` - What happens when starting work?
- **`check-first`** (default): Only create branch if none exists
- **`always`**: Create new branch every time
- **`manual`**: User must explicitly request

```yaml
# From opinions.yaml line 801
startBehavior: "check-first"  # Smart default - avoids branch explosion
```

#### `protectionResponse` - Saving to protected branches?
- **`prompt`** (default): Ask user what to do
- **`auto-branch`**: Automatically create feature branch
- **`block`**: Prevent save, show error

When set to `prompt`, users see:
```
You're trying to save to main branch. What would you like to do?
1) Create feature branch (continues save)
2) Create session branch (for experiments)
3) Cancel (aborts save)
```

#### `typeSelection` - How to pick branch type?
- **`prompt`** (default): Ask user which type
- **`auto-detect`**: Guess from content/context
- **`default`**: Always use feature type

Prompt shows:
```
What type of work is this?
1) Feature - New functionality (→ feature/description)
2) Bug Fix - Fixing an issue (→ fix/description)
3) Documentation - Docs only (→ docs/description)
4) Experiment - Just trying (→ test/description)
```

### 2. Merge Triggers (`workflows.merging`)

Controls when branches are merged back.

#### `sessionMerge` - When to merge temporary work?
- **`on-stop`** (default): Merge when stopping session
- **`on-save`**: Merge after each save
- **`manual`**: User must request merge
- **`never`**: Keep session branches separate

#### `featureComplete` - How to know feature is ready?
- **`prompt`** (default): Ask if ready to merge
- **`auto-detect`**: When marked as done
- **`manual`**: Explicit merge command

Prompt shows:
```
Is this feature complete and ready to merge?
1) Yes, merge now (→ starts merge process)
2) No, keep working (→ stays on branch)
3) Create PR for review (→ push & create PR)
```

#### `conflictHandling` - What if git can't auto-merge?
- **`interactive`** (default): Walk through conflicts
- **`abort`**: Stop and notify user
- **`force-local`**: Keep local version
- **`force-remote`**: Take remote version

### 3. Sync Triggers (`workflows.synchronization`)

Controls when to sync with remote repository.

#### `pullOnStart` - Should we get latest changes?
- **`if-clean`** (default): Only if no local changes
- **`always`**: Pull every time
- **`prompt`**: Ask user
- **`never`**: Don't auto-pull

Prompt shows:
```
Remote has new changes. Update now?
1) Yes, update (→ pulls changes)
2) No, work offline (→ continues without pull)
3) View changes first (→ shows what's new)
```

#### `pushOnStop` - Should we share changes?
- **`if-feature`** (default): Only push feature branches
- **`always`**: Push all branches
- **`prompt`**: Ask what to push
- **`never`**: Manual push only

Prompt shows:
```
You have unpushed changes. Share them?
1) Yes, push all (→ pushes to remote)
2) Push some (→ lists branches to choose)
3) No, keep local (→ changes stay local only)
```

#### `autoBackup` - Backup strategy during work
- **`on-save`** (default): Push after each save
- **`periodic`**: Based on intervals
- **`manual`**: User controls
- **`never`**: No auto-backup

### 4. Cleanup Triggers (`workflows.cleanup`)

Controls when to clean up branches.

#### `afterMerge` - Post-merge cleanup
- **`prompt`** (default): Ask user
- **`immediate`**: Delete right after merge
- **`scheduled`**: According to lifecycle rules
- **`never`**: Keep all branches

Prompt shows:
```
Branch merged successfully. Delete it?
1) Yes, delete now (→ removes branch)
2) Keep for now (→ branch remains)
3) Archive it (→ renames to archive/*)
```

#### `staleHandling` - Old, unused branches?
- **`notify`** (default): Tell user about stale branches
- **`auto-clean`**: Delete based on lifecycle
- **`ignore`**: Don't check for staleness

#### `failedWork` - Abandoned experiments?
- **`archive`** (default): Move to archive namespace
- **`delete`**: Remove completely
- **`keep`**: Leave as-is

### 5. Branch Flow Rules (`workflows.branchFlow`)

Defines where branches come from and merge to.

#### Sources - Where to branch FROM
```yaml
sources:
  default: "current"  # Branch from current location
  byType:
    "feature/*": "{mainBranch}"   # Features from main
    "fix/*": "{mainBranch}"       # Fixes from main
    "session/*": "current"        # Sessions from current
    "test/*": "current"           # Tests from current
```

#### Targets - Where to merge TO
```yaml
targets:
  default: "parent"  # Merge back to origin
  byType:
    "feature/*": "{mainBranch}"   # Features to main
    "fix/*": "{mainBranch}"       # Fixes to main
    "session/*": "parent"         # Sessions to parent
    "release/*": "none"           # Releases don't merge
```

## Integration with State Management

Workflows are pre-computed by `opinions-state.sh` and stored in `workspace.json`:

```json
{
  "computed": {
    "workflows": {
      "branchCreation": {
        "startBehavior": "check-first",
        "protectionResponse": "prompt",
        "prompts": {
          "protected": "You're trying to save to main..."
        }
      }
    }
  }
}
```

Wrapper scripts query these rules:
```bash
# In save.sh
local protection=$(get_workflow_rule "branchCreation.protectionResponse")
if [[ "$protection" == "prompt" ]]; then
    # Show prompt to user
fi
```

## User Experience

### For New Users
- Workflows default to `prompt` - educational and safe
- Clear explanations at each decision point
- Can't accidentally break things

### For Power Users
- Can change to `auto` modes for speed
- Batch operations supported
- Override individual decisions

### For Teams
- Consistent behavior across team
- Workflows enforce team standards
- Remote sync keeps everyone updated

## Workflow Examples

### Example 1: Starting New Feature
```bash
aipm start
# Workflow: startBehavior = "check-first"
# → No active branch, so creates one
# Workflow: typeSelection = "prompt"
# → User selects "Feature"
# → Branch created: AIPM_feature/new-dashboard
```

### Example 2: Saving Work
```bash
aipm save -d "Added dashboard component"
# On main branch...
# Workflow: protectionResponse = "prompt"
# → Shows protection prompt
# → User selects "Create feature branch"
# → Creates AIPM_feature/dashboard-update
# → Saves decision
```

### Example 3: Ending Session
```bash
aipm stop
# Workflow: sessionMerge = "on-stop"
# → Checks for session branch
# → If exists, merges to parent
# Workflow: pushOnStop = "if-feature"
# → If on feature branch, pushes changes
```

## Customization

Teams can adjust workflows in their `opinions.yaml`:

```yaml
# For a more automated experience
workflows:
  branchCreation:
    startBehavior: "always"        # New branch each time
    protectionResponse: "auto-branch"  # No prompts
  synchronization:
    pullOnStart: "always"          # Always stay synced
    pushOnStop: "always"           # Share everything
```

## Best Practices

1. **Start Conservative**: Use prompts while learning
2. **Evolve Gradually**: Move to automation as comfort grows
3. **Document Choices**: Explain workflow decisions in comments
4. **Test Changes**: Try workflow changes on test branches first
5. **Team Alignment**: Ensure team agrees on automation levels

## Summary

AIPM workflows transform git from a complex tool into an intelligent assistant. By defining WHEN operations should happen, workflows enable non-technical users to benefit from git's power without learning its complexity.

The key insight: **Workflows aren't about HOW git works, but WHEN git should act.**