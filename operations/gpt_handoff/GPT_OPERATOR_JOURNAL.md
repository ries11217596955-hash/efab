# GPT_OPERATOR_JOURNAL — ACTIVE CURRENT STATE ONLY

Updated: 2026-07-14T17:52:26.206917+00:00
Repo HEAD at update: 3625b8f

## One school launch

STATUS: PASS_SINGLE_OWNER_SCHOOL_LAUNCH_ROUTE_LOCK_VALIDATED

Use only:

```powershell
operations/school/run_agent_school.ps1 -Count <N> -Mode <Test|Live> -Topics <AUTO|topic1,topic2>
```

Owner-facing fields:

```text
Count
Mode = Test | Live
```

Internal topics plan:

```text
operations/school/curriculum/topics/builder_night_school_topics_v1.json
```

School completion proof requires all of:

```text
absorption PASS
active_memory_changed = true
compact_memory_updated = true
proof report exists
```

Internal helpers are not launch routes:

```text
Codex material authoring
candidate factory
stream processing
quality gate
digest pipeline
source router
finalizer
autonomous cycle controller
```

## Latest completed school cycle

STATUS: PASS_ONE_TOPIC_SEP_LADDER_100K_COMPLETED_AND_ABSORBED

Run:

```text
builder_sep_ladder_100k_20260714_205600
```

Proof:

```text
stream accepted = 100000
stream rejected = 0
quality gate = PASS_ONE_TOPIC_SEP_100K_QUALITY_GATE_COMPACT_DIGEST_READY
compact digest atoms = 191
absorption = PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1
active_memory_changed = True
compact_memory_updated = True
raw_100k_promotion = false
```

Memory update path:

```text
100k school material
-> quality gate
-> 191-atom compact digest
-> absorption pipeline
-> active compact memory published
```

## Cleanup state

STATUS: PASS_RETENTION_CLEANUP_AFTER_ABSORPTION

```text
transient_runtime_deleted_mb = 2842.6
active_memory_kept = true
backup_kept = true
absorption_proof_kept = true
```

## Proof reports to read first

```text
operations/reports/SCHOOL_SINGLE_OWNER_LAUNCH_ROUTE_LOCK_20260714.json
operations/reports/ONE_TOPIC_SEP_LADDER_100K_COMPLETION_20260714.json
operations/reports/ONE_TOPIC_SEP_LADDER_100K_RETENTION_CLEANUP_REPORT_20260714.json
```

## Next school run rule

```text
fresh reality check
use one school launch only
claim completion only after compact memory proof
```

## Current school cleanup state

```text
school_deep_audit = complete
school_deep_cleanup = complete
old generated school material = deleted
old school reports = replaced by current compact audit/cleanup proof
```


## Dynamic theme-cell selector

```text
dynamic_theme_cell_selector = installed and validated
dynamic_topic_count = 122
selected_topic = intake_school_school_topics_plan_school_summary_school_factory_digest_use_real_1
selected_label = school_topics_plan
selector_memory_changed = false
```

Meaning:

```text
School now reads active compact memory before a run and selects one weak dynamic topic cell.
No fixed cell count is required.
If future material has no matching topic cell, the school can create a new topic cell through the normal memory update path.
```


## Development vector and depth-aware school selection

```text
development_vector_selector = installed and validated
expected_topic_count = 12
missing_expected_topic_count = 12
under_depth_expected_topic_count = 0
selected_topic = codex_school_task_template_strength
selection_reason = missing_expected_topic
selected_depth = 0 -> 4
codex_candidate_limit_hint = 1000
selector_memory_changed = false
```

Meaning:

```text
School now compares active memory against its development vector.
It can choose a missing expected topic or an under-depth topic.
Codex receives target topic, current depth, target depth, single-topic boundary, candidate rules, and acceptance contract.
```


## Topics patch school launch

```text
owner_fields = Count, Mode, Topics
patch_size_internal = 1000
count = total ceiling, not equal topic split
partial_progress_counted_states = ABSORBED, CLEANED_AFTER_ABSORPTION
```

Meaning:

```text
School can be launched with AUTO or selected topics.
It works in 1000-candidate patches.
After stop/restart, memory progress is whatever patches reached absorption proof.
Open/generated/validated/digested-only patches do not count as memory update.
```


## Codex school patch task template

```text
codex_patch_task_template = installed and validated
selected_topic = codex_school_task_template_strength
candidate_limit = 1000
depth = 0 -> 4
required_candidate_fields_count = 18
acceptance_contract_count = 9
selector_memory_changed = false
```

Meaning:

```text
Codex receives one-topic patch tasks with topic, depth, count, schema, quality rules, proof fields, validator fields, source rule, return-to-parent rule, preflight guard, and retry/quarantine policy.
Codex failure does not decrement Count and does not update memory.
```


## School patch executor v1

```text
school_patch_executor_v1 = installed and validated
executor_status = PASS_PATCH_EXECUTOR_VALIDATED_NO_ABSORB_V1
codex_status = MOCK_CODEX_DRAFT_CREATED
ledger_state = VALIDATED_NORMALIZED
memory_changed = False
```

Meaning:

```text
One patch can now be executed through topic selection, 1000-patch planning, Codex task creation, candidate validation, normalization into atom JSONL, and runtime ledger update.
This validation used MockCodex and no absorption.
VALIDATED_NORMALIZED is not memory progress. Only ABSORBED counts.
```


## Real Codex no-absorb patch trial

```text
launcher_probe = PASS, codex stdin exec returned OK
real_1000_patch = CODEX_FAILED / HANG_OR_TIMEOUT
ledger_state = CODEX_FAILED
memory_changed = false
absorption_run = false
runtime_tails_cleaned = true
```

Meaning:

```text
Codex bridge is now launchable, but 1000-candidate task is too heavy for first real patch.
Next step is not another 1000 run; use retry narrowing: 500 then 200, or simplify the Codex task before absorption.
Executor timeout cleanup was repaired to kill only its own child process tree.
```


## Codex warehouse pipeline v1

```text
warehouse_pipeline = installed and validated
patch_candidate_count = 1000
micro_batch_size = 100
micro_batch_count = 10
ready_consumer_status = PASS_WAREHOUSE_CONSUMED_READY_BATCHES_NO_ABSORB_V1
ready_accepted_count = 100
school_ahead_wait_status = PASS_WAREHOUSE_CONSUMER_WAIT_TIMEOUT_NO_READY_V1
memory_changed = False
```

Meaning:

```text
Codex can be treated as producer that fills runtime warehouse with READY micro-batches.
School is consumer that independently consumes READY only, waits with heartbeat when ahead, and never counts memory progress until ABSORBED.
```
