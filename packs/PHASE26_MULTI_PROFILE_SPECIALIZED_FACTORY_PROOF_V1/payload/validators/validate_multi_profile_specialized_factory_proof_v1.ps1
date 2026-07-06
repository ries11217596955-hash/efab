param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$AuditRawIdeaPath = ".\specs\multi_profile_specialization_proof\RAW_IDEA_AUDIT_MULTI_PROFILE_PROOF.json"
$SpecRawIdeaPath = ".\specs\multi_profile_specialization_proof\RAW_IDEA_SPECIFICATION_MULTI_PROFILE_PROOF.json"

$AuditRunId = "$RunId`__AUDIT"
$SpecRunId = "$RunId`__SPEC"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $AuditRunId `
    -RawIdeaPath $AuditRawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

& ".\orchestrator\run.ps1" `
    -Mode BUILD_FROM_RAW_IDEA_SPECIALIZED `
    -RunId $SpecRunId `
    -RawIdeaPath $SpecRawIdeaPath `
    -OutputRoot ".\generated_agents" |
    Out-Host

$AuditReportPath = ".\runs\$AuditRunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"
$SpecReportPath = ".\runs\$SpecRunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"

foreach ($Path in @($AuditReportPath, $SpecReportPath)) {
    if (-not (Test-Path $Path)) {
        throw "Multi-profile report missing: $Path"
    }
}

$AuditReport = Get-Content $AuditReportPath -Raw | ConvertFrom-Json
$SpecReport = Get-Content $SpecReportPath -Raw | ConvertFrom-Json

if ($AuditReport.status -ne "PASS") {
    throw "Audit multi-profile report must be PASS."
}

if ($SpecReport.status -ne "PASS") {
    throw "Specification multi-profile report must be PASS."
}

if ($AuditReport.specialization.profile_id -ne "audit_agent_v1") {
    throw "Audit raw idea did not route to audit_agent_v1."
}

if ($SpecReport.specialization.profile_id -ne "specification_agent_v1") {
    throw "Specification raw idea did not route to specification_agent_v1."
}

$AuditValidationOutput = $AuditReport.target_build.validation_output
$SpecValidationOutput = $SpecReport.target_build.validation_output

foreach ($Path in @($AuditValidationOutput, $SpecValidationOutput)) {
    if (-not (Test-Path $Path)) {
        throw "Multi-profile validation output missing: $Path"
    }
}

$AuditResult = Get-Content $AuditValidationOutput -Raw | ConvertFrom-Json
$SpecResult = Get-Content $SpecValidationOutput -Raw | ConvertFrom-Json

if ($AuditResult.result.operation -ne "audit_signal_triage") {
    throw "Audit specialized operation mismatch."
}

if ($SpecResult.result.operation -ne "spec_blueprint_synthesis") {
    throw "Specification specialized operation mismatch."
}

if ($AuditResult.diagnostics.specialization_profile -ne "audit_agent_v1") {
    throw "Audit diagnostics specialization profile mismatch."
}

if ($SpecResult.diagnostics.specialization_profile -ne "specification_agent_v1") {
    throw "Specification diagnostics specialization profile mismatch."
}

$Proof = [ordered]@{
    proof_id = "MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    audit_route = [ordered]@{
        raw_idea_path = $AuditRawIdeaPath
        profile_id = $AuditReport.specialization.profile_id
        validation_output = $AuditValidationOutput
        operation = $AuditResult.result.operation
    }
    specification_route = [ordered]@{
        raw_idea_path = $SpecRawIdeaPath
        profile_id = $SpecReport.specialization.profile_id
        validation_output = $SpecValidationOutput
        operation = $SpecResult.result.operation
    }
    conclusion = "Agent Builder now routes distinct raw idea families into distinct registry-backed specialization profiles and generates specialized operational agents for both."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "multi_profile_specialized_factory_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_26") { throw "Expected PHASE_26." }
if ($State.current_capability -ne "multi_profile_specialized_factory_proof_v1") { throw "Expected multi_profile_specialized_factory_proof_v1." }
if ($Queue.active_task_id -ne "TASK_MULTI_PROFILE_SPECIALIZED_FACTORY_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 26 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 26 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_26"
    $State.current_capability = "multi_profile_specialized_factory_proof_v1"
    $State.completed_capabilities += "multi_profile_specialized_factory_proof_v1"
    $State.last_run_status = "PASS"
    $State.multi_profile_specialization_factory_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: multi_profile_specialized_factory_proof_v1 checks passed. run_id=$RunId"
