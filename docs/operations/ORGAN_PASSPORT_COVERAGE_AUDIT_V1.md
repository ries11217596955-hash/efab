# Organ Passport Coverage Audit V1

status: PASS_ORGAN_PASSPORT_COVERAGE_AUDIT_V1

total_organs: 7
passport_active: 0
passport_needs_repair: 1
passport_missing_but_evidence_exists: 6
passport_missing_no_evidence: 0

## Organs
- school: PASSPORT_MISSING_BUT_EVIDENCE_EXISTS; files=97; validators=20; proofs=20; next=auto_draft_passport_from_evidence
- school_source_router: PASSPORT_MISSING_BUT_EVIDENCE_EXISTS; files=8; validators=1; proofs=4; next=auto_draft_passport_from_evidence
- compact_memory_intake: PASSPORT_MISSING_BUT_EVIDENCE_EXISTS; files=10; validators=1; proofs=20; next=auto_draft_passport_from_evidence
- autonomous_inner_motor: PASSPORT_NEEDS_REPAIR; files=76; validators=2; proofs=20; next=normalize_existing_contract_or_passport_to_v1_draft
- knowledge_acquisition_port: PASSPORT_MISSING_BUT_EVIDENCE_EXISTS; files=50; validators=0; proofs=3; next=auto_draft_passport_from_evidence
- map_control: PASSPORT_MISSING_BUT_EVIDENCE_EXISTS; files=2; validators=0; proofs=4; next=auto_draft_passport_from_evidence
- gpt_handoff: PASSPORT_MISSING_BUT_EVIDENCE_EXISTS; files=3; validators=0; proofs=4; next=auto_draft_passport_from_evidence

No deletion is allowed from this audit.
