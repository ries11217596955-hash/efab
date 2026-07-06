param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE50_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1"

Copy-Item ".\packs\PHASE50_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1\payload\validators\validate_one_run_remediation_seed_program_synthesis_proof_v1.ps1" ".\validators\validate_one_run_remediation_seed_program_synthesis_proof_v1.ps1" -Force

& ".\validators\validate_one_run_remediation_seed_program_synthesis_proof_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\validators\validate_one_run_remediation_seed_program_synthesis_proof_v1.ps1"
git add ".\proofs\ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 50 one-run remediation seed program synthesis proof v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
