param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE18_ARCHITECT_TO_SPEC_HANDOFF_V1"

New-Item -ItemType Directory -Force -Path ".\specs\idea_to_agent_proof" | Out-Null

Copy-Item ".\packs\PHASE18_ARCHITECT_TO_SPEC_HANDOFF_V1\payload\modules\invoke_agent_spec_architect_handoff.ps1" ".\modules\invoke_agent_spec_architect_handoff.ps1" -Force
Copy-Item ".\packs\PHASE18_ARCHITECT_TO_SPEC_HANDOFF_V1\payload\specs\architect_handoff_proof\RAW_IDEA_HANDOFF_PROOF.json" ".\specs\idea_to_agent_proof\RAW_IDEA_HANDOFF_PROOF.json" -Force
Copy-Item ".\packs\PHASE18_ARCHITECT_TO_SPEC_HANDOFF_V1\payload\validators\validate_architect_to_spec_handoff_v1.ps1" ".\validators\validate_architect_to_spec_handoff_v1.ps1" -Force
Copy-Item ".\packs\PHASE18_ARCHITECT_TO_SPEC_HANDOFF_V1\payload\tasks\TASK_BUILD_FROM_RAW_IDEA_MODE_V1_001.json" ".\tasks\TASK_BUILD_FROM_RAW_IDEA_MODE_V1_001.json" -Force

& ".\validators\validate_architect_to_spec_handoff_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\modules\invoke_agent_spec_architect_handoff.ps1"
git add ".\specs\idea_to_agent_proof\RAW_IDEA_HANDOFF_PROOF.json"
git add ".\validators\validate_architect_to_spec_handoff_v1.ps1"
git add ".\tasks\TASK_BUILD_FROM_RAW_IDEA_MODE_V1_001.json"
git add ".\proofs\ARCHITECT_TO_SPEC_HANDOFF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 18 architect-to-spec handoff v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
