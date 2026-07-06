param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\resolve_specialization_overlay.ps1"

$Resolution = Resolve-SpecializationOverlay `
    -AgentKind "audit_agent" `
    -PackageProfile "operational_specialized"

Write-Host "SPECIALIZATION_RESOLUTION_STATUS=$($Resolution.status)"
Write-Host "SPECIALIZATION_PROFILE_ID=$($Resolution.profile_id)"
Write-Host "SPECIALIZATION_OVERLAY_ROOT=$($Resolution.overlay_root)"

if ($Resolution.status -ne "PASS") {
    throw "Specialization resolver must return PASS for audit_agent."
}

if ($Resolution.profile_id -ne "audit_agent_v1") {
    throw "Unexpected specialization profile id."
}

if (-not (Test-Path $Resolution.overlay_root)) {
    throw "Resolved specialization overlay root missing."
}

$OverlayModule = Join-Path $Resolution.overlay_root "modules\invoke_agent_operation.ps1"
$OverlaySample = Join-Path $Resolution.overlay_root "examples\SAMPLE_REQUEST.json"

if (-not (Test-Path $OverlayModule)) {
    throw "Specialization overlay runtime module missing."
}

if (-not (Test-Path $OverlaySample)) {
    throw "Specialization overlay sample request missing."
}

$Proof = [ordered]@{
    proof_id = "SPECIALIZATION_OVERLAY_RESOLUTION_V1"
    run_id = $RunId
    status = "PASS"
    profile_id = $Resolution.profile_id
    overlay_root = $Resolution.overlay_root
    overlay_module = $OverlayModule
    overlay_sample = $OverlaySample
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\SPECIALIZATION_OVERLAY_RESOLUTION_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specialization_overlay_resolution_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "build_from_raw_idea_specialized_mode_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_SPECIALIZATION_OVERLAY_RESOLUTION_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_21") { throw "Expected PHASE_21." }
if ($State.current_capability -ne "specialization_overlay_resolution_v1") { throw "Expected specialization_overlay_resolution_v1." }
if ($Queue.active_task_id -ne "TASK_SPECIALIZATION_OVERLAY_RESOLUTION_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 21 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 21 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_22"
    $State.current_capability = "build_from_raw_idea_specialized_mode_v1"
    $State.completed_capabilities += "specialization_overlay_resolution_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_001"
        capability_id = "build_from_raw_idea_specialized_mode_v1"
        status = "ACTIVE"
        objective = "Expose direct BUILD_FROM_RAW_IDEA_SPECIALIZED mode that resolves and applies a specialization overlay."
        expected_gate = "BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_READY"
        build_task_path = "tasks/TASK_BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: specialization_overlay_resolution_v1 checks passed. run_id=$RunId"
