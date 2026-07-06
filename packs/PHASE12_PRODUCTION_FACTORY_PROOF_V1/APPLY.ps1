param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE12_PRODUCTION_FACTORY_PROOF_V1"

New-Item -ItemType Directory -Force -Path ".\specs\production_factory_proof" | Out-Null

Copy-Item ".\packs\PHASE12_PRODUCTION_FACTORY_PROOF_V1\payload\specs\production_factory_proof\PRODUCTION_FACTORY_PROOF_SPEC.json" ".\specs\production_factory_proof\PRODUCTION_FACTORY_PROOF_SPEC.json" -Force
Copy-Item ".\packs\PHASE12_PRODUCTION_FACTORY_PROOF_V1\payload\validators\validate_production_factory_proof_v1.ps1" ".\validators\validate_production_factory_proof_v1.ps1" -Force

& ".\validators\validate_production_factory_proof_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\specs\production_factory_proof\PRODUCTION_FACTORY_PROOF_SPEC.json"
git add ".\validators\validate_production_factory_proof_v1.ps1"
git add ".\proofs\PRODUCTION_FACTORY_PROOF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 12 production factory proof v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
