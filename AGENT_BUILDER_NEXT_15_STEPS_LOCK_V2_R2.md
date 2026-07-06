# AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2

# Agent Builder Next 15 Steps Lock V2_R2

Status: SUPERSEDED_BY_PHASE160L_ROUTE_LOCK_SUPERSESSION_REPAIR
Version: V2_R2
Active line: AGENT_BUILDER / SELF_BUILD
Supersedes: AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md
Reason: previous V2 moved toward external agent production too early.
Baseline: PHASE90 completed at commit 77a8839.
Superseded by: route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_PHASE161_BATCH_SCHOOL_PREP.md
Supersession phase: PHASE160L_ROUTE_LOCK_SUPERSESSION_REPAIR_V1
Supersession reason: PHASE91-PHASE105 are completed historical batch-engine steps. Runtime work has advanced through the PHASE160 repair line to PHASE160K, and the next strategic target is PHASE161_BATCH_SCHOOL_FOUNDATION.
Current classification: SUPERSEDED

## Main Doctrine

The next 15 steps are not for external agent production.
They are for building a batch self-build engine.

## Batch Meaning

Builder must eventually accept a large program of many requested items.
It must attempt items one by one or in safe batches.
It must continue after item-level failure when safe.
It must produce item-level evidence.
Successful items are proven.
Failed items are quarantined or blocked with reason.
The whole run must produce a batch report.

## Required Item Statuses

- PLANNED
- RUNNING
- PASS
- FAILED
- QUARANTINED
- BLOCKED
- NEEDS_OWNER_DECISION
- NEEDS_CODEX_REPAIR
- NEEDS_MATERIAL
- SKIPPED_BY_POLICY

## Locked Next 15 Steps

1. PHASE91 - Route V1 Closure And V2_R2 Activation
2. PHASE92 - Self-Build Backlog Contract V1
3. PHASE93 - Capability Gap Detector V1
4. PHASE94 - Owner Order To Gap Map V1
5. PHASE95 - Self-Build Program Generator V2
6. PHASE96 - Batch Planner V1
7. PHASE97 - Batch Admission Policy V1
8. PHASE98 - Item-Level Execution Ledger V1
9. PHASE99 - Continue-On-Failure Runtime V1
10. PHASE100 - Quarantine And Blocker Registry V1
11. PHASE101 - Batch Proof Aggregator V1
12. PHASE102 - Auto Next-Gap Decision V1
13. PHASE103 - Repair Loop Generator V1
14. PHASE104 - Controlled Multi-Cycle Self-Build Run V1
15. PHASE105 - Scale Trial 10 To 30 To 100 Tasks V1

## Hard Prohibitions

- No external agents in PHASE91-PHASE105.
- No unbounded autonomous loop.
- No destructive changes without approval.
- No trust without proof.
- No batch commit if validation fails.
- No hiding failed items.
- No stopping the whole batch on a safe item-level failure.
- No Codex replacing Builder runtime.
