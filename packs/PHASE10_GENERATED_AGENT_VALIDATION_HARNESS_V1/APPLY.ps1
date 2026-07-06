param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE10_GENERATED_AGENT_VALIDATION_HARNESS_V1"

Copy-Item ".\packs\PHASE10_GENERATED_AGENT_VALIDATION_HARNESS_V1\payload\contracts\generated_agent_validation_report.schema.json" ".\contracts\generated_agent_validation_report.schema.json" -Force
Copy-Item ".\packs\PHASE10_GENERATED_AGENT_VALIDATION_HARNESS_V1\payload\modules\test_generated_agent_package.ps1" ".\modules\test_generated_agent_package.ps1" -Force
Copy-Item ".\packs\PHASE10_GENERATED_AGENT_VALIDATION_HARNESS_V1\payload\validators\validate_generated_agent_validation_harness_v1.ps1" ".\validators\validate_generated_agent_validation_harness_v1.ps1" -Force
Copy-Item ".\packs\PHASE10_GENERATED_AGENT_VALIDATION_HARNESS_V1\payload\tasks\TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_001.json" ".\tasks\TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_001.json" -Force

& ".\validators\validate_generated_agent_validation_harness_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\generated_agent_validation_report.schema.json"
git add ".\modules\test_generated_agent_package.ps1"
git add ".\validators\validate_generated_agent_validation_harness_v1.ps1"
git add ".\tasks\TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 10 generated agent validation harness v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
