# Current Repo Root and Remote Pointer

Status: ACTIVE_REPO_POINTER_V1
Updated: 2026-07-06T22:56:39+04:00

## Canonical current working repo

```text
H:\efab
```

## Canonical GitHub backup repo

```text
https://github.com/ries11217596955-hash/efab.git
```

## Branch

```text
main
```

## Proof boundary at pointer creation

```text
local_head=0d4b0eebc81c851eb02f86fb70d675f1c0b83d2f
remote_origin=https://github.com/ries11217596955-hash/efab.git
sync_status=PROVEN_LOCAL_REMOTE_0_0_BEFORE_POINTER_UPDATE
map_validator=PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1_BEFORE_POINTER_UPDATE
```

## Old repo boundary

```text
C:\Users\Azerbaijan\Downloads\e-factory-agent-builder
```

The old repo is archive/reference only. It is not the active working body and must not be used for Builder growth, Codex tasks, readiness validation, or GitHub backup sync unless Owner explicitly requests archive recovery.

## Operator rule

Before any repo mutation, terminal command, Codex task, validator claim, or push:

```text
expected_root=H:\efab
branch=main
origin=https://github.com/ries11217596955-hash/efab.git
```

If the observed root/branch/origin does not match, stop with:

```text
STATUS: BLOCKED_PREFLIGHT
STOP: REPO_CONTEXT_MISMATCH
```