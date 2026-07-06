param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE42_REMEDIATION_PROGRAM_SEED_CONTRACT_V1"

Copy-Item ".\packs\PHASE42_REMEDIATION_PROGRAM_SEED_CONTRACT_V1\payload\contracts\GAP_REMEDIATION_PROGRAM_SEED_CONTRACT_V1.json" ".\contracts\GAP_REMEDIATION_PROGRAM_SEED_CONTRACT_V1.json" -Force
Copy-Item ".\packs\PHASE42_REMEDIATION_PROGRAM_SEED_CONTRACT_V1\payload\modules\new_gap_remediation_program_seed.ps1" ".\modules\new_gap_remediation_program_seed.ps1" -Force
Copy-Item ".\packs\PHASE42_REMEDIATION_PROGRAM_SEED_CONTRACT_V1\payload\validators\validate_remediation_program_seed_contract_v1.ps1" ".\validators\validate_remediation_program_seed_contract_v1.ps1" -Force
Copy-Item ".\packs\PHASE42_REMEDIATION_PROGRAM_SEED_CONTRACT_V1\payload\tasks\TASK_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_001.json" ".\tasks\TASK_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_001.json" -Force

& ".\validators\validate_remediation_program_seed_contract_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\GAP_REMEDIATION_PROGRAM_SEED_CONTRACT_V1.json"
git add ".\modules\new_gap_remediation_program_seed.ps1"
git add ".\validators\validate_remediation_program_seed_contract_v1.ps1"
git add ".\tasks\TASK_SPECIALIZED_GAP_AUTO_PROGRAM_SEED_RUNTIME_V1_001.json"
git add ".\proofs\REMEDIATION_PROGRAM_SEED_CONTRACT_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 42 remediation program seed contract v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
