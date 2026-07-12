# THINKING ACCEPTANCE GATE V1 REQUIREMENT

STATUS: LAB_ONLY / ACCEPTANCE_GATE / NON_MUTATING / NOT_MEMORY_UPDATE

## Purpose

Thinking Acceptance Gate V1 reads Thinking Sandbox V1 outputs and classifies knowledge candidates, atom candidates, and compact memory proposals.

It decides acceptance status only. It does not install atoms. It does not update active compact memory. It does not execute actions.

## Inputs

Required:
- `reports/self_development/THINKING_SANDBOX_V1_TRACE.json`
- `reports/self_development/THINKING_SANDBOX_V1_KNOWLEDGE_ATOM_CANDIDATES.json`
- `reports/self_development/THINKING_SANDBOX_V1_COMPACT_MEMORY_PROPOSALS.json`
- `tests/self_development/THINKING_SANDBOX_V1_PROOF.json`
- `operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md`

## Outputs

Required:
- `reports/self_development/THINKING_ACCEPTANCE_GATE_V1_DECISIONS.json`
- `reports/self_development/THINKING_ACCEPTANCE_GATE_V1_REPORT.json`
- `tests/self_development/THINKING_ACCEPTANCE_GATE_V1_PROOF.json`

## Decision classes

Allowed decision classes:
- `ACCEPT_AS_CANDIDATE_FOR_FUTURE_VALIDATION`
- `NEEDS_VALIDATOR_BEFORE_ACCEPTANCE`
- `REWRITE_FOR_CLARITY`
- `REJECT_AS_UNSUPPORTED_OR_OVERCLAIM`

## Acceptance rules

A proposal can be `ACCEPT_AS_CANDIDATE_FOR_FUTURE_VALIDATION` only if:
- it is explicitly candidate/proposal-only;
- it does not claim active memory update;
- it does not claim installed atom;
- it has evidence refs or trace refs;
- it preserves no-action boundary.

A proposal must be `NEEDS_VALIDATOR_BEFORE_ACCEPTANCE` if:
- it would change future behavior;
- it could become compact memory;
- it could become an installed atom;
- it is useful but not yet validated as active rule.

A proposal must be rejected if it claims live/runtime, active memory update, installed atom, PASSPORT_ACTIVE, or mutation authority.

## Required output fields per decision

- `decision_id`
- `source_cycle`
- `source_type`
- `source_ref`
- `decision_class`
- `why`
- `validator_required`
- `accepted_now=false`
- `install_allowed=false`
- `active_memory_update_allowed=false`
- `rewrite_required`
- `forbidden_actions`
- `next_gate`

## Laws enforced

- Candidate acceptance is not active acceptance.
- Memory proposal is not memory update.
- Atom candidate is not installed atom.
- Useful idea still needs validator before becoming active rule.
- Reject overclaims.
- No mutation from thought.

## Acceptance

Validator must prove:
- Thinking Sandbox V1 validates;
- every sandbox cycle is covered;
- all 10 knowledge candidates are covered;
- all 10 atom candidates are covered;
- all 10 compact memory proposals are covered;
- no decision allows install/update/mutation;
- at least one candidate is marked needs validator;
- no active memory was updated;
- no active atom was installed;
- no live/runtime/pack execution occurred.
