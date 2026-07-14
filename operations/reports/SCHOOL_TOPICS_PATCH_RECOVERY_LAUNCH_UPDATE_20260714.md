# SCHOOL_TOPICS_PATCH_RECOVERY_LAUNCH_UPDATE_20260714

Status: PASS_TOPICS_PATCH_RECOVERY_LAUNCH_UPDATE_VALIDATED

Owner launch fields:

```powershell
operations/school/run_agent_school.ps1 -Count <N> -Mode <Test|Live> -Topics <AUTO|topic1,topic2>
```

Patch policy:

- PatchSize is internal and fixed at 1000.
- Count is a total ceiling and is not split evenly between topics.
- Budget is assigned patch-by-patch by topic pressure and completion state.
- After restart, only ABSORBED and CLEANED_AFTER_ABSORPTION patch ledger states count as memory progress.
- Patch raw proof stays in runtime; tracked repo keeps compact run/topic summaries only.

Validation:

- canonical_route: PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2
- selector_status: PASS_DEVELOPMENT_VECTOR_THEME_SELECTOR_VALIDATION_V1
- selector_candidate_limit: 1000
- patch_plan_status: PASS_SCHOOL_TOPIC_PATCH_PLAN_VALIDATION_V1
- patch_size: 1000
- patch_next_topic: codex_school_task_template_strength
- patch_next_count: 1000
- partial_absorption_allowed: True
- memory_changed_by_validators: False

Boundary: no Codex run and no long school run were executed. Active memory was not mutated.
