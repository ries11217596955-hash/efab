# THINKING SANDBOX V1 REQUIREMENT

STATUS: LAB_ONLY / NON_MUTATING / THINKING_TRIAL / NOT_LIVE / NOT_AUTONOMOUS_RUNTIME

## Purpose

Thinking Sandbox V1 runs a bounded non-mutating thinking trial.

It tests whether the Builder can read current body state and priority policy, form questions, build reasoning chains, propose knowledge atoms, propose compact memory updates, and return to parent without executing actions.

This is not live runtime.
This is not autonomous life.
This is not pack execution.
This is not memory mutation.
This is not PASSPORT_ACTIVE.

## Inputs

Required:
- `reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_BODY_STATE.json`
- `reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_REASONER.json`
- `reports/self_development/PRIORITY_POLICY_CONTRACT_V1_SCORED_OPTIONS.json`
- `tests/self_development/PRIORITY_POLICY_CONTRACT_V1_PROOF.json`
- `operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md`

## Outputs

Required:
- `reports/self_development/THINKING_SANDBOX_V1_TRACE.json`
- `reports/self_development/THINKING_SANDBOX_V1_KNOWLEDGE_ATOM_CANDIDATES.json`
- `reports/self_development/THINKING_SANDBOX_V1_COMPACT_MEMORY_PROPOSALS.json`
- `reports/self_development/THINKING_SANDBOX_V1_REPORT.json`
- `tests/self_development/THINKING_SANDBOX_V1_PROOF.json`

## Trial behavior

The sandbox must produce at least 10 thought cycles.
Each cycle must contain:
- observed_signal
- question
- reasoning_chain
- new_knowledge_candidate
- atom_candidate
- memory_update_proposal
- action_recommendation
- forbidden_actions
- return_to_parent_note

## Laws enforced

- Thinking is not execution.
- Knowledge candidate is not active memory.
- Atom candidate is not installed atom.
- Compact memory proposal is not compact memory update.
- A signal can lead to inquiry, not forced action.
- No live/runtime/pack execution during thinking trial.
- No file writes outside sandbox outputs.
- No PASSPORT_ACTIVE.

## Acceptance

Validator must prove:
- priority policy validates;
- current state refresh validates;
- trace has at least 10 cycles;
- every cycle has all required fields;
- knowledge atoms are candidates only;
- compact memory proposals are proposals only;
- no active memory was modified;
- no runtime/live/pack execution occurred;
- no mutation authority was claimed;
- no installed atom or PASSPORT_ACTIVE was created;
- report returns to parent with next logic tuning recommendation.
