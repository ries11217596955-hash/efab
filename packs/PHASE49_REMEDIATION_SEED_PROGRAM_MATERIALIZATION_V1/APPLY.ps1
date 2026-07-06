param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE49_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1"

Copy-Item ".\packs\PHASE49_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1\payload\modules\new_remediation_seed_self_build_program_package.ps1" ".\modules\new_remediation_seed_self_build_program_package.ps1" -Force
Copy-Item ".\packs\PHASE49_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1\payload\validators\validate_remediation_seed_program_materialization_v1.ps1" ".\validators\validate_remediation_seed_program_materialization_v1.ps1" -Force
Copy-Item ".\packs\PHASE49_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1\payload\tasks\TASK_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1_001.json" ".\tasks\TASK_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1_001.json" -Force

& ".\validators\validate_remediation_seed_program_materialization_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\modules\new_remediation_seed_self_build_program_package.ps1"
git add ".\validators\validate_remediation_seed_program_materialization_v1.ps1"
git add ".\tasks\TASK_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1_001.json"
git add ".\self_build_programs\generated\monitoring_agent_v1"
git add ".\proofs\REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 49 remediation seed program materialization v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
