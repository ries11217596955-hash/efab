# AIMO default no-gate live hotswap preflight V1

status: PASS_AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_PREFLIGHT_V1
head: 535ea8b
live_aimo_pid: 10044
current_live_gated: True

## What is proven before live hotswap
- Default no-gate selector chooses SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT in lab.
- Legacy School/latest paths are demoted and do not win default authority.
- Runtime is compact and repo is clean/synced.

## Proposed live hotswap
- Stop current gated live AIMO with checkpoint.
- Start new live AIMO without `-UseSourceAgnosticPathSelectionLabGate`.
- Expected selection: `SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT` and task `build_source_agnostic_path_selector_v1`.

## Boundaries
- This preflight does not perform live hotswap.
- Active memory purity is not claimed because live AIMO shares `.runtime` active memory.
- Legacy emergency fallback on missing source-agnostic report remains not proven.
- Child-agent factory readiness remains not proven.
