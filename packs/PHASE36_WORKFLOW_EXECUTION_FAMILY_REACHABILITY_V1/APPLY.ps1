param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE36_WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1"

New-Item -ItemType Directory -Force -Path ".\specs\workflow_gap_proof" | Out-Null

Copy-Item ".\packs\PHASE36_WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1\payload\applied_agents\agent_spec_architect\overlay\modules\build_agent_spec_architecture.ps1" ".\applied_agents\agent_spec_architect\overlay\modules\build_agent_spec_architecture.ps1" -Force
Copy-Item ".\packs\PHASE36_WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1\payload\specs\workflow_gap_proof\RAW_IDEA_WORKFLOW_EXECUTION_GAP_PROOF.json" ".\specs\workflow_gap_proof\RAW_IDEA_WORKFLOW_EXECUTION_GAP_PROOF.json" -Force
Copy-Item ".\packs\PHASE36_WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1\payload\validators\validate_workflow_execution_family_reachability_v1.ps1" ".\validators\validate_workflow_execution_family_reachability_v1.ps1" -Force
Copy-Item ".\packs\PHASE36_WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1\payload\tasks\TASK_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_001.json" ".\tasks\TASK_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_001.json" -Force

& ".\validators\validate_workflow_execution_family_reachability_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\applied_agents\agent_spec_architect\overlay\modules\build_agent_spec_architecture.ps1"
git add ".\specs\workflow_gap_proof\RAW_IDEA_WORKFLOW_EXECUTION_GAP_PROOF.json"
git add ".\validators\validate_workflow_execution_family_reachability_v1.ps1"
git add ".\tasks\TASK_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_001.json"
git add ".\remediation_intake\WORKFLOW_EXECUTION_AGENT_PROFILE_CANDIDATE_V1.json"
git add ".\remediation_intake\WORKFLOW_EXECUTION_AGENT_INTAKE_REPORT_V1.json"
git add ".\proofs\WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 36 workflow execution family reachability v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
