param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE17_OPERATIONAL_FACTORY_PROOF_V2"

New-Item -ItemType Directory -Force -Path ".\specs\operational_factory_proof" | Out-Null

Copy-Item ".\packs\PHASE17_OPERATIONAL_FACTORY_PROOF_V2\payload\specs\operational_factory_proof\OPERATIONAL_FACTORY_PROOF_SPEC.json" ".\specs\operational_factory_proof\OPERATIONAL_FACTORY_PROOF_SPEC.json" -Force
Copy-Item ".\packs\PHASE17_OPERATIONAL_FACTORY_PROOF_V2\payload\validators\validate_operational_factory_proof_v2.ps1" ".\validators\validate_operational_factory_proof_v2.ps1" -Force

& ".\validators\validate_operational_factory_proof_v2.ps1" -FinalizePhase -RunId $RunId

git add ".\specs\operational_factory_proof\OPERATIONAL_FACTORY_PROOF_SPEC.json"
git add ".\validators\validate_operational_factory_proof_v2.ps1"
git add ".\proofs\OPERATIONAL_FACTORY_PROOF_V2.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 17 operational factory proof v2"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
