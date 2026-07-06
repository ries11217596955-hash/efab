param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_specialization_gap_report.ps1"

$SyntheticGapRoot = ".\runs\$RunId\PHASE35_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1\synthetic_gap_source"

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
    resolution_reason = "Deterministic unsupported specialization family for final runtime proof."
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
    throw "Runtime proof candidate artifact missing."
}

if (-not (Test-Path $IntakeReportPath)) {
    throw "Runtime proof intake report missing."
}

$Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json
$Intake = Get-Content $IntakeReportPath -Raw | ConvertFrom-Json

if ($Candidate.candidate_profile_id -ne "workflow_execution_agent_v1") {
    throw "Runtime proof candidate profile id mismatch."
}

if ($Candidate.candidate_agent_kind -ne "workflow_execution_agent") {
    throw "Runtime proof candidate agent kind mismatch."
}

if ($Intake.status -ne "PASS") {
    throw "Runtime proof intake status mismatch."
}

if ($Intake.required_build_move -ne "CREATE_SPECIALIZATION_PROFILE_AND_REGISTRY_MAPPING") {
    throw "Runtime proof required build move mismatch."
}

Write-Host "RUNTIME_FACTORY_CANDIDATE_PROFILE_ID=$($Candidate.candidate_profile_id)"
Write-Host "RUNTIME_FACTORY_CANDIDATE_AGENT_KIND=$($Candidate.candidate_agent_kind)"
Write-Host "RUNTIME_FACTORY_CANDIDATE_PATH=$CandidatePath"
Write-Host "RUNTIME_FACTORY_INTAKE_REPORT_PATH=$IntakeReportPath"

$Proof = [ordered]@{
    proof_id = "RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    synthetic_gap_report = $Gap.report_path
    runtime_candidate_path = $CandidatePath
    runtime_intake_report_path = $IntakeReportPath
    candidate_profile_id = $Candidate.candidate_profile_id
    candidate_agent_kind = $Candidate.candidate_agent_kind
    required_build_move = $Intake.required_build_move
    conclusion = "Builder runtime now converts a specialization gap report into both a normalized profile candidate and an intake report artifact."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "runtime_gap_to_candidate_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_35") { throw "Expected PHASE_35." }
if ($State.current_capability -ne "runtime_gap_to_candidate_factory_proof_v1") { throw "Expected runtime_gap_to_candidate_factory_proof_v1." }
if ($Queue.active_task_id -ne "TASK_RUNTIME_GAP_TO_CANDIDATE_FACTORY_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 35 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 35 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_35"
    $State.current_capability = "runtime_gap_to_candidate_factory_proof_v1"
    $State.completed_capabilities += "runtime_gap_to_candidate_factory_proof_v1"
    $State.last_run_status = "PASS"
    $State.gap_remediation_intake_runtime_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: runtime_gap_to_candidate_factory_proof_v1 checks passed. run_id=$RunId"
