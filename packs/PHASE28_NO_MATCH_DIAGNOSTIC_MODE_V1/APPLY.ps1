param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE28_NO_MATCH_DIAGNOSTIC_MODE_V1"

New-Item -ItemType Directory -Force -Path ".\specs\specialization_gap_proof" | Out-Null

Copy-Item ".\packs\PHASE28_NO_MATCH_DIAGNOSTIC_MODE_V1\payload\orchestrator\run.ps1" ".\orchestrator\run.ps1" -Force
Copy-Item ".\packs\PHASE28_NO_MATCH_DIAGNOSTIC_MODE_V1\payload\specs\gap_mode_proof\RAW_IDEA_GAP_MODE_PROOF.json" ".\specs\specialization_gap_proof\RAW_IDEA_GAP_MODE_PROOF.json" -Force
Copy-Item ".\packs\PHASE28_NO_MATCH_DIAGNOSTIC_MODE_V1\payload\validators\validate_no_match_diagnostic_mode_v1.ps1" ".\validators\validate_no_match_diagnostic_mode_v1.ps1" -Force
Copy-Item ".\packs\PHASE28_NO_MATCH_DIAGNOSTIC_MODE_V1\payload\tasks\TASK_MISSING_PROFILE_FACTORY_PROOF_V1_001.json" ".\tasks\TASK_MISSING_PROFILE_FACTORY_PROOF_V1_001.json" -Force

& ".\validators\validate_no_match_diagnostic_mode_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\orchestrator\run.ps1"
git add ".\specs\specialization_gap_proof\RAW_IDEA_GAP_MODE_PROOF.json"
git add ".\validators\validate_no_match_diagnostic_mode_v1.ps1"
git add ".\tasks\TASK_MISSING_PROFILE_FACTORY_PROOF_V1_001.json"
git add ".\proofs\NO_MATCH_DIAGNOSTIC_MODE_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 28 no-match diagnostic mode v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
