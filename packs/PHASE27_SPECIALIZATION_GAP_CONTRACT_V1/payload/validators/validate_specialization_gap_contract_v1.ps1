param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_specialization_gap_report.ps1"

$ModeRoot = ".\runs\$RunId\PHASE27_SPECIALIZATION_GAP_CONTRACT_V1\gap_contract_proof"

$DerivedSpec = [pscustomobject]@{
    agent_id = "decision_route_agent"
    agent_kind = "decision_support_agent"
    package_profile = "operational_specialized"
}

$Specialization = [pscustomobject]@{
    status = "NO_MATCH"
    profile_id = "NONE"
    profile_kind = "decision_support_agent"
    overlay_root = ""
    resolution_reason = "No active specialization profile matched derived agent_kind/package_profile."
}

$Gap = New-SpecializationGapReport `
    -RunId $RunId `
    -ModeRoot $ModeRoot `
    -RawIdeaPath ".\specs\synthetic\RAW_IDEA_DECISION_ROUTE_AGENT.json" `
    -DerivedSpecPath ".\runs\$RunId\synthetic\DERIVED_AGENT_SPEC.json" `
    -DerivedSpec $DerivedSpec `
    -Specialization $Specialization

Write-Host "GAP_CONTRACT_REPORT_STATUS=$($Gap.status)"
Write-Host "GAP_CONTRACT_DIAGNOSTIC_STATUS=$($Gap.diagnostic_status)"
Write-Host "GAP_CONTRACT_MISSING_AGENT_KIND=$($Gap.missing_agent_kind)"
Write-Host "GAP_CONTRACT_REPORT_PATH=$($Gap.report_path)"

if ($Gap.status -ne "PASS") {
    throw "Gap report writer must return PASS."
}

if ($Gap.diagnostic_status -ne "MISSING_SPECIALIZATION_PROFILE") {
    throw "Unexpected diagnostic status."
}

if ($Gap.missing_agent_kind -ne "decision_support_agent") {
    throw "Unexpected missing agent kind."
}

if (-not (Test-Path $Gap.report_path)) {
    throw "Gap report file missing."
}

$GapJson = Get-Content $Gap.report_path -Raw | ConvertFrom-Json

if ($GapJson.required_next_move -ne "ADD_OR_MAP_SPECIALIZATION_PROFILE") {
    throw "Gap report next move mismatch."
}

$Proof = [ordered]@{
    proof_id = "SPECIALIZATION_GAP_CONTRACT_V1"
    run_id = $RunId
    status = "PASS"
    report_path = $Gap.report_path
    diagnostic_status = $GapJson.diagnostic_status
    missing_agent_kind = $GapJson.missing_agent_kind
    required_next_move = $GapJson.required_next_move
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\SPECIALIZATION_GAP_CONTRACT_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specialization_gap_contract_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "no_match_diagnostic_mode_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_SPECIALIZATION_GAP_CONTRACT_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_27") { throw "Expected PHASE_27." }
if ($State.current_capability -ne "specialization_gap_contract_v1") { throw "Expected specialization_gap_contract_v1." }
if ($Queue.active_task_id -ne "TASK_SPECIALIZATION_GAP_CONTRACT_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 27 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 27 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_28"
    $State.current_capability = "no_match_diagnostic_mode_v1"
    $State.completed_capabilities += "specialization_gap_contract_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_NO_MATCH_DIAGNOSTIC_MODE_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_NO_MATCH_DIAGNOSTIC_MODE_V1_001"
        capability_id = "no_match_diagnostic_mode_v1"
        status = "ACTIVE"
        objective = "Modify BUILD_FROM_RAW_IDEA_SPECIALIZED so NO_MATCH writes structured diagnostic artifacts instead of throwing."
        expected_gate = "NO_MATCH_DIAGNOSTIC_MODE_V1_READY"
        build_task_path = "tasks/TASK_NO_MATCH_DIAGNOSTIC_MODE_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: specialization_gap_contract_v1 checks passed. run_id=$RunId"
