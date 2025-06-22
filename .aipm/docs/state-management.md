# AIPM State Management

## Overview

The state management system provides a high-performance caching layer that pre-computes all configuration values and decisions. This eliminates the need for runtime computation and ensures consistent, fast operations.

## Architecture

```
opinions.yaml → opinions-loader.sh → EXPORTS → opinions-state.sh → CACHED STATE
                                                       ↓
                                              .aipm/state/workspace.json
                                                       ↓
                                              All scripts read from here
```

## Key Components

### 1. opinions-loader.sh
- Pure transformation layer (YAML → shell exports)
- Validates configuration
- Provides raw exports only

### 2. opinions-state.sh
- State management layer
- Pre-computes ALL derived values
- Queries git for runtime state
- Makes ALL decisions upfront
- Caches everything in workspace.json

### 3. workspace.json
- Complete brain of AIPM
- Contains raw exports + computed values + runtime state + decisions
- Updated only when needed
- Single source of truth

## State Structure

```json
{
  "metadata": {
    "version": "1.0",
    "opinionsHash": "sha256:...",
    "lastRefresh": "2025-06-22T10:00:00Z"
  },
  "raw_exports": {
    // All AIPM_* environment variables
  },
  "computed": {
    // Pre-computed patterns, rules, matrices
  },
  "runtime": {
    // Current git state, branches, etc.
  },
  "decisions": {
    // Pre-made decisions for all operations
  }
}
```

## Benefits

1. **Performance**: No runtime computation needed
2. **Consistency**: All scripts see the same state
3. **Debugging**: Complete state visible in one file
4. **Separation**: Clear boundaries between loading, computing, and using

## Usage

### For Script Authors

```bash
# Source the state module
source opinions-state.sh

# Ensure state is current
ensure_state

# Get any value - no computation!
can_create=$(get_value "decisions.canCreateBranch")
merge_target=$(get_value "decisions.mergeTarget")
branch_pattern=$(get_value "computed.allBranchPatterns.feature")
```

### State Refresh Strategy

1. **Automatic**: On opinions.yaml change
2. **Periodic**: Every 5 minutes
3. **On-demand**: Via `refresh_state`
4. **Selective**: Can refresh just branches or decisions

### Example Integration

```bash
# In start.sh
ensure_state  # Ensures state is loaded and current

if [[ "$(get_value 'decisions.shouldFetchOnStart')" == "true" ]]; then
    git fetch origin
fi

# In save.sh
if [[ "$(get_value 'decisions.canMergeCurrentBranch')" == "true" ]]; then
    target=$(get_value "decisions.mergeTarget")
    git merge "$target"
fi
```

## State Management Commands

```bash
# Initialize state from scratch
./opinions-state.sh init

# Refresh runtime state only
./opinions-state.sh refresh branches

# Get a specific value
./opinions-state.sh get decisions.canCreateBranch

# Dump entire state (debugging)
./opinions-state.sh dump

# Validate state integrity
./opinions-state.sh validate
```

## How It Works

1. **Initialization**:
   - Loads raw exports via opinions-loader.sh
   - Computes all patterns, rules, and matrices
   - Queries git for branch states
   - Makes all possible decisions
   - Writes complete state to workspace.json

2. **Runtime**:
   - Scripts call `get_value()` - instant lookup
   - No YAML parsing, no rule evaluation
   - Everything is pre-computed

3. **Updates**:
   - Hash-based change detection
   - Selective refresh capability
   - Atomic file updates with locking

## Performance Impact

- Initial load: ~1 second (one-time cost)
- Subsequent reads: <1ms (just JSON lookup)
- Memory usage: ~100KB (entire state in memory)
- No repeated YAML parsing or git queries

## Future Enhancements

1. **State History**: Track state changes over time
2. **State Diff**: Show what changed between refreshes
3. **State Metrics**: Performance and usage statistics
4. **State Sync**: Share state across distributed teams