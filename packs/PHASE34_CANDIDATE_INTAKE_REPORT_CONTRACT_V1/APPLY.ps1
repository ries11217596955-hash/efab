param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE34_CANDIDATE_INTAKE_REPORT_CONTRACT_V1"

Copy-Item ".\packs\PHASE34_CANDIDATE_INTAKE_REPORT_CONTRACT_V1\payload\contracts\GAP_REMEDIATION_INTAKE_REPORT_CONTRACT_V1.json" ".\contracts\GAP_REMEDIATION_INTAKE_REPORT_CONTRACT_V1.json" -Force
Copy-Item ".\packs\PHASE34_CANDIDATE_INTAKE_REPORT_CONTRACT_V1\payload\modules\new_gap_remediation_intake_report.ps1" ".\modules\new_gap_remediation_intake_report.ps1" -Force
Copy-Item ".\packs\PHASE34_CANDIDATE_INTAKE_REPORT_CONTRACT_V1\payload\orchestrator\run.ps1" ".\orchestrator\run.ps1" -Force
Copy-Item ".\packs\PHASE34_CANDIDATE_INTAKE_REPORT_CONTRACT_V1\payload\validators\validate_candidate_intake_report_contract_v1.ps1" ".\validators\validate_candidate_intake_report_contract_v1.ps1" -Force
Copy-Item ".\packs\PHASE34_CANDIDATE_INTAKE_REPORT_CONTRACT_V1\payload\tasks\TASK_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1_001.json" ".\tasks\TASK_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1_001.json" -Force

& ".\validators\validate_candidate_intake_report_contract_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\GAP_REMEDIATION_INTAKE_REPORT_CONTRACT_V1.json"
git add ".\modules\new_gap_remediation_intake_report.ps1"
git add ".\orchestrator\run.ps1"
git add ".\validators\validate_candidate_intake_report_contract_v1.ps1"
git add ".\tasks\TASK_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1_001.json"
git add ".\proofs\CANDIDATE_INTAKE_REPORT_CONTRACT_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 34 candidate intake report contract v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
