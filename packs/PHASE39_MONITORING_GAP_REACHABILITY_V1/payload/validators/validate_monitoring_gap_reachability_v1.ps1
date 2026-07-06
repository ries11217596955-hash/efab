param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$RawIdeaPath = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"
$GapRunId = "$RunId`__RAW_MONITORING_GAP"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $GapRunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$GapFactoryReportPath = ".\runs\$GapRunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $GapFactoryReportPath)) {
    throw "Monitoring gap factory report missing."
}

$GapFactoryReport = Get-Content $GapFactoryReportPath -Raw | ConvertFrom-Json

if ($GapFactoryReport.status -ne "SPECIALIZATION_GAP") {
    throw "Monitoring raw idea must produce SPECIALIZATION_GAP before auto-intake runtime patch."
}

if ($GapFactoryReport.specialization.status -ne "NO_MATCH") {
    throw "Monitoring specialization status must be NO_MATCH."
}

if ($GapFactoryReport.gap_report.missing_agent_kind -ne "monitoring_agent") {
    throw "Monitoring gap missing agent kind mismatch."
}

if (-not (Test-Path $GapFactoryReport.gap_report.report_path)) {
    throw "Monitoring gap report artifact missing."
}

$CandidateRunId = "$RunId`__RUNTIME_CANDIDATE"

& ".\orchestrator\run.ps1" `
    -Mode GAP_TO_PROFILE_CANDIDATE `
    -RunId $CandidateRunId `
    -GapReportPath $GapFactoryReport.gap_report.report_path |
    Out-Host

$ModeRoot = ".\runs\$CandidateRunId\GAP_TO_PROFILE_CANDIDATE_MODE_V1"
$CandidatePath = Join-Path $ModeRoot "SPECIALIZATION_PROFILE_CANDIDATE.json"
$IntakeReportPath = Join-Path $ModeRoot "GAP_REMEDIATION_INTAKE_REPORT.json"

if (-not (Test-Path $CandidatePath)) {
    throw "Monitoring runtime candidate artifact missing."
}

if (-not (Test-Path $IntakeReportPath)) {
    throw "Monitoring runtime intake report artifact missing."
}

$Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json
$Intake = Get-Content $IntakeReportPath -Raw | ConvertFrom-Json

if ($Candidate.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Monitoring runtime candidate profile id mismatch."
}

if ($Candidate.candidate_agent_kind -ne "monitoring_agent") {
    throw "Monitoring runtime candidate agent kind mismatch."
}

if ($Intake.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Monitoring runtime intake profile id mismatch."
}

if ($Intake.candidate_agent_kind -ne "monitoring_agent") {
    throw "Monitoring runtime intake agent kind mismatch."
}

New-Item -ItemType Directory -Force -Path ".\remediation_intake" | Out-Null

$CanonicalCandidatePath = ".\remediation_intake\MONITORING_AGENT_PROFILE_CANDIDATE_V1.json"
$CanonicalIntakePath = ".\remediation_intake\MONITORING_AGENT_INTAKE_REPORT_V1.json"

Copy-Item $CandidatePath $CanonicalCandidatePath -Force
Copy-Item $IntakeReportPath $CanonicalIntakePath -Force

Write-Host "MONITORING_GAP_STATUS=$($GapFactoryReport.status)"
Write-Host "MONITORING_CANDIDATE_PROFILE_ID=$($Candidate.candidate_profile_id)"
Write-Host "MONITORING_INTAKE_REPORT_PATH=$CanonicalIntakePath"

$Proof = [ordered]@{
    proof_id = "MONITORING_GAP_REACHABILITY_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    gap_factory_report_path = $GapFactoryReportPath
    gap_report_path = $GapFactoryReport.gap_report.report_path
    canonical_candidate_path = $CanonicalCandidatePath
    canonical_intake_report_path = $CanonicalIntakePath
    candidate_profile_id = $Candidate.candidate_profile_id
    candidate_agent_kind = $Candidate.candidate_agent_kind
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\MONITORING_GAP_REACHABILITY_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "monitoring_gap_reachability_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specialized_gap_auto_intake_runtime_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_MONITORING_GAP_REACHABILITY_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_39") { throw "Expected PHASE_39." }
if ($State.current_capability -ne "monitoring_gap_reachability_v1") { throw "Expected monitoring_gap_reachability_v1." }
if ($Queue.active_task_id -ne "TASK_MONITORING_GAP_REACHABILITY_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 39 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 39 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_40"
    $State.current_capability = "specialized_gap_auto_intake_runtime_v1"
    $State.completed_capabilities += "monitoring_gap_reachability_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_SPECIALIZED_GAP_AUTO_INTAKE_RUNTIME_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_SPECIALIZED_GAP_AUTO_INTAKE_RUNTIME_V1_001"
        capability_id = "specialized_gap_auto_intake_runtime_v1"
        status = "ACTIVE"
        objective = "Upgrade BUILD_FROM_RAW_IDEA_SPECIALIZED no-match runtime so one run emits gap, candidate, and intake artifacts."
        expected_gate = "SPECIALIZED_GAP_AUTO_INTAKE_RUNTIME_V1_READY"
        build_task_path = "tasks/TASK_SPECIALIZED_GAP_AUTO_INTAKE_RUNTIME_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: monitoring_gap_reachability_v1 checks passed. run_id=$RunId"
