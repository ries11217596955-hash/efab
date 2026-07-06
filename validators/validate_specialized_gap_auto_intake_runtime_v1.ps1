param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

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

$RawIdeaPath = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "Specialized auto-intake report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "SPECIALIZATION_GAP") {
    throw "Specialized auto-intake run must return SPECIALIZATION_GAP."
}

if ($Report.gap_report.missing_agent_kind -ne "monitoring_agent") {
    throw "Specialized auto-intake gap kind mismatch."
}

if ($Report.remediation_intake.status -ne "PASS") {
    throw "Specialized remediation intake status mismatch."
}

if ($Report.remediation_intake.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Specialized remediation candidate profile id mismatch."
}

if ($Report.remediation_intake.candidate_agent_kind -ne "monitoring_agent") {
    throw "Specialized remediation candidate kind mismatch."
}

if (-not (Test-Path $Report.remediation_intake.candidate_path)) {
    throw "Specialized remediation candidate artifact missing."
}

if (-not (Test-Path $Report.remediation_intake.intake_report_path)) {
    throw "Specialized remediation intake report artifact missing."
}

$Candidate = Get-Content $Report.remediation_intake.candidate_path -Raw | ConvertFrom-Json
$Intake = Get-Content $Report.remediation_intake.intake_report_path -Raw | ConvertFrom-Json

if ($Candidate.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Candidate file profile id mismatch."
}

if ($Intake.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Intake file profile id mismatch."
}

if ($Intake.required_build_move -ne "CREATE_SPECIALIZATION_PROFILE_AND_REGISTRY_MAPPING") {
    throw "Intake required build move mismatch."
}

Write-Host "AUTO_INTAKE_STATUS=$($Report.remediation_intake.status)"
Write-Host "AUTO_INTAKE_CANDIDATE_PROFILE_ID=$($Report.remediation_intake.candidate_profile_id)"
Write-Host "AUTO_INTAKE_CANDIDATE_PATH=$($Report.remediation_intake.candidate_path)"
Write-Host "AUTO_INTAKE_REPORT_PATH=$($Report.remediation_intake.intake_report_path)"

$Proof = [ordered]@{
    proof_id = "SPECIALIZED_GAP_AUTO_INTAKE_RUNTIME_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    specialized_report_path = $ReportPath
    gap_report_path = $Report.gap_report.report_path
    candidate_path = $Report.remediation_intake.candidate_path
    intake_report_path = $Report.remediation_intake.intake_report_path
    candidate_profile_id = $Report.remediation_intake.candidate_profile_id
    candidate_agent_kind = $Report.remediation_intake.candidate_agent_kind
    required_build_move = $Report.remediation_intake.required_build_move
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\SPECIALIZED_GAP_AUTO_INTAKE_RUNTIME_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specialized_gap_auto_intake_runtime_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "one_run_gap_remediation_packet_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_SPECIALIZED_GAP_AUTO_INTAKE_RUNTIME_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_40") { throw "Expected PHASE_40." }
if ($State.current_capability -ne "specialized_gap_auto_intake_runtime_v1") { throw "Expected specialized_gap_auto_intake_runtime_v1." }
if ($Queue.active_task_id -ne "TASK_SPECIALIZED_GAP_AUTO_INTAKE_RUNTIME_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 40 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 40 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_41"
    $State.current_capability = "one_run_gap_remediation_packet_proof_v1"
    $State.completed_capabilities += "specialized_gap_auto_intake_runtime_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1_001"
        capability_id = "one_run_gap_remediation_packet_proof_v1"
        status = "ACTIVE"
        objective = "Prove a real monitoring raw idea returns gap report, candidate, and intake in one specialized run."
        expected_gate = "ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1"
        build_task_path = "tasks/TASK_ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: specialized_gap_auto_intake_runtime_v1 checks passed. run_id=$RunId"
