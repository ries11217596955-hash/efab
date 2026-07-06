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
    throw "Monitoring closure factory report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "PASS") {
    throw "Monitoring closure factory report must be PASS."
}

if ($Report.specialization.profile_id -ne "monitoring_agent_v1") {
    throw "Monitoring closure did not route to monitoring_agent_v1."
}

if ($Report.gap_report -ne $null) {
    throw "Monitoring closure path must not retain a gap report."
}

if ($Report.target_build.overlay_status -ne "PASS") {
    throw "Monitoring closure target overlay status must be PASS."
}

if (-not (Test-Path $Report.target_build.validation_output)) {
    throw "Monitoring closure validation output missing."
}

$Result = Get-Content $Report.target_build.validation_output -Raw | ConvertFrom-Json

if ($Result.result.operation -ne "monitoring_alert_triage_queue") {
    throw "Monitoring closure specialized operation mismatch."
}

if ($Result.diagnostics.specialization_profile -ne "monitoring_agent_v1") {
    throw "Monitoring closure specialization diagnostics mismatch."
}

if ($Result.result.next_alert_id -ne "cpu_spike") {
    throw "Monitoring closure next alert mismatch."
}

if ($Result.result.escalation_status -ne "ESCALATE") {
    throw "Monitoring closure escalation status mismatch."
}

$Proof = [ordered]@{
    proof_id = "MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    factory_report_path = $ReportPath
    selected_profile_id = $Report.specialization.profile_id
    generated_package_root = $Report.target_build.package_root
    validation_output = $Report.target_build.validation_output
    specialized_operation = $Result.result.operation
    next_alert_id = $Result.result.next_alert_id
    escalation_status = $Result.result.escalation_status
    conclusion = "The monitoring raw idea that previously emitted a specialization gap now closes through monitoring_agent_v1 specialized factory success."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "monitoring_gap_closure_specialized_proof_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "remediation_program_seed_consumption_closure_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_46") { throw "Expected PHASE_46." }
if ($State.current_capability -ne "monitoring_gap_closure_specialized_proof_v1") { throw "Expected monitoring_gap_closure_specialized_proof_v1." }
if ($Queue.active_task_id -ne "TASK_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 46 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 46 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_47"
    $State.current_capability = "remediation_program_seed_consumption_closure_proof_v1"
    $State.completed_capabilities += "monitoring_gap_closure_specialized_proof_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1_001"
        capability_id = "remediation_program_seed_consumption_closure_proof_v1"
        status = "ACTIVE"
        objective = "Prove the canonical remediation program seed was consumed into a real monitoring specialization closure loop."
        expected_gate = "REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1"
        build_task_path = "tasks/TASK_REMEDIATION_PROGRAM_SEED_CONSUMPTION_CLOSURE_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: monitoring_gap_closure_specialized_proof_v1 checks passed. run_id=$RunId"
