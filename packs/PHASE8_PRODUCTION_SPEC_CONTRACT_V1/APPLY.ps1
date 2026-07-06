param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE8_PRODUCTION_SPEC_CONTRACT_V1"

Copy-Item ".\packs\PHASE8_PRODUCTION_SPEC_CONTRACT_V1\payload\contracts\external_agent_spec.schema.json" ".\contracts\external_agent_spec.schema.json" -Force
Copy-Item ".\packs\PHASE8_PRODUCTION_SPEC_CONTRACT_V1\payload\specs\external_agent_spec_template\SPEC_TEMPLATE.json" ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json" -Force
Copy-Item ".\packs\PHASE8_PRODUCTION_SPEC_CONTRACT_V1\payload\modules\validate_production_external_agent_spec.ps1" ".\modules\validate_production_external_agent_spec.ps1" -Force
Copy-Item ".\packs\PHASE8_PRODUCTION_SPEC_CONTRACT_V1\payload\validators\validate_production_spec_contract_v1.ps1" ".\validators\validate_production_spec_contract_v1.ps1" -Force
Copy-Item ".\packs\PHASE8_PRODUCTION_SPEC_CONTRACT_V1\payload\tasks\TASK_PRODUCTION_PACKAGE_BLUEPRINT_V1_001.json" ".\tasks\TASK_PRODUCTION_PACKAGE_BLUEPRINT_V1_001.json" -Force

& ".\validators\validate_production_spec_contract_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\external_agent_spec.schema.json"
git add ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json"
git add ".\modules\validate_production_external_agent_spec.ps1"
git add ".\validators\validate_production_spec_contract_v1.ps1"
git add ".\tasks\TASK_PRODUCTION_PACKAGE_BLUEPRINT_V1_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 8 production spec contract v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
