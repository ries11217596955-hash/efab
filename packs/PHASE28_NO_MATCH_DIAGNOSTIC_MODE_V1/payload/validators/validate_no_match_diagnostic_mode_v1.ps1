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

$RawIdeaPath = ".\specs\specialization_gap_proof\RAW_IDEA_GAP_MODE_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "Specialized diagnostic mode report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "SPECIALIZATION_GAP") {
    throw "Specialized mode must return SPECIALIZATION_GAP."
}

if ($Report.specialization.status -ne "NO_MATCH") {
    throw "Specialized mode resolver status must be NO_MATCH."
}

if ($Report.gap_report.status -ne "PASS") {
    throw "Gap report status must be PASS."
}

if (-not (Test-Path $Report.gap_report.report_path)) {
    throw "Gap report artifact missing."
}

$Gap = Get-Content $Report.gap_report.report_path -Raw | ConvertFrom-Json

if ($Gap.diagnostic_status -ne "MISSING_SPECIALIZATION_PROFILE") {
    throw "Gap diagnostic status mismatch."
}

if ($Gap.missing_agent_kind -ne "decision_support_agent") {
    throw "Gap missing agent kind mismatch."
}

if ($Gap.requested_package_profile -ne "operational_specialized") {
    throw "Gap requested package profile mismatch."
}

Write-Host "NO_MATCH_MODE_REPORT_STATUS=$($Report.status)"
Write-Host "NO_MATCH_MODE_SPECIALIZATION_STATUS=$($Report.specialization.status)"
Write-Host "NO_MATCH_MODE_GAP_KIND=$($Gap.missing_agent_kind)"
Write-Host "NO_MATCH_MODE_GAP_REPORT_PATH=$($Report.gap_report.report_path)"

$Proof = [ordered]@{
    proof_id = "NO_MATCH_DIAGNOSTIC_MODE_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    report_path = $ReportPath
    gap_report_path = $Report.gap_report.report_path
    missing_agent_kind = $Gap.missing_agent_kind
    requested_package_profile = $Gap.requested_package_profile
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\NO_MATCH_DIAGNOSTIC_MODE_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "no_match_diagnostic_mode_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "missing_profile_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_NO_MATCH_DIAGNOSTIC_MODE_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_28") { throw "Expected PHASE_28." }
if ($State.current_capability -ne "no_match_diagnostic_mode_v1") { throw "Expected no_match_diagnostic_mode_v1." }
if ($Queue.active_task_id -ne "TASK_NO_MATCH_DIAGNOSTIC_MODE_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 28 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 28 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_29"
    $State.current_capability = "missing_profile_factory_proof_v1"
    $State.completed_capabilities += "no_match_diagnostic_mode_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_MISSING_PROFILE_FACTORY_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_MISSING_PROFILE_FACTORY_PROOF_V1_001"
        capability_id = "missing_profile_factory_proof_v1"
        status = "ACTIVE"
        objective = "Prove unsupported raw idea families emit structured specialization gap diagnostics without crashing the factory."
        expected_gate = "MISSING_PROFILE_FACTORY_PROOF_V1"
        build_task_path = "tasks/TASK_MISSING_PROFILE_FACTORY_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: no_match_diagnostic_mode_v1 checks passed. run_id=$RunId"
