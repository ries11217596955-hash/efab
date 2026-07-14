# DYNAMIC_SCHOOL_REQUEST_PLANNER_INSTALLATION_20260715

Status: PASS_DYNAMIC_SCHOOL_REQUEST_PLANNER_V1_INSTALLED_AND_VALIDATED

Installed dynamic School Request planner.

School no longer has to think in fixed 1000 patches. It now computes a variable logical request from memory/development-vector pressure:

```text
min_request_size = 50
max_request_size = 50000
micro_batch_size = 100
warehouse_backlog_limit_candidates = 3000
topic_reselection = after_request_complete_only
memory_progress = ABSORBED only
```

Validation:

```text
status = PASS_DYNAMIC_SCHOOL_REQUEST_PLANNER_VALIDATION_V1
selected_topic = codex_school_task_template_strength
selected_pressure_class = MISSING_OR_ZERO_DEPTH_HIGH_GAP
selected_request_candidate_count = 20000
selected_micro_batch_size = 100
selected_micro_batch_count = 200
selected_max_ready_backlog_candidates = 3000
task_total_candidate_count = 20000
task_micro_batch_count = 200
memory_changed = False
```

Synthetic sizing cases:

```text
near_complete => 100
missing_high_gap => 20000
cap_50k => 50000
```

Boundary: no real Codex and no absorption were run.
