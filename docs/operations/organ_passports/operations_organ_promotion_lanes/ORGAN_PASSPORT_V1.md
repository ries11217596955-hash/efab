# ORGAN_PASSPORT_V1 — operations_organ_promotion_lanes

status: PASSPORT_DRAFT_FROM_EVIDENCE
maturity: DRAFT
live_or_lab_status: NOT_PROVEN
owning_root: operations/organ_promotion_lanes

## Purpose
persistent growth gate with build script, validator, model, report, and proof for all current candidates

## Boundaries
- draft only
- no PASSPORT_ACTIVE claim
- no PROVEN_LIVE claim
- no live process touched
- activation requires separate validator/proof/Owner acceptance

## Validators
- operations/organ_promotion_lanes/validate_organ_promotion_lanes_v1.ps1

## Gaps
- runtime proof missing
- ACTIVE status forbidden
- PROVEN_LIVE forbidden
- auto map refresh on commit not proven
