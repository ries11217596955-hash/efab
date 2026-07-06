# PHASE164K Owner Candidate Self-Growth Adapter

Purpose:
Register a pack that lets the existing orchestrator take the first owner-candidate self-growth task.

This is not a parallel runner.

Correct flow:
TASK_QUEUE.active_task_id -> orchestrator/run.ps1 -Mode SELF_BUILD -> packs/registry.json -> this adapter pack -> self-growth request artifact.

This adapter does not:
- accept atoms;
- mutate accepted core;
- mutate route lock;
- execute Codex;
- directly promote owner candidates.
