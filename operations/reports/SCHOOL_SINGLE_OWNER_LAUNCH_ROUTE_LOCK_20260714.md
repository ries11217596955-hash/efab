# SCHOOL_SINGLE_OWNER_LAUNCH_ROUTE_LOCK_20260714

Status: PASS_SINGLE_OWNER_SCHOOL_LAUNCH_ROUTE_LOCK_VALIDATED

Canonical Owner-facing launch:

```powershell
operations/school/run_agent_school.ps1 -Count <N> -Mode <Test|Live>
```

Owner fields:
- Count
- Mode = Test | Live

Internal canonical topics plan:
- operations/school/curriculum/topics/builder_night_school_topics_v1.json

Validator:
- PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2
- OWNER_FACING_ENTRYPOINT_COUNT=1
- OWNER_FIELDS=Count,Mode
- unexpected_owner_like_launch_surfaces_count=0

Deleted confusing route files:
- operations/reports/SCHOOL_CANONICAL_LAUNCH_POINTER_20260714.json
- operations/reports/SCHOOL_CANONICAL_LAUNCH_POINTER_20260714.md
- operations/gpt_handoff/CODEX_TASK_SCHOOL_100K_USEFUL_CAMPAIGN_GENERATOR_V1.md
- operations/gpt_handoff/CODEX_TASK_SCHOOL_ONE_TOPIC_SEP_LADDER_100K_V1.md

School completion rule: compact memory update proof must exist. Otherwise the school run is not complete.