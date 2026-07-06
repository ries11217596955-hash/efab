# R4-HYGIENE-03 External Runtime Data Root Contract

Status: ACTIVE CONTRACT CANDIDATE

Problem:
The repo currently mixes source code, active Builder state, runtime data, and historical proof artifacts.

Contract:
- Source repo keeps code, validators, route locks, small proof summaries, manifests, checksums, pointers and active contracts.
- Source repo must not receive new bulky generated runtime folders.
- EFAB_DATA_ROOT is the external shared data root for large reusable runtime data.
- EFAB_WORK_ROOT is the short local transient work root for execution packages.
- Legacy repo-relative paths remain fallback until modules are patched.

Recommended EFAB_DATA_ROOT example:
G:\Мой диск\efab-data

Recommended EFAB_WORK_ROOT examples:
C:\efab-work
D:\efab-work
G:\efab-work

Raw shards rule:
D2 raw_shards are RUNTIME_DATA_ACTIVE_OR_REPLAY_NEEDED.
Do not delete or move raw_shards until D2B runner and validators support external data root and smoke tests pass.

Accepted state rule:
Do not move packs/registry.json, accepted_change_memory_snapshot.json, SELF_MODEL_ACTIVE_MAP.json or agent_body_map.json in this step.

R4-03 implication:
Before retrying R4-03, runtime work packages must avoid deep nested report paths.
