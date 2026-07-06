param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\invoke_agent_spec_architect_handoff.ps1"

$ArchitectSpecPath = ".\specs\applied_agents\agent_spec_architect\AGENT_SPEC_ARCHITECT_SPEC.json"
$ArchitectOverlayRoot = ".\applied_agents\agent_spec_architect\overlay"
$RawIdeaRequestPath = ".\specs\idea_to_agent_proof\RAW_IDEA_HANDOFF_PROOF.json"
$GeneratedAgentsRoot = ".\generated_agents"
$RunRoot = ".\runs\$RunId\PHASE18_ARCHITECT_TO_SPEC_HANDOFF_V1"
$DerivedSpecOutputPath = ".\runs\$RunId\PHASE18_ARCHITECT_TO_SPEC_HANDOFF_V1\DERIVED_AGENT_SPEC.json"

$Result = Invoke-AgentSpecArchitectHandoff `
    -ArchitectSpecPath $ArchitectSpecPath `
    -ArchitectOverlayRoot $ArchitectOverlayRoot `
    -RawIdeaRequestPath $RawIdeaRequestPath `
    -GeneratedAgentsRoot $GeneratedAgentsRoot `
    -RunRoot $RunRoot `
    -DerivedSpecOutputPath $DerivedSpecOutputPath

Write-Host "HANDOFF_STATUS=$($Result.status)"
Write-Host "HANDOFF_DERIVED_AGENT_ID=$($Result.derived_agent_id)"
Write-Host "HANDOFF_DERIVED_SPEC_PATH=$($Result.derived_spec_path)"
Write-Host "HANDOFF_BUILD_READINESS=$($Result.build_readiness)"

if ($Result.status -ne "PASS") {
    throw "Architect-to-spec handoff must be PASS."
}

if ($Result.derived_agent_id -ne "website_funnel_audit_agent") {
    throw "Unexpected derived agent id."
}

if (-not (Test-Path $DerivedSpecOutputPath)) {
    throw "Derived spec output missing."
}

$Proof = [ordered]@{
    proof_id = "ARCHITECT_TO_SPEC_HANDOFF_V1"
    run_id = $RunId
    status = "PASS"
    derived_agent_id = $Result.derived_agent_id
    derived_spec_path = $Result.derived_spec_path
    architect_result_path = $Result.architect_result_path
    build_readiness = $Result.build_readiness
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\ARCHITECT_TO_SPEC_HANDOFF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "architect_to_spec_handoff_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "build_from_raw_idea_mode_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_ARCHITECT_TO_SPEC_HANDOFF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_18") { throw "Expected PHASE_18." }
if ($State.current_capability -ne "architect_to_spec_handoff_v1") { throw "Expected architect_to_spec_handoff_v1." }
if ($Queue.active_task_id -ne "TASK_ARCHITECT_TO_SPEC_HANDOFF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 18 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 18 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_19"
    $State.current_capability = "build_from_raw_idea_mode_v1"
    $State.completed_capabilities += "architect_to_spec_handoff_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_BUILD_FROM_RAW_IDEA_MODE_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_BUILD_FROM_RAW_IDEA_MODE_V1_001"
        capability_id = "build_from_raw_idea_mode_v1"
        status = "ACTIVE"
        objective = "Expose direct BUILD_FROM_RAW_IDEA mode that chains Agent Spec Architect handoff into external agent build."
        expected_gate = "BUILD_FROM_RAW_IDEA_MODE_V1_READY"
        build_task_path = "tasks/TASK_BUILD_FROM_RAW_IDEA_MODE_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: architect_to_spec_handoff_v1 checks passed. run_id=$RunId"
