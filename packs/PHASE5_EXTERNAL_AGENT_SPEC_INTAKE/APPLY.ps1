param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) {
    throw "Pack must be invoked by orchestrator."
}

Set-Location $RepoRoot

Write-Host "PACK=PHASE5_EXTERNAL_AGENT_SPEC_INTAKE_V1"

New-Item -ItemType Directory -Force -Path ".\specs\external_agent_spec_template" | Out-Null

Copy-Item ".\packs\PHASE5_EXTERNAL_AGENT_SPEC_INTAKE\payload\contracts\external_agent_spec.schema.json" ".\contracts\external_agent_spec.schema.json" -Force
Copy-Item ".\packs\PHASE5_EXTERNAL_AGENT_SPEC_INTAKE\payload\specs\external_agent_spec_template\SPEC_TEMPLATE.json" ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json" -Force
Copy-Item ".\packs\PHASE5_EXTERNAL_AGENT_SPEC_INTAKE\payload\modules\validate_external_agent_spec_template.ps1" ".\modules\validate_external_agent_spec_template.ps1" -Force
Copy-Item ".\packs\PHASE5_EXTERNAL_AGENT_SPEC_INTAKE\payload\validators\validate_external_agent_spec_intake.ps1" ".\validators\validate_external_agent_spec_intake.ps1" -Force
Copy-Item ".\packs\PHASE5_EXTERNAL_AGENT_SPEC_INTAKE\payload\tasks\TASK_EXTERNAL_AGENT_PACKAGE_GENERATOR_001.json" ".\tasks\TASK_EXTERNAL_AGENT_PACKAGE_GENERATOR_001.json" -Force

& ".\validators\validate_external_agent_spec_intake.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\external_agent_spec.schema.json"
git add ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json"
git add ".\modules\validate_external_agent_spec_template.ps1"
git add ".\validators\validate_external_agent_spec_intake.ps1"
git add ".\tasks\TASK_EXTERNAL_AGENT_PACKAGE_GENERATOR_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 5 external agent spec intake"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
