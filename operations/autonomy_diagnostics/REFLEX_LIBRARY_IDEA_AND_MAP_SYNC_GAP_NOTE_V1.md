# Reflex Library idea and map sync gap note

Status: STRATEGY_SUPPORTED / NOT_IMPLEMENTED

Owner proposed adding newborn-style innate reflexes: small safe built-in abilities that the agent can use before higher intelligence matures.

Accepted direction:
- one `AGENT_REFLEX_LIBRARY`, not a loose pile of scripts;
- one registry;
- one dispatcher;
- one validator;
- read-only by default;
- compact proof only;
- no mutation unless later maturity explicitly proves it.

Candidate first reflex atoms:
- READ_FILE_SUMMARY
- DETECT_FILE_TYPE
- VALIDATE_JSON
- COUNT_HASH_SIZE
- INSPECT_REPO_STATUS
- INSPECT_ACTIVE_MEMORY
- INSPECT_PROCESS_STATE
- SCAN_MARKERS
- POWERSHELL_SYNTAX_CHECK_READONLY
- WRITE_COMPACT_REFLEX_PROOF

Map check result:
- `self_control/CURRENT_AGENT_BUILDER_STATE.json` did not show the new autonomous inner motor organ markers.
- `self_knowledge/ROADMAP_STATE.json` did not show the new autonomous inner motor organ markers.
- Conclusion: current body/map/status surfaces did not auto-refresh after the new organ appeared.

Boundary:
- This note is not implementation.
- This note is not a new organ.
- Running SandboxTestLife process should not be stopped merely because map sync is stale.
