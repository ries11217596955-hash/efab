param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_external_agent_package.ps1"
. ".\modules\test_generated_agent_package_operational.ps1"

$Spec = Get-Content ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json" -Raw | ConvertFrom-Json
$ProofRoot = ".\runs\$RunId\PHASE15_OPERATIONAL_HARNESS_PROOF"
New-Item -ItemType Directory -Force -Path $ProofRoot | Out-Null

$Manifest = New-ExternalAgentPackage -Spec $Spec -OutputRoot $ProofRoot
$ValidationRunRoot = Join-Path $ProofRoot "validation_run"

$Report = Test-GeneratedAgentPackageOperational `
    -PackageRoot $Manifest.package_root `
    -RunRoot $ValidationRunRoot

if ($Report.status -ne "PASS") {
    throw "Operational harness report status must be PASS."
}

$Report | ConvertTo-Json -Depth 100 |
    Set-Content (Join-Path $ProofRoot "OPERATIONAL_VALIDATION_REPORT.json") -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "operational_validation_harness_v2" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "factory_build_external_agent_mode_v2" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_OPERATIONAL_VALIDATION_HARNESS_V2_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_15") { throw "Expected PHASE_15." }
if ($State.current_capability -ne "operational_validation_harness_v2") { throw "Expected operational_validation_harness_v2." }
if ($Queue.active_task_id -ne "TASK_OPERATIONAL_VALIDATION_HARNESS_V2_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 15 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 15 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_16"
    $State.current_capability = "factory_build_external_agent_mode_v2"
    $State.completed_capabilities += "operational_validation_harness_v2"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_001"
        capability_id = "factory_build_external_agent_mode_v2"
        status = "ACTIVE"
        objective = "Upgrade BUILD_EXTERNAL_AGENT mode so that every generated package is operationally validated and emits a structured build report."
        expected_gate = "FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_READY"
        build_task_path = "tasks/TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V2_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: operational_validation_harness_v2 checks passed. run_id=$RunId"
