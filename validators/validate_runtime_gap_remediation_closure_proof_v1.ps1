param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$RawIdeaPath = ".\specs\workflow_gap_proof\RAW_IDEA_WORKFLOW_EXECUTION_GAP_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "Runtime closure factory report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "PASS") {
    throw "Runtime closure factory report must be PASS."
}

if ($Report.specialization.profile_id -ne "workflow_execution_agent_v1") {
    throw "Runtime closure did not route to workflow_execution_agent_v1."
}

if ($Report.gap_report -ne $null) {
    throw "Runtime closure path must not retain a gap report."
}

if ($Report.target_build.overlay_status -ne "PASS") {
    throw "Runtime closure target overlay status must be PASS."
}

if (-not (Test-Path $Report.target_build.validation_output)) {
    throw "Runtime closure validation output missing."
}

$Result = Get-Content $Report.target_build.validation_output -Raw | ConvertFrom-Json

if ($Result.result.operation -ne "workflow_step_dispatch_plan") {
    throw "Runtime closure specialized operation mismatch."
}

if ($Result.diagnostics.specialization_profile -ne "workflow_execution_agent_v1") {
    throw "Runtime closure specialization diagnostics mismatch."
}

if ($Result.result.next_step_id -ne "collect_input") {
    throw "Runtime closure next step mismatch."
}

$Proof = [ordered]@{
    proof_id = "RUNTIME_GAP_REMEDIATION_CLOSURE_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    factory_report_path = $ReportPath
    selected_profile_id = $Report.specialization.profile_id
    generated_package_root = $Report.target_build.package_root
    validation_output = $Report.target_build.validation_output
    specialized_operation = $Result.result.operation
    next_step_id = $Result.result.next_step_id
    conclusion = "A real raw idea that previously produced a runtime specialization gap now closes through candidate intake, profile registration, and specialized factory success."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\RUNTIME_GAP_REMEDIATION_CLOSURE_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "runtime_gap_remediation_closure_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_RUNTIME_GAP_REMEDIATION_CLOSURE_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_38") { throw "Expected PHASE_38." }
if ($State.current_capability -ne "runtime_gap_remediation_closure_proof_v1") { throw "Expected runtime_gap_remediation_closure_proof_v1." }
if ($Queue.active_task_id -ne "TASK_RUNTIME_GAP_REMEDIATION_CLOSURE_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 38 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 38 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_38"
    $State.current_capability = "runtime_gap_remediation_closure_proof_v1"
    $State.completed_capabilities += "runtime_gap_remediation_closure_proof_v1"
    $State.last_run_status = "PASS"
    $State.runtime_gap_remediation_closure_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: runtime_gap_remediation_closure_proof_v1 checks passed. run_id=$RunId"
