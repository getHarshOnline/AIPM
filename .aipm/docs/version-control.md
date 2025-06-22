# Version Control Architecture

## Overview

`version-control.sh` is the **single gateway** for all git operations in AIPM, ensuring atomic state management through bidirectional integration with `opinions-state.sh`.

## Architecture Principles

```
1. Single Source of Truth: ONLY version-control.sh calls git
2. Atomic Operations: Git + State succeed or fail together  
3. Bidirectional Sync: Git operations ↔ State updates
4. Formatted Output: All output through shell-formatting.sh
```

## System Architecture

```mermaid
graph TB
    subgraph "AIPM Core Architecture"
        subgraph "Configuration Layer"
            OY[opinions.yaml]
            OL[opinions-loader.sh]
        end
        
        subgraph "State Layer"
            OS[opinions-state.sh]
            WJ[workspace.json]
            LOCK[State Lock]
        end
        
        subgraph "Operations Layer"
            VC[version-control.sh]
            SF[shell-formatting.sh]
            MM[migrate-memories.sh]
        end
        
        subgraph "External"
            GIT[(Git Repo)]
            TERM[Terminal]
            MEM[Memory Files]
        end
    end
    
    OY -->|load| OL
    OL -->|export AIPM_*| OS
    OS <-->|read/write| WJ
    OS <-->|bidirectional| VC
    OS -->|lock| LOCK
    
    VC -->|ONLY module| GIT
    VC -->|format| SF
    SF -->|output| TERM
    
    MM -->|memory ops| MEM
    MM -->|state updates| OS
    
    style VC fill:#ff6b6b,stroke:#333,stroke-width:4px
    style OS fill:#4ecdc4,stroke:#333,stroke-width:4px
    style LOCK fill:#ffe66d,stroke:#333,stroke-width:2px
```

## Lock Management Architecture

```mermaid
graph LR
    subgraph "Concurrent Operation Protection"
        OP1[Operation 1] -->|acquire| LOCK{State Lock}
        OP2[Operation 2] -->|wait| LOCK
        OP3[Operation 3] -->|wait| LOCK
        
        LOCK -->|exclusive| STATE[State File]
        STATE -->|atomic update| WJ[workspace.json]
        
        LOCK -->|release| NEXT[Next Operation]
    end
    
    subgraph "Lock Implementation"
        FLOCK[flock<br/>Kernel Lock]
        MKDIR[mkdir<br/>Directory Lock]
        TIMEOUT[30s Timeout]
    end
    
    style LOCK fill:#ffe66d
    style STATE fill:#4ecdc4
```

## Atomic Operation Flow

```mermaid
sequenceDiagram
    participant C as Caller
    participant VC as version-control.sh
    participant LOCK as State Lock
    participant GIT as Git
    participant OS as opinions-state.sh
    participant WJ as workspace.json
    participant SF as shell-formatting.sh
    
    Note over C,SF: Atomic Checkout Example
    
    C->>VC: checkout_branch("feature/new")
    VC->>VC: Save rollback state
    
    VC->>LOCK: acquire_state_lock()
    LOCK-->>VC: Lock acquired
    
    VC->>GIT: git checkout feature/new
    
    alt Git Success
        GIT-->>VC: Success
        VC->>OS: update_state("runtime.currentBranch", "feature/new")
        OS->>WJ: Write state
        WJ-->>OS: Written
        OS-->>VC: State updated
        
        VC->>OS: refresh_state("branches")
        OS->>GIT: git branch --all
        GIT-->>OS: Branch list
        OS->>WJ: Update branch cache
        OS-->>VC: Refreshed
        
        VC->>LOCK: release_state_lock()
        VC->>SF: success("Switched to feature/new")
        SF-->>C: ✓ Displayed
        VC-->>C: return 0
        
    else Git Failure
        GIT-->>VC: Error
        VC->>LOCK: release_state_lock()
        VC->>SF: error("Checkout failed")
        SF-->>C: ✗ Displayed
        VC-->>C: return 1
    end
```

## State Integration Architecture

```mermaid
graph TB
    subgraph "State Updates Flow Both Ways"
        subgraph "Git → State"
            G1[Git Operation] -->|triggers| S1[State Update]
            S1 -->|updates| C1[Cache Refresh]
            C1 -->|notifies| W1[Workspace Sync]
        end
        
        subgraph "State → Git"  
            S2[State Query] -->|validates| G2[Git Reality]
            G2 -->|mismatch| S3[State Correction]
            S3 -->|triggers| G3[Git Sync]
        end
    end
    
    subgraph "Operation Types"
        READ[Read Ops<br/>get_status<br/>list_branches]
        WRITE[Write Ops<br/>commit<br/>checkout]
        SYNC[Sync Ops<br/>pull<br/>push]
    end
    
    READ -->|always updates| S1
    WRITE -->|atomic with| S1
    SYNC -->|full refresh| C1
```

## Module Integration Points

```mermaid
graph LR
    subgraph "version-control.sh Functions"
        subgraph "Branch Operations"
            CB[checkout_branch]
            CR[create_branch]
            DB[delete_branch]
        end
        
        subgraph "Status Operations"
            GS[get_status]
            GSP[get_status_porcelain]
            CU[count_uncommitted]
        end
        
        subgraph "Sync Operations"
            PL[pull_latest]
            PS[push_changes]
            FR[fetch_remote]
        end
    end
    
    subgraph "State Integration"
        US[update_state]
        RS[refresh_state]
        GV[get_value]
    end
    
    subgraph "Output Functions"
        SEC[section]
        SUC[success]
        ERR[error]
        INF[info]
    end
    
    CB -->|atomic| US
    CR -->|atomic| US
    DB -->|atomic| US
    
    GS -->|sync| RS
    GSP -->|sync| US
    CU -->|sync| US
    
    PL -->|full| RS
    PS -->|update| US
    FR -->|check| GV
    
    CB -->|result| SUC
    CB -->|fail| ERR
    GS -->|display| INF
```

## Critical Functions & State Updates

### Branch Operations
```mermaid
graph TB
    subgraph "checkout_branch()"
        CHK1[Save Current State] --> CHK2[Git Checkout]
        CHK2 -->|success| CHK3[Update currentBranch]
        CHK3 --> CHK4[Refresh branches.*]
        CHK2 -->|fail| CHK5[No State Change]
    end
    
    subgraph "create_branch()"
        CR1[Validate Name] --> CR2[Git Branch]
        CR2 -->|success| CR3[Append branches.all]
        CR3 --> CR4[Update branches.count]
        CR2 -->|fail| CR5[No State Change]
    end
    
    subgraph "delete_branch()"
        DEL1[Check Merged] --> DEL2[Git Branch -d]
        DEL2 -->|success| DEL3[Remove from branches.*]
        DEL3 --> DEL4[Update counts]
        DEL2 -->|fail| DEL5[No State Change]
    end
```

### State Synchronization Points

| Operation | State Path | Update Type | Lock Required |
|-----------|------------|-------------|---------------|
| checkout | runtime.currentBranch | Direct | Yes |
| branch --all | runtime.branches.all | Full Replace | Yes |
| status | runtime.git.uncommittedCount | Direct | Yes |
| commit | runtime.git.uncommittedCount<br>runtime.git.lastCommit | Multiple | Yes |
| fetch | runtime.git.hasNewRemote | Check | Yes |
| pull | runtime.branches.*<br>runtime.git.ahead/behind | Refresh | Yes |
| push | runtime.lastSync | Timestamp | Yes |

## Function Implementation Pattern

```bash
# Every function MUST follow this pattern
function_name() {
    local param="$1"
    
    # 1. Pre-operation state
    local rollback_state=$(get_current_state)
    
    # 2. Acquire lock for atomic operation
    acquire_state_lock
    
    # 3. Git operation
    if git command "$param"; then
        # 4. State update (atomic with git)
        update_state "state.path" "new_value"
        release_state_lock
        
        # 5. Success output
        success "Operation completed"
        return 0
    else
        # 6. No state change on git failure
        release_state_lock
        error "Operation failed"
        return 1
    fi
}
```

## Missing Functions Architecture

```mermaid
graph TB
    subgraph "Configuration Functions"
        GGC[get_git_config] -->|updates| CFG[runtime.git.config.*]
    end
    
    subgraph "Status Functions"
        GSP[get_status_porcelain] -->|updates| UC[uncommittedCount]
        GSP -->|updates| IC[isClean]
        CUF[count_uncommitted_files] -->|reads| GSP
    end
    
    subgraph "Branch Functions"
        GBC[get_branch_commit] -->|caches| BCM[branches.commits.*]
        LMB[list_merged_branches] -->|updates| BRM[branches.merged]
        GUB[get_upstream_branch] -->|tracks| BRU[branches.upstream.*]
    end
    
    subgraph "Log Functions"
        GBL[get_branch_log] -->|query| GIT[(Git)]
        GBCD[get_branch_creation_date] -->|caches| BRC[branches.created.*]
        GBLCD[get_branch_last_commit_date] -->|tracks| BRA[branches.lastActivity.*]
    end
    
    style GSP fill:#ff6b6b
    style GBC fill:#ff6b6b
    style GUB fill:#ff6b6b
```

## Error Handling & Rollback

```mermaid
stateDiagram-v2
    [*] --> Validate
    Validate --> SaveState: Valid
    Validate --> Error: Invalid
    
    SaveState --> GitOp
    GitOp --> StateUpdate: Success
    GitOp --> Rollback: Failure
    
    StateUpdate --> Success: Updated
    StateUpdate --> GitRollback: Failed
    
    GitRollback --> Rollback
    Rollback --> Error
    
    Success --> [*]
    Error --> [*]
```

## Performance Considerations

```mermaid
graph LR
    subgraph "Cached Operations"
        CC[Current Branch<br/>Cached in State]
        BC[Branch List<br/>Refreshed on Demand]
        SC[Status Count<br/>Updated on Query]
    end
    
    subgraph "Direct Git Calls"
        GC[git command]
        GC2[git command]
        GC3[git command]
    end
    
    subgraph "Optimization"
        CACHE[State Cache] -->|avoid| GC
        BATCH[Batch Updates] -->|reduce| GC2
        LAZY[Lazy Refresh] -->|defer| GC3
    end
```

## Summary

This architecture ensures:
1. **No git calls outside version-control.sh**
2. **Every git operation atomically updates state**
3. **Locks prevent concurrent state corruption**
4. **All output properly formatted**
5. **Rollback possible for failed operations**

The bidirectional integration between `version-control.sh` and `opinions-state.sh` eliminates state desync by design.