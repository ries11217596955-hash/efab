param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE48_REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1"

Copy-Item ".\packs\PHASE48_REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1\payload\contracts\remediation_seed_self_build_program_blueprint.schema.json" ".\contracts\remediation_seed_self_build_program_blueprint.schema.json" -Force
Copy-Item ".\packs\PHASE48_REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1\payload\modules\new_remediation_seed_program_blueprint.ps1" ".\modules\new_remediation_seed_program_blueprint.ps1" -Force
Copy-Item ".\packs\PHASE48_REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1\payload\validators\validate_remediation_seed_program_blueprint_contract_v1.ps1" ".\validators\validate_remediation_seed_program_blueprint_contract_v1.ps1" -Force
Copy-Item ".\packs\PHASE48_REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1\payload\tasks\TASK_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_001.json" ".\tasks\TASK_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_001.json" -Force

& ".\validators\validate_remediation_seed_program_blueprint_contract_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\contracts\remediation_seed_self_build_program_blueprint.schema.json"
git add ".\modules\new_remediation_seed_program_blueprint.ps1"
git add ".\validators\validate_remediation_seed_program_blueprint_contract_v1.ps1"
git add ".\tasks\TASK_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_001.json"
git add ".\remediation_programs\generated_programs\monitoring_agent_v1\SELF_BUILD_PROGRAM_BLUEPRINT.json"
git add ".\proofs\REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 48 remediation seed program blueprint contract v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
