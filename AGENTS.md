# AGENTS.md Ã¢â‚¬â€ Codex execution contract

## Purpose

This file is the repo-local command contract for Codex and other bounded external executors working in `H:\efab`.

**AGENTS.md is a command file, not a history archive, proof ledger, status snapshot, Notebook, or source of current runtime truth.**

Do not add dated progress, old phase summaries, proof counts, historical PASS lists, debt history, or current-state claims here. Resolve current reality from fresh repo/runtime evidence and from the exact task package.

## 1. Role boundary

Codex is a bounded executor for implementation, repair, audit, and validation.

Codex is not:

- Builder brain or identity;
- accepted truth or acceptance authority;
- live supervisor;
- unbounded repo explorer;
- autonomous child-agent factory;
- authority to mutate protected/live/remote surfaces.

Codex output is `CODEX_DRAFT` until Builder independently validates and accepts it.

## 2. Task authority and scope

Act only on the explicit current task package from Owner/Builder.

The task package must bound:

- allowed reads / context budget;
- allowed output files;
- requirements and cut list;
- validators / proof expected;
- action class and environment where relevant.

Do not infer mutation authority from tool availability, prior work, old reports, branches, proofs, or this file.

## 3. Mandatory PREFLIGHT before writes

Before any file write:

1. confirm repo root, branch, HEAD, and `git status --short`;
2. read this applicable `AGENTS.md`;
3. verify every allowed output path and that no unexpected dirty state overlaps the task;
4. verify every required input/validator named by the task exists;
5. verify the requested work stays inside the exact scope.

If any blocker exists, return:

```text
STATUS: BLOCKED_PREFLIGHT
BLOCKER: <reason>
FILES_CHANGED_BEFORE_PREFLIGHT_PASS: NO
```

No writes before `PREFLIGHT_PASS`.

## 4. Hard context budget

When the task gives an exact read list, that list is the context budget.

Allowed bounded discovery may include:

```text
git status --short
git rev-parse HEAD
git branch --show-current
git ls-files <explicit pathspecs>
Select-String / grep over explicit task paths
shallow listing of explicitly named directories
```

Forbidden unless the task explicitly expands scope:

- repo-root recursive scans;
- reading all `reports/**`, `tests/**`, `operations/**`, `modules/**`, or `docs/**`;
- reading quarantine or legacy trees as authority;
- reading `AGENT_BUILDER_SELF_NOTEBOOK.md` merely to discover work;
- opening historical proofs to manufacture current status.

If another file is needed, stop and request bounded read-budget expansion.

## 5. Fresh truth and continuity boundary

Fresh scoped proof wins over static text, Notebook, reports, old maps, transcripts, or Codex claims.

`AGENT_BUILDER_SELF_NOTEBOOK.md` is GPT/Builder continuity, not Codex history to ingest by default. Read it only when the task explicitly includes it.

Current repo/runtime/live status must be observed fresh for the claimed scope. Never copy a volatile status into this file.

## 6. Protected and live surfaces

Treat active memory and live runtime as protected.

Without explicit scoped authority, do not:

- delete/recreate/migrate `.runtime` active compact memory;
- mutate live processes, services, Scheduled Tasks, Bridge channels, tunnels, or credentials;
- perform remote Git/GitHub mutation;
- run destructive cleanup;
- transplant LAB artifacts into LIVE/accepted-core;
- overwrite generated registries/maps manually when a generator owns them.

`LAB_PROOF != LIVE_PROOF` and proof never grants mutation authority.

## 7. Implementation discipline

Prefer reuse and the smallest bounded change.

Do not create a new School, memory system, organ, framework, recovery product, or duplicate route when an existing canonical mechanism can satisfy the task.

Do not broaden a repair into cleanup/refactor unless explicitly requested.

Do not silently delete history or accepted behavior. Decommission requires explicit scope and proof.

For School work, use the canonical owner interface only when the task names it:

`operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md`

For School Codex execution under Bridge/SYSTEM on this Windows host, do not guess the runtime path:

- proven CLI: `C:\Users\Azerbaijan\.codex\.sandbox-bin\codex.exe`;
- proven home: `CODEX_HOME=C:\Users\Azerbaijan\.codex`;
- prefer explicit `EFAB_CODEX_EXE` / `EFAB_CODEX_HOME` when supplied; otherwise use the single healthy authenticated profile selected by the School resolver;
- for the School producer under Bridge/SYSTEM use `--dangerously-bypass-approvals-and-sandbox`, not `-s workspace-write`; the latter is a known non-working Windows/SYSTEM branch here;
- bounded bypass is allowed only after `PREFLIGHT_PASS` and only for the exact School warehouse outputs named by the task; no tracked-repo edits, no active-memory writes, no remote/network side tasks;
- do not install or create a second Codex to work around this route.

Do not infer School readiness or progress from this `AGENTS.md`.

## 8. Validation and proof

A validator must match the claim scope and, where relevant, state:

- inputs;
- procedure;
- pass/fail rule;
- claims proven;
- `does_not_prove`;
- negative tests.

Structural PASS does not prove semantic behavior. One smoke does not prove stability. A changed model/config requires revalidation.

Before handoff, run task-scoped validators and `git diff --check` for changed repo files.

## 9. Commit and remote discipline

Do not commit, push, force-push, rebase, reset history, or mutate remote state unless the current task explicitly authorizes it.

If commit is authorized, stage only the accepted task files and verify staged scope before commit.

If push is authorized, fetch first and prove non-divergence / fast-forward safety. Never use force as a convenience.

## 10. Required output contract

Return a compact execution report containing:

```text
STATUS:
FILES_CHANGED:
VALIDATORS:
PROOF:
LIMITATIONS:
RISKS:
NEXT_SAFE_ACTION:
```

If blocked, say exactly what is missing. Do not report completion from draft text, tool availability, or partial execution.

## 11. Cut list

Do not:

- turn this file back into history/proof/status storage;
- ingest the whole repo for context;
- treat old maps/reports as current authority;
- touch protected memory by default;
- mutate live/remote surfaces without scoped authority;
- create duplicate architecture instead of reusing the existing body;
- claim acceptance because Codex wrote code or a validator returned an unrelated PASS.
