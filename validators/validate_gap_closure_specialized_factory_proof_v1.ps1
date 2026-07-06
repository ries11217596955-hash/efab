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
    throw "Gap closure factory report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "PASS") {
    throw "Gap closure factory report must be PASS."
}

if ($Report.specialization.profile_id -ne "decision_support_agent_v1") {
    throw "Gap closure did not route to decision_support_agent_v1."
}

if ($Report.gap_report -ne $null) {
    throw "Gap closure path must not retain a gap report."
}

if ($Report.target_build.overlay_status -ne "PASS") {
    throw "Gap closure target overlay status must be PASS."
}

if (-not (Test-Path $Report.target_build.validation_output)) {
    throw "Gap closure validation output missing."
}

$Result = Get-Content $Report.target_build.validation_output -Raw | ConvertFrom-Json

if ($Result.result.operation -ne "decision_route_prioritization") {
    throw "Gap closure specialized operation mismatch."
}

if ($Result.diagnostics.specialization_profile -ne "decision_support_agent_v1") {
    throw "Gap closure specialization diagnostics mismatch."
}

if ($Result.result.top_route_id -ne "execute_high_confidence_patch") {
    throw "Gap closure top route mismatch."
}

$Proof = [ordered]@{
    proof_id = "GAP_CLOSURE_SPECIALIZED_FACTORY_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    factory_report_path = $ReportPath
    selected_profile_id = $Report.specialization.profile_id
    generated_package_root = $Report.target_build.package_root
    validation_output = $Report.target_build.validation_output
    specialized_operation = $Result.result.operation
    top_route_id = $Result.result.top_route_id
    conclusion = "A previously unsupported decision_support_agent family now closes through profile candidate generation, profile registration, and successful specialized factory execution."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\GAP_CLOSURE_SPECIALIZED_FACTORY_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "gap_closure_specialized_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_GAP_CLOSURE_SPECIALIZED_FACTORY_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_32") { throw "Expected PHASE_32." }
if ($State.current_capability -ne "gap_closure_specialized_factory_proof_v1") { throw "Expected gap_closure_specialized_factory_proof_v1." }
if ($Queue.active_task_id -ne "TASK_GAP_CLOSURE_SPECIALIZED_FACTORY_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 32 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 32 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_32"
    $State.current_capability = "gap_closure_specialized_factory_proof_v1"
    $State.completed_capabilities += "gap_closure_specialized_factory_proof_v1"
    $State.last_run_status = "PASS"
    $State.gap_to_profile_closure_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: gap_closure_specialized_factory_proof_v1 checks passed. run_id=$RunId"
