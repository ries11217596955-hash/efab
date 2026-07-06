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

$CandidatePath = ".\remediation_intake\WORKFLOW_EXECUTION_AGENT_PROFILE_CANDIDATE_V1.json"
$IntakePath = ".\remediation_intake\WORKFLOW_EXECUTION_AGENT_INTAKE_REPORT_V1.json"

if (-not (Test-Path $CandidatePath)) {
    throw "Canonical workflow candidate artifact missing."
}

if (-not (Test-Path $IntakePath)) {
    throw "Canonical workflow intake report artifact missing."
}

$Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json
$Intake = Get-Content $IntakePath -Raw | ConvertFrom-Json

if ($Candidate.candidate_profile_id -ne "workflow_execution_agent_v1") {
    throw "Workflow candidate profile id mismatch."
}

if ($Candidate.candidate_agent_kind -ne "workflow_execution_agent") {
    throw "Workflow candidate agent kind mismatch."
}

if ($Intake.required_build_move -ne "CREATE_SPECIALIZATION_PROFILE_AND_REGISTRY_MAPPING") {
    throw "Workflow intake required build move mismatch."
}

$Resolution = Resolve-SpecializationOverlay `
    -AgentKind "workflow_execution_agent" `
    -PackageProfile "operational_specialized"

Write-Host "WORKFLOW_PROFILE_RESOLUTION_STATUS=$($Resolution.status)"
Write-Host "WORKFLOW_PROFILE_ID=$($Resolution.profile_id)"
Write-Host "WORKFLOW_PROFILE_OVERLAY_ROOT=$($Resolution.overlay_root)"

if ($Resolution.status -ne "PASS") {
    throw "Resolver must return PASS for workflow_execution_agent."
}

if ($Resolution.profile_id -ne "workflow_execution_agent_v1") {
    throw "Unexpected workflow specialization profile id."
}

$SpecPath = ".\specs\workflow_execution_profile_proof\WORKFLOW_EXECUTION_AGENT_PROFILE_PROOF_SPEC.json"
$RunRoot = ".\runs\$RunId\PHASE37_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1\profile_build"

$Build = Invoke-ExternalAgentBuild `
    -SpecPath $SpecPath `
    -OutputRoot ".\generated_agents" `
    -RunRoot $RunRoot `
    -OverlayRoot $Resolution.overlay_root

if ($Build.status -ne "PASS") {
    throw "Workflow execution profile build must be PASS."
}

if ($Build.overlay.status -ne "PASS") {
    throw "Workflow overlay apply must be PASS."
}

$ValidationOutput = $Build.validation.output_result_path
if (-not (Test-Path $ValidationOutput)) {
    throw "Workflow profile validation output missing."
}

$Result = Get-Content $ValidationOutput -Raw | ConvertFrom-Json

if ($Result.result.operation -ne "workflow_step_dispatch_plan") {
    throw "Workflow specialized operation mismatch."
}

if ($Result.diagnostics.specialization_profile -ne "workflow_execution_agent_v1") {
    throw "Workflow specialization diagnostics mismatch."
}

if ($Result.result.next_step_id -ne "collect_input") {
    throw "Workflow next step mismatch."
}

$Proof = [ordered]@{
    proof_id = "INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1"
    run_id = $RunId
    status = "PASS"
    canonical_candidate_path = $CandidatePath
    canonical_intake_report_path = $IntakePath
    profile_id = $Resolution.profile_id
    build_report_path = $Build.report_path
    validation_output = $ValidationOutput
    specialized_operation = $Result.result.operation
    next_step_id = $Result.result.next_step_id
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "intake_driven_workflow_execution_profile_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "runtime_gap_remediation_closure_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_37") { throw "Expected PHASE_37." }
if ($State.current_capability -ne "intake_driven_workflow_execution_profile_v1") { throw "Expected intake_driven_workflow_execution_profile_v1." }
if ($Queue.active_task_id -ne "TASK_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 37 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 37 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_38"
    $State.current_capability = "runtime_gap_remediation_closure_proof_v1"
    $State.completed_capabilities += "intake_driven_workflow_execution_profile_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_RUNTIME_GAP_REMEDIATION_CLOSURE_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_RUNTIME_GAP_REMEDIATION_CLOSURE_PROOF_V1_001"
        capability_id = "runtime_gap_remediation_closure_proof_v1"
        status = "ACTIVE"
        objective = "Prove the exact workflow raw idea now closes from prior gap into a specialized PASS route."
        expected_gate = "RUNTIME_GAP_REMEDIATION_CLOSURE_PROOF_V1"
        build_task_path = "tasks/TASK_RUNTIME_GAP_REMEDIATION_CLOSURE_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: intake_driven_workflow_execution_profile_v1 checks passed. run_id=$RunId"
