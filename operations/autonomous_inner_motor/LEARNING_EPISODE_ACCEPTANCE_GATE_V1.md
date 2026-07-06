# Learning Episode Acceptance Gate V1

Status: ACTIVE_RULE_CANDIDATE

## Purpose

This gate accepts or rejects a `SandboxStudyLife` learning episode.

It does not prove that the learned content is true. It proves that the agent handled learning safely:

- unresolved or practical X is parked, not treated as death
- life continues with intellectual Y/Z
- Codex/source output remains `CODEX_DRAFT`
- raw source is deleted after compact digest
- practical actions and code writes remain zero
- active memory is not mutated
- output classification is sane
- atom candidates are routed to the existing accepted-atom retention mechanism

## Accepted classifications

- `CASE_PATTERN_CANDIDATE`
- `ATOM_CANDIDATE`
- `OPEN_LEARNING_GAP`
- `FUTURE_ACTION_CREATION_LANE`

Default for source-derived material is `CASE_PATTERN_CANDIDATE`.

## Atom route

Atom is not forbidden.

A source digest alone does not become an accepted atom automatically. If the learning output qualifies as `ATOM_CANDIDATE`, it must be routed to:

```text
EXISTING_ACCEPTED_ATOM_RETENTION_MECHANISM
```

Known validator family includes:

```text
validate_accepted_atom_retention_contract_v1.ps1
validate_accepted_atom_retention_micro_proof_v1.ps1
validate_accepted_atom_retention_passports_v1.ps1
validate_compact_atom_storage_bridge_micro_proof_v1.ps1
```

Only that downstream mechanism can accept/reject/quarantine/store the atom.

## Non-death requirement

At least one proof path must show:

```text
X parked
â†’ later Y/Z continued
```

## Boundary

Learning gate may accept an episode and route an atom candidate. It must not silently mutate active memory or claim `ACCEPTED_ATOM` without the accepted-atom retention proof path.
