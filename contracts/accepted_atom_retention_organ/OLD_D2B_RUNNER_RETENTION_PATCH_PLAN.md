# Old D2B Runner Retention Patch Plan v1

Status: PATCH_CANDIDATE

Old atom absorption organ:

- modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1

Problem:

- old runner accepts atoms but leaves heavy successful traces/logs/snapshots
- repo grows during mass learning

Patch strategy:

- do not replace old atom absorption organ
- keep old runner as legacy worker
- introduce guarded wrapper as new safe entrypoint
- wrapper requires RetentionMode=CompactAccepted
- wrapper blocks FullTrace/Disabled mode
- wrapper supports dry-trial adapter proof before live learning
- future live mode must call legacy worker and then retention gate

Current stage:

- guarded wrapper dry trial only
- no mass learning
- no live legacy runner execution
- runtime_ready=false
