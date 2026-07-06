# Operations

Operations are controlled contracts for future wrappers and runtime-adjacent material use.

An operation contract defines what an operation does, what it may read and write, which material or quarantine record it relates to, what it must never do, and what proof is required before the operation can advance.

Operation contracts are not tool installs. They do not fetch repositories, run candidate tools, run smoke tests, or grant trust.

PHASE83 creates the operation contract skeleton only. No operation is trusted by default, and no `TRUSTED_OPERATION` may be created in this phase.

PHASE84 will create the first wrapper operation contracts. PHASE85 will run the first smoke install trial through a controlled proof path.

Materials cannot be used directly in external agents without an operation contract, validation evidence, and proof.
