param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE29_MISSING_PROFILE_FACTORY_PROOF_V1"

Copy-Item ".\packs\PHASE29_MISSING_PROFILE_FACTORY_PROOF_V1\payload\specs\missing_profile_factory_proof\RAW_IDEA_MISSING_PROFILE_FACTORY_PROOF.json" ".\specs\specialization_gap_proof\RAW_IDEA_MISSING_PROFILE_FACTORY_PROOF.json" -Force
Copy-Item ".\packs\PHASE29_MISSING_PROFILE_FACTORY_PROOF_V1\payload\validators\validate_missing_profile_factory_proof_v1.ps1" ".\validators\validate_missing_profile_factory_proof_v1.ps1" -Force

& ".\validators\validate_missing_profile_factory_proof_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\specs\specialization_gap_proof\RAW_IDEA_MISSING_PROFILE_FACTORY_PROOF.json"
git add ".\validators\validate_missing_profile_factory_proof_v1.ps1"
git add ".\proofs\MISSING_PROFILE_FACTORY_PROOF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 29 missing-profile factory proof v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
