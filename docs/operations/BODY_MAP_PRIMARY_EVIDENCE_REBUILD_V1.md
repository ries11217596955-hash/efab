# Body Map Primary Evidence Rebuild V1

Status: CODEX_DRAFT_VALIDATED_BY_LOCAL_VALIDATORS

## Purpose

`reports/self_development/SELF_MODEL_ACTIVE_MAP.json` remains the canonical auto-refreshed body composition map. Its generator now separates confirmed current components from candidate surfaces and legacy hints.

## Authority Rules

- `confirmed_components` are explicit required components with current repo evidence.
- `primary_evidence_candidates` come from bounded tracked-file discovery and always require triage.
- `legacy_unverified_hints` records old maps and prior snapshots as hints only.
- `rejected_or_stale_hints` records stale or unproven hints that must not create confirmed components.

## Legacy Boundary

The generator must not read `self_knowledge/BUILDER_SELF_MODEL.json` or `reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json` as raw authority. Those files may be referenced only as legacy hints.

## Validation

Dedicated validator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/validate_body_map_primary_evidence_rebuild_v1.ps1
```

Expected proof:

```text
tests/self_development/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1_PROOF.json
```

Runtime readiness remains unproven. Child-agent factory readiness remains `NOT_PROVEN`.
