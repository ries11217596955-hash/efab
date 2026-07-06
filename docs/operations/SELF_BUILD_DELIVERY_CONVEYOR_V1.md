# SELF_BUILD_DELIVERY_CONVEYOR_V1

This operational contract records the post-PHASE97 delivery rule for complex Builder self-development work.

- Codex prepares the bounded seed files and leaves Builder runtime unrun.
- A combined terminal pack performs seed validation, Builder runtime, proof/report validation, then commit and push.
- Runtime may start only after seed validation passes.
- Commit may happen only after runtime and proof validation pass.
- Any FAIL stops the conveyor before commit or push and requires an owner-facing failure report.
- Fake PASS is forbidden; failed evidence remains visible.

This reduces manual actions by joining the repetitive validation-runtime-proof-commit path into one guarded terminal packet while keeping proof discipline intact.
