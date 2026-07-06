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

$RawIdeaPath = ".\specs\idea_to_specialized_agent_proof\RAW_IDEA_SPECIALIZED_MODE_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "BUILD_FROM_RAW_IDEA_SPECIALIZED report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "PASS") {
    throw "BUILD_FROM_RAW_IDEA_SPECIALIZED report must be PASS."
}

if ($Report.derived_agent_id -ne "website_funnel_audit_agent") {
    throw "Unexpected derived specialized agent id."
}

if ($Report.specialization.profile_id -ne "audit_agent_v1") {
    throw "Unexpected specialization profile id."
}

if ($Report.target_build.overlay_status -ne "PASS") {
    throw "Specialized target build overlay status must be PASS."
}

if (-not (Test-Path $Report.target_build.validation_output)) {
    throw "Specialized target validation output missing."
}

$TargetResult = Get-Content $Report.target_build.validation_output -Raw | ConvertFrom-Json

if ($TargetResult.result.operation -ne "audit_signal_triage") {
    throw "Specialized target operation mismatch."
}

if ($TargetResult.diagnostics.specialization_profile -ne "audit_agent_v1") {
    throw "Specialized target diagnostics profile mismatch."
}

Write-Host "SPECIALIZED_MODE_REPORT_STATUS=$($Report.status)"
Write-Host "SPECIALIZED_MODE_PROFILE_ID=$($Report.specialization.profile_id)"
Write-Host "SPECIALIZED_MODE_OPERATION=$($TargetResult.result.operation)"

$Proof = [ordered]@{
    proof_id = "BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1"
    run_id = $RunId
    status = "PASS"
    derived_agent_id = $Report.derived_agent_id
    specialization_profile = $Report.specialization.profile_id
    report_path = $ReportPath
    target_validation_output = $Report.target_build.validation_output
    target_operation = $TargetResult.result.operation
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "build_from_raw_idea_specialized_mode_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "idea_to_specialized_agent_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_22") { throw "Expected PHASE_22." }
if ($State.current_capability -ne "build_from_raw_idea_specialized_mode_v1") { throw "Expected build_from_raw_idea_specialized_mode_v1." }
if ($Queue.active_task_id -ne "TASK_BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 22 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 22 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_23"
    $State.current_capability = "idea_to_specialized_agent_factory_proof_v1"
    $State.completed_capabilities += "build_from_raw_idea_specialized_mode_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_IDEA_TO_SPECIALIZED_AGENT_FACTORY_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_IDEA_TO_SPECIALIZED_AGENT_FACTORY_PROOF_V1_001"
        capability_id = "idea_to_specialized_agent_factory_proof_v1"
        status = "ACTIVE"
        objective = "Prove end-to-end raw idea to specialized generated agent factory loop."
        expected_gate = "IDEA_TO_SPECIALIZED_AGENT_FACTORY_PROOF_V1"
        build_task_path = "tasks/TASK_IDEA_TO_SPECIALIZED_AGENT_FACTORY_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: build_from_raw_idea_specialized_mode_v1 checks passed. run_id=$RunId"
