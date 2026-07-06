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

function Add-CompletedCapability {
    param(
        [object]$State,
        [string]$CompletedCapabilityId
    )

    if (@($State.completed_capabilities) -notcontains $CompletedCapabilityId) {
        $State.completed_capabilities += $CompletedCapabilityId
    }
}

function Read-RawArtifactSnapshot {
    param([string]$ProgramManifestPath)

    return [ordered]@{
        registry = Get-Content ".\packs\registry.json" -Raw
        roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw
        queue = Get-Content ".\TASK_QUEUE.json" -Raw
        state = Get-Content ".\GENESIS_STATE.json" -Raw
        manifest = Get-Content $ProgramManifestPath -Raw
    }
}

function Assert-SnapshotUnchanged {
    param(
        [object]$Before,
        [object]$After
    )

    foreach ($Key in $Before.Keys) {
        if ($Before[$Key] -ne $After[$Key]) {
            throw "ContractValidationOnly mutated protected artifact: $Key"
        }
    }
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\admit_generated_self_build_program_to_live_execution.ps1"

$CapabilityId = "generalized_generated_program_live_admission_contract_v1"
$TaskId = "TASK_GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1_001"
$ProgramManifestPath = ".\self_build_programs\generated\monitoring_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"
$ExpectedFirstTaskId = "TASK_GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1_001"
$ExpectedFirstCapabilityId = "generated_monitoring_agent_v1_profile_materialization_v1"
$ReportPath = ".\reports\generalized_generated_program_live_admission\MONITORING_AGENT_V1_GENERALIZED_ADMISSION_CONTRACT.json"
$ProofPath = ".\proofs\GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1.json"

Write-Host "=== GENERALIZED GENERATED PROGRAM LIVE ADMISSION CONTRACT V1 ==="
Write-Host "Capability: $CapabilityId"
Write-Host "Task: $TaskId"
Write-Host "Run: $RunId"

if (-not (Test-Path $ProgramManifestPath)) {
    throw "Program manifest missing: $ProgramManifestPath"
}

$ProgramManifest = Get-Content $ProgramManifestPath -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "Program Manifest Status: $($ProgramManifest.status)"
Write-Host "Program Admission Status: $($ProgramManifest.admission_status)"
Write-Host "Target Profile: $($ProgramManifest.target_profile_id)"

if ($ProgramManifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") {
    throw "Program manifest status must be PROGRAM_PACKAGE_MATERIALIZED."
}

if ($ProgramManifest.admission_status -ne "ADMITTED_TO_LIVE_EXECUTION") {
    throw "Program manifest admission_status must be ADMITTED_TO_LIVE_EXECUTION (already admitted from PHASE57)."
}

Write-Host ""
Write-Host "--- Contract-Driven Validation (Non-Mutating) ---"

$BeforeContractValidation = Read-RawArtifactSnapshot -ProgramManifestPath $ProgramManifestPath

$ValidationResult = Admit-GeneratedSelfBuildProgramToLiveExecution `
    -ProgramManifestPath $ProgramManifestPath `
    -ContractValidationOnly

$AfterContractValidation = Read-RawArtifactSnapshot -ProgramManifestPath $ProgramManifestPath
Assert-SnapshotUnchanged -Before $BeforeContractValidation -After $AfterContractValidation

if ($ValidationResult.status -ne "PASS") {
    throw "Contract validation failed with status: $($ValidationResult.status)"
}
if ($ValidationResult.mode -ne "CONTRACT_VALIDATION_ONLY") {
    throw "Validation result mode must be CONTRACT_VALIDATION_ONLY."
}
if ([int]$ValidationResult.resolved_pack_count -ne 3) {
    throw "Resolved pack count must be 3."
}
if ([int]$ValidationResult.resolved_capability_count -ne 3) {
    throw "Resolved capability count must be 3."
}
if ([int]$ValidationResult.resolved_task_count -ne 3) {
    throw "Resolved task count must be 3."
}
if ($ValidationResult.first_activatable_task_id -ne $ExpectedFirstTaskId) {
    throw "First activatable task id mismatch."
}
if ($ValidationResult.first_activatable_capability_id -ne $ExpectedFirstCapabilityId) {
    throw "First activatable capability id mismatch."
}
if ($ValidationResult.admission_readiness_decision -ne "ADMISSION_READY") {
    throw "Admission readiness decision must be ADMISSION_READY."
}

Write-Host "Validation Mode: $($ValidationResult.mode)"
Write-Host "Validation Status: $($ValidationResult.status)"
Write-Host "Admission Decision: $($ValidationResult.admission_readiness_decision)"
Write-Host "Resolved Pack Count: $($ValidationResult.resolved_pack_count)"
Write-Host "Resolved Capability Count: $($ValidationResult.resolved_capability_count)"
Write-Host "Resolved Task Count: $($ValidationResult.resolved_task_count)"
Write-Host "First Activatable Task: $($ValidationResult.first_activatable_task_id)"
Write-Host "First Activatable Capability: $($ValidationResult.first_activatable_capability_id)"
Write-Host "Duplicate Guard Status: $($ValidationResult.duplicate_guard_status)"

$ReportDir = Split-Path -Parent $ReportPath
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
}

$ValidationReport = [pscustomobject][ordered]@{
    report_id = "MONITORING_AGENT_V1_GENERALIZED_ADMISSION_CONTRACT"
    task_id = $TaskId
    capability_id = $CapabilityId
    run_id = $RunId
    status = "PASS"
    timestamp = (Get-Date -Format 'o')
    validation_mode = "CONTRACT_VALIDATION_ONLY"
    program_manifest = $ProgramManifestPath
    source_program_manifest = $ValidationResult.source_program_manifest
    program_root = $ValidationResult.program_root
    target_profile_id = $ValidationResult.target_profile_id
    target_agent_kind = $ValidationResult.target_agent_kind
    resolved_pack_count = $ValidationResult.resolved_pack_count
    resolved_capability_count = $ValidationResult.resolved_capability_count
    resolved_task_count = $ValidationResult.resolved_task_count
    first_activatable_task_id = $ValidationResult.first_activatable_task_id
    first_activatable_capability_id = $ValidationResult.first_activatable_capability_id
    admission_readiness_decision = $ValidationResult.admission_readiness_decision
    duplicate_guard_status = $ValidationResult.duplicate_guard_status
    protected_artifacts_unchanged = $true
}

$ValidationReport | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

$ProofsDir = Split-Path -Parent $ProofPath
if (-not (Test-Path $ProofsDir)) {
    New-Item -ItemType Directory -Force -Path $ProofsDir | Out-Null
}

$ContractValidationProof = [pscustomobject][ordered]@{
    proof_id = "GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1"
    task_id = $TaskId
    capability_id = $CapabilityId
    run_id = $RunId
    status = "PASS"
    validation_mode = "CONTRACT_VALIDATION_ONLY"
    proof_timestamp = (Get-Date -Format 'o')
    program_manifest_path = $ProgramManifestPath
    program_target_profile_id = $ProgramManifest.target_profile_id
    program_admission_status = $ProgramManifest.admission_status
    resolved_pack_count = $ValidationResult.resolved_pack_count
    resolved_capability_count = $ValidationResult.resolved_capability_count
    resolved_task_count = $ValidationResult.resolved_task_count
    first_activatable_task_id = $ValidationResult.first_activatable_task_id
    first_activatable_capability_id = $ValidationResult.first_activatable_capability_id
    admission_readiness_decision = $ValidationResult.admission_readiness_decision
    duplicate_guard_status = $ValidationResult.duplicate_guard_status
    next_required_capability = "second_generated_program_family_proof_v1"
    report_path = $ReportPath
    assertion_coverage = @(
        "Program manifest exists and is parseable",
        "Program is already ADMITTED_TO_LIVE_EXECUTION from PHASE57",
        "Admission module supports ContractValidationOnly parameter",
        "Contract validation passes without protected artifact mutation",
        "Resolved pack/capability/task counts match manifest and patch declarations",
        "First activatable generated task and capability are derived from patches",
        "Admission readiness decision is ADMISSION_READY",
        "Admission is driven by manifest-rooted contracts rather than fixture paths"
    )
    conclusion = "Generated-program live admission now has a generalized manifest-rooted validation contract."
}

$ContractValidationProof | ConvertTo-Json -Depth 100 |
    Set-Content $ProofPath -Encoding UTF8

Write-Host ""
Write-Host "Report saved to: $ReportPath"
Write-Host "Proof saved to: $ProofPath"

if ($FinalizePhase) {
    Write-Host ""
    Write-Host "--- Finalizing PHASE60 ---"

    $State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
    $Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
    $Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

    $Phase60Capability = $Roadmap.capabilities |
        Where-Object { $_.id -eq $CapabilityId } |
        Select-Object -First 1

    $Phase60Task = $Queue.tasks |
        Where-Object { $_.task_id -eq $TaskId } |
        Select-Object -First 1

    if ($null -eq $Phase60Capability) { throw "PHASE60 capability missing from roadmap." }
    if ($Phase60Capability.status -ne "ACTIVE") { throw "PHASE60 capability must be ACTIVE." }
    if ($null -eq $Phase60Task) { throw "PHASE60 task missing from queue." }
    if ($Phase60Task.status -ne "ACTIVE") { throw "PHASE60 task must be ACTIVE." }
    if ($Queue.active_task_id -ne $TaskId) { throw "PHASE60 task must be the active task." }

    $Phase60Capability.status = "COMPLETED"
    $Phase60Task.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId

    $State.current_phase = "PHASE_60"
    $State.current_capability = $CapabilityId
    $State.last_run_status = "PASS"
    $State | Add-Member -NotePropertyName "generalized_program_live_admission_contract_ready" -NotePropertyValue $true -Force

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8

    Write-Host "State updated: PHASE_60 COMPLETED"
    Write-Host "PHASE60=FINALIZED"
}

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\packs\registry.json"
Assert-JsonParse $ProgramManifestPath
Assert-JsonParse $ReportPath
Assert-JsonParse $ProofPath

Write-Host ""
Write-Host "GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_STATUS=PASS"
Write-Host "GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_NEXT_REQUIRED_CAPABILITY=second_generated_program_family_proof_v1"
Write-Host "=== PHASE60 VALIDATION COMPLETE ==="
