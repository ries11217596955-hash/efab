# PHASE161B Unified Learning Mode Loop

PHASE161B adds one learning mode loop around the existing Builder organs.

It does not create a duplicate school brain. It uses the accepted PHASE161A school runner for school batches and the existing PHASE160 self-growth surface for self mode. The new layer decides which mode is appropriate, absorbs completed school experience into session-local recommendations, and returns the Builder to self mode after absorption.

Modes:

- `SELF_MODE`: no curriculum is available, or absorption is complete and self-development should resume.
- `SCHOOL_MODE`: a valid owner/internal/generated curriculum is available, or an active school run must continue.
- `ABSORB_EXPERIENCE`: a school run completed and has not yet been absorbed.
- `WAITING_OWNER_REVIEW`: accepted promotion is blocked by owner review, while session-local learning remains safe-only.
- `SAFE_IDLE_ONLY`: an explicit stop or safety condition exists.

Runtime-only artifacts:

- `runtime_sessions/learning_mode_decisions/<decision_id>/learning_mode_decision.json`
- `runtime_sessions/learning_absorption/<absorption_id>/learning_absorption.json`
- `runtime_sessions/learning_absorption/<absorption_id>/learning_absorption_report.md`
- `runtime_sessions/learning_absorption/<absorption_id>/next_self_learning_recommendations.json`
- `runtime_sessions/learning_absorption/<absorption_id>/school_to_gap_backlog_suggestions.json`
- `runtime_sessions/learning_runs/<run_id>/overnight_learning_run_plan.json`

Absorption writes recommendations only. It does not mutate `TASK_QUEUE.json`, `GENESIS_STATE.json`, `CAPABILITY_ROADMAP.json`, `packs/registry.json`, or `orchestrator/run.ps1`.
