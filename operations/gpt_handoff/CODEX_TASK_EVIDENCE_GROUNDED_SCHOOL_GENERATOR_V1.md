# CODEX TASK — Codex-authored knowledge campaign pack for existing school V1

STATUS: CODEX_DRAFT_TASK_FOR_EXISTING_SCHOOL_UPDATE
TARGET: existing school candidate factory / generator; do not create duplicate organ
OWNER GOAL: each new serious school campaign gets a fresh Codex-authored knowledge/candidate pack, then the school accelerates it into atoms and memory

## 0. Correct architecture

The school remains the main learning accelerator.
Codex is not the brain and not the runtime teacher.
Codex is used before a new serious knowledge campaign to author/update the campaign content that the existing school will consume.

Correct route:

```text
Owner chooses campaign goal/count/theme
→ Codex prepares/updates deep knowledge campaign pack for the existing school
→ existing school generator consumes that pack
→ school emits candidates/atoms
→ validators/streaming/digest gates accept or reject
→ compact memory stores only compressed accepted lessons
```

Do NOT build a separate direct-answer organ.
Do NOT replace the school with a new mechanism.
Do NOT make Codex run the school.
Do NOT start Count=50000 or Count=1000000 in this task.

## 1. Important clarification

A generator cannot create knowledge from nothing.
For external/domain knowledge, Codex must rely on provided sources or explicitly marked source requirements.
For current self-build work, this first campaign pack should use local Builder sources only:

```text
repo contracts
school scripts
validators
journal lessons
tracked proof summaries
preserved compact memory evidence snapshot
body-map reports
Owner instructions captured in journal/task files
```

For future campaigns about medicine, law, finance, biology, etc., Codex must require trusted source material before authoring candidate content.
No source → no knowledge.
No proof/source anchor → no memory candidate.

## 2. Existing organ to update, not duplicate

Existing school/candidate surfaces:

```text
operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1
operations/school/curriculum/candidate_factory/CODEX_CANDIDATE_FACTORY_V1.md
operations/school/curriculum/candidate_factory/FACTORY_MEMORY_AND_LADDER_LEDGER_V1.md
operations/school/curriculum/candidate_factory/FACTORY_TOPIC_CURSOR_LEDGER_V1.md
operations/school/curriculum/candidate_factory/validate_codex_curriculum_candidate_factory_v1.ps1
operations/school/curriculum/candidate_factory/validate_codex_candidate_factory_topic_cursor_ledger_v1.ps1
operations/school/curriculum/candidate_factory/validate_theme_cursor_ledger_v1.ps1
```

Do not create a new school organ or parallel generator directory.
Small helper file inside candidate_factory is allowed only if it is clearly part of the existing organ.

## 3. Mandatory coverage / level audit before campaign pack

Before authoring campaign seeds, Codex must read:

```text
operations/school/curriculum/candidate_factory/CAMPAIGN_COVERAGE_STATUS_POINTER_V1.md
```

Codex must produce compact tracked reports:

```text
operations/school/curriculum/candidate_factory/reports/CAMPAIGN_COVERAGE_AUDIT_V1.json
operations/school/curriculum/candidate_factory/reports/CAMPAIGN_LEVEL_PLAN_V1.json
```

Codex must reconcile the cursor ledger with compact memory snapshot and journal/proof history. Current known risk: theme_cursor_ledger reports all last_level=0 / next_level=1, while compact snapshot has 18021 cells. Blindly starting every root at level 1 is rejected.

Required audit fields per root/topic:

```text
root
memory_signal
cursor_signal
journal_signal
coverage_status = missing | weak | medium | saturated | unknown_conflict
recommended_start_level
recommended_seed_count
priority
reason
source_refs
```

Acceptance rule:

```text
No CAMPAIGN_COVERAGE_AUDIT_V1.json -> FAIL_VALIDATION
No CAMPAIGN_LEVEL_PLAN_V1.json -> FAIL_VALIDATION
Blind level=1 for all roots -> FAIL_VALIDATION
No source_refs -> FAIL_VALIDATION
```

## 4. Campaign pack concept

Codex should make the existing generator able to consume a Codex-authored campaign pack.
The pack is content, not a second organ.

Preferred location:

```text
operations/school/curriculum/candidate_factory/campaign_packs/
```

Create only one current pack for this task, for example:

```text
operations/school/curriculum/candidate_factory/campaign_packs/builder_self_knowledge_deep_v1.jsonl
operations/school/curriculum/candidate_factory/campaign_packs/builder_self_knowledge_deep_v1.manifest.json
```

The pack must be compact enough for Git. Do not write millions of candidate rows into Git.
For a million-atom campaign, store deep source lessons/templates/lesson seeds and let the generator expand them deterministically during runtime.

## 5. What Codex must author

Codex must author deep, varied lesson seeds from real local sources.
Each seed must include:

```text
seed_id
campaign_id
theme/root
depth_level_band
source_kind
source_path
source_anchor_or_hint
source_summary
lesson
negative_trap
proof_target
behavior_delta
return_to_parent
allowed_verbs/modes
expansion_budget
```

Good seed example:

```text
source_path: operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md
lesson: Count is a launch-time parameter of the canonical school entrypoint, not a reason to rewrite run_agent_school.ps1.
negative_trap: asking Codex to edit school code just to change Count.
proof_target: launch.json or command line shows -Count and -Mode.
behavior_delta: when Owner asks for 50k vs 1M, Builder changes launch parameter, not code.
```

Bad seed example:

```text
lesson: Builder must learn repo_structure through define.
```

## 6. Generator behavior after update

The existing generator should support campaign pack input.
Do not remove current fallback mode unless tests depend on it.
Preferred behavior:

```text
1. load topics plan
2. load cursor ledger
3. load campaign pack if provided or default current pack exists
4. select seed by campaign/root/least-used/cursor
5. expand seed into candidate using verb/mode/level
6. candidate includes source evidence and campaign seed identity
7. learning_key includes seed_id + root + verb + mode + level
8. generic template fallback allowed only when no seed exists, and must be marked fallback_template
```

Existing required candidate schema must remain compatible:

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

Additional fields are allowed if downstream validators tolerate them:

```text
campaign_id
seed_id
evidence_kind
evidence_path
evidence_summary
candidate_depth_score
```

## 7. Required source ladder for this first campaign

Use these local source surfaces:

```text
1. AGENTS.md current task/rules
2. operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md recent school/finalizer/generator lessons
3. operations/gpt_handoff/CODEX_TASK_EVIDENCE_GROUNDED_SCHOOL_GENERATOR_V1.md this task
4. operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md
5. operations/school/run_agent_school.ps1
6. operations/school/school_lifecycle_policy.json
7. operations/school/curriculum/topics/builder_night_school_topics_v1.json
8. operations/school/curriculum/candidate_factory/current files
9. operations/school/curriculum/candidate_factory/memory/active_compact_memory_snapshot_for_evidence_v1/manifest.json
10. operations/school/curriculum/candidate_factory/memory/active_compact_memory_snapshot_for_evidence_v1/index.json
11. operations/school/curriculum/candidate_factory/memory/active_compact_memory_snapshot_for_evidence_v1/cells_tail_sample_200.jsonl
12. tracked compact reports under reports/self_development when relevant
```

Runtime was cleaned before this task. Do not assume .runtime exists.

## 8. Required validation

Codex must add/update validation so a bounded batch proves that candidates are campaign-seed grounded.

Required checks:

```text
TargetAccepted=25 generation PASS
TargetAccepted=100 generation PASS
>= 90% generated candidates come from campaign seeds, not fallback_template
100% campaign candidates have seed_id/campaign_id/source_path/source_summary
100% source_path exists for local source seeds
learning_key uniqueness PASS
candidate schema compatibility PASS
streaming absorption on 100 candidates PASS or explain rejects
canonical school validator PASS
no long Live run started
no active compact memory mutation
no runtime/report bloat
```

If adding a validator, keep it under existing candidate_factory:

```text
operations/school/curriculum/candidate_factory/validate_campaign_pack_candidate_factory_v1.ps1
```

## 9. Bounded tests only

Allowed tests:

```text
candidate factory TargetAccepted=25 Test
candidate factory TargetAccepted=100 Test
streaming absorption on 100 candidates
canonical school validator
optional Count=10 Mode=Test if safe and non-live
```

Forbidden:

```text
Count=50000
Count=1000000
Mode=Live long run
attached long polling
direct active memory writes
```

## 10. PREFLIGHT requirement

Before file writes, Codex must inspect and report:

```text
repo root / branch / HEAD
git status --short --untracked-files=all
school-related process count
existing candidate_factory files
current topics plan path
current cursor ledger path
campaign_pack existing/missing status
coverage status pointer path and whether CAMPAIGN_COVERAGE_AUDIT / CAMPAIGN_LEVEL_PLAN exist
validator surfaces
preserved compact snapshot status
```

If blocker exists:

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

## 11. Delivery report

Final Codex report must include:

```text
STATUS: PASS | BLOCKED_PREFLIGHT | FAIL_VALIDATION
Files changed before PREFLIGHT_PASS: YES/NO
Existing organ updated: YES/NO
New organ created: YES/NO
Expected New organ created: NO
Coverage audit path
Level plan path
Campaign pack path
Campaign seeds count
Source paths used
Generated candidates tested
Seed-backed candidate percent
Fallback percent
Validators run and exact outputs
Runtime/report size impact
Files changed
Files intentionally not changed
Recommended next school run size after validation
```

## 12. Acceptance boundary

Accept only if:

```text
Codex authored a real campaign pack or pack support for existing generator
generator can consume campaign seeds
bounded tests pass
no duplicate organ exists
no long school run was started
repo is clean except intended tracked changes
```
