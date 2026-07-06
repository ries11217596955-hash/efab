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

$CandidatePath = ".\specialization_candidates\DECISION_SUPPORT_AGENT_PROFILE_CANDIDATE_V1.json"
if (-not (Test-Path $CandidatePath)) {
    throw "Decision support profile candidate brief missing."
}

$Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json

if ($Candidate.candidate_profile_id -ne "decision_support_agent_v1") {
    throw "Unexpected candidate profile id."
}

if ($Candidate.candidate_agent_kind -ne "decision_support_agent") {
    throw "Unexpected candidate agent kind."
}

$Resolution = Resolve-SpecializationOverlay `
    -AgentKind "decision_support_agent" `
    -PackageProfile "operational_specialized"

Write-Host "DECISION_PROFILE_RESOLUTION_STATUS=$($Resolution.status)"
Write-Host "DECISION_PROFILE_ID=$($Resolution.profile_id)"
Write-Host "DECISION_PROFILE_OVERLAY_ROOT=$($Resolution.overlay_root)"

if ($Resolution.status -ne "PASS") {
    throw "Resolver must return PASS for decision_support_agent."
}

if ($Resolution.profile_id -ne "decision_support_agent_v1") {
    throw "Unexpected decision support specialization profile id."
}

$SpecPath = ".\specs\decision_support_profile_proof\DECISION_SUPPORT_AGENT_PROFILE_PROOF_SPEC.json"
$RunRoot = ".\runs\$RunId\PHASE31_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1\profile_build"

$Build = Invoke-ExternalAgentBuild `
    -SpecPath $SpecPath `
    -OutputRoot ".\generated_agents" `
    -RunRoot $RunRoot `
    -OverlayRoot $Resolution.overlay_root

if ($Build.status -ne "PASS") {
    throw "Decision support profile build must be PASS."
}

if ($Build.overlay.status -ne "PASS") {
    throw "Decision support overlay apply must be PASS."
}

$ValidationOutput = $Build.validation.output_result_path
if (-not (Test-Path $ValidationOutput)) {
    throw "Decision support profile validation output missing."
}

$Result = Get-Content $ValidationOutput -Raw | ConvertFrom-Json

if ($Result.result.operation -ne "decision_route_prioritization") {
    throw "Decision support profile specialized operation mismatch."
}

if ($Result.diagnostics.specialization_profile -ne "decision_support_agent_v1") {
    throw "Decision support profile diagnostics mismatch."
}

if ($Result.result.top_route_id -ne "execute_high_confidence_patch") {
    throw "Decision support top route mismatch."
}

$Proof = [ordered]@{
    proof_id = "DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1"
    run_id = $RunId
    status = "PASS"
    candidate_path = $CandidatePath
    profile_id = $Resolution.profile_id
    build_report_path = $Build.report_path
    validation_output = $ValidationOutput
    specialized_operation = $Result.result.operation
    top_route_id = $Result.result.top_route_id
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "decision_support_agent_specialization_profile_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "gap_closure_specialized_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_31") { throw "Expected PHASE_31." }
if ($State.current_capability -ne "decision_support_agent_specialization_profile_v1") { throw "Expected decision_support_agent_specialization_profile_v1." }
if ($Queue.active_task_id -ne "TASK_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 31 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 31 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_32"
    $State.current_capability = "gap_closure_specialized_factory_proof_v1"
    $State.completed_capabilities += "decision_support_agent_specialization_profile_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_GAP_CLOSURE_SPECIALIZED_FACTORY_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_GAP_CLOSURE_SPECIALIZED_FACTORY_PROOF_V1_001"
        capability_id = "gap_closure_specialized_factory_proof_v1"
        status = "ACTIVE"
        objective = "Prove the previously unsupported decision_support_agent raw idea now builds as a specialized agent."
        expected_gate = "GAP_CLOSURE_SPECIALIZED_FACTORY_PROOF_V1"
        build_task_path = "tasks/TASK_GAP_CLOSURE_SPECIALIZED_FACTORY_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: decision_support_agent_specialization_profile_v1 checks passed. run_id=$RunId"
