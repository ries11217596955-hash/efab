# REPO_CLEANUP_PLAN_V1

Status: PLAN_ONLY_NO_DELETION
Created: 2026-07-15T16:17:35+04:00
Source audit: operations/gpt_handoff/REPO_DEEP_CLEANUP_AUDIT_V1.json
Repo HEAD at audit: ee1476d

## 1. Human verdict

The repo is not mainly dirty because of tracked code. The working tree is dirty because runtime retained large ignored artifacts.

```text
tracked repo size ~= 37.5MB
filesystem excluding .git ~= 457.6MB
.runtime size ~= 419.3MB / files=291 / ignored=291
```

No cleanup is authorized by this plan. It separates safe-looking candidates from protected surfaces.

## 2. P0 — do not touch without explicit Owner decision

- `.runtime/active_compact_semantic_memory_v1`
- `reports/self_development`
- `tests/self_development`
- `operations/gpt_handoff`
- `operations/school current control surface`
- `self_model/organ_passports`
- `validators`
- `modules`

Rule: active memory snapshot/tail is not proof of full preservation. No runtime cleanup while School/digest/absorption is active.

## 3. P1 — biggest cleanup candidates, still NOT deleted

These are large ignored runtime artifacts. They can only be removed after a no-active-process check and a retention decision.

- 108.1MB `.runtime/file_atom_absorption/file_atom_absorption_20260714_124613/memory_candidate/cells.jsonl` [ignored_untracked]
- 12.1MB `.runtime/speed_probe/active_memory_guard_copy/cells.jsonl` [ignored_untracked]
- 12.0MB `.runtime/file_atom_absorption/file_atom_absorption_20260715_102251/memory_candidate/cells.jsonl` [ignored_untracked]
- 12.0MB `.runtime/file_atom_absorption/file_atom_absorption_20260715_102224/memory_candidate/cells.jsonl` [ignored_untracked]
- 11.9MB `.runtime/file_atom_absorption/file_atom_absorption_20260715_102156/memory_candidate/cells.jsonl` [ignored_untracked]
- 11.9MB `.runtime/file_atom_absorption/file_atom_absorption_20260715_092338/memory_candidate/cells.jsonl` [ignored_untracked]
- 11.9MB `.runtime/file_atom_absorption/file_atom_absorption_20260715_084844/memory_candidate/cells.jsonl` [ignored_untracked]
- 11.9MB `.runtime/protected_backups/before_canonical_exact_live_1_20260715_092114/active_compact_semantic_memory_v1/cells.jsonl` [archive_candidate, ignored_untracked]
- 11.9MB `.runtime/file_atom_absorption/file_atom_absorption_20260715_084812/memory_candidate/cells.jsonl` [ignored_untracked]
- 11.9MB `.runtime/file_atom_absorption/file_atom_absorption_20260715_070849/memory_candidate/cells.jsonl` [ignored_untracked]
- 11.9MB `.runtime/protected_backups/before_exact_101_absorb_20260715_084556/active_compact_semantic_memory_v1/cells.jsonl` [archive_candidate, ignored_untracked]
- 11.9MB `.runtime/file_atom_absorption/file_atom_absorption_20260715_070747/memory_candidate/cells.jsonl` [ignored_untracked]
- 11.9MB `.runtime/file_atom_absorption/file_atom_absorption_20260714_213120/memory_candidate/cells.jsonl` [ignored_untracked]
- 11.9MB `.runtime/protected_backups/before_one_micro_absorb_20260715_070013/active_compact_semantic_memory_v1/cells.jsonl` [archive_candidate, ignored_untracked]
- 3.9MB `.runtime/compact_memory_intake_v1/checkpoints/merge_queue_20260713_232222/active_memory_before/cells.jsonl` [ignored_untracked]
- 485.1KB `operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json` [proof_or_generated_report, ignored_untracked]
- 306.4KB `.runtime/file_atom_absorption/file_atom_absorption_20260715_070747/staging/raw_atoms.jsonl` [transient_candidate, ignored_untracked]
- 302.8KB `.runtime/file_atom_absorption/file_atom_absorption_20260715_102156/memory_candidate/index.json` [ignored_untracked]
- 302.8KB `.runtime/file_atom_absorption/file_atom_absorption_20260715_102224/memory_candidate/index.json` [ignored_untracked]
- 302.8KB `.runtime/file_atom_absorption/file_atom_absorption_20260715_102251/memory_candidate/index.json` [ignored_untracked]
- 302.7KB `.runtime/file_atom_absorption/file_atom_absorption_20260715_092338/memory_candidate/index.json` [ignored_untracked]
- 302.6KB `.runtime/file_atom_absorption/file_atom_absorption_20260715_084812/memory_candidate/index.json` [ignored_untracked]
- 302.6KB `.runtime/file_atom_absorption/file_atom_absorption_20260715_084844/memory_candidate/index.json` [ignored_untracked]
- 302.6KB `.runtime/protected_backups/before_canonical_exact_live_1_20260715_092114/active_compact_semantic_memory_v1/index.json` [archive_candidate, ignored_untracked]
- 302.6KB `.runtime/file_atom_absorption/file_atom_absorption_20260715_070747/memory_candidate/index.json` [ignored_untracked]

Likely first cleanup slice: old `.runtime/file_atom_absorption/*/memory_candidate/` and old raw staging, keeping active memory and latest selected proofs/backups.

## 4. P2 — archive/compress candidates, not blind delete

Runtime backup dirs contain previous active memory copies. They are large, but safer action is retention policy: keep latest N, compress or move older ones only after manifest/hash proof.

- 11.9MB `.runtime/protected_backups/before_canonical_exact_live_1_20260715_092114/active_compact_semantic_memory_v1/cells.jsonl` [archive_candidate, ignored_untracked]
- 11.9MB `.runtime/protected_backups/before_exact_101_absorb_20260715_084556/active_compact_semantic_memory_v1/cells.jsonl` [archive_candidate, ignored_untracked]
- 11.9MB `.runtime/protected_backups/before_one_micro_absorb_20260715_070013/active_compact_semantic_memory_v1/cells.jsonl` [archive_candidate, ignored_untracked]
- 302.6KB `.runtime/protected_backups/before_canonical_exact_live_1_20260715_092114/active_compact_semantic_memory_v1/index.json` [archive_candidate, ignored_untracked]
- 302.6KB `.runtime/protected_backups/before_exact_101_absorb_20260715_084556/active_compact_semantic_memory_v1/index.json` [archive_candidate, ignored_untracked]
- 302.1KB `.runtime/protected_backups/before_one_micro_absorb_20260715_070013/active_compact_semantic_memory_v1/index.json` [archive_candidate, ignored_untracked]

## 5. P3 — tracked bloat / design cleanup, not file deletion

Tracked repo is moderate, but there are design smells: generated/proof files, packs containing copies of modules/validators, and a large School ledger.

- `.runtime`: 419.3MB files=291 tracked=0 ignored=291
- `operations`: 25.9MB files=522 tracked=485 ignored=36
- `reports`: 3.7MB files=125 tracked=124 ignored=1
- `modules`: 1.8MB files=203 tracked=203 ignored=0
- `packs`: 1.6MB files=455 tracked=455 ignored=0
- `self_model`: 1.2MB files=146 tracked=146 ignored=0
- `self_build_programs`: 962.9KB files=88 tracked=88 ignored=0
- `validators`: 957.3KB files=175 tracked=175 ignored=0
- `tests`: 485.8KB files=128 tracked=128 ignored=0
- `materials`: 390.3KB files=26 tracked=26 ignored=0
- `docs`: 189.9KB files=218 tracked=218 ignored=0
- `knowledge_library`: 183.4KB files=91 tracked=91 ignored=0

Tracked cleanup should be done only with validators and route-change reports, not by deleting files from the inventory.

## 6. Duplicate content signals

- possible_saved=1.5MB size=300.9KB count=6
  - `.runtime/active_compact_semantic_memory_v1_backups/before_conservative_compaction_20260714_163639/index.json`
  - `.runtime/active_compact_semantic_memory_v1_backups/before_sep_ladder_100k_digest_20260714_1730/index.json`
  - `.runtime/active_compact_semantic_memory_v1_compaction_work_20260714/candidate_aggressive/index.json`
  - `.runtime/active_compact_semantic_memory_v1_compaction_work_20260714/candidate_conservative/index.json`
  - `.runtime/file_atom_absorption/file_atom_absorption_20260714_124613/memory_candidate/index.json`
- possible_saved=908.4KB size=302.8KB count=4
  - `.runtime/active_compact_semantic_memory_v1/index.json`
  - `.runtime/file_atom_absorption/file_atom_absorption_20260715_102156/memory_candidate/index.json`
  - `.runtime/file_atom_absorption/file_atom_absorption_20260715_102224/memory_candidate/index.json`
  - `.runtime/file_atom_absorption/file_atom_absorption_20260715_102251/memory_candidate/index.json`
- possible_saved=605.3KB size=302.6KB count=3
  - `.runtime/file_atom_absorption/file_atom_absorption_20260715_084812/memory_candidate/index.json`
  - `.runtime/file_atom_absorption/file_atom_absorption_20260715_084844/memory_candidate/index.json`
  - `.runtime/protected_backups/before_canonical_exact_live_1_20260715_092114/active_compact_semantic_memory_v1/index.json`
- possible_saved=605.1KB size=302.6KB count=3
  - `.runtime/file_atom_absorption/file_atom_absorption_20260715_070747/memory_candidate/index.json`
  - `.runtime/file_atom_absorption/file_atom_absorption_20260715_070849/memory_candidate/index.json`
  - `.runtime/protected_backups/before_exact_101_absorb_20260715_084556/active_compact_semantic_memory_v1/index.json`
- possible_saved=306.4KB size=306.4KB count=2
  - `.runtime/file_atom_absorption/file_atom_absorption_20260715_070747/staging/raw_atoms.jsonl`
  - `operations/reports/one_micro_absorb_20260715/micro_001.normalized_atoms.jsonl`
- possible_saved=302.1KB size=302.1KB count=2
  - `.runtime/file_atom_absorption/file_atom_absorption_20260714_213120/memory_candidate/index.json`
  - `.runtime/protected_backups/before_one_micro_absorb_20260715_070013/active_compact_semantic_memory_v1/index.json`
- possible_saved=238.7KB size=79.6KB count=4
  - `self_build_programs/canonical_trials/PHASE165N_FIRST_DYNAMIC_OWNER_MATERIAL_CANONICAL_TRIAL_V1/TASK_QUEUE_AFTER_PHASE165N_CANONICAL_TRIAL_BEFORE_RESTORE.json`
  - `self_build_programs/canonical_trials/PHASE165N_FIRST_DYNAMIC_OWNER_MATERIAL_CANONICAL_TRIAL_V1/TASK_QUEUE_BEFORE_PHASE165N_CANONICAL_TRIAL.json`
  - `self_build_programs/canonical_trials/PHASE165O_HARDENED_CANONICAL_DYNAMIC_CONTRACT_TRIAL_V1/TASK_QUEUE_AFTER_PHASE165O_HARDENED_TRIAL_BEFORE_RESTORE.json`
  - `self_build_programs/canonical_trials/PHASE165O_HARDENED_CANONICAL_DYNAMIC_CONTRACT_TRIAL_V1/TASK_QUEUE_BEFORE_PHASE165O_HARDENED_TRIAL.json`
- possible_saved=24.7KB size=24.7KB count=2
  - `modules/materialize_generated_self_build_program_from_family_contract.ps1`
  - `packs/PHASE62_SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1/payload/modules/materialize_generated_self_build_program_from_family_contract.ps1`
- possible_saved=23.8KB size=23.8KB count=2
  - `modules/render_generated_self_build_pack_apply_from_recipe.ps1`
  - `packs/PHASE59_RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1/payload/modules/render_generated_self_build_pack_apply_from_recipe.ps1`
- possible_saved=23.6KB size=23.6KB count=2
  - `packs/PHASE63_SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_V1/payload/validators/validate_second_generated_program_family_live_admission_v1.ps1`
  - `validators/validate_second_generated_program_family_live_admission_v1.ps1`
- possible_saved=19.7KB size=19.7KB count=2
  - `modules/admit_generated_self_build_program_to_live_execution.ps1`
  - `packs/PHASE60_GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1/payload/modules/admit_generated_self_build_program_to_live_execution.ps1`
- possible_saved=16.5KB size=16.5KB count=2
  - `packs/PHASE73_RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1/payload/validators/validate_runbook_executor_agent_production_v1.ps1`
  - `validators/validate_runbook_executor_agent_production_v1.ps1`

## 7. Proposed cleanup order

```text
Step A: freeze/observe runtime processes; no active School/digest/absorption.
Step B: produce retention manifest for .runtime active memory/backups/candidates.
Step C: delete only old absorption memory_candidate/staging dirs outside protected active memory.
Step D: compress or move old protected backups only after Owner decision.
Step E: tracked bloat review separately; no broad tracked deletion.
Step F: rerun body inventory map + repo audit to prove reduced size and no protected loss.
```

## 8. Hard stop

If any School/digest/absorption process is active, cleanup becomes observe-only.
