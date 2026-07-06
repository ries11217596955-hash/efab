param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$RawIdeaPath = ".\specs\idea_to_specialized_agent_proof\RAW_IDEA_SPECIALIZED_FACTORY_PROOF.json"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $RunId `
    -RawIdeaPath $RawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

if (-not (Test-Path $ReportPath)) {
    throw "Idea-to-specialized-agent factory report missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json

if ($Report.status -ne "PASS") {
    throw "Idea-to-specialized-agent factory report must be PASS."
}

if ($Report.derived_agent_id -ne "website_funnel_audit_agent") {
    throw "Unexpected proof derived specialized agent id."
}

if ($Report.specialization.profile_id -ne "audit_agent_v1") {
    throw "Unexpected proof specialization profile id."
}

if ($Report.target_build.overlay_status -ne "PASS") {
    throw "Proof specialized target build overlay status must be PASS."
}

if (-not (Test-Path $Report.target_build.validation_output)) {
    throw "Proof specialized target validation output missing."
}

$TargetResult = Get-Content $Report.target_build.validation_output -Raw | ConvertFrom-Json

if ($TargetResult.result.operation -ne "audit_signal_triage") {
    throw "Proof specialized target operation mismatch."
}

if ($TargetResult.diagnostics.specialization_profile -ne "audit_agent_v1") {
    throw "Proof specialized diagnostics profile mismatch."
}

if ($TargetResult.result.finding_count -ne 3) {
    throw "Proof specialized finding count mismatch."
}

$Proof = [ordered]@{
    proof_id = "IDEA_TO_SPECIALIZED_AGENT_FACTORY_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    raw_idea_path = $RawIdeaPath
    derived_agent_id = $Report.derived_agent_id
    specialization_profile = $Report.specialization.profile_id
    generated_package_root = $Report.target_build.package_root
    generated_validation_output = $Report.target_build.validation_output
    specialized_operation = $TargetResult.result.operation
    specialized_finding_count = $TargetResult.result.finding_count
    factory_report_path = $ReportPath
    conclusion = "Agent Builder can now transform a raw idea into a specialized operational agent through derived spec, specialization resolution, and overlay-backed target build."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\IDEA_TO_SPECIALIZED_AGENT_FACTORY_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "idea_to_specialized_agent_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_IDEA_TO_SPECIALIZED_AGENT_FACTORY_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_23") { throw "Expected PHASE_23." }
if ($State.current_capability -ne "idea_to_specialized_agent_factory_proof_v1") { throw "Expected idea_to_specialized_agent_factory_proof_v1." }
if ($Queue.active_task_id -ne "TASK_IDEA_TO_SPECIALIZED_AGENT_FACTORY_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 23 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 23 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_23"
    $State.current_capability = "idea_to_specialized_agent_factory_proof_v1"
    $State.completed_capabilities += "idea_to_specialized_agent_factory_proof_v1"
    $State.last_run_status = "PASS"
    $State.idea_to_specialized_agent_factory_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: idea_to_specialized_agent_factory_proof_v1 checks passed. run_id=$RunId"
