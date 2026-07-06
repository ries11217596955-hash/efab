param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE41_ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1"

Copy-Item ".\packs\PHASE41_ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1\payload\validators\validate_one_run_gap_remediation_packet_proof_v1.ps1" ".\validators\validate_one_run_gap_remediation_packet_proof_v1.ps1" -Force

& ".\validators\validate_one_run_gap_remediation_packet_proof_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\validators\validate_one_run_gap_remediation_packet_proof_v1.ps1"
git add ".\proofs\ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 41 one-run gap remediation packet proof v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
