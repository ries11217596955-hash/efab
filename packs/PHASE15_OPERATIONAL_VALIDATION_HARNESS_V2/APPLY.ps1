param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE15_OPERATIONAL_VALIDATION_HARNESS_V2"

Copy-Item ".\packs\PHASE15_OPERATIONAL_VALIDATION_HARNESS_V2\payload\contracts\operational_generated_agent_validation_report.schema.json" ".\contracts\operational_generated_agent_validation_report.schema.json" -Force
Copy-Item ".\packs\PHASE15_OPERATIONAL_VALIDATION_HARNESS_V2\payload\modules\test_generated_agent_package_operational.ps1" ".\modules\test_generated_agent_package_operational.ps1" -Force
Copy-Item ".\packs\PHASE15_OPERATIONAL_VALIDATION_HARNESS_V2\payload\validators\validate_operational_validation_harness_v2.ps1" ".\validators\validate_operational_validation_harness_v2.ps1" -Force
Copy-Item ".\packs\PHASE15_OPERATIONAL_VALIDATION_HARNESS_V2\payload\tasks\TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_001.json" ".\tasks\TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_001.json" -Force

& ".\validators\validate_operational_validation_harness_v2.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\operational_generated_agent_validation_report.schema.json"
git add ".\modules\test_generated_agent_package_operational.ps1"
git add ".\validators\validate_operational_validation_harness_v2.ps1"
git add ".\tasks\TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 15 operational validation harness v2"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
