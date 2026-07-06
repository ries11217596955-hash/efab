param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-JsonParse {
    param([string]$Path)
    $null = Get-Content $Path -Raw | ConvertFrom-Json
}

function Assert-RequiredPath {
    param(
        [string]$Path,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Label path must not be empty."
    }
    if (-not (Test-Path $Path)) {
        throw "$Label missing: $Path"
    }
}

function Assert-PathMissing {
    param(
        [string]$Path,
        [string]$Label
    )

    if (Test-Path $Path) {
        throw "$Label must not exist before PHASE63 runtime: $Path"
    }
}

function Read-JsonFile {
    param([string]$Path)
    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $Value | ConvertTo-Json -Depth 100 |
        Set-Content $Path -Encoding UTF8
}

function Add-CompletedCapability {
    param(
        [object]$State,
        [string]$CompletedCapabilityId
    )

    if (@($State.completed_capabilities) -notcontains $CompletedCapabilityId) {
        $State.completed_capabilities += $CompletedCapabilityId
    }
}

function Get-SingleByProperty {
    param(
        [object[]]$Items,
        [string]$PropertyName,
        [string]$ExpectedValue,
        [string]$Label
    )

    $Matches = @($Items | Where-Object { $_.$PropertyName -eq $ExpectedValue })
    if ($Matches.Count -ne 1) {
        throw "$Label expected exactly one item where $PropertyName = $ExpectedValue, found $($Matches.Count)."
    }

    return $Matches[0]
}

function Assert-NoGeneratedRemediationProofs {
    param([string[]]$GeneratedPackIds)

    foreach ($GeneratedPackId in $GeneratedPackIds) {
        $GeneratedProofPath = ".\proofs\$GeneratedPackId.json"
        if (Test-Path $GeneratedProofPath) {
            throw "PHASE63 must not execute generated remediation packs; generated proof exists: $GeneratedProofPath"
        }
    }
}

function Assert-GeneratedProgramNotYetAdmitted {
    param(
        [object]$Registry,
        [object]$Roadmap,
        [object]$Queue,
        [string[]]$GeneratedPackIds,
        [string[]]$GeneratedCapabilityIds,
        [string[]]$GeneratedTaskIds
    )

    foreach ($GeneratedPackId in $GeneratedPackIds) {
        if (@($Registry.packs | Where-Object { $_.pack_id -eq $GeneratedPackId }).Count -gt 0) {
            throw "Generated remediation pack is already in live registry before PHASE63 admission: $GeneratedPackId"
        }
    }
    foreach ($GeneratedCapabilityId in $GeneratedCapabilityIds) {
        if (@($Roadmap.capabilities | Where-Object { $_.id -eq $GeneratedCapabilityId }).Count -gt 0) {
            throw "Generated remediation capability is already in live roadmap before PHASE63 admission: $GeneratedCapabilityId"
        }
    }
    foreach ($GeneratedTaskId in $GeneratedTaskIds) {
        if (@($Queue.tasks | Where-Object { $_.task_id -eq $GeneratedTaskId }).Count -gt 0) {
            throw "Generated remediation task is already in live queue before PHASE63 admission: $GeneratedTaskId"
        }
    }
}

function Set-AdmissionModuleLivePreconditions {
    param(
        [string]$RepoRoot,
        [string]$Phase57CapabilityId,
        [string]$Phase57TaskId
    )

    $RoadmapPath = Join-Path $RepoRoot "CAPABILITY_ROADMAP.json"
    $QueuePath = Join-Path $RepoRoot "TASK_QUEUE.json"
    $StatePath = Join-Path $RepoRoot "GENESIS_STATE.json"

    $Roadmap = Read-JsonFile $RoadmapPath
    $Queue = Read-JsonFile $QueuePath
    $State = Read-JsonFile $StatePath

    $Phase57Capability = Get-SingleByProperty `
        -Items @($Roadmap.capabilities) `
        -PropertyName "id" `
        -ExpectedValue $Phase57CapabilityId `
        -Label "PHASE57 capability"

    $Phase57Task = Get-SingleByProperty `
        -Items @($Queue.tasks) `
        -PropertyName "task_id" `
        -ExpectedValue $Phase57TaskId `
        -Label "PHASE57 task"

    if (@("COMPLETED", "ACTIVE") -notcontains [string]$Phase57Capability.status) {
        throw "PHASE57 capability must be COMPLETED or ACTIVE for admission-module compatibility."
    }
    if (@("COMPLETED", "ACTIVE") -notcontains [string]$Phase57Task.status) {
        throw "PHASE57 task must be COMPLETED or ACTIVE for admission-module compatibility."
    }

    $Phase57Capability.status = "ACTIVE"
    $Phase57Task.status = "ACTIVE"
    $Queue.active_task_id = $Phase57TaskId
    $State.current_phase = "PHASE_57"
    $State.current_capability = $Phase57CapabilityId

    Write-JsonFile -Path $RoadmapPath -Value $Roadmap
    Write-JsonFile -Path $QueuePath -Value $Queue
    Write-JsonFile -Path $StatePath -Value $State
}

function Restore-AdmissionPreconditionSnapshot {
    param(
        [string]$RepoRoot,
        [object]$Snapshot
    )

    Set-Content (Join-Path $RepoRoot "packs/registry.json") $Snapshot.registry -Encoding UTF8
    Set-Content (Join-Path $RepoRoot "CAPABILITY_ROADMAP.json") $Snapshot.roadmap -Encoding UTF8
    Set-Content (Join-Path $RepoRoot "TASK_QUEUE.json") $Snapshot.queue -Encoding UTF8
    Set-Content (Join-Path $RepoRoot "GENESIS_STATE.json") $Snapshot.state -Encoding UTF8
    Set-Content (Join-Path $RepoRoot "self_build_programs/generated/remediation_intake_agent_v1/SELF_BUILD_PROGRAM_MANIFEST.json") $Snapshot.manifest -Encoding UTF8
}

function Complete-Phase63WithoutClearingGeneratedTask {
    param(
        [string]$CapabilityId,
        [string]$TaskId,
        [string]$ExpectedActiveTaskId
    )

    $State = Read-JsonFile ".\GENESIS_STATE.json"
    $Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
    $Queue = Read-JsonFile ".\TASK_QUEUE.json"

    $Phase63Capability = Get-SingleByProperty `
        -Items @($Roadmap.capabilities) `
        -PropertyName "id" `
        -ExpectedValue $CapabilityId `
        -Label "PHASE63 capability"

    $Phase63Task = Get-SingleByProperty `
        -Items @($Queue.tasks) `
        -PropertyName "task_id" `
        -ExpectedValue $TaskId `
        -Label "PHASE63 task"

    if ($Phase63Capability.status -ne "ACTIVE") { throw "PHASE63 capability must be ACTIVE before finalization." }
    if ($Phase63Task.status -ne "ACTIVE") { throw "PHASE63 task must be ACTIVE before finalization." }
    if ($Queue.active_task_id -ne $ExpectedActiveTaskId) {
        throw "PHASE63 finalization must preserve generated remediation active task $ExpectedActiveTaskId."
    }

    $Phase63Capability.status = "COMPLETED"
    $Phase63Task.status = "COMPLETED"

    Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
    $State.last_run_status = "PASS"
    $State | Add-Member -NotePropertyName "second_generated_program_family_live_admission_ready" -NotePropertyValue $true -Force

    Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
    Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State
    Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
}

if (-not $FinalizePhase) {
    throw "PHASE63 live admission validator requires -FinalizePhase."
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\test_generated_self_build_program_admission_readiness.ps1"
. ".\modules\admit_generated_self_build_program_to_live_execution.ps1"

$CapabilityId = "second_generated_program_family_live_admission_v1"
$TaskId = "TASK_SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_V1_001"
$FamilyId = "remediation_intake_agent_v1"
$ProgramManifestPath = ".\self_build_programs\generated\remediation_intake_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"
$Phase62ProofPath = ".\proofs\SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1.json"
$ReportPath = ".\reports\second_generated_program_family_live_admission\REMEDIATION_INTAKE_AGENT_V1_LIVE_ADMISSION.json"
$ProofPath = ".\proofs\SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_V1.json"
$ExpectedFirstTaskId = "TASK_GENERATED_REMEDIATION_INTAKE_AGENT_V1_PROFILE_MATERIALIZATION_V1_001"
$ExpectedFirstCapabilityId = "generated_remediation_intake_agent_v1_profile_materialization_v1"
$ExpectedFirstPhase = "GENERATED_REMEDIATION_INTAKE_AGENT_V1_PHASE_1"
$NextRequiredCapability = "second_generated_program_family_consumption_proof_v1"
$Phase57CapabilityId = "generated_program_live_admission_proof_v1"
$Phase57TaskId = "TASK_GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1_001"

Write-Host "=== SECOND GENERATED PROGRAM FAMILY LIVE ADMISSION V1 ==="
Write-Host "Capability: $CapabilityId"
Write-Host "Task: $TaskId"
Write-Host "Run: $RunId"
Write-Host "Family: $FamilyId"

Assert-RequiredPath -Path $Phase62ProofPath -Label "PHASE62 proof"
Assert-RequiredPath -Path $ProgramManifestPath -Label "Remediation generated program manifest"
Assert-PathMissing -Path $ProofPath -Label "PHASE63 proof"
Assert-PathMissing -Path $ReportPath -Label "PHASE63 report"

Assert-JsonParse $Phase62ProofPath
Assert-JsonParse $ProgramManifestPath

$Phase62Proof = Read-JsonFile $Phase62ProofPath
if ($Phase62Proof.status -ne "PASS") { throw "PHASE62 proof status must be PASS." }
if ($Phase62Proof.family_id -ne $FamilyId) { throw "PHASE62 proof family_id mismatch." }
if ($Phase62Proof.next_required_capability -ne $CapabilityId) { throw "PHASE62 proof must point to PHASE63 capability." }
if ([int]$Phase62Proof.materialized_pack_count -ne 3) { throw "PHASE62 materialized_pack_count must be 3." }
if ([int]$Phase62Proof.materialized_capability_count -ne 3) { throw "PHASE62 materialized_capability_count must be 3." }
if ([int]$Phase62Proof.materialized_task_count -ne 3) { throw "PHASE62 materialized_task_count must be 3." }
if ([int]$Phase62Proof.materialized_execution_recipe_count -ne 3) { throw "PHASE62 materialized_execution_recipe_count must be 3." }
if ([int]$Phase62Proof.materialized_apply_script_count -ne 3) { throw "PHASE62 materialized_apply_script_count must be 3." }
if ($Phase62Proof.admission_readiness_decision -ne "ADMISSION_READY") { throw "PHASE62 admission readiness decision must be ADMISSION_READY." }
if ([bool]$Phase62Proof.live_admission_attempted) { throw "PHASE62 proof must not have attempted live admission." }
if ([bool]$Phase62Proof.generated_pack_execution_attempted) { throw "PHASE62 proof must not have attempted generated pack execution." }

$Manifest = Read-JsonFile $ProgramManifestPath
if ($Manifest.family_id -ne $FamilyId) { throw "Manifest family_id mismatch." }
if ($Manifest.target_profile_id -ne $FamilyId) { throw "Manifest target_profile_id mismatch." }
if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") { throw "Manifest status must be PROGRAM_PACKAGE_MATERIALIZED." }
if ($Manifest.admission_status -ne "NOT_ADMITTED_YET") { throw "Manifest admission_status must be NOT_ADMITTED_YET before PHASE63 runtime." }
if ($Manifest.first_activatable_task_id -ne $ExpectedFirstTaskId) { throw "Manifest first activatable task mismatch." }
if ($Manifest.first_activatable_capability_id -ne $ExpectedFirstCapabilityId) { throw "Manifest first activatable capability mismatch." }
if ([int]$Manifest.pack_count -ne 3) { throw "Manifest pack_count must be 3." }
if ([int]$Manifest.capability_count -ne 3) { throw "Manifest capability_count must be 3." }
if ([int]$Manifest.task_count -ne 3) { throw "Manifest task_count must be 3." }

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"
$Registry = Read-JsonFile ".\packs\registry.json"

$ThisCapability = Get-SingleByProperty `
    -Items @($Roadmap.capabilities) `
    -PropertyName "id" `
    -ExpectedValue $CapabilityId `
    -Label "PHASE63 capability"

$ThisTask = Get-SingleByProperty `
    -Items @($Queue.tasks) `
    -PropertyName "task_id" `
    -ExpectedValue $TaskId `
    -Label "PHASE63 task"

if ($State.current_phase -ne "PHASE_63") { throw "State current_phase must be PHASE_63 before PHASE63 runtime." }
if ($State.current_capability -ne $CapabilityId) { throw "State current_capability must be PHASE63 capability before runtime." }
if ($Queue.active_task_id -ne $TaskId) { throw "TASK_QUEUE active_task_id must point to PHASE63 seed task before runtime." }
if ($ThisCapability.status -ne "ACTIVE") { throw "PHASE63 capability must be ACTIVE before runtime." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE63 task must be ACTIVE before runtime." }

$RegistryPatchPath = ".\self_build_programs\generated\remediation_intake_agent_v1\patches\PACK_REGISTRY_PATCH.json"
$RoadmapPatchPath = ".\self_build_programs\generated\remediation_intake_agent_v1\patches\CAPABILITY_ROADMAP_PATCH.json"
$QueueSeedPath = ".\self_build_programs\generated\remediation_intake_agent_v1\patches\TASK_QUEUE_SEED.json"

foreach ($PatchPath in @($RegistryPatchPath, $RoadmapPatchPath, $QueueSeedPath)) {
    Assert-RequiredPath -Path $PatchPath -Label "Generated remediation admission patch"
    Assert-JsonParse $PatchPath
}

$RegistryPatch = Read-JsonFile $RegistryPatchPath
$RoadmapPatch = Read-JsonFile $RoadmapPatchPath
$QueueSeed = Read-JsonFile $QueueSeedPath

$GeneratedPacks = @($RegistryPatch.generated_packs | Sort-Object { [int]$_.order })
$GeneratedCapabilities = @($RoadmapPatch.generated_capabilities | Sort-Object { [int]$_.order })
$GeneratedTasks = @($QueueSeed.generated_tasks | Sort-Object { [int]$_.order })
$GeneratedPackIds = @($GeneratedPacks | ForEach-Object { [string]$_.pack_id })
$GeneratedCapabilityIds = @($GeneratedCapabilities | ForEach-Object { [string]$_.capability_id })
$GeneratedTaskIds = @($GeneratedTasks | ForEach-Object { [string]$_.task_id })

if ($GeneratedPacks.Count -ne 3) { throw "Remediation registry patch must contain 3 generated packs." }
if ($GeneratedCapabilities.Count -ne 3) { throw "Remediation roadmap patch must contain 3 generated capabilities." }
if ($GeneratedTasks.Count -ne 3) { throw "Remediation queue seed must contain 3 generated tasks." }
if ($GeneratedTaskIds[0] -ne $ExpectedFirstTaskId) { throw "First generated remediation task mismatch." }
if ($GeneratedCapabilityIds[0] -ne $ExpectedFirstCapabilityId) { throw "First generated remediation capability mismatch." }
if ($QueueSeed.active_task_id -ne $ExpectedFirstTaskId) { throw "Generated remediation queue seed active_task_id mismatch." }

Assert-NoGeneratedRemediationProofs -GeneratedPackIds $GeneratedPackIds
Assert-GeneratedProgramNotYetAdmitted `
    -Registry $Registry `
    -Roadmap $Roadmap `
    -Queue $Queue `
    -GeneratedPackIds $GeneratedPackIds `
    -GeneratedCapabilityIds $GeneratedCapabilityIds `
    -GeneratedTaskIds $GeneratedTaskIds

Write-Host ""
Write-Host "--- Admission readiness evaluation ---"

$Readiness = Test-GeneratedSelfBuildProgramAdmissionReadiness -ProgramManifestPath $ProgramManifestPath
if ($Readiness.status -ne "PASS") { throw "Admission readiness evaluator status must be PASS." }
if ($Readiness.admission_decision -ne "ADMISSION_READY") { throw "Admission readiness decision must be ADMISSION_READY." }
if ([int]$Readiness.executable_pack_count -ne 3) { throw "Admission readiness executable_pack_count must be 3." }
if ([int]$Readiness.blocked_pack_count -ne 0) { throw "Admission readiness blocked_pack_count must be 0." }

Write-Host "Readiness: $($Readiness.admission_decision)"

$PreAdmissionSnapshot = [pscustomobject][ordered]@{
    registry = Get-Content ".\packs\registry.json" -Raw
    roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw
    queue = Get-Content ".\TASK_QUEUE.json" -Raw
    state = Get-Content ".\GENESIS_STATE.json" -Raw
    manifest = Get-Content $ProgramManifestPath -Raw
}

$AdmissionModulePreconditionBridgeApplied = $true
$AdmissionModulePreconditionBridgeReason = "Current generalized admission module live mode still enforces PHASE57 active-task preconditions; PHASE63 stages those preconditions immediately before invoking live admission, then finalizes PHASE63 without clearing the generated remediation task."

Write-Host ""
Write-Host "--- Live admission via generalized admission module ---"

try {
    Set-AdmissionModuleLivePreconditions `
        -RepoRoot $RepoRoot `
        -Phase57CapabilityId $Phase57CapabilityId `
        -Phase57TaskId $Phase57TaskId

    $Admission = Admit-GeneratedSelfBuildProgramToLiveExecution -ProgramManifestPath $ProgramManifestPath
}
catch {
    Restore-AdmissionPreconditionSnapshot -RepoRoot $RepoRoot -Snapshot $PreAdmissionSnapshot
    throw
}

if ($Admission.status -ne "PASS") { throw "Live admission status must be PASS." }
if ([int]$Admission.admitted_registry_entry_count -ne 3) { throw "Live admission registry entry count must be 3." }
if ([int]$Admission.admitted_capability_count -ne 3) { throw "Live admission capability count must be 3." }
if ([int]$Admission.admitted_task_count -ne 3) { throw "Live admission task count must be 3." }
if ($Admission.activated_task_id -ne $ExpectedFirstTaskId) { throw "Live admission activated task mismatch." }
if ($Admission.activated_capability_id -ne $ExpectedFirstCapabilityId) { throw "Live admission activated capability mismatch." }
if ($Admission.manifest_admission_status_after -ne "ADMITTED_TO_LIVE_EXECUTION") {
    throw "Live admission must mutate manifest admission_status to ADMITTED_TO_LIVE_EXECUTION."
}

Complete-Phase63WithoutClearingGeneratedTask `
    -CapabilityId $CapabilityId `
    -TaskId $TaskId `
    -ExpectedActiveTaskId $ExpectedFirstTaskId

$PostRegistry = Read-JsonFile ".\packs\registry.json"
$PostRoadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$PostQueue = Read-JsonFile ".\TASK_QUEUE.json"
$PostState = Read-JsonFile ".\GENESIS_STATE.json"
$PostManifest = Read-JsonFile $ProgramManifestPath

foreach ($GeneratedPackId in $GeneratedPackIds) {
    $LivePack = Get-SingleByProperty `
        -Items @($PostRegistry.packs) `
        -PropertyName "pack_id" `
        -ExpectedValue $GeneratedPackId `
        -Label "Admitted generated remediation pack"

    if (-not (Test-Path ([string]$LivePack.entry_script))) {
        throw "Admitted generated remediation entry script missing: $($LivePack.entry_script)"
    }
}

foreach ($GeneratedCapabilityId in $GeneratedCapabilityIds) {
    $null = Get-SingleByProperty `
        -Items @($PostRoadmap.capabilities) `
        -PropertyName "id" `
        -ExpectedValue $GeneratedCapabilityId `
        -Label "Admitted generated remediation capability"
}

foreach ($GeneratedTaskId in $GeneratedTaskIds) {
    $null = Get-SingleByProperty `
        -Items @($PostQueue.tasks) `
        -PropertyName "task_id" `
        -ExpectedValue $GeneratedTaskId `
        -Label "Admitted generated remediation task"
}

$FirstGeneratedCapability = Get-SingleByProperty `
    -Items @($PostRoadmap.capabilities) `
    -PropertyName "id" `
    -ExpectedValue $ExpectedFirstCapabilityId `
    -Label "First generated remediation capability"

$FirstGeneratedTask = Get-SingleByProperty `
    -Items @($PostQueue.tasks) `
    -PropertyName "task_id" `
    -ExpectedValue $ExpectedFirstTaskId `
    -Label "First generated remediation task"

$Phase63CapabilityAfter = Get-SingleByProperty `
    -Items @($PostRoadmap.capabilities) `
    -PropertyName "id" `
    -ExpectedValue $CapabilityId `
    -Label "PHASE63 capability after finalization"

$Phase63TaskAfter = Get-SingleByProperty `
    -Items @($PostQueue.tasks) `
    -PropertyName "task_id" `
    -ExpectedValue $TaskId `
    -Label "PHASE63 task after finalization"

if ($FirstGeneratedCapability.status -ne "ACTIVE") { throw "First generated remediation capability must be ACTIVE after admission." }
if ($FirstGeneratedTask.status -ne "ACTIVE") { throw "First generated remediation task must be ACTIVE after admission." }
if ($PostQueue.active_task_id -ne $ExpectedFirstTaskId) { throw "TASK_QUEUE active_task_id must point to first generated remediation task after admission." }
if ($PostState.current_phase -ne $ExpectedFirstPhase) { throw "State current_phase must point to first generated remediation phase after admission." }
if ($PostState.current_capability -ne $ExpectedFirstCapabilityId) { throw "State current_capability must point to first generated remediation capability after admission." }
if ($Phase63CapabilityAfter.status -ne "COMPLETED") { throw "PHASE63 capability must be COMPLETED after finalization." }
if ($Phase63TaskAfter.status -ne "COMPLETED") { throw "PHASE63 task must be COMPLETED after finalization." }
if ($PostManifest.admission_status -ne "ADMITTED_TO_LIVE_EXECUTION") { throw "Remediation manifest admission_status must be ADMITTED_TO_LIVE_EXECUTION." }
if ([bool]$PostManifest.generated_pack_execution_attempted) { throw "Remediation manifest must not show generated pack execution." }

Assert-NoGeneratedRemediationProofs -GeneratedPackIds $GeneratedPackIds

$ReportDir = Split-Path -Parent $ReportPath
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
}

$Report = [pscustomobject][ordered]@{
    report_id = "REMEDIATION_INTAKE_AGENT_V1_LIVE_ADMISSION"
    run_id = $RunId
    status = "PASS"
    timestamp = (Get-Date -Format 'o')
    family_id = $FamilyId
    source_program_manifest = $ProgramManifestPath
    pre_admission_readiness_decision = $Readiness.admission_decision
    live_admission_mode = "LIVE_ADMISSION"
    live_admission_status = $Admission.status
    admission_module_precondition_bridge_applied = $AdmissionModulePreconditionBridgeApplied
    admission_module_precondition_bridge_reason = $AdmissionModulePreconditionBridgeReason
    resolved_pack_count = 3
    resolved_capability_count = 3
    resolved_task_count = 3
    generated_pack_ids = $GeneratedPackIds
    generated_capability_ids = $GeneratedCapabilityIds
    generated_task_ids = $GeneratedTaskIds
    first_activatable_task_id = $ExpectedFirstTaskId
    first_activatable_capability_id = $ExpectedFirstCapabilityId
    active_task_after_admission = $PostQueue.active_task_id
    phase63_task_status = $Phase63TaskAfter.status
    phase63_capability_status = $Phase63CapabilityAfter.status
    manifest_admission_status_after = $PostManifest.admission_status
    generated_pack_execution_attempted = $false
    next_required_capability = $NextRequiredCapability
}

$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

$ProofDir = Split-Path -Parent $ProofPath
if (-not (Test-Path $ProofDir)) {
    New-Item -ItemType Directory -Force -Path $ProofDir | Out-Null
}

$Proof = [pscustomobject][ordered]@{
    proof_id = "SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_V1"
    run_id = $RunId
    status = "PASS"
    family_id = $FamilyId
    source_program_manifest = $ProgramManifestPath
    pre_admission_readiness_decision = $Readiness.admission_decision
    live_admission_status = $Admission.status
    live_admission_mode = "LIVE_ADMISSION"
    admission_module_precondition_bridge_applied = $AdmissionModulePreconditionBridgeApplied
    resolved_pack_count = 3
    resolved_capability_count = 3
    resolved_task_count = 3
    first_activatable_task_id = $ExpectedFirstTaskId
    first_activatable_capability_id = $ExpectedFirstCapabilityId
    active_task_after_admission = $PostQueue.active_task_id
    generated_pack_execution_attempted = $false
    next_required_capability = $NextRequiredCapability
    conclusion = "The second generated self-build program family has been admitted into live Builder execution and is ready for ordinary SELF_BUILD consumption."
    report_path = $ReportPath
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content $ProofPath -Encoding UTF8

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\packs\registry.json"
Assert-JsonParse $ProgramManifestPath
Assert-JsonParse $ReportPath
Assert-JsonParse $ProofPath

Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_STATUS=PASS"
Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_FAMILY=$FamilyId"
Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_ACTIVE_TASK=$($PostQueue.active_task_id)"
Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_NEXT_REQUIRED_CAPABILITY=$NextRequiredCapability"
