# Map Authority Duplicate Audit V1

status: PASS_MAP_AUTHORITY_DUPLICATE_AUDIT_V1

## Finding

The current canonical body map is not the only map. It is the current generated authority, but it is incomplete for full organism inventory because the refresh module uses a hardcoded component list.

current canonical components: 7
parallel body capability snapshot components: 10
legacy self_knowledge module inventory modules: 42
legacy self_knowledge generated programs: 38
legacy self_knowledge produced agents: 93
expanded candidate audit strong candidates: 85

## Root cause

The current body map is rebuilt from `modules/invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1`, where components are declared through `New-Component` lines. So repeated refreshes preserve the narrow set instead of discovering the whole body.

## Boundary

Do not delete duplicate/legacy maps and do not promote the legacy map raw. Repair map authority first.

## Next step

MAP_AUTHORITY_REPAIR_V1_UNIFY_CURRENT_BODY_MAP_WITH_LEGACY_AND_SNAPSHOT_EVIDENCE_USING_VALIDATOR
