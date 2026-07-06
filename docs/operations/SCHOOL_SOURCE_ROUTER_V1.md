# School Source Router V1

Status: ACTIVE_MINIMAL_INTERNAL_FACTORY_FIRST

## Purpose

School source router governs how school obtains candidate material before the existing validators/finalizer/intake/merge path.

## Sources

```text
InternalFactory        -> enabled/proven first source
CodexSourcePort        -> registered, not enabled in V1
ExternalWorldSourcePort -> registered, not enabled in V1
```

## Law

Sources are material suppliers only. They are not school brain, not route authority, and cannot write compact memory directly.

```text
source material
-> existing factory/normalizer
-> existing school validators
-> school proof
-> finalizer
-> intake
-> merge queue
-> compact memory
```

V1 wires the existing InternalFactory path through a source router and records source-selection proof. Codex and ExternalWorld ports are explicitly registered but blocked until their governed ports and validators are implemented.
## CodexSourcePort V1

CodexSourcePort is a governed readonly draft material supplier. It calls the existing `ask_codex_batch_knowledge_source.ps1` port and accepts only `CODEX_DRAFT` with required schema shape. V1 does not let Codex write memory or bypass school validators. When explicitly enabled and selected, Codex draft material is recorded, then candidate generation still passes through the existing factory/validator path.

## ExternalWorldSourcePort V1

ExternalWorldSourcePort is a governed external material supplier. It admits only EXTERNAL_MATERIAL_CANDIDATE after provenance, authority-tier and validation-shape checks. V1 supports seeded material packets and bounded URL fetch attempts. Fetched/seeded material cannot write memory, cannot decide route, and cannot bypass school validators. Explicit selection is required; default policy remains InternalFactory-first.
