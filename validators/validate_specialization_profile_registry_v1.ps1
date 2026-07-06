param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\resolve_specialization_overlay.ps1"

$RegistryPath = ".\applied_agents\specialization_profiles\SPECIALIZATION_PROFILE_REGISTRY.json"

if (-not (Test-Path $RegistryPath)) {
    throw "Specialization profile registry missing."
}

$Registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

$AuditProfile = $Registry.profiles |
    Where-Object { $_.profile_id -eq "audit_agent_v1" } |
    Select-Object -First 1

if ($null -eq $AuditProfile) {
    throw "audit_agent_v1 registry profile missing."
}

if ($AuditProfile.status -ne "ACTIVE") {
    throw "audit_agent_v1 registry profile must be ACTIVE."
}

$Resolution = Resolve-SpecializationOverlay `
    -AgentKind "audit_agent" `
    -PackageProfile "operational_specialized"

Write-Host "REGISTRY_RESOLUTION_STATUS=$($Resolution.status)"
Write-Host "REGISTRY_RESOLUTION_PROFILE_ID=$($Resolution.profile_id)"
Write-Host "REGISTRY_RESOLUTION_OVERLAY_ROOT=$($Resolution.overlay_root)"

if ($Resolution.status -ne "PASS") {
    throw "Registry resolver must resolve audit_agent."
}

if ($Resolution.profile_id -ne "audit_agent_v1") {
    throw "Registry resolver returned unexpected audit profile."
}

$Proof = [ordered]@{
    proof_id = "SPECIALIZATION_PROFILE_REGISTRY_V1"
    run_id = $RunId
    status = "PASS"
    registry_path = $RegistryPath
    resolved_agent_kind = "audit_agent"
    resolved_profile_id = $Resolution.profile_id
    resolved_overlay_root = $Resolution.overlay_root
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\SPECIALIZATION_PROFILE_REGISTRY_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specialization_profile_registry_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "specification_agent_specialization_profile_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_SPECIALIZATION_PROFILE_REGISTRY_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_24") { throw "Expected PHASE_24." }
if ($State.current_capability -ne "specialization_profile_registry_v1") { throw "Expected specialization_profile_registry_v1." }
if ($Queue.active_task_id -ne "TASK_SPECIALIZATION_PROFILE_REGISTRY_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 24 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 24 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_25"
    $State.current_capability = "specification_agent_specialization_profile_v1"
    $State.completed_capabilities += "specialization_profile_registry_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_001"
        capability_id = "specification_agent_specialization_profile_v1"
        status = "ACTIVE"
        objective = "Add and prove specification_agent_v1 as the second registry-backed specialization profile."
        expected_gate = "SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_READY"
        build_task_path = "tasks/TASK_SPECIFICATION_AGENT_SPECIALIZATION_PROFILE_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: specialization_profile_registry_v1 checks passed. run_id=$RunId"
