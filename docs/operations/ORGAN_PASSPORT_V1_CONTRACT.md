# Organ Passport V1 Contract

status: ACTIVE_CONTRACT

A passport is the evidence-grounded source of truth for one organ. The body map is only the index/summary.

## Required fields
- schema
- status
- organ_id
- display_name
- purpose
- responsibilities
- what_it_is_not
- owning_root
- owned_files
- inputs
- outputs
- invocation_surfaces
- dependencies
- validators
- proof_refs
- runtime_refs
- exported_capabilities
- safety_boundaries
- failure_modes
- rollback_or_quarantine
- maturity
- live_or_lab_status
- gaps
- source_evidence
- last_validated_at

## Auto-draft rule

Auto-draft is allowed from evidence, but draft is not active. Missing evidence becomes gaps, not guessed content.

## Safety rules
- No passport may be marked PASSPORT_ACTIVE without validator and proof references.
- No passport may claim PROVEN_LIVE without fresh live proof.
- No passport may claim child-agent readiness without dedicated child-agent readiness validator.
- No missing evidence may be filled by guesswork; record a gap instead.
- No audit result may delete, move, or demote files without separate migration proof and Owner approval.
