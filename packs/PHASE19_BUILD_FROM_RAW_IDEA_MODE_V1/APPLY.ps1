param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE19_BUILD_FROM_RAW_IDEA_MODE_V1"

Copy-Item ".\packs\PHASE19_BUILD_FROM_RAW_IDEA_MODE_V1\payload\orchestrator\run.ps1" ".\orchestrator\run.ps1" -Force
Copy-Item ".\packs\PHASE19_BUILD_FROM_RAW_IDEA_MODE_V1\payload\specs\mode_proof\RAW_IDEA_MODE_PROOF.json" ".\specs\idea_to_agent_proof\RAW_IDEA_MODE_PROOF.json" -Force
Copy-Item ".\packs\PHASE19_BUILD_FROM_RAW_IDEA_MODE_V1\payload\validators\validate_build_from_raw_idea_mode_v1.ps1" ".\validators\validate_build_from_raw_idea_mode_v1.ps1" -Force
Copy-Item ".\packs\PHASE19_BUILD_FROM_RAW_IDEA_MODE_V1\payload\tasks\TASK_IDEA_TO_AGENT_FACTORY_PROOF_V1_001.json" ".\tasks\TASK_IDEA_TO_AGENT_FACTORY_PROOF_V1_001.json" -Force

& ".\validators\validate_build_from_raw_idea_mode_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\orchestrator\run.ps1"
git add ".\specs\idea_to_agent_proof\RAW_IDEA_MODE_PROOF.json"
git add ".\validators\validate_build_from_raw_idea_mode_v1.ps1"
git add ".\tasks\TASK_IDEA_TO_AGENT_FACTORY_PROOF_V1_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 19 build-from-raw-idea mode v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
