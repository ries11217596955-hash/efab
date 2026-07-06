# Evidence Packager Agent v1

Evidence Packager Agent v1 receives a task or incident and a list of evidence items. It produces an evidence package that identifies available evidence, missing evidence, risk flags, and the next operator action.

## Local Run

```powershell
pwsh -NoLogo -NoProfile -File generated_agents/evidence_packager_agent_v1/run.ps1 -InputPath generated_agents/evidence_packager_agent_v1/INPUT_EXAMPLE.json -OutputPath generated_agents/evidence_packager_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json
```

## Output

The output is JSON with:

- `evidence_manifest`
- `missing_evidence`
- `risk_flags`
- `next_operator_action`
- `validation_status`
