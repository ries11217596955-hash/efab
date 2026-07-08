# Body Map Triage Promotion Plan V1

status: PASS_BODY_MAP_TRIAGE_PROMOTION_PLAN_V1

This plan converts triage into bounded next actions. It does not accept candidates as organs.

total triaged: 156
real organ candidates: 17
candidate ready for draft: 2
needs review: 26
owner link blocked: 9
not organ: 119

## Fast lane: draft passport candidates

- contracts_accepted_atom_retention_organ `contracts/accepted_atom_retention_organ` next=NORMALIZE_EXISTING_CONTRACT_TO_ORGAN_PASSPORT_V1
- operations_self_model `operations/self_model` next=CREATE_ORGAN_PASSPORT_DRAFT_FROM_PRIMARY_EVIDENCE

## Boundary

- Draft passports only.
- No active passport creation.
- No body-map mutation.
- No candidate accepted as organ from triage alone.

Next: ORGAN_PASSPORT_DRAFT_GENERATOR_FOR_CANDIDATE_READY_ONLY_V1.
