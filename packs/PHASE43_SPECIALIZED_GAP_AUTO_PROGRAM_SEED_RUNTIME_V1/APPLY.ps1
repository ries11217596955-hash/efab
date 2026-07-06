param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE43_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1"

Copy-Item ".\packs\PHASE43_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1\payload\orchestrator\run.ps1" ".\orchestrator\run.ps1" -Force
Copy-Item ".\packs\PHASE43_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1\payload\validators\validate_specialized_gap_auto_program_seed_runtime_v1.ps1" ".\validators\validate_specialized_gap_auto_program_seed_runtime_v1.ps1" -Force
Copy-Item ".\packs\PHASE43_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1\payload\tasks\TASK_ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1_001.json" ".\tasks\TASK_ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1_001.json" -Force

& ".\validators\validate_specialized_gap_auto_program_seed_runtime_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\orchestrator\run.ps1"
git add ".\validators\validate_specialized_gap_auto_program_seed_runtime_v1.ps1"
git add ".\tasks\TASK_ONE_RUN_REMEDIATION_PROGRAM_SEED_PROOF_V1_001.json"
git add ".\proofs\SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 43 specialized gap auto-program-seed runtime v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
