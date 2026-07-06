param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE26_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1"

New-Item -ItemType Directory -Force -Path ".\specs\multi_profile_specialization_proof" | Out-Null

Copy-Item ".\packs\PHASE26_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1\payload\specs\multi_profile_proof\RAW_IDEA_AUDIT_MULTI_PROFILE_PROOF.json" ".\specs\multi_profile_specialization_proof\RAW_IDEA_AUDIT_MULTI_PROFILE_PROOF.json" -Force
Copy-Item ".\packs\PHASE26_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1\payload\specs\multi_profile_proof\RAW_IDEA_SPECIFICATION_MULTI_PROFILE_PROOF.json" ".\specs\multi_profile_specialization_proof\RAW_IDEA_SPECIFICATION_MULTI_PROFILE_PROOF.json" -Force
Copy-Item ".\packs\PHASE26_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1\payload\validators\validate_multi_profile_specialized_factory_proof_v1.ps1" ".\validators\validate_multi_profile_specialized_factory_proof_v1.ps1" -Force

& ".\validators\validate_multi_profile_specialized_factory_proof_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\specs\multi_profile_specialization_proof\RAW_IDEA_AUDIT_MULTI_PROFILE_PROOF.json"
git add ".\specs\multi_profile_specialization_proof\RAW_IDEA_SPECIFICATION_MULTI_PROFILE_PROOF.json"
git add ".\validators\validate_multi_profile_specialized_factory_proof_v1.ps1"
git add ".\proofs\MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 26 multi-profile specialized factory proof v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
