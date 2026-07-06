# PHASE78 Agent Builder Self-Knowledge System Full Contract V1

## Active Line

AGENT_BUILDER_SELF_DEVELOPMENT

## Purpose

This pack seeds the full-contract self-knowledge surface for Agent Builder. It does not create an external agent, and it does not mark Operation System or Blueprint Compiler as completed.

The self-knowledge system reads repo artifacts and writes durable JSON plus an owner-readable summary that answers:

- Who Builder is.
- What repo this is.
- What the current capability is.
- Whether the queue is clean or active.
- What major systems exist.
- What major systems are missing.
- What agents or agent-like products are evidenced.
- What proofs and reports support the claims.
- What should be built next.
- What should not be done next.

## Runtime

Run from the repository root in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/APPLY.ps1
```

## Validation

Pre-runtime structural validation:

```powershell
powershell -ExecutionPolicy Bypass -File packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/VALIDATE.ps1 -Stage PreRuntime
```

Completed runtime validation:

```powershell
powershell -ExecutionPolicy Bypass -File packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/VALIDATE.ps1 -Stage Completed
```

## Outputs

- `self_knowledge/BUILDER_SELF_MODEL.json`
- `self_knowledge/CAPABILITY_MANIFEST.json`
- `self_knowledge/MODULE_INVENTORY.json`
- `self_knowledge/EVIDENCE_INDEX.json`
- `self_knowledge/PRODUCED_AGENTS_INDEX.json`
- `self_knowledge/ROADMAP_STATE.json`
- `reports/self_knowledge/BUILDER_SELF_DESCRIBE_REPORT.json`
- `reports/self_knowledge/BUILDER_SELF_DESCRIBE_SUMMARY.md`
- `proofs/self_knowledge/AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1.json`
