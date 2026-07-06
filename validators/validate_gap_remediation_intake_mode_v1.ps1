param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_specialization_gap_report.ps1"

$Tokens = $null
$Errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path ".\orchestrator\run.ps1"),
    [ref]$Tokens,
    [ref]$Errors
) | Out-Null

if ($Errors.Count -ne 0) {
    throw "Orchestrator parser check failed."
}

$SyntheticGapRoot = ".\runs\$RunId\PHASE33_GAP_REMEDIATION_INTAKE_MODE_V1\synthetic_gap_source"

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
    resolution_reason = "Deterministic unsupported specialization family for runtime gap-to-candidate proof."
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

if (-not (Test-Path $Gap.report_path)) {
    throw "Synthetic gap report file missing."
}

$CandidateRunId = "$RunId`__CANDIDATE_RUNTIME"

& ".\orchestrator\run.ps1" `
    -Mode GAP_TO_PROFILE_CANDIDATE `
    -RunId $CandidateRunId `
    -GapReportPath $Gap.report_path |
    Out-Host

$CandidatePath = ".\runs\$CandidateRunId\GAP_TO_PROFILE_CANDIDATE_MODE_V1\SPECIALIZATION_PROFILE_CANDIDATE.json"

if (-not (Test-Path $CandidatePath)) {
    throw "Runtime candidate output missing."
}

$Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json

if ($Candidate.candidate_profile_id -ne "workflow_execution_agent_v1") {
    throw "Runtime candidate profile id mismatch."
}

if ($Candidate.candidate_agent_kind -ne "workflow_execution_agent") {
    throw "Runtime candidate agent kind mismatch."
}

Write-Host "RUNTIME_CANDIDATE_PROFILE_ID=$($Candidate.candidate_profile_id)"
Write-Host "RUNTIME_CANDIDATE_AGENT_KIND=$($Candidate.candidate_agent_kind)"
Write-Host "RUNTIME_CANDIDATE_PATH=$CandidatePath"

$Proof = [ordered]@{
    proof_id = "GAP_REMEDIATION_INTAKE_MODE_V1"
    run_id = $RunId
    status = "PASS"
    synthetic_gap_report = $Gap.report_path
    candidate_path = $CandidatePath
    candidate_profile_id = $Candidate.candidate_profile_id
    candidate_agent_kind = $Candidate.candidate_agent_kind
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\GAP_REMEDIATION_INTAKE_MODE_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "gap_remediation_intake_mode_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "candidate_intake_report_contract_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_GAP_REMEDIATION_INTAKE_MODE_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_33") { throw "Expected PHASE_33." }
if ($State.current_capability -ne "gap_remediation_intake_mode_v1") { throw "Expected gap_remediation_intake_mode_v1." }
if ($Queue.active_task_id -ne "TASK_GAP_REMEDIATION_INTAKE_MODE_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 33 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 33 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_34"
    $State.current_capability = "candidate_intake_report_contract_v1"
    $State.completed_capabilities += "gap_remediation_intake_mode_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_CANDIDATE_INTAKE_REPORT_CONTRACT_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_CANDIDATE_INTAKE_REPORT_CONTRACT_V1_001"
        capability_id = "candidate_intake_report_contract_v1"
        status = "ACTIVE"
        objective = "Create a formal runtime report contract for gap-to-profile candidate intake."
        expected_gate = "CANDIDATE_INTAKE_REPORT_CONTRACT_V1_READY"
        build_task_path = "tasks/TASK_CANDIDATE_INTAKE_REPORT_CONTRACT_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: gap_remediation_intake_mode_v1 checks passed. run_id=$RunId"
