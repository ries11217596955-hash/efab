param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE11_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1"

Copy-Item ".\packs\PHASE11_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1\payload\modules\invoke_external_agent_build.ps1" ".\modules\invoke_external_agent_build.ps1" -Force
Copy-Item ".\packs\PHASE11_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1\payload\orchestrator\run.ps1" ".\orchestrator\run.ps1" -Force
Copy-Item ".\packs\PHASE11_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1\payload\validators\validate_factory_build_external_agent_mode_v1.ps1" ".\validators\validate_factory_build_external_agent_mode_v1.ps1" -Force
Copy-Item ".\packs\PHASE11_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1\payload\tasks\TASK_PRODUCTION_FACTORY_PROOF_V1_001.json" ".\tasks\TASK_PRODUCTION_FACTORY_PROOF_V1_001.json" -Force

& ".\validators\validate_factory_build_external_agent_mode_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\modules\invoke_external_agent_build.ps1"
git add ".\orchestrator\run.ps1"
git add ".\validators\validate_factory_build_external_agent_mode_v1.ps1"
git add ".\tasks\TASK_PRODUCTION_FACTORY_PROOF_V1_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 11 factory build external agent mode v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
