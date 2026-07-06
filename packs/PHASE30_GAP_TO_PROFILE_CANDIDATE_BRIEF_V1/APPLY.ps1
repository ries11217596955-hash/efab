param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE30_GAP_TO_PROFILE_CANDIDATE_BRIEF_V1"

Copy-Item ".\packs\PHASE30_GAP_TO_PROFILE_CANDIDATE_BRIEF_V1\payload\modules\new_specialization_profile_candidate_brief.ps1" ".\modules\new_specialization_profile_candidate_brief.ps1" -Force
Copy-Item ".\packs\PHASE30_GAP_TO_PROFILE_CANDIDATE_BRIEF_V1\payload\validators\validate_gap_to_profile_candidate_brief_v1.ps1" ".\validators\validate_gap_to_profile_candidate_brief_v1.ps1" -Force
Copy-Item ".\packs\PHASE30_GAP_TO_PROFILE_CANDIDATE_BRIEF_V1\payload\tasks\TASK_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_001.json" ".\tasks\TASK_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_001.json" -Force

& ".\validators\validate_gap_to_profile_candidate_brief_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\modules\new_specialization_profile_candidate_brief.ps1"
git add ".\validators\validate_gap_to_profile_candidate_brief_v1.ps1"
git add ".\tasks\TASK_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_001.json"
git add ".\specialization_candidates\DECISION_SUPPORT_AGENT_PROFILE_CANDIDATE_V1.json"
git add ".\proofs\GAP_TO_PROFILE_CANDIDATE_BRIEF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 30 gap-to-profile candidate brief v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
