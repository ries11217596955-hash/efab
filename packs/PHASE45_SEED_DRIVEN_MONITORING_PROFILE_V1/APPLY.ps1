param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE45_SEED_DRIVEN_MONITORING_PROFILE_V1"

New-Item -ItemType Directory -Force -Path ".\applied_agents\specialization_profiles\monitoring_agent_v1\overlay\modules" | Out-Null
New-Item -ItemType Directory -Force -Path ".\applied_agents\specialization_profiles\monitoring_agent_v1\overlay\examples" | Out-Null
New-Item -ItemType Directory -Force -Path ".\specs\monitoring_profile_proof" | Out-Null

Copy-Item ".\packs\PHASE45_SEED_DRIVEN_MONITORING_PROFILE_V1\payload\applied_agents\specialization_profiles\monitoring_agent_v1\overlay\modules\invoke_agent_operation.ps1" ".\applied_agents\specialization_profiles\monitoring_agent_v1\overlay\modules\invoke_agent_operation.ps1" -Force
Copy-Item ".\packs\PHASE45_SEED_DRIVEN_MONITORING_PROFILE_V1\payload\applied_agents\specialization_profiles\monitoring_agent_v1\overlay\examples\SAMPLE_REQUEST.json" ".\applied_agents\specialization_profiles\monitoring_agent_v1\overlay\examples\SAMPLE_REQUEST.json" -Force
Copy-Item ".\packs\PHASE45_SEED_DRIVEN_MONITORING_PROFILE_V1\payload\applied_agents\specialization_profiles\SPECIALIZATION_PROFILE_REGISTRY.json" ".\applied_agents\specialization_profiles\SPECIALIZATION_PROFILE_REGISTRY.json" -Force
Copy-Item ".\packs\PHASE45_SEED_DRIVEN_MONITORING_PROFILE_V1\payload\specs\monitoring_profile_proof\MONITORING_AGENT_PROFILE_PROOF_SPEC.json" ".\specs\monitoring_profile_proof\MONITORING_AGENT_PROFILE_PROOF_SPEC.json" -Force
Copy-Item ".\packs\PHASE45_SEED_DRIVEN_MONITORING_PROFILE_V1\payload\validators\validate_seed_driven_monitoring_profile_v1.ps1" ".\validators\validate_seed_driven_monitoring_profile_v1.ps1" -Force
Copy-Item ".\packs\PHASE45_SEED_DRIVEN_MONITORING_PROFILE_V1\payload\tasks\TASK_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1_001.json" ".\tasks\TASK_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1_001.json" -Force

& ".\validators\validate_seed_driven_monitoring_profile_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\applied_agents\specialization_profiles\monitoring_agent_v1\overlay\modules\invoke_agent_operation.ps1"
git add ".\applied_agents\specialization_profiles\monitoring_agent_v1\overlay\examples\SAMPLE_REQUEST.json"
git add ".\applied_agents\specialization_profiles\SPECIALIZATION_PROFILE_REGISTRY.json"
git add ".\specs\monitoring_profile_proof\MONITORING_AGENT_PROFILE_PROOF_SPEC.json"
git add ".\validators\validate_seed_driven_monitoring_profile_v1.ps1"
git add ".\tasks\TASK_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1_001.json"
git add ".\proofs\SEED_DRIVEN_MONITORING_PROFILE_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 45 seed-driven monitoring profile v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
