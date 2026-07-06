# PHASE161H Acceptance Pipeline Self-Map Refresh Enforcement

The accepted-change completion contract is:

`ACCEPTED_CHANGE -> SELF_MAP_REFRESH -> SELF_KNOWLEDGE_READY`

An accepted functional change uses two commits:

1. the functional commit;
2. the self-map refresh commit describing the functional commit.

The refresh commit is not itself another refresh subject. This prevents infinite self-hash recursion.

Future tasks provide exact functional and refresh allowlists. The pipeline validates the functional change, commits and remotely verifies it, invokes the existing PHASE161E refresh, requires `SELF_KNOWLEDGE_READY`, commits the refreshed map, and verifies the final remote head.

Dry-run mode proves sequence, policy, allowlists, and safety without commit, push, or protected-state mutation.

Protected files, route locks, and `runtime_sessions` are excluded unless a separately approved phase explicitly places a protected file in the functional allowlist.
