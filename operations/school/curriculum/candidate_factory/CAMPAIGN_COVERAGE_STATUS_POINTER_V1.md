# Campaign Coverage Status Pointer V1

STATUS: ACTIVE_POINTER_FOR_CODEX_PREFLIGHT
PURPOSE: prevent Codex from wasting limits by authoring campaign content without first knowing what levels/topics already exist and what gaps matter.

## Canonical files to inspect before any campaign authoring

Codex must read these before creating or updating a campaign pack:

```text
operations/school/curriculum/topics/builder_night_school_topics_v1.json
operations/school/curriculum/candidate_factory/memory/theme_cursor_ledger.json
operations/school/curriculum/candidate_factory/memory/active_compact_memory_snapshot_for_evidence_v1/manifest.json
operations/school/curriculum/candidate_factory/memory/active_compact_memory_snapshot_for_evidence_v1/index.json
operations/school/curriculum/candidate_factory/memory/active_compact_memory_snapshot_for_evidence_v1/cells_tail_sample_200.jsonl
operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md
operations/school/curriculum/candidate_factory/reports/THEME_CURSOR_LEDGER_REBUILD_V1_REPORT.json
```

## Current known snapshot

Last checked by GPT operator before Codex task:

```text
compact_snapshot_cell_count = 18021
compact_snapshot_index_terms = 18468
theme_cursor_ledger_theme_keys = 17922
theme_cursor_ledger_roots = 87
theme_cursor_ledger_verbs = 103
theme_cursor_ledger_modes = 2
theme_cursor_ledger_last_level_min = 0
theme_cursor_ledger_last_level_max = 0
theme_cursor_ledger_next_level_min = 1
theme_cursor_ledger_next_level_max = 1
```

## Critical warning

The theme cursor ledger currently appears to be a seed ledger, not a reliable completed-coverage ledger:

```text
ledger says all last_level=0 / next_level=1
compact snapshot says memory already has 18021 cells
```

Therefore Codex must not blindly start all topics at level 1. Codex must reconcile:

```text
topics plan
cursor ledger
compact snapshot/index/cell sample
journal/proof history
```

## Required Codex pre-campaign outputs

Before writing a campaign pack, Codex must produce compact tracked audit reports under the existing candidate_factory surface:

```text
operations/school/curriculum/candidate_factory/reports/CAMPAIGN_COVERAGE_AUDIT_V1.json
operations/school/curriculum/candidate_factory/reports/CAMPAIGN_LEVEL_PLAN_V1.json
```

Minimum fields per root/topic:

```text
root
memory_signal
cursor_signal
journal_signal
coverage_status = missing | weak | medium | saturated | unknown_conflict
recommended_start_level
recommended_seed_count
priority
reason
source_refs
```

## Acceptance rule

```text
No CAMPAIGN_COVERAGE_AUDIT_V1.json -> Codex task not accepted.
No CAMPAIGN_LEVEL_PLAN_V1.json -> Codex task not accepted.
Blind level=1 for all roots -> reject.
No source_refs -> reject.
```

## Intended use

AGENTS.md points Codex here. Codex should update this pointer only when the canonical coverage/audit mechanism changes, not on every school run. Per-campaign coverage decisions belong in CAMPAIGN_COVERAGE_AUDIT_V1.json and CAMPAIGN_LEVEL_PLAN_V1.json.
