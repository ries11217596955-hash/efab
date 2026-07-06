param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_specialization_profile_candidate_brief.ps1"

$RawIdeaPath = ".\specs\specialization_gap_proof\RAW_IDEA_MISSING_PROFILE_FACTORY_PROOF.json"
$GapRunId = "$RunId`__GAP_REPRO"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $GapRunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$GapFactoryReportPath = ".\runs\$GapRunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $GapFactoryReportPath)) {
    throw "Gap reproduction factory report missing."
}

$GapFactoryReport = Get-Content $GapFactoryReportPath -Raw | ConvertFrom-Json

if ($GapFactoryReport.status -ne "SPECIALIZATION_GAP") {
    throw "Gap reproduction must still produce SPECIALIZATION_GAP before profile closure."
}

if (-not (Test-Path $GapFactoryReport.gap_report.report_path)) {
    throw "Gap reproduction report path missing."
}

$CandidatePath = ".\specialization_candidates\DECISION_SUPPORT_AGENT_PROFILE_CANDIDATE_V1.json"

$Candidate = New-SpecializationProfileCandidateBrief `
    -RunId $RunId `
    -GapReportPath $GapFactoryReport.gap_report.report_path `
    -CandidateOutputPath $CandidatePath

Write-Host "PROFILE_CANDIDATE_STATUS=$($Candidate.status)"
Write-Host "PROFILE_CANDIDATE_PROFILE_ID=$($Candidate.candidate_profile_id)"
Write-Host "PROFILE_CANDIDATE_AGENT_KIND=$($Candidate.candidate_agent_kind)"
Write-Host "PROFILE_CANDIDATE_PATH=$($Candidate.candidate_path)"

if ($Candidate.status -ne "PASS") {
    throw "Profile candidate generation must be PASS."
}

if ($Candidate.candidate_profile_id -ne "decision_support_agent_v1") {
    throw "Unexpected profile candidate id."
}

if ($Candidate.candidate_agent_kind -ne "decision_support_agent") {
    throw "Unexpected profile candidate agent kind."
}

if (-not (Test-Path $Candidate.candidate_path)) {
    throw "Profile candidate brief file missing."
}

$Proof = [ordered]@{
    proof_id = "GAP_TO_PROFILE_CANDIDATE_BRIEF_V1"
    run_id = $RunId
    status = "PASS"
    source_gap_factory_report = $GapFactoryReportPath
    source_gap_report = $GapFactoryReport.gap_report.report_path
    candidate_path = $Candidate.candidate_path
    candidate_profile_id = $Candidate.candidate_profile_id
    candidate_agent_kind = $Candidate.candidate_agent_kind
    required_build_move = $Candidate.required_build_move
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\GAP_TO_PROFILE_CANDIDATE_BRIEF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "gap_to_profile_candidate_brief_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "decision_support_agent_specialization_profile_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_GAP_TO_PROFILE_CANDIDATE_BRIEF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_30") { throw "Expected PHASE_30." }
if ($State.current_capability -ne "gap_to_profile_candidate_brief_v1") { throw "Expected gap_to_profile_candidate_brief_v1." }
if ($Queue.active_task_id -ne "TASK_GAP_TO_PROFILE_CANDIDATE_BRIEF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 30 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 30 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_31"
    $State.current_capability = "decision_support_agent_specialization_profile_v1"
    $State.completed_capabilities += "gap_to_profile_candidate_brief_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_001"
        capability_id = "decision_support_agent_specialization_profile_v1"
        status = "ACTIVE"
        objective = "Build and prove decision_support_agent_v1 from the canonical gap-driven profile candidate brief."
        expected_gate = "DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_READY"
        build_task_path = "tasks/TASK_DECISION_SUPPORT_AGENT_SPECIALIZATION_PROFILE_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: gap_to_profile_candidate_brief_v1 checks passed. run_id=$RunId"
