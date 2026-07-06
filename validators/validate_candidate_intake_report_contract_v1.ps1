param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_specialization_gap_report.ps1"

$SyntheticGapRoot = ".\runs\$RunId\PHASE34_CANDIDATE_INTAKE_REPORT_CONTRACT_V1\synthetic_gap_source"

$DerivedSpec = [pscustomobject]@{
    agent_id = "workflow_execution_probe_agent"
    agent_kind = "workflow_execution_agent"
    package_profile = "operational_specialized"
}

$Specialization = [pscustomobject]@{
    status = "NO_MATCH"
    profile_id = "NONE"
    profile_kind = "workflow_execution_agent"
    overlay_root = ""
    resolution_reason = "Deterministic unsupported specialization family for candidate intake report runtime proof."
}

$Gap = New-SpecializationGapReport `
    -RunId $RunId `
    -ModeRoot $SyntheticGapRoot `
    -RawIdeaPath ".\synthetic\RAW_IDEA_WORKFLOW_EXECUTION_PROBE.json" `
    -DerivedSpecPath ".\synthetic\DERIVED_WORKFLOW_EXECUTION_AGENT_SPEC.json" `
    -DerivedSpec $DerivedSpec `
    -Specialization $Specialization

if ($Gap.status -ne "PASS") {
    throw "Synthetic gap report generation failed."
}

$CandidateRunId = "$RunId`__CANDIDATE_RUNTIME"

& ".\orchestrator\run.ps1" `
    -Mode GAP_TO_PROFILE_CANDIDATE `
    -RunId $CandidateRunId `
    -GapReportPath $Gap.report_path |
    Out-Host

$ModeRoot = ".\runs\$CandidateRunId\GAP_TO_PROFILE_CANDIDATE_MODE_V1"
$CandidatePath = Join-Path $ModeRoot "SPECIALIZATION_PROFILE_CANDIDATE.json"
$IntakeReportPath = Join-Path $ModeRoot "GAP_REMEDIATION_INTAKE_REPORT.json"

if (-not (Test-Path $CandidatePath)) {
    throw "Runtime candidate artifact missing."
}

if (-not (Test-Path $IntakeReportPath)) {
    throw "Runtime intake report artifact missing."
}

$Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json
$Intake = Get-Content $IntakeReportPath -Raw | ConvertFrom-Json

if ($Candidate.candidate_profile_id -ne "workflow_execution_agent_v1") {
    throw "Candidate profile id mismatch."
}

if ($Candidate.candidate_agent_kind -ne "workflow_execution_agent") {
    throw "Candidate agent kind mismatch."
}

if ($Intake.status -ne "PASS") {
    throw "Intake report status mismatch."
}

if ($Intake.candidate_profile_id -ne "workflow_execution_agent_v1") {
    throw "Intake report candidate profile id mismatch."
}

if ($Intake.candidate_agent_kind -ne "workflow_execution_agent") {
    throw "Intake report candidate agent kind mismatch."
}

if ($Intake.required_build_move -ne "CREATE_SPECIALIZATION_PROFILE_AND_REGISTRY_MAPPING") {
    throw "Intake report required build move mismatch."
}

Write-Host "INTAKE_REPORT_STATUS=$($Intake.status)"
Write-Host "INTAKE_REPORT_PROFILE_ID=$($Intake.candidate_profile_id)"
Write-Host "INTAKE_REPORT_AGENT_KIND=$($Intake.candidate_agent_kind)"
Write-Host "INTAKE_REPORT_PATH=$IntakeReportPath"

$Proof = [ordered]@{
    proof_id = "CANDIDATE_INTAKE_REPORT_CONTRACT_V1"
    run_id = $RunId
    status = "PASS"
    synthetic_gap_report = $Gap.report_path
    candidate_path = $CandidatePath
    intake_report_path = $IntakeReportPath
    candidate_profile_id = $Intake.candidate_profile_id
    candidate_agent_kind = $Intake.candidate_agent_kind
    required_build_move = $Intake.required_build_move
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\CANDIDATE_INTAKE_REPORT_CONTRACT_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "candidate_intake_report_contract_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "runtime_gap_to_candidate_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_CANDIDATE_INTAKE_REPORT_CONTRACT_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_34") { throw "Expected PHASE_34." }
if ($State.current_capability -ne "candidate_intake_report_contract_v1") { throw "Expected candidate_intake_report_contract_v1." }
if ($Queue.active_task_id -ne "TASK_CANDIDATE_INTAKE_REPORT_CONTRACT_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 34 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 34 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_35"
    $State.current_capability = "runtime_gap_to_candidate_factory_proof_v1"
    $State.completed_capabilities += "candidate_intake_report_contract_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1_001"
        capability_id = "runtime_gap_to_candidate_factory_proof_v1"
        status = "ACTIVE"
        objective = "Prove Builder runtime emits both candidate brief and intake report from a specialization gap report."
        expected_gate = "RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1"
        build_task_path = "tasks/TASK_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: candidate_intake_report_contract_v1 checks passed. run_id=$RunId"
