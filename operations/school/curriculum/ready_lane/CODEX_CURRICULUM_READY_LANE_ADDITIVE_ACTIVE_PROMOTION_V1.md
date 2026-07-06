# CODEX_CURRICULUM_READY_LANE_ADDITIVE_ACTIVE_PROMOTION_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

Ready-lane promotion must not replace the active repo-body memory when the Owner is adding a new accepted run. It must merge the existing active atoms with the new ready-lane atoms and then require decision-use and scale proof.

## Flow

```text
current active checkpoint
+ new ready lane
→ overlap check by topic and duplicate_key
→ rewrite incoming atom_id to avoid run-local id collisions
→ merged active checkpoint
→ decision-use proof
→ scale gate
```

## Boundary

This promotes only repo-body active decision source. It is not live runtime proof and not D2B accepted-core promotion.