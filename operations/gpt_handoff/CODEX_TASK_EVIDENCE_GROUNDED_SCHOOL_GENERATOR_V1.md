# CODEX TASK — Evidence-grounded school candidate generator V1

STATUS: CODEX_DRAFT_TASK_FOR_EXISTING_ORGAN_UPDATE
TARGET: update existing school candidate factory; do not create duplicate organ
OWNER GOAL: stop producing shallow template permutations; generate candidates from real Builder evidence and lessons

## 0. Hard boundary

This is a bounded repair/evolution task for the existing school candidate factory.

Do NOT create a new school organ.
Do NOT create a parallel generator directory.
Do NOT create a new runtime system.
Do NOT start a long school run.
Do NOT run Count=50000 or Count=1000000.
Do NOT rewrite unrelated school/digest/finalizer code.
Do NOT modify active compact memory directly.
Do NOT delete runtime/proof data.

Codex output is CODEX_DRAFT until validated by terminal proof.

## 1. Required PREFLIGHT

Before any file write, Codex must inspect and report:

```text
repo root
branch
HEAD
git status --short --untracked-files=all
whether school/digest/finalizer/queue-maintenance processes are running
existing candidate_factory files
current topics plan path
current cursor ledger path
current active compact memory manifest presence
current generator candidate schema
current validators relevant to candidate factory/school
```

If any blocker exists, stop with:

```text
BLOCKED_PREFLIGHT
```

No file writes before:

```text
PREFLIGHT_PASS
```

Final report must include:

```text
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

## 2. Existing organ to update

Existing school candidate factory surface:

```text
operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1
operations/school/curriculum/candidate_factory/CODEX_CANDIDATE_FACTORY_V1.md
operations/school/curriculum/candidate_factory/FACTORY_MEMORY_AND_LADDER_LEDGER_V1.md
operations/school/curriculum/candidate_factory/FACTORY_TOPIC_CURSOR_LEDGER_V1.md
operations/school/curriculum/candidate_factory/validate_codex_curriculum_candidate_factory_v1.ps1
operations/school/curriculum/candidate_factory/validate_codex_candidate_factory_topic_cursor_ledger_v1.ps1
operations/school/curriculum/candidate_factory/validate_theme_cursor_ledger_v1.ps1
```

Likely input data:

```text
operations/school/curriculum/topics/builder_night_school_topics_v1.json
operations/school/curriculum/candidate_factory/memory/theme_cursor_ledger.json
.runtime/active_compact_semantic_memory_v1/manifest.json
.runtime/active_compact_semantic_memory_v1/index.json
.runtime/active_compact_semantic_memory_v1/cells.jsonl
operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md
operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md
operations/school/school_lifecycle_policy.json
operations/reports/* selected compact reports only
```

## 3. Problem to fix

Current generator mostly does:

```text
topic root + verb + mode + level + generic template
```

This produces many formally valid but shallow variations.
It trains discipline and pipeline shape, but not enough real Builder knowledge.

Required change:

```text
candidate = topic/root + evidence source + extracted fact/lesson + negative trap + proof target + behavior delta
```

The generator must become evidence-grounded while preserving the existing school contract.

## 4. Source ladder for candidate evidence

Candidate evidence must come from real local Builder surfaces, in this priority order:

```text
1. canonical school contracts and policies
2. current generator/candidate_factory files
3. active compact memory manifest/index/cells sampled safely
4. GPT operator journal lessons/failures
5. school runtime proof JSON summaries
6. validators and their PASS/FAIL rules
7. body-map/self-model reports when compact and tracked
8. topics plan only as routing/curriculum frame, not as full knowledge source
```

Do not ingest huge raw runtime logs.
Do not embed full source files in candidates.
Do not copy raw cells.jsonl into candidates.
Do not use web/external sources.

## 5. Required generated candidate fields

Keep the existing schema required by current school contract. Each candidate must still include the current required fields, including but not limited to:

```text
candidate_id
topic
new_knowledge
exercise
expected_behavior
negative_trap
validator_hint
behavior_use_proof_target
return_to_parent
source_anchor
self_generated_easy_candidate=false
```

Add fields only if downstream validators tolerate them or update validators safely:

```text
evidence_kind
evidence_path
evidence_summary
evidence_hash_or_line_hint
lesson_type
candidate_depth_score
```

Do not break existing streaming/digest contract.

## 6. Evidence-grounded candidate rules

Each candidate must satisfy:

```text
has concrete evidence_path
has evidence_summary derived from that path/report/memory sample
new_knowledge contains a specific lesson, not generic template filler
negative_trap names a real mistake or likely false proof pattern
validator_hint names a concrete proof/check, not vague 'validate it'
behavior_use_proof_target says how future Builder behavior should change
return_to_parent says what parent task becomes stronger
source_anchor points to a real local file/report/memory surface
```

Bad candidate examples:

```text
Builder must learn the practical meaning of repo_structure through define.
Do not treat count as proof.
```

Better candidate example:

```text
Evidence: operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md
Lesson: Count is a launch-time parameter of the canonical school entrypoint, not a hardcoded curriculum rewrite.
Negative trap: editing run_agent_school.ps1 to change Count instead of passing -Count.
Validator hint: prove command line / launch.json includes Count and Mode.
Behavior target: when Owner asks for 50k vs 1M, Builder must choose launch parameter, not ask Codex to rewrite script.
```

## 7. Candidate source sampler requirement

Implement inside the existing candidate factory a small source/evidence sampler, not a new organ.

Acceptable implementation options:

```text
internal functions in generate_codex_curriculum_candidate_factory_run_v1.ps1
small helper file inside operations/school/curriculum/candidate_factory/ only if necessary
small tracked evidence catalogue JSON only if generated deterministically and not huge
```

Sampler should collect compact evidence cards such as:

```text
kind: contract | validator | journal_lesson | memory_manifest | memory_index_term | proof_summary | repo_file_rule
path: local path
summary: one compact fact/lesson
hash_or_hint: optional SHA256 / line hint / field hint
usable_topics: topic roots this evidence can support
trap: optional real trap
proof_hint: optional validator/proof check
```

Keep evidence cards compact.
Do not produce report spam.
Do not create large archives.

## 8. Selection logic requirement

Replace pure template scheduling with evidence-aware scheduling:

```text
1. choose next topic/root by cursor/weight as today
2. find evidence cards relevant to that root or adjacent roots
3. choose least recently used evidence card / rotate across evidence kinds
4. build candidate from evidence card + topic/root + verb/mode/level
5. produce learning_key including evidence identity to avoid shallow duplicates
```

If no evidence card exists for a root:

```text
fallback allowed = one generic candidate only
mark evidence_kind='fallback_template'
low candidate_depth_score
```

For large runs, generic fallback must not dominate.

## 9. Validators / proof requirements

Codex must add or update validation so that a small generated batch proves depth.

Required validation checks:

```text
candidate count matches TargetAccepted
100% candidates have required schema fields
>= 80% candidates in TargetAccepted=100 test have evidence_kind != fallback_template
>= 80% candidates have real evidence_path that exists or is a recognized active memory virtual path
>= 80% candidates have non-generic new_knowledge length and include evidence-derived content
learning_key uniqueness remains PASS
streaming still produces ready atoms without duplicate flood
no operations/reports heavy output bloat
```

Existing validators must continue to pass:

```text
operations/school/validate_agent_school_canonical_entrypoint_v1.ps1
operations/school/curriculum/candidate_factory/validate_codex_curriculum_candidate_factory_v1.ps1
operations/school/curriculum/candidate_factory/validate_theme_cursor_ledger_v1.ps1
```

If existing validators are insufficient, add one focused validator under existing candidate_factory directory:

```text
operations/school/curriculum/candidate_factory/validate_evidence_grounded_candidate_factory_v1.ps1
```

Do not add a new organ.

## 10. Test plan

Run only bounded tests:

```text
TargetAccepted=25 Test
TargetAccepted=100 Test
streaming absorption on 100 candidates
optional Count=10 Mode=Test through canonical school entrypoint
```

Do NOT run Live large school.
Do NOT mutate active compact memory in validation unless explicitly using a tiny Test mode that does not merge active memory.

Expected proof snippets:

```text
PREFLIGHT_PASS
EVIDENCE_CARDS_COUNT=<n>
GENERIC_FALLBACK_RATE=<percent>
CANDIDATE_DEPTH_PASS=true
VALIDATION_STATUS=PASS_EVIDENCE_GROUNDED_CANDIDATE_FACTORY_V1
STREAM_READY_ATOMS=100
STREAM_QUARANTINED=0 or justified low number
CANONICAL_VALIDATOR_PASS
```

## 11. Report format

Final Codex report must include:

```text
STATUS: PASS | BLOCKED_PREFLIGHT | FAIL_VALIDATION
Files changed before PREFLIGHT_PASS: YES/NO
Files changed
Files intentionally not changed
Existing organ updated: YES/NO
New organ created: YES/NO
Expected New organ created: NO
Evidence sources used
Evidence cards count
Fallback rate in 100-candidate test
Validators run and exact outputs
Runtime/report size impact
Remaining risks
Suggested next run size
```

## 12. Acceptance boundary

Accept only if:

```text
no duplicate organ created
existing factory still works
bounded tests pass
candidates are evidence-grounded, not mostly template permutations
repo remains clean except intended tracked changes
no long live school run started
```
