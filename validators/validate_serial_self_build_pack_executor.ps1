param(
    [switch]$FinalizePhase,
    [string]$RunId = "PHASE3_PACK_EXECUTOR_001"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
$Registry = Get-Content ".\packs\registry.json" -Raw | ConvertFrom-Json

$ExecutorCap = $Roadmap.capabilities | Where-Object { $_.id -eq "serial_self_build_pack_executor" } | Select-Object -First 1
$ReleaseCap = $Roadmap.capabilities | Where-Object { $_.id -eq "self_validation_release_gates" } | Select-Object -First 1
$ExecutorTask = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_SERIAL_SELF_BUILD_PACK_EXECUTOR_001" } | Select-Object -First 1
$ReleaseTask = $Queue.tasks | Where-Object { $_.task_id -eq "TASK_SELF_VALIDATION_RELEASE_GATES_001" } | Select-Object -First 1
$ReleasePack = $Registry.packs | Where-Object { $_.task_id -eq "TASK_SELF_VALIDATION_RELEASE_GATES_001" } | Select-Object -First 1

if ($State.current_phase -ne "PHASE_3") { throw "Expected PHASE_3." }
if ($State.current_capability -ne "serial_self_build_pack_executor") { throw "Expected serial_self_build_pack_executor." }
if ($ExecutorCap.status -ne "ACTIVE") { throw "Executor capability must be ACTIVE." }
if ($ReleaseCap.status -ne "PENDING") { throw "Release gates capability must be PENDING." }
if ($Queue.active_task_id -ne "TASK_SERIAL_SELF_BUILD_PACK_EXECUTOR_001") { throw "Executor task must be active." }
if ($ExecutorTask.status -ne "ACTIVE") { throw "Executor task status must be ACTIVE." }
if ($ReleaseTask.status -ne "PENDING") { throw "Release task status must be PENDING." }
if ($null -eq $ReleasePack) { throw "Release gate pack missing from registry." }

if ($FinalizePhase) {
    $ExecutorCap.status = "COMPLETED"
    $ReleaseCap.status = "ACTIVE"

    $State.current_phase = "PHASE_4"
    $State.current_capability = "self_validation_release_gates"
    $State.completed_capabilities += "serial_self_build_pack_executor"
    $State.last_run_status = "PASS"

    $ExecutorTask.status = "COMPLETED"
    $ReleaseTask.status = "ACTIVE"
    $Queue.active_task_id = "TASK_SELF_VALIDATION_RELEASE_GATES_001"

    $Roadmap | ConvertTo-Json -Depth 100 | Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8
    $State | ConvertTo-Json -Depth 100 | Set-Content ".\GENESIS_STATE.json" -Encoding UTF8
    $Queue | ConvertTo-Json -Depth 100 | Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: serial_self_build_pack_executor checks passed. run_id=$RunId"
