param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\resolve_specialization_overlay.ps1"
. ".\modules\invoke_external_agent_build.ps1"

$Resolution = Resolve-SpecializationOverlay `
    -AgentKind "specification_agent" `
    -PackageProfile "operational_specialized"

Write-Host "SPEC_PROFILE_RESOLUTION_STATUS=$($Resolution.status)"
Write-Host "SPEC_PROFILE_ID=$($Resolution.profile_id)"
Write-Host "SPEC_PROFILE_OVERLAY_ROOT=$($Resolution.overlay_root)"

if ($Resolution.status -ne "PASS") {
    throw "Resolver must return PASS for specification_agent."
}

if ($Resolution.profile_id -ne "specification_agent_v1") {
    throw "Unexpected specification profile id."
}

$SpecPath = ".\specs\specialization_profile_proof\SPECIFICATION_AGENT_PROFILE_PROOF_SPEC.json"
$RunRoot = ".\runs\$RunId\PHASE25_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1\profile_build"

$Build = Invoke-ExternalAgentBuild `
    -SpecPath $SpecPath `
    -OutputRoot ".\generated_agents" `
    -RunRoot $RunRoot `
    -OverlayRoot $Resolution.overlay_root

if ($Build.status -ne "PASS") {
    throw "Specification agent profile build must be PASS."
}

if ($Build.overlay.status -ne "PASS") {
    throw "Specification agent overlay apply must be PASS."
}

$ValidationOutput = $Build.validation.output_result_path
if (-not (Test-Path $ValidationOutput)) {
    throw "Specification profile validation output missing."
}

$Result = Get-Content $ValidationOutput -Raw | ConvertFrom-Json

if ($Result.result.operation -ne "spec_blueprint_synthesis") {
    throw "Specification profile specialized operation mismatch."
}

if ($Result.diagnostics.specialization_profile -ne "specification_agent_v1") {
    throw "Specification profile diagnostics mismatch."
}

if ($Result.result.section_count -ne 4) {
    throw "Specification profile section count mismatch."
}

$Proof = [ordered]@{
    proof_id = "SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1"
    run_id = $RunId
    status = "PASS"
    profile_id = $Resolution.profile_id
    build_report_path = $Build.report_path
    validation_output = $ValidationOutput
    specialized_operation = $Result.result.operation
    specialized_section_count = $Result.result.section_count
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specification_agent_specialization_profile_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "multi_profile_specialized_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_25") { throw "Expected PHASE_25." }
if ($State.current_capability -ne "specification_agent_specialization_profile_v1") { throw "Expected specification_agent_specialization_profile_v1." }
if ($Queue.active_task_id -ne "TASK_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 25 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 25 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_26"
    $State.current_capability = "multi_profile_specialized_factory_proof_v1"
    $State.completed_capabilities += "specification_agent_specialization_profile_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1_001"
        capability_id = "multi_profile_specialized_factory_proof_v1"
        status = "ACTIVE"
        objective = "Prove two raw idea families route into distinct registry-backed specialization profiles."
        expected_gate = "MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1"
        build_task_path = "tasks/TASK_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: specification_agent_specialization_profile_v1 checks passed. run_id=$RunId"
