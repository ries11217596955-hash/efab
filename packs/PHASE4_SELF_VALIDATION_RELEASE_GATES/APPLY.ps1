param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) {
    throw "Pack must be invoked by orchestrator."
}

Set-Location $RepoRoot

Write-Host "PACK=PHASE4_SELF_VALIDATION_RELEASE_GATES_V1"

Copy-Item ".\packs\PHASE4_SELF_VALIDATION_RELEASE_GATES\payload\contracts\failure_diagnostic.schema.json" ".\contracts\failure_diagnostic.schema.json" -Force
Copy-Item ".\packs\PHASE4_SELF_VALIDATION_RELEASE_GATES\payload\tasks\TASK_EXTERNAL_AGENT_SPEC_INTAKE_001.json" ".\tasks\TASK_EXTERNAL_AGENT_SPEC_INTAKE_001.json" -Force
Copy-Item ".\packs\PHASE4_SELF_VALIDATION_RELEASE_GATES\payload\modules\validate_truth_alignment.ps1" ".\modules\validate_truth_alignment.ps1" -Force
Copy-Item ".\packs\PHASE4_SELF_VALIDATION_RELEASE_GATES\payload\modules\emit_failure_diagnostic.ps1" ".\modules\emit_failure_diagnostic.ps1" -Force
Copy-Item ".\packs\PHASE4_SELF_VALIDATION_RELEASE_GATES\payload\validators\validate_self_validation_release_gates.ps1" ".\validators\validate_self_validation_release_gates.ps1" -Force

& ".\validators\validate_self_validation_release_gates.ps1" -FinalizePhase -RunId $RunId

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

Write-Host "PACK_FINAL_PHASE=$($State.current_phase)"
Write-Host "PACK_FINAL_CAPABILITY=$($State.current_capability)"
Write-Host "PACK_FINAL_SELF_BUILD_READY=$($State.self_build_ready)"
Write-Host "PACK_FINAL_ACTIVE_TASK=$($Queue.active_task_id)"

if ($State.current_phase -ne "PHASE_5") { throw "Pack final phase verify failed." }
if ($State.current_capability -ne "external_agent_spec_intake") { throw "Pack final capability verify failed." }
if ($State.self_build_ready -ne $true) { throw "Pack self_build_ready verify failed." }
if ($Queue.active_task_id -ne "TASK_EXTERNAL_AGENT_SPEC_INTAKE_001") { throw "Pack active task verify failed." }

git add ".\contracts\failure_diagnostic.schema.json"
git add ".\tasks\TASK_EXTERNAL_AGENT_SPEC_INTAKE_001.json"
git add ".\modules\validate_truth_alignment.ps1"
git add ".\modules\emit_failure_diagnostic.ps1"
git add ".\validators\validate_self_validation_release_gates.ps1"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 4 release gates through pack executor"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
