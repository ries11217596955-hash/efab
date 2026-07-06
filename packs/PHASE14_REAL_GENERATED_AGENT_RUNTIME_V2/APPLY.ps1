param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE14_REAL_GENERATED_AGENT_RUNTIME_V2"

Copy-Item ".\packs\PHASE14_REAL_GENERATED_AGENT_RUNTIME_V2\payload\contracts\generated_agent_request.schema.json" ".\contracts\generated_agent_request.schema.json" -Force
Copy-Item ".\packs\PHASE14_REAL_GENERATED_AGENT_RUNTIME_V2\payload\contracts\generated_agent_result.schema.json" ".\contracts\generated_agent_result.schema.json" -Force
Copy-Item ".\packs\PHASE14_REAL_GENERATED_AGENT_RUNTIME_V2\payload\modules\new_external_agent_package.ps1" ".\modules\new_external_agent_package.ps1" -Force
Copy-Item ".\packs\PHASE14_REAL_GENERATED_AGENT_RUNTIME_V2\payload\validators\validate_real_generated_agent_runtime_v2.ps1" ".\validators\validate_real_generated_agent_runtime_v2.ps1" -Force
Copy-Item ".\packs\PHASE14_REAL_GENERATED_AGENT_RUNTIME_V2\payload\tasks\TASK_OPERATIONAL_VALIDATION_HARNESS_V2_001.json" ".\tasks\TASK_OPERATIONAL_VALIDATION_HARNESS_V2_001.json" -Force

& ".\validators\validate_real_generated_agent_runtime_v2.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\generated_agent_request.schema.json"
git add ".\contracts\generated_agent_result.schema.json"
git add ".\modules\new_external_agent_package.ps1"
git add ".\validators\validate_real_generated_agent_runtime_v2.ps1"
git add ".\tasks\TASK_OPERATIONAL_VALIDATION_HARNESS_V2_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 14 real generated agent runtime v2"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
