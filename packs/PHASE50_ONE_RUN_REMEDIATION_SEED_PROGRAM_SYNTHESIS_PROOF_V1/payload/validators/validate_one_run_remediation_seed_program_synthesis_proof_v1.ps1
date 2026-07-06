param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_remediation_seed_program_blueprint.ps1"
. ".\modules\new_remediation_seed_self_build_program_package.ps1"

$ProgramSeedPath = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"
$ProofRunRoot = ".\runs\$RunId\PHASE50_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1"
$BlueprintPath = Join-Path $ProofRunRoot "SELF_BUILD_PROGRAM_BLUEPRINT.json"
$MaterializationRoot = Join-Path $ProofRunRoot "materialized_program"

New-Item -ItemType Directory -Force -Path $ProofRunRoot | Out-Null

if (-not (Test-Path $ProgramSeedPath)) {
    throw "Canonical remediation program seed missing."
}

$Seed = Get-Content $ProgramSeedPath -Raw | ConvertFrom-Json

$Blueprint = New-RemediationSeedProgramBlueprint `
    -ProgramSeed $Seed `
    -ProgramSeedPath $ProgramSeedPath

$Blueprint | ConvertTo-Json -Depth 100 |
    Set-Content $BlueprintPath -Encoding UTF8

if (-not (Test-Path $BlueprintPath)) {
    throw "One-run blueprint output missing."
}

$Materialized = New-RemediationSeedSelfBuildProgramPackage `
    -Blueprint $Blueprint `
    -OutputRoot $MaterializationRoot

if ($Materialized.status -ne "PASS") {
    throw "One-run materialization failed."
}

$Manifest = Get-Content $Materialized.manifest_path -Raw | ConvertFrom-Json

if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") {
    throw "One-run manifest status mismatch."
}

if ($Manifest.target_profile_id -ne "monitoring_agent_v1") {
    throw "One-run target profile mismatch."
}

if ($Manifest.pack_count -ne 3) {
    throw "One-run pack count mismatch."
}

if ($Manifest.task_count -ne 3) {
    throw "One-run task count mismatch."
}

if ($Manifest.capability_count -ne 3) {
    throw "One-run capability count mismatch."
}

$RegistryPatch = Join-Path $Materialized.patches_root "PACK_REGISTRY_PATCH.json"
$RoadmapPatch = Join-Path $Materialized.patches_root "CAPABILITY_ROADMAP_PATCH.json"
$QueueSeed = Join-Path $Materialized.patches_root "TASK_QUEUE_SEED.json"

foreach ($Path in @($RegistryPatch, $RoadmapPatch, $QueueSeed)) {
    if (-not (Test-Path $Path)) {
        throw "One-run synthesis patch artifact missing: $Path"
    }
}

Write-Host "SYNTHESIS_BLUEPRINT_STATUS=$($Blueprint.status)"
Write-Host "SYNTHESIS_TARGET_PROFILE=$($Manifest.target_profile_id)"
Write-Host "SYNTHESIS_PROGRAM_STATUS=$($Manifest.status)"
Write-Host "SYNTHESIS_PACK_COUNT=$($Manifest.pack_count)"
Write-Host "SYNTHESIS_TASK_COUNT=$($Manifest.task_count)"
Write-Host "SYNTHESIS_CAPABILITY_COUNT=$($Manifest.capability_count)"
Write-Host "SYNTHESIS_ADMISSION_STATUS=$($Manifest.admission_status)"

$Proof = [ordered]@{
    proof_id = "ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    source_seed_path = $ProgramSeedPath
    blueprint_path = $BlueprintPath
    materialized_program_root = $Materialized.program_root
    materialized_manifest_path = $Materialized.manifest_path
    registry_patch_path = $RegistryPatch
    roadmap_patch_path = $RoadmapPatch
    queue_seed_path = $QueueSeed
    target_profile_id = $Manifest.target_profile_id
    pack_count = $Manifest.pack_count
    task_count = $Manifest.task_count
    capability_count = $Manifest.capability_count
    admission_status = $Manifest.admission_status
    conclusion = "Builder can now turn a remediation program seed into a normalized self-build program blueprint and a materialized serial program package without manual serial-program design."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "one_run_remediation_seed_program_synthesis_proof_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_50") { throw "Expected PHASE_50." }
if ($State.current_capability -ne "one_run_remediation_seed_program_synthesis_proof_v1") { throw "Expected one_run_remediation_seed_program_synthesis_proof_v1." }
if ($Queue.active_task_id -ne "TASK_ONE_RUN_REMEDIATION_SEED_PROGRAM_SYNTHESIS_PROOF_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 50 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 50 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"

    $State.current_phase = "PHASE_50"
    $State.current_capability = "one_run_remediation_seed_program_synthesis_proof_v1"
    $State.completed_capabilities += "one_run_remediation_seed_program_synthesis_proof_v1"
    $State.last_run_status = "PASS"
    $State.remediation_seed_to_self_build_program_synthesis_ready = $true

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: one_run_remediation_seed_program_synthesis_proof_v1 checks passed. run_id=$RunId"
