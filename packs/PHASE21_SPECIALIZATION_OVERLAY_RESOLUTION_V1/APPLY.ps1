param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE21_SPECIALIZATION_OVERLAY_RESOLUTION_V1"

New-Item -ItemType Directory -Force -Path ".\applied_agents\specialization_profiles\audit_agent_v1\overlay\modules" | Out-Null
New-Item -ItemType Directory -Force -Path ".\applied_agents\specialization_profiles\audit_agent_v1\overlay\examples" | Out-Null

Copy-Item ".\packs\PHASE21_SPECIALIZATION_OVERLAY_RESOLUTION_V1\payload\modules\resolve_specialization_overlay.ps1" ".\modules\resolve_specialization_overlay.ps1" -Force
Copy-Item ".\packs\PHASE21_SPECIALIZATION_OVERLAY_RESOLUTION_V1\payload\applied_agents\specialization_profiles\audit_agent_v1\overlay\modules\invoke_agent_operation.ps1" ".\applied_agents\specialization_profiles\audit_agent_v1\overlay\modules\invoke_agent_operation.ps1" -Force
Copy-Item ".\packs\PHASE21_SPECIALIZATION_OVERLAY_RESOLUTION_V1\payload\applied_agents\specialization_profiles\audit_agent_v1\overlay\examples\SAMPLE_REQUEST.json" ".\applied_agents\specialization_profiles\audit_agent_v1\overlay\examples\SAMPLE_REQUEST.json" -Force
Copy-Item ".\packs\PHASE21_SPECIALIZATION_OVERLAY_RESOLUTION_V1\payload\validators\validate_specialization_overlay_resolution_v1.ps1" ".\validators\validate_specialization_overlay_resolution_v1.ps1" -Force
Copy-Item ".\packs\PHASE21_SPECIALIZATION_OVERLAY_RESOLUTION_V1\payload\tasks\TASK_BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_001.json" ".\tasks\TASK_BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_001.json" -Force

& ".\validators\validate_specialization_overlay_resolution_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\modules\resolve_specialization_overlay.ps1"
git add ".\applied_agents\specialization_profiles\audit_agent_v1\overlay\modules\invoke_agent_operation.ps1"
git add ".\applied_agents\specialization_profiles\audit_agent_v1\overlay\examples\SAMPLE_REQUEST.json"
git add ".\validators\validate_specialization_overlay_resolution_v1.ps1"
git add ".\tasks\TASK_BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_001.json"
git add ".\proofs\SPECIALIZATION_OVERLAY_RESOLUTION_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 21 specialization overlay resolution v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
