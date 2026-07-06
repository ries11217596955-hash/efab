param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE13_PRODUCTION_TRUTH_RESET_V2"

Copy-Item ".\packs\PHASE13_PRODUCTION_TRUTH_RESET_V2\payload\validators\validate_production_truth_reset_v2.ps1" ".\validators\validate_production_truth_reset_v2.ps1" -Force
Copy-Item ".\packs\PHASE13_PRODUCTION_TRUTH_RESET_V2\payload\tasks\TASK_REAL_GENERATED_AGENT_RUNTIME_V2_001.json" ".\tasks\TASK_REAL_GENERATED_AGENT_RUNTIME_V2_001.json" -Force

& ".\validators\validate_production_truth_reset_v2.ps1" -FinalizePhase -RunId $RunId

git add ".\validators\validate_production_truth_reset_v2.ps1"
git add ".\tasks\TASK_REAL_GENERATED_AGENT_RUNTIME_V2_001.json"
git add ".\proofs\PRODUCTION_HONESTY_RESET_V2.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 13 production truth reset v2"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
