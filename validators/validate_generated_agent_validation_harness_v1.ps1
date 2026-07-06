param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_external_agent_package.ps1"
. ".\modules\test_generated_agent_package.ps1"

$Spec = Get-Content ".\specs\external_agent_spec_template\SPEC_TEMPLATE.json" -Raw | ConvertFrom-Json
$ProofRoot = ".\runs\$RunId\PHASE10_VALIDATION_HARNESS_PROOF"
New-Item -ItemType Directory -Force -Path $ProofRoot | Out-Null

$Manifest = New-ExternalAgentPackage -Spec $Spec -OutputRoot $ProofRoot
$Validation = Test-GeneratedAgentPackage -PackageRoot $Manifest.package_root

if ($Validation.status -ne "PASS") {
    throw "Generated agent validation harness failed."
}

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities | Where-Object { $_.id -eq "generated_agent_validation_harness_v1" } | Select-Object -First 1
$NextCap = $Roadmap.capabilities | Where-Object { $_.id -eq "factory_build_external_agent_mode_v1" } | Select-Object -First 1
$ThisTask = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_GENERATED_AGENT_VALIDATION_HARNESS_V1_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_10") { throw "Expected PHASE_10." }
if ($State.current_capability -ne "generated_agent_validation_harness_v1") { throw "Expected generated_agent_validation_harness_v1." }
if ($Queue.active_task_id -ne "TASK_GENERATED_AGENT_VALIDATION_HARNESS_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 10 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 10 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_11"
    $State.current_capability = "factory_build_external_agent_mode_v1"
    $State.completed_capabilities += "generated_agent_validation_harness_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_001"
        capability_id = "factory_build_external_agent_mode_v1"
        status = "ACTIVE"
        objective = "Expose direct BUILD_EXTERNAL_AGENT mode in the Agent Builder orchestrator."
        expected_gate = "FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_READY"
        build_task_path = "tasks/TASK_FACTORY_BUILD_EXTERNAL_AGENT_MODE_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: generated_agent_validation_harness_v1 checks passed. run_id=$RunId"
