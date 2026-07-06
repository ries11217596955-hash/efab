param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$RawIdeaPath = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "One-run remediation packet report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "SPECIALIZATION_GAP") {
    throw "One-run remediation packet must return SPECIALIZATION_GAP."
}

if ($Report.gap_report.missing_agent_kind -ne "monitoring_agent") {
    throw "One-run remediation packet gap kind mismatch."
}

if ($Report.remediation_intake.status -ne "PASS") {
    throw "One-run remediation packet intake status mismatch."
}

if ($Report.remediation_intake.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "One-run remediation packet candidate profile id mismatch."
}

if (-not (Test-Path $Report.gap_report.report_path)) {
    throw "One-run remediation packet gap report missing."
}

if (-not (Test-Path $Report.remediation_intake.candidate_path)) {
    throw "One-run remediation packet candidate artifact missing."
}

if (-not (Test-Path $Report.remediation_intake.intake_report_path)) {
    throw "One-run remediation packet intake artifact missing."
}

$Candidate = Get-Content $Report.remediation_intake.candidate_path -Raw | ConvertFrom-Json
$Intake = Get-Content $Report.remediation_intake.intake_report_path -Raw | ConvertFrom-Json

if ($Candidate.candidate_agent_kind -ne "monitoring_agent") {
    throw "One-run candidate kind mismatch."
}

if ($Intake.candidate_agent_kind -ne "monitoring_agent") {
    throw "One-run intake kind mismatch."
}

if ($Intake.required_build_move -ne "CREATE_SPECIALIZATION_PROFILE_AND_REGISTRY_MAPPING") {
    throw "One-run intake required build move mismatch."
}

Write-Host "ONE_RUN_GAP_KIND=$($Report.gap_report.missing_agent_kind)"
Write-Host "ONE_RUN_CANDIDATE_PROFILE_ID=$($Report.remediation_intake.candidate_profile_id)"
Write-Host "ONE_RUN_CANDIDATE_PATH=$($Report.remediation_intake.candidate_path)"
Write-Host "ONE_RUN_INTAKE_REPORT_PATH=$($Report.remediation_intake.intake_report_path)"

$Proof = [ordered]@{
    proof_id = "ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1"
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
    conclusion = "Unknown specialization families now return a complete remediation packet from one BUILD_FROM_RAW_IDEA_SPECIALIZED run."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "one_run_gap_remediation_packet_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_41") { throw "Expected PHASE_41." }
if ($State.current_capability -ne "one_run_gap_remediation_packet_proof_v1") { throw "Expected one_run_gap_remediation_packet_proof_v1." }
if ($Queue.active_task_id -ne "TASK_ONE_RUN_GAP_REMEDIATION_PACKET_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 41 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 41 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_41"
    $State.current_capability = "one_run_gap_remediation_packet_proof_v1"
    $State.completed_capabilities += "one_run_gap_remediation_packet_proof_v1"
    $State.last_run_status = "PASS"
    $State.inline_gap_remediation_packet_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: one_run_gap_remediation_packet_proof_v1 checks passed. run_id=$RunId"
