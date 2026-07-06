param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_remediation_seed_self_build_program_package.ps1"

$BlueprintPath = ".\remediation_programs\generated_programs\monitoring_agent_v1\SELF_BUILD_PROGRAM_BLUEPRINT.json"
$ProgramOutputRoot = ".\self_build_programs\generated"

if (-not (Test-Path $BlueprintPath)) {
    throw "Blueprint path missing."
}

$Blueprint = Get-Content $BlueprintPath -Raw | ConvertFrom-Json
$Materialized = New-RemediationSeedSelfBuildProgramPackage `
    -Blueprint $Blueprint `
    -OutputRoot $ProgramOutputRoot

if ($Materialized.status -ne "PASS") {
    throw "Program materialization failed."
}

if (-not (Test-Path $Materialized.manifest_path)) {
    throw "Program manifest missing."
}

$Manifest = Get-Content $Materialized.manifest_path -Raw | ConvertFrom-Json

if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") {
    throw "Program manifest status mismatch."
}

if ($Manifest.target_profile_id -ne "monitoring_agent_v1") {
    throw "Materialized target profile mismatch."
}

if ($Manifest.pack_count -ne 3) {
    throw "Materialized pack count mismatch."
}

if ($Manifest.task_count -ne 3) {
    throw "Materialized task count mismatch."
}

if ($Manifest.capability_count -ne 3) {
    throw "Materialized capability count mismatch."
}

$RegistryPatch = Join-Path $Materialized.patches_root "PACK_REGISTRY_PATCH.json"
$RoadmapPatch = Join-Path $Materialized.patches_root "CAPABILITY_ROADMAP_PATCH.json"
$QueueSeed = Join-Path $Materialized.patches_root "TASK_QUEUE_SEED.json"

foreach ($Path in @($RegistryPatch, $RoadmapPatch, $QueueSeed)) {
    if (-not (Test-Path $Path)) {
        throw "Materialization patch artifact missing: $Path"
    }
}

Write-Host "MATERIALIZATION_STATUS=$($Manifest.status)"
Write-Host "MATERIALIZATION_TARGET_PROFILE=$($Manifest.target_profile_id)"
Write-Host "MATERIALIZATION_PACK_COUNT=$($Manifest.pack_count)"
Write-Host "MATERIALIZATION_TASK_COUNT=$($Manifest.task_count)"
Write-Host "MATERIALIZATION_CAPABILITY_COUNT=$($Manifest.capability_count)"
Write-Host "MATERIALIZATION_ADMISSION_STATUS=$($Manifest.admission_status)"

$Proof = [ordered]@{
    proof_id = "REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1"
    run_id = $RunId
    status = "PASS"
    blueprint_path = $BlueprintPath
    materialized_program_root = $Materialized.program_root
    manifest_path = $Materialized.manifest_path
    registry_patch_path = $RegistryPatch
    roadmap_patch_path = $RoadmapPatch
    queue_seed_path = $QueueSeed
    pack_count = $Manifest.pack_count
    task_count = $Manifest.task_count
    capability_count = $Manifest.capability_count
    admission_status = $Manifest.admission_status
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "remediation_seed_program_materialization_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "one_run_remediation_seed_program_synthesis_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_49") { throw "Expected PHASE_49." }
if ($State.current_capability -ne "remediation_seed_program_materialization_v1") { throw "Expected remediation_seed_program_materialization_v1." }
if ($Queue.active_task_id -ne "TASK_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 49 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 49 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_50"
    $State.current_capability = "one_run_remediation_seed_program_synthesis_proof_v1"
    $State.completed_capabilities += "remediation_seed_program_materialization_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1_001"
        capability_id = "one_run_remediation_seed_program_synthesis_proof_v1"
        status = "ACTIVE"
        objective = "Prove that one canonical remediation program seed can become a normalized blueprint and a materialized serial self-build program package."
        expected_gate = "ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1"
        build_task_path = "tasks/TASK_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: remediation_seed_program_materialization_v1 checks passed. run_id=$RunId"
