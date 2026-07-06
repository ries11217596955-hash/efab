# GPT Operator Journal - Active Compact Pointer

Status: ACTIVE_COMPACT_JOURNAL
Created: 2026-07-05T15:43:33.8961641+04:00
Replaces oversized active journal blob.

## Boundary

This file is the active journal surface. It must stay compact.

Do not paste raw logs, full command outputs, proof dumps, Codex answers, web answers, or large reports here.

Do not run full-file normalization on this journal when it grows. Use append-only UTF-8 pointer entries or create compact notes in focused files.

## Oversized journal retirement

Previous active journal body reached:

```text
1671111573 bytes
```

Root cause found by forensic sampling and git history:

1. Normal journal grew to about 30.7 MB by commit `2ed93c2`.
2. At commit `8823c07` it jumped to about 750.8 MB.
3. At commit `7401ccc` it jumped to about 1.671 GB.
4. Samples in the inflated regions are mojibake/corrupted repeated text such as `AÃ¯Â¿Â½A...`, not valid markdown notes.
5. Most likely mechanism: Windows PowerShell full-file read/write normalization read a UTF-8/no-BOM journal through the wrong default encoding, then re-encoded corrupted text as UTF-8. Repeating that expanded the file again.

The old oversized content remains reachable through git history if forensic recovery is ever required. It is no longer the active working journal.

## Current route pointer

- Current branch: `thin-control`
- Last head before replacement: `5566f9bedd4009ec46f74945805f83ca51e7d3fa`
- AIMO SandboxTestLife can detect `KNOWLEDGE_GAP_FOR_X`.
- AIMO can call governed `KNOWLEDGE_ACQUISITION_PORT` once per sandbox run.
- Codex is only `CODEX_READONLY_SOURCE`; answers are `CODEX_DRAFT`.
- Source answers are not automatically memory/atom/reflex/organ.
- Reflex promotion can be triggered by `OBSERVED_REPEAT` or `PREDICTED_BREADTH`, but requires promotion request.
- Organ/module candidate is triggered by `CAPABILITY_NECESSITY_FOR_TASK_X`, not repeat count.

## Active compact notes

- `operations/autonomy_diagnostics/SOURCE_ANSWER_DIGEST_AND_ABSORPTION_GOVERNANCE_V1.md`
- `operations/autonomy_diagnostics/PROMOTION_DECISION_GOVERNANCE_V1.md`
- `operations/autonomy_diagnostics/REFLEX_ORGAN_PROMOTION_AND_REPO_BLOAT_CLARIFICATION_V1.md`
- `operations/knowledge_acquisition_port/KNOWLEDGE_ACQUISITION_PORT_CONTRACT.md`
- `operations/knowledge_acquisition_port/CODEX_KNOWLEDGE_REQUEST_TEMPLATE.md`

## Append rule

Future entries must be short pointers only:

```text
YYYY-MM-DD - short title
- decision/proof pointer
- file/commit pointer
```

If an entry needs more than 20 lines, create a focused compact note and link it here.
## 2026-07-05 - SandboxStudyLife 10min observation + night-school decision note

Context: SandboxStudyLife was observed for 10 minutes after STUDY_EPISODE_MANAGER_V1.

Proof refs:
- observation commit: 8c9c38c01949ac9a383af60409db294449ad8be3
- proof: operations/autonomous_inner_motor/study_life_runs/sandbox_study_life_10min_observation_20260705_01/STUDY_LIFE_PROOF.json
- report: operations/autonomous_inner_motor/validation/SANDBOX_STUDY_LIFE_10MIN_OBSERVATION_20260705_01.json

Result:
- safe boundary held: memory unchanged, no practical actions, no code writes, no active memory mutation, raw source deleted, gate PASS.
- gap spam repaired: open_learning_gaps=1 vs previous 77.
- new root defect: life collapses to idle after seed focus set is exhausted: total_cycles=401, episodes_closed=5, learning_residue_created=5, idle_cycles=396.

Active learning law candidate:
- failure without residue is waste.
- failure with learning residue is development.
- residue must feed next-focus selection; otherwise learning becomes archived proof, not life.

Next repair candidates:
1. WEAKNESS_BASED_FOCUS_SELECTOR_V1
2. RESIDUE_TO_FOCUS_EXPANDER_V1
3. IDLE_BACKOFF_SIGNAL_V1
4. per-episode acceptance receipts
5. semantic atom-candidate filter before atom route

Night-school note:
- canonical school supports N=300000 as parameter: 60 chunks of 5000 and 3000 batches of 100.
- last PROVEN_LAB Real scale was 30000, not 300000.
- 300000 should not be launched as a blind live/autonomous claim. It may be launched only as governed long school run with checkpoint/resume/cleanup/proof boundaries and no promise of later chat delivery.

## 2026-07-06 - Growth system status + next source ports

- current status pointer: `docs/operations/GROWTH_SYSTEM_STATUS_AND_NEXT_PORTS_20260706.md`
- school -> finalizer -> intake -> merge queue -> compact memory is built/proven; per-cycle SLA law is committed/proven.
- parallel AIMO + active school remains NOT_ENABLED / NOT_PROVEN; next organ is `AIMO_MULTI_SOURCE_MEMORY_COMPATIBILITY_V1`.
- future ports recorded: School+Codex/ExternalWorld and Agent+Codex/ExternalWorld/Reflex.