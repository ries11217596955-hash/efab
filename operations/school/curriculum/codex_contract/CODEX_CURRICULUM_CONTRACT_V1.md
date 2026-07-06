# CODEX_CURRICULUM_CONTRACT_V1

Status: ACTIVE_CODEX_INPUT_CONTRACT
Runtime ready: false

## Purpose

This contract tells Codex how to create curriculum lesson candidates for CURRICULUM_SCHOOL_V1.

Codex is a candidate producer / draft curriculum builder. Codex is not the Builder brain and cannot self-promote learning.

## Boundary

- N is only a run budget, not proof of learning.
- Codex must not write active checkpoints or promote atoms.
- School validates every candidate.
- Accepted candidates become atoms only after validator + behavior-use proof + return-to-parent.
- Bad candidates are rejected or quarantined.

## Required candidate object

Each JSONL line must be one JSON object with:

```text
candidate_id
source_mode
topic
level
objective
new_knowledge
exercise
expected_behavior
negative_trap
validator_hint
behavior_use_proof_target
return_to_parent
source_anchor
duplicate_key
self_generated_easy_candidate=false
```

Allowed source_mode:

```text
directed_curriculum
experience_curriculum
```

## Reject rules

Reject candidate if:

- any required field is empty
- source_mode is unknown
- level is not a positive integer
- exercise is missing
- negative_trap is missing
- behavior_use_proof_target is missing
- return_to_parent is missing
- self_generated_easy_candidate is true
- duplicate_key repeats inside the same batch
- candidate is just a numbered restatement of another lesson
- candidate uses N/count as proof of quality
- candidate is a raw archive dump instead of compact lesson object

## Codex final report required

Codex must report:

```text
PREFLIGHT_STATUS=PREFLIGHT_PASS or BLOCKED_PREFLIGHT
candidate_count
file_written
validation_command_to_run
known_risks
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

## Correct generation target

Generate useful lesson candidates, not bulk text.

Good candidate:

```text
concept -> objective -> new knowledge -> exercise -> expected behavior -> negative trap -> validator hint -> behavior-use target -> return-to-parent
```

Bad candidate:

```text
candidate_001 says learn proof
candidate_002 says learn proof
candidate_003 says learn proof
```