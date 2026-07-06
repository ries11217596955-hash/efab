param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE47_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1"

Copy-Item ".\packs\PHASE47_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1\payload\validators\validate_remediation_program_seed_consumption_closure_proof_v1.ps1" ".\validators\validate_remediation_program_seed_consumption_closure_proof_v1.ps1" -Force

& ".\validators\validate_remediation_program_seed_consumption_closure_proof_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\validators\validate_remediation_program_seed_consumption_closure_proof_v1.ps1"
git add ".\proofs\REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 47 remediation program seed consumption closure proof v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
