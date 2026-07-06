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

if (-not $FinalizePhase) {
    throw "PHASE57 live admission validator requires -FinalizePhase."
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\admit_generated_self_build_program_to_live_execution.ps1"
. ".\modules\read_pack_registry.ps1"

$ProgramManifestPath = ".\self_build_programs\generated\monitoring_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"
$ExpectedActivatedTaskId = "TASK_GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1_001"
$ExpectedActivatedCapabilityId = "generated_monitoring_agent_v1_profile_materialization_v1"
$ExpectedSelectedPackId = "GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1"

$GeneratedProofPaths = @(
    ".\proofs\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1.json",
    ".\proofs\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1.json",
    ".\proofs\GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1.json"
)

foreach ($GeneratedProofPath in $GeneratedProofPaths) {
    if (Test-Path $GeneratedProofPath) {
        throw "PHASE57 must not execute generated packs; generated proof already exists: $GeneratedProofPath"
    }
}

$Admission = Admit-GeneratedSelfBuildProgramToLiveExecution -ProgramManifestPath $ProgramManifestPath

if ($Admission.status -ne "PASS") {
    throw "Generated program live admission status must be PASS."
}
if ([int]$Admission.admitted_registry_entry_count -ne 3) {
    throw "Admitted registry entry count must be 3."
}
if ([int]$Admission.admitted_capability_count -ne 3) {
    throw "Admitted capability count must be 3."
}
if ([int]$Admission.admitted_task_count -ne 3) {
    throw "Admitted task count must be 3."
}
if ($Admission.activated_task_id -ne $ExpectedActivatedTaskId) {
    throw "Activated generated task mismatch."
}
if ($Admission.activated_capability_id -ne $ExpectedActivatedCapabilityId) {
    throw "Activated generated capability mismatch."
}
if ($Admission.manifest_admission_status_after -ne "ADMITTED_TO_LIVE_EXECUTION") {
    throw "Manifest admission status after live admission mismatch."
}

$Manifest = Get-Content $ProgramManifestPath -Raw | ConvertFrom-Json
if ($Manifest.admission_status -ne "ADMITTED_TO_LIVE_EXECUTION") {
    throw "Generated program manifest must be ADMITTED_TO_LIVE_EXECUTION."
}

$Registry = Read-SelfBuildPackRegistry -RepoRoot $RepoRoot
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json

$FirstRegistryEntry = $Registry.packs |
    Where-Object { $_.pack_id -eq $ExpectedSelectedPackId } |
    Select-Object -First 1

if ($null -eq $FirstRegistryEntry) {
    throw "Live registry missing first generated pack entry."
}
if ($FirstRegistryEntry.task_id -ne $ExpectedActivatedTaskId) {
    throw "First generated pack task id mismatch in live registry."
}
if ($Queue.active_task_id -ne $ExpectedActivatedTaskId) {
    throw "TASK_QUEUE active_task_id must point to first generated task."
}

$SelectedPack = $Registry.packs |
    Where-Object { $_.task_id -eq $Queue.active_task_id } |
    Select-Object -First 1

if ($null -eq $SelectedPack) {
    throw "Normal self-build selection did not resolve a pack for active generated task."
}
if ($SelectedPack.pack_id -ne $ExpectedSelectedPackId) {
    throw "Normal self-build selection resolved unexpected pack: $($SelectedPack.pack_id)"
}

$SelectedEntryScript = [string]$SelectedPack.entry_script
if (-not (Test-Path $SelectedEntryScript)) {
    throw "Selected generated entry_script missing: $SelectedEntryScript"
}

$GeneratedCapabilityStatuses = @{}
foreach ($Capability in @($Admission.admitted_capabilities)) {
    $LiveCapability = $Roadmap.capabilities |
        Where-Object { $_.id -eq $Capability.id } |
        Select-Object -First 1
    if ($null -eq $LiveCapability) {
        throw "Admitted generated capability missing from live roadmap: $($Capability.id)"
    }
    $GeneratedCapabilityStatuses[$Capability.id] = $LiveCapability.status
}

$GeneratedTaskStatuses = @{}
foreach ($Task in @($Admission.admitted_tasks)) {
    $LiveTask = $Queue.tasks |
        Where-Object { $_.task_id -eq $Task.task_id } |
        Select-Object -First 1
    if ($null -eq $LiveTask) {
        throw "Admitted generated task missing from live queue: $($Task.task_id)"
    }
    $GeneratedTaskStatuses[$Task.task_id] = $LiveTask.status
}

if ($GeneratedCapabilityStatuses[$ExpectedActivatedCapabilityId] -ne "ACTIVE") {
    throw "First generated capability must be ACTIVE."
}
if ($GeneratedTaskStatuses[$ExpectedActivatedTaskId] -ne "ACTIVE") {
    throw "First generated task must be ACTIVE."
}
if ($State.current_phase -ne "GENERATED_MONITORING_AGENT_V1_PHASE_1") {
    throw "State current_phase must point to first generated phase."
}
if ($State.current_capability -ne $ExpectedActivatedCapabilityId) {
    throw "State current_capability must point to first generated capability."
}

foreach ($GeneratedProofPath in $GeneratedProofPaths) {
    if (Test-Path $GeneratedProofPath) {
        throw "PHASE57 executed a generated pack unexpectedly: $GeneratedProofPath"
    }
}

$ReportRoot = ".\reports\generated_program_live_admission"
New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
$ReportPath = Join-Path $ReportRoot "MONITORING_AGENT_V1_LIVE_ADMISSION.json"

$Report = [ordered]@{
    report_id = "MONITORING_AGENT_V1_LIVE_ADMISSION"
    run_id = $RunId
    status = "PASS"
    admitted_program_manifest = $Admission.admitted_program_manifest
    admitted_registry_entry_count = $Admission.admitted_registry_entry_count
    admitted_capability_count = $Admission.admitted_capability_count
    admitted_task_count = $Admission.admitted_task_count
    activated_task_id = $Admission.activated_task_id
    activated_capability_id = $Admission.activated_capability_id
    manifest_admission_status_after = $Admission.manifest_admission_status_after
    selected_live_pack_id = $SelectedPack.pack_id
    selected_live_entry_script = $SelectedEntryScript
    selected_live_entry_script_exists = (Test-Path $SelectedEntryScript)
    generated_pack_execution_performed = $false
    generated_capability_statuses = $GeneratedCapabilityStatuses
    generated_task_statuses = $GeneratedTaskStatuses
}

$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

$Proof = [ordered]@{
    proof_id = "GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    admitted_program_manifest = $Admission.admitted_program_manifest
    admitted_registry_entry_count = 3
    admitted_capability_count = 3
    admitted_task_count = 3
    activated_task_id = $Admission.activated_task_id
    activated_capability_id = $Admission.activated_capability_id
    selected_live_pack_id = $SelectedPack.pack_id
    selected_live_entry_script = $SelectedEntryScript
    next_runtime_step = "Run normal SELF_BUILD with MaxPacks = 3 to consume the admitted generated program."
    conclusion = "Builder can now admit an executable generated self-build program into the live execution contour, leaving it ready for ordinary serial self-build consumption."
    report_path = $ReportPath
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1.json" -Encoding UTF8

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\packs\registry.json"
Assert-JsonParse $ProgramManifestPath
Assert-JsonParse $ReportPath
Assert-JsonParse ".\proofs\GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1.json"

Write-Host "GENERATED_PROGRAM_LIVE_ADMISSION_STATUS=PASS"
Write-Host "GENERATED_PROGRAM_LIVE_ADMITTED_PACK_COUNT=$($Admission.admitted_registry_entry_count)"
Write-Host "GENERATED_PROGRAM_LIVE_ADMITTED_CAPABILITY_COUNT=$($Admission.admitted_capability_count)"
Write-Host "GENERATED_PROGRAM_LIVE_ADMITTED_TASK_COUNT=$($Admission.admitted_task_count)"
Write-Host "GENERATED_PROGRAM_LIVE_ACTIVE_TASK=$($Queue.active_task_id)"
Write-Host "GENERATED_PROGRAM_LIVE_SELECTED_PACK=$($SelectedPack.pack_id)"
Write-Host "PASS :: generated_program_live_admission_proof_v1 checks passed. run_id=$RunId"
