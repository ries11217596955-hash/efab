# SCHOOL_PATCH_EXECUTOR_INSTALLATION_20260714

Status: PASS_SCHOOL_PATCH_EXECUTOR_V1_LAUNCHER_REPAIRED_AND_VALIDATED

What changed:

- Windows launcher now uses `codex.cmd`, not `codex.ps1`.
- Obsolete `--ask-for-approval` was removed.
- Long Codex prompt is passed through stdin using `codex exec ... -`.
- Windows `cmd /c` double-outer quoting is used for executable paths.
- Timeout cleanup now kills only the process tree rooted at the executor cmd process.

Validation:

- mock_executor_validation: PASS_SCHOOL_PATCH_EXECUTOR_VALIDATION_V1
- mock_executor_status: PASS_PATCH_EXECUTOR_VALIDATED_NO_ABSORB_V1
- mock_codex_status: MOCK_CODEX_DRAFT_CREATED
- mock_ledger_state: VALIDATED_NORMALIZED
- mock_memory_changed: False

Real Codex no-absorb trial:

- status: PASS_REAL_CODEX_TIMEOUT_RECORDED_NO_MEMORY_MUTATION_V1
- codex_status: CODEX_FAILED
- codex_failure_class: HANG_OR_TIMEOUT
- ledger_state: CODEX_FAILED
- memory_changed: False
- absorption_run: False
- candidates_created: False

Conclusion:

```text
1000-candidate real Codex patch reached Codex execution but timed out without candidates.
Next slice must use retry narrowing: 500, then 200, or reduce task complexity before absorption.
```

Operator incident:

```text
manual cleanup regex was too broad and stopped unrelated Codex app-server/node processes while clearing locked runtime files.
No repo or memory damage was observed.
Corrective change: executor timeout cleanup now kills only its own child process tree.
```
