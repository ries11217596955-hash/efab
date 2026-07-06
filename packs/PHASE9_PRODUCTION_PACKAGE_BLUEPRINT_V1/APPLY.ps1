param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE9_PRODUCTION_PACKAGE_BLUEPRINT_V1"

Copy-Item ".\packs\PHASE9_PRODUCTION_PACKAGE_BLUEPRINT_V1\payload\contracts\agent_package_blueprint.schema.json" ".\contracts\agent_package_blueprint.schema.json" -Force
Copy-Item ".\packs\PHASE9_PRODUCTION_PACKAGE_BLUEPRINT_V1\payload\modules\new_external_agent_package.ps1" ".\modules\new_external_agent_package.ps1" -Force
Copy-Item ".\packs\PHASE9_PRODUCTION_PACKAGE_BLUEPRINT_V1\payload\validators\validate_production_package_blueprint_v1.ps1" ".\validators\validate_production_package_blueprint_v1.ps1" -Force
Copy-Item ".\packs\PHASE9_PRODUCTION_PACKAGE_BLUEPRINT_V1\payload\tasks\TASK_GENERATED_AGENT_VALIDATION_HARNESS_V1_001.json" ".\tasks\TASK_GENERATED_AGENT_VALIDATION_HARNESS_V1_001.json" -Force

& ".\validators\validate_production_package_blueprint_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\agent_package_blueprint.schema.json"
git add ".\modules\new_external_agent_package.ps1"
git add ".\validators\validate_production_package_blueprint_v1.ps1"
git add ".\tasks\TASK_GENERATED_AGENT_VALIDATION_HARNESS_V1_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 9 production package blueprint v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
