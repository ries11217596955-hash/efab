param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE46_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1"

Copy-Item ".\packs\PHASE46_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1\payload\validators\validate_monitoring_gap_closure_specialized_proof_v1.ps1" ".\validators\validate_monitoring_gap_closure_specialized_proof_v1.ps1" -Force
Copy-Item ".\packs\PHASE46_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1\payload\tasks\TASK_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1_001.json" ".\tasks\TASK_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1_001.json" -Force

& ".\validators\validate_monitoring_gap_closure_specialized_proof_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\validators\validate_monitoring_gap_closure_specialized_proof_v1.ps1"
git add ".\tasks\TASK_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1_001.json"
git add ".\proofs\MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 46 monitoring gap closure specialized proof v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
