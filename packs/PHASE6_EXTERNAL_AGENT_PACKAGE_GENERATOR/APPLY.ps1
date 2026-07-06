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

Write-Host "PACK=PHASE6_EXTERNAL_AGENT_PACKAGE_GENERATOR_V1"

Copy-Item ".\packs\PHASE6_EXTERNAL_AGENT_PACKAGE_GENERATOR\payload\contracts\external_agent_package_manifest.schema.json" ".\contracts\external_agent_package_manifest.schema.json" -Force
Copy-Item ".\packs\PHASE6_EXTERNAL_AGENT_PACKAGE_GENERATOR\payload\modules\new_external_agent_package.ps1" ".\modules\new_external_agent_package.ps1" -Force
Copy-Item ".\packs\PHASE6_EXTERNAL_AGENT_PACKAGE_GENERATOR\payload\validators\validate_external_agent_package_generator.ps1" ".\validators\validate_external_agent_package_generator.ps1" -Force
Copy-Item ".\packs\PHASE6_EXTERNAL_AGENT_PACKAGE_GENERATOR\payload\tasks\TASK_FIRST_PROVEN_EXTERNAL_AGENT_001.json" ".\tasks\TASK_FIRST_PROVEN_EXTERNAL_AGENT_001.json" -Force

& ".\validators\validate_external_agent_package_generator.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\external_agent_package_manifest.schema.json"
git add ".\modules\new_external_agent_package.ps1"
git add ".\validators\validate_external_agent_package_generator.ps1"
git add ".\tasks\TASK_FIRST_PROVEN_EXTERNAL_AGENT_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 6 external agent package generator"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
