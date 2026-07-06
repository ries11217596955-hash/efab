param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_remediation_seed_program_blueprint.ps1"

$ProgramSeedPath = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"
$BlueprintOutputDir = ".\remediation_programs\generated_programs\monitoring_agent_v1"
$BlueprintOutputPath = Join-Path $BlueprintOutputDir "SELF_BUILD_PROGRAM_BLUEPRINT.json"

if (-not (Test-Path $ProgramSeedPath)) {
    throw "Program seed missing."
}

New-Item -ItemType Directory -Force -Path $BlueprintOutputDir | Out-Null

$Seed = Get-Content $ProgramSeedPath -Raw | ConvertFrom-Json
$Blueprint = New-RemediationSeedProgramBlueprint `
    -ProgramSeed $Seed `
    -ProgramSeedPath $ProgramSeedPath

$Blueprint | ConvertTo-Json -Depth 100 |
    Set-Content $BlueprintOutputPath -Encoding UTF8

if (-not (Test-Path $BlueprintOutputPath)) {
    throw "Blueprint output missing."
}

$LoadedBlueprint = Get-Content $BlueprintOutputPath -Raw | ConvertFrom-Json

if ($LoadedBlueprint.status -ne "BLUEPRINT_READY") {
    throw "Blueprint status mismatch."
}

if ($LoadedBlueprint.target.profile_id -ne "monitoring_agent_v1") {
    throw "Blueprint target profile mismatch."
}

if ($LoadedBlueprint.target.agent_kind -ne "monitoring_agent") {
    throw "Blueprint target agent kind mismatch."
}

if (@($LoadedBlueprint.generated_capabilities).Count -ne 3) {
    throw "Blueprint capability count mismatch."
}

if (@($LoadedBlueprint.generated_tasks).Count -ne 3) {
    throw "Blueprint task count mismatch."
}

if (@($LoadedBlueprint.generated_packs).Count -ne 3) {
    throw "Blueprint pack count mismatch."
}

if ($LoadedBlueprint.materialization_contract.admission_status -ne "NOT_ADMITTED_YET") {
    throw "Blueprint admission status mismatch."
}

Write-Host "BLUEPRINT_STATUS=$($LoadedBlueprint.status)"
Write-Host "BLUEPRINT_TARGET_PROFILE=$($LoadedBlueprint.target.profile_id)"
Write-Host "BLUEPRINT_TARGET_AGENT_KIND=$($LoadedBlueprint.target.agent_kind)"
Write-Host "BLUEPRINT_PACK_COUNT=$(@($LoadedBlueprint.generated_packs).Count)"
Write-Host "BLUEPRINT_TASK_COUNT=$(@($LoadedBlueprint.generated_tasks).Count)"
Write-Host "BLUEPRINT_CAPABILITY_COUNT=$(@($LoadedBlueprint.generated_capabilities).Count)"

$Proof = [ordered]@{
    proof_id = "REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1"
    run_id = $RunId
    status = "PASS"
    source_seed_path = $ProgramSeedPath
    blueprint_path = $BlueprintOutputPath
    target_profile_id = $LoadedBlueprint.target.profile_id
    target_agent_kind = $LoadedBlueprint.target.agent_kind
    generated_pack_count = @($LoadedBlueprint.generated_packs).Count
    generated_task_count = @($LoadedBlueprint.generated_tasks).Count
    generated_capability_count = @($LoadedBlueprint.generated_capabilities).Count
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1.json" -Encoding UTF8

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "remediation_seed_program_blueprint_contract_v1" } |
    Select-Object -First 1

$NextCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq "remediation_seed_program_materialization_v1" } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq "TASK_REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1_001" } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_48") { throw "Expected PHASE_48." }
if ($State.current_capability -ne "remediation_seed_program_blueprint_contract_v1") { throw "Expected remediation_seed_program_blueprint_contract_v1." }
if ($Queue.active_task_id -ne "TASK_REMEDIATION_SEED_PROGRAM_BLUEPRINT_CONTRACT_V1_001") { throw "Unexpected active task." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE 48 capability must be ACTIVE." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE 48 task must be ACTIVE." }

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $NextCap.status = "ACTIVE"

    $State.current_phase = "PHASE_49"
    $State.current_capability = "remediation_seed_program_materialization_v1"
    $State.completed_capabilities += "remediation_seed_program_blueprint_contract_v1"
    $State.last_run_status = "PASS"

    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "TASK_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_001"
    $Queue.tasks += [pscustomobject]@{
        task_id = "TASK_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_001"
        capability_id = "remediation_seed_program_materialization_v1"
        status = "ACTIVE"
        objective = "Materialize a normalized remediation seed blueprint into a generated serial self-build program package."
        expected_gate = "REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_READY"
        build_task_path = "tasks/TASK_REMEDIATION_SEED_PROGRAM_MATERIALIZATION_V1_001.json"
    }

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Write-Host "PASS :: remediation_seed_program_blueprint_contract_v1 checks passed. run_id=$RunId"
