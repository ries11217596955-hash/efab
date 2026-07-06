param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE27_SPECIALIZATION_GAP_CONTRACT_V1"

Copy-Item ".\packs\PHASE27_SPECIALIZATION_GAP_CONTRACT_V1\payload\contracts\SPECIALIZATION_GAP_REPORT_CONTRACT_V1.json" ".\contracts\SPECIALIZATION_GAP_REPORT_CONTRACT_V1.json" -Force
Copy-Item ".\packs\PHASE27_SPECIALIZATION_GAP_CONTRACT_V1\payload\modules\new_specialization_gap_report.ps1" ".\modules\new_specialization_gap_report.ps1" -Force
Copy-Item ".\packs\PHASE27_SPECIALIZATION_GAP_CONTRACT_V1\payload\validators\validate_specialization_gap_contract_v1.ps1" ".\validators\validate_specialization_gap_contract_v1.ps1" -Force
Copy-Item ".\packs\PHASE27_SPECIALIZATION_GAP_CONTRACT_V1\payload\tasks\TASK_NO_MATCH_DIAGNOSTIC_MODE_V1_001.json" ".\tasks\TASK_NO_MATCH_DIAGNOSTIC_MODE_V1_001.json" -Force

& ".\validators\validate_specialization_gap_contract_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\SPECIALIZATION_GAP_REPORT_CONTRACT_V1.json"
git add ".\modules\new_specialization_gap_report.ps1"
git add ".\validators\validate_specialization_gap_contract_v1.ps1"
git add ".\tasks\TASK_NO_MATCH_DIAGNOSTIC_MODE_V1_001.json"
git add ".\proofs\SPECIALIZATION_GAP_CONTRACT_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 27 specialization gap contract v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
