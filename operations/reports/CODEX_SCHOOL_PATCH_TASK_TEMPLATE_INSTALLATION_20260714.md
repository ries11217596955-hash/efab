# CODEX_SCHOOL_PATCH_TASK_TEMPLATE_INSTALLATION_20260714

Status: PASS_CODEX_SCHOOL_PATCH_TASK_TEMPLATE_GENERATOR_INSTALLED_AND_VALIDATED

Prepared and validated generator for strict one-topic Codex school patch tasks.

Template includes:

- topic
- current depth
- start depth
- target depth
- candidate limit
- single-topic boundary
- required candidate fields
- quality rules
- proof requirements
- validator requirements
- negative case
- source rule
- return-to-parent rule
- PREFLIGHT_PASS guard
- retry/failure policy
- no active-memory mutation rule

Validation:

- status: PASS_CODEX_SCHOOL_PATCH_TASK_TEMPLATE_VALIDATION_V1
- selected_topic: codex_school_task_template_strength
- candidate_limit: 1000
- depth: 0 -> 4
- required_candidate_fields_count: 18
- acceptance_contract_count: 9
- memory_changed: False

Codex failure cycle:

- attempt 1: normal 1000 candidate task
- attempt 2: narrowed retry, max 500 candidates
- attempt 3: minimal retry, max 200 candidates; quarantine after failure

Boundary: no Codex run was executed. Runtime task output is not tracked as repo proof.
