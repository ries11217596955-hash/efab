param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE24_SPECIALIZATION_PROFILE_REGISTRY_V1"

New-Item -ItemType Directory -Force -Path ".\applied_agents\specialization_profiles" | Out-Null

Copy-Item ".\packs\PHASE24_SPECIALIZATION_PROFILE_REGISTRY_V1\payload\applied_agents\specialization_profiles\SPECIALIZATION_PROFILE_REGISTRY.json" ".\applied_agents\specialization_profiles\SPECIALIZATION_PROFILE_REGISTRY.json" -Force
Copy-Item ".\packs\PHASE24_SPECIALIZATION_PROFILE_REGISTRY_V1\payload\modules\resolve_specialization_overlay.ps1" ".\modules\resolve_specialization_overlay.ps1" -Force
Copy-Item ".\packs\PHASE24_SPECIALIZATION_PROFILE_REGISTRY_V1\payload\validators\validate_specialization_profile_registry_v1.ps1" ".\validators\validate_specialization_profile_registry_v1.ps1" -Force
Copy-Item ".\packs\PHASE24_SPECIALIZATION_PROFILE_REGISTRY_V1\payload\tasks\TASK_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_001.json" ".\tasks\TASK_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_001.json" -Force

& ".\validators\validate_specialization_profile_registry_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\applied_agents\specialization_profiles\SPECIALIZATION_PROFILE_REGISTRY.json"
git add ".\modules\resolve_specialization_overlay.ps1"
git add ".\validators\validate_specialization_profile_registry_v1.ps1"
git add ".\tasks\TASK_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_001.json"
git add ".\proofs\SPECIALIZATION_PROFILE_REGISTRY_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 24 specialization profile registry v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
