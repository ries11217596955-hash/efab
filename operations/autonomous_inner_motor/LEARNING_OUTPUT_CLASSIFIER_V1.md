# Learning Output Classifier V1

Status: ACTIVE_RULE_CANDIDATE

## Purpose

Classify each `SandboxStudyLife` learning output before the Learning Episode Acceptance Gate.

The classifier does not prove truth and does not store atoms. It selects the next route:

- `CASE_PATTERN_CANDIDATE`
- `ATOM_CANDIDATE`
- `OPEN_LEARNING_GAP`
- `FUTURE_ACTION_CREATION_LANE`

## Atom candidate route

`ATOM_CANDIDATE` is allowed when the learning output appears small, reusable, composable, Builder-relevant, has a validation path, and does not require practical action or memory mutation.

It remains route-only:

```text
ATOM_CANDIDATE -> EXISTING_ACCEPTED_ATOM_RETENTION_MECHANISM
```

It is not `ACCEPTED_ATOM` until downstream accepted-atom retention proof passes.

## Default

If the learning output is useful but not atom-shaped, classify as `CASE_PATTERN_CANDIDATE`.
