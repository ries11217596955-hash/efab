param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

New-Item -ItemType Directory -Force -Path ".\specs\operational_factory_proof" | Out-Null

$SpecPath = ".\specs\operational_factory_proof\OPERATIONAL_FACTORY_PROOF_SPEC.json"
$OutputRoot = ".\generated_agents"

& ".\orchestrator\run.ps1" `
    -Mode BUILD_EXTERNAL_AGENT `
    -RunId $RunId `
    -SpecPath $SpecPath `
    -OutputRoot $OutputRoot |
    Out-Host

$ReportPath = ".\runs\$RunId\BUILD_EXTERNAL_AGENT_MODE_V2\BUILD_EXTERNAL_AGENT_REPORT.json"
if (-not (Test-Path $ReportPath)) {
    throw "Operational factory proof build report missing."
}

$BuildReport = Get-Content $ReportPath -Raw | ConvertFrom-Json
if ($BuildReport.status -ne "PASS") {
    throw "Operational factory proof build report must be PASS."
}

$GeneratedRoot = ".\generated_agents\operational_factory_proof_agent"
$GeneratedOutput = ".\runs\$RunId\BUILD_EXTERNAL_AGENT_MODE_V2\operational_validation\OPERATIONAL_RESULT.json"

if (-not (Test-Path $GeneratedRoot)) {
    throw "Operational proof generated root missing."
}

if (-not (Test-Path $GeneratedOutput)) {
    throw "Operational proof generated result output missing."
}

$GeneratedResult = Get-Content $GeneratedOutput -Raw | ConvertFrom-Json

if ($GeneratedResult.status -ne "PASS") {
    throw "Operational proof generated result must be PASS."
}

$Proof = [ordered]@{
    proof_id = "OPERATIONAL_FACTORY_PROOF_V2"
    run_id = $RunId
    status = "PASS"
    generated_agent_id = "operational_factory_proof_agent"
    generated_package_root = $GeneratedRoot
    build_report_path = $ReportPath
    generated_result_path = $GeneratedOutput
    generated_result_status = $GeneratedResult.status
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\OPERATIONAL_FACTORY_PROOF_V2.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "operational_factory_proof_v2" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_OPERATIONAL_FACTORY_PROOF_V2_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_17") { throw "Expected PHASE_17." }
if ($State.current_capability -ne "operational_factory_proof_v2") { throw "Expected operational_factory_proof_v2." }
if ($Queue.active_task_id -ne "TASK_OPERATIONAL_FACTORY_PROOF_V2_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 17 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 17 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.production_factory_ready = $true
    $State.production_hardening_v2_ready = $true
    $State.operational_agent_package_ready = $true
    $State.current_phase = "PHASE_17"
    $State.current_capability = "operational_factory_proof_v2"
    $State.completed_capabilities += "operational_factory_proof_v2"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: operational_factory_proof_v2 checks passed. run_id=$RunId"
