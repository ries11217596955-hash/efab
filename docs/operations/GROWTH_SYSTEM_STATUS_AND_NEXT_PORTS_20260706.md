# Growth System Status and Next Ports - 2026-07-06 Current Pointer

Status: ACTIVE_CURRENT_STATUS_POINTER_V2
Updated: 2026-07-06T23:01:00+04:00

## Current canonical repo

```text
ACTIVE_WORKING_REPO=H:\efab
ACTIVE_GITHUB_REPO=https://github.com/ries11217596955-hash/efab.git
ACTIVE_BRANCH=main
OLD_REPO=C:\Users\Azerbaijan\Downloads\e-factory-agent-builder
OLD_REPO_ROLE=ARCHIVE_REFERENCE_ONLY
```

## What was closed in this chat

```text
CLEAN_REPO_CUTOVER=PROVEN
GITHUB_BACKUP_SYNC=PROVEN
ACTIVE_REPO_POINTER=PROVEN
AGENTS_REPO_IDENTITY_UPDATED=PROVEN
JOURNAL_CUTOVER_POINTER_ADDED=PROVEN
MAP_VALIDATOR_STATUS=PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1
```

## What was found after cutover

The overnight school run/watch/validate scripts still contained hard-coded old repo root:

```text
C:/Users/Azerbaijan/Downloads/e-factory-agent-builder
```

This is a repo-context mismatch risk. These scripts must resolve repo root from `$PSScriptRoot` and run under `H:\efab`.

## Current route

Owner wants a night test run before sleep.

Night test must be treated as:

```text
PROVEN_LAB candidate only until final proof is inspected.
NOT_PROVEN_LIVE until a fresh final proof exists.
```

## Night run target

Use the existing overnight 30k full-process school mechanics runner after root repair:

```text
operations/overnight_school/run_useful_school_30k_full_process_v1.ps1
```

Expected proof class:

```text
PROVEN_LAB_MECHANICS_NOT_LIVE
```

## Next morning check

Use:

```text
operations/overnight_school/validate_useful_school_30k_full_process_v1.ps1
```

And inspect:

```text
H:/bridge/overnight_school_runs/<latest>/LIVE_STATUS.json
H:/bridge/overnight_school_runs/<latest>/USEFUL_SCHOOL_30K_FULL_PROCESS_V1_PROOF.json
```