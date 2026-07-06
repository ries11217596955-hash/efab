param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$RawIdeaPath = ".\specs\workflow_gap_proof\RAW_IDEA_WORKFLOW_EXECUTION_GAP_PROOF.json"
$GapRunId = "$RunId`__RAW_WORKFLOW_GAP"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $GapRunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$GapFactoryReportPath = ".\runs\$GapRunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $GapFactoryReportPath)) {
    throw "Workflow gap factory report missing."
}

$GapFactoryReport = Get-Content $GapFactoryReportPath -Raw | ConvertFrom-Json

if ($GapFactoryReport.status -ne "SPECIALIZATION_GAP") {
    throw "Workflow raw idea must produce SPECIALIZATION_GAP before profile registration."
}

if ($GapFactoryReport.specialization.status -ne "NO_MATCH") {
    throw "Workflow specialization status must be NO_MATCH."
}

if ($GapFactoryReport.gap_report.missing_agent_kind -ne "workflow_execution_agent") {
    throw "Workflow gap missing agent kind mismatch."
}

if (-not (Test-Path $GapFactoryReport.gap_report.report_path)) {
    throw "Workflow gap report artifact missing."
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
    throw "Runtime workflow candidate artifact missing."
}

if (-not (Test-Path $IntakeReportPath)) {
    throw "Runtime workflow intake report artifact missing."
}

$Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json
$Intake = Get-Content $IntakeReportPath -Raw | ConvertFrom-Json

if ($Candidate.candidate_profile_id -ne "workflow_execution_agent_v1") {
    throw "Workflow runtime candidate profile id mismatch."
}

if ($Candidate.candidate_agent_kind -ne "workflow_execution_agent") {
    throw "Workflow runtime candidate agent kind mismatch."
}

if ($Intake.candidate_profile_id -ne "workflow_execution_agent_v1") {
    throw "Workflow runtime intake profile id mismatch."
}

if ($Intake.candidate_agent_kind -ne "workflow_execution_agent") {
    throw "Workflow runtime intake agent kind mismatch."
}

New-Item -ItemType Directory -Force -Path ".\remediation_intake" | Out-Null

$CanonicalCandidatePath = ".\remediation_intake\WORKFLOW_EXECUTION_AGENT_PROFILE_CANDIDATE_V1.json"
$CanonicalIntakePath = ".\remediation_intake\WORKFLOW_EXECUTION_AGENT_INTAKE_REPORT_V1.json"

Copy-Item $CandidatePath $CanonicalCandidatePath -Force
Copy-Item $IntakeReportPath $CanonicalIntakePath -Force

Write-Host "WORKFLOW_GAP_STATUS=$($GapFactoryReport.status)"
Write-Host "WORKFLOW_CANDIDATE_PROFILE_ID=$($Candidate.candidate_profile_id)"
Write-Host "WORKFLOW_INTAKE_REPORT_PATH=$CanonicalIntakePath"

$Proof = [ordered]@{
    proof_id = "WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1"
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
    Set-Content ".\proofs\WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "workflow_execution_family_reachability_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "intake_driven_workflow_execution_profile_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_36") { throw "Expected PHASE_36." }
if ($State.current_capability -ne "workflow_execution_family_reachability_v1") { throw "Expected workflow_execution_family_reachability_v1." }
if ($Queue.active_task_id -ne "TASK_WORKFLOW_EXECUTION_FAMILY_REACHABILITY_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 36 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 36 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_37"
    $State.current_capability = "intake_driven_workflow_execution_profile_v1"
    $State.completed_capabilities += "workflow_execution_family_reachability_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_001"
        capability_id = "intake_driven_workflow_execution_profile_v1"
        status = "ACTIVE"
        objective = "Build and prove workflow_execution_agent_v1 from canonical runtime remediation intake artifacts."
        expected_gate = "INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_READY"
        build_task_path = "tasks/TASK_INTAKE_DRIVEN_WORKFLOW_EXECUTION_PROFILE_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: workflow_execution_family_reachability_v1 checks passed. run_id=$RunId"
