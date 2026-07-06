param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$RawIdeaPath = ".\specs\specialization_gap_proof\RAW_IDEA_MISSING_PROFILE_FACTORY_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "Missing-profile factory report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "SPECIALIZATION_GAP") {
    throw "Missing-profile factory report must return SPECIALIZATION_GAP."
}

if ($Report.specialization.status -ne "NO_MATCH") {
    throw "Missing-profile specialization status must be NO_MATCH."
}

if ($Report.target_build -ne $null) {
    throw "Missing-profile path must not build a target agent."
}

if (-not (Test-Path $Report.gap_report.report_path)) {
    throw "Missing-profile gap report artifact missing."
}

$Gap = Get-Content $Report.gap_report.report_path -Raw | ConvertFrom-Json

if ($Gap.diagnostic_status -ne "MISSING_SPECIALIZATION_PROFILE") {
    throw "Missing-profile diagnostic status mismatch."
}

if ($Gap.missing_agent_kind -ne "decision_support_agent") {
    throw "Missing-profile derived agent kind mismatch."
}

if ($Gap.required_next_move -ne "ADD_OR_MAP_SPECIALIZATION_PROFILE") {
    throw "Missing-profile required next move mismatch."
}

$Proof = [ordered]@{
    proof_id = "MISSING_PROFILE_FACTORY_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    factory_report_path = $ReportPath
    gap_report_path = $Report.gap_report.report_path
    specialization_status = $Report.specialization.status
    missing_agent_kind = $Gap.missing_agent_kind
    requested_package_profile = $Gap.requested_package_profile
    required_next_move = $Gap.required_next_move
    conclusion = "Agent Builder now handles unsupported specialization families through structured diagnostic output instead of opaque fatal failure."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\MISSING_PROFILE_FACTORY_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "missing_profile_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_MISSING_PROFILE_FACTORY_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_29") { throw "Expected PHASE_29." }
if ($State.current_capability -ne "missing_profile_factory_proof_v1") { throw "Expected missing_profile_factory_proof_v1." }
if ($Queue.active_task_id -ne "TASK_MISSING_PROFILE_FACTORY_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 29 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 29 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_29"
    $State.current_capability = "missing_profile_factory_proof_v1"
    $State.completed_capabilities += "missing_profile_factory_proof_v1"
    $State.last_run_status = "PASS"
    $State.specialization_gap_diagnostic_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: missing_profile_factory_proof_v1 checks passed. run_id=$RunId"
