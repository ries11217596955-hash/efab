param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\resolve_specialization_overlay.ps1"
. ".\modules\invoke_external_agent_build.ps1"

$ProgramSeedPath = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"

if (-not (Test-Path $ProgramSeedPath)) {
    throw "Canonical monitoring remediation program seed missing."
}

$Seed = Get-Content $ProgramSeedPath -Raw | ConvertFrom-Json

if ($Seed.status -ne "PROGRAM_SEED_READY") {
    throw "Program seed status mismatch."
}

if ($Seed.candidate_profile_id -ne "monitoring_agent_v1") {
    throw "Program seed profile target mismatch."
}

if ($Seed.candidate_agent_kind -ne "monitoring_agent") {
    throw "Program seed kind target mismatch."
}

if ($Seed.recommended_program.profile_capability_id -ne "monitoring_agent_specialization_profile_v1") {
    throw "Program seed profile capability target mismatch."
}

$Resolution = Resolve-SpecializationOverlay `
    -AgentKind "monitoring_agent" `
    -PackageProfile "operational_specialized"

Write-Host "MONITORING_PROFILE_RESOLUTION_STATUS=$($Resolution.status)"
Write-Host "MONITORING_PROFILE_ID=$($Resolution.profile_id)"
Write-Host "MONITORING_PROFILE_OVERLAY_ROOT=$($Resolution.overlay_root)"

if ($Resolution.status -ne "PASS") {
    throw "Resolver must return PASS for monitoring_agent."
}

if ($Resolution.profile_id -ne "monitoring_agent_v1") {
    throw "Unexpected monitoring specialization profile id."
}

$SpecPath = ".\specs\monitoring_profile_proof\MONITORING_AGENT_PROFILE_PROOF_SPEC.json"
$RunRoot = ".\runs\$RunId\PHASE45_SEED_DRIVEN_MONITORING_PROFILE_V1\profile_build"

$Build = Invoke-ExternalAgentBuild `
    -SpecPath $SpecPath `
    -OutputRoot ".\generated_agents" `
    -RunRoot $RunRoot `
    -OverlayRoot $Resolution.overlay_root

if ($Build.status -ne "PASS") {
    throw "Monitoring profile build must be PASS."
}

if ($Build.overlay.status -ne "PASS") {
    throw "Monitoring overlay apply must be PASS."
}

$ValidationOutput = $Build.validation.output_result_path
if (-not (Test-Path $ValidationOutput)) {
    throw "Monitoring profile validation output missing."
}

$Result = Get-Content $ValidationOutput -Raw | ConvertFrom-Json

if ($Result.result.operation -ne "monitoring_alert_triage_queue") {
    throw "Monitoring specialized operation mismatch."
}

if ($Result.diagnostics.specialization_profile -ne "monitoring_agent_v1") {
    throw "Monitoring specialization diagnostics mismatch."
}

if ($Result.result.next_alert_id -ne "cpu_spike") {
    throw "Monitoring next alert mismatch."
}

if ($Result.result.escalation_status -ne "ESCALATE") {
    throw "Monitoring escalation status mismatch."
}

if ($Result.result.alert_count -ne 2) {
    throw "Monitoring alert count mismatch."
}

$Proof = [ordered]@{
    proof_id = "SEED_DRIVEN_MONITORING_PROFILE_V1"
    run_id = $RunId
    status = "PASS"
    program_seed_path = $ProgramSeedPath
    candidate_profile_id = $Seed.candidate_profile_id
    candidate_agent_kind = $Seed.candidate_agent_kind
    profile_capability_id = $Seed.recommended_program.profile_capability_id
    selected_profile_id = $Resolution.profile_id
    build_report_path = $Build.report_path
    validation_output = $ValidationOutput
    specialized_operation = $Result.result.operation
    next_alert_id = $Result.result.next_alert_id
    escalation_status = $Result.result.escalation_status
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\SEED_DRIVEN_MONITORING_PROFILE_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "seed_driven_monitoring_profile_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "monitoring_gap_closure_specialized_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_SEED_DRIVEN_MONITORING_PROFILE_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_45") { throw "Expected PHASE_45." }
if ($State.current_capability -ne "seed_driven_monitoring_profile_v1") { throw "Expected seed_driven_monitoring_profile_v1." }
if ($Queue.active_task_id -ne "TASK_SEED_DRIVEN_MONITORING_PROFILE_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 45 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 45 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_46"
    $State.current_capability = "monitoring_gap_closure_specialized_proof_v1"
    $State.completed_capabilities += "seed_driven_monitoring_profile_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1_001"
        capability_id = "monitoring_gap_closure_specialized_proof_v1"
        status = "ACTIVE"
        objective = "Rerun the prior monitoring raw idea and prove it now resolves to monitoring_agent_v1 with specialized PASS output."
        expected_gate = "MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1"
        build_task_path = "tasks/TASK_MONITORING_GAP_CLOSURE_SPECIALIZED_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: seed_driven_monitoring_profile_v1 checks passed. run_id=$RunId"
