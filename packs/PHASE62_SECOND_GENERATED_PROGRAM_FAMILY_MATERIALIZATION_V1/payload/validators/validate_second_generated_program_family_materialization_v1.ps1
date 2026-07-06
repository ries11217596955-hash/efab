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

function Assert-PowerShellParse {
    param([string]$Path)

    $Tokens = $null
    $Errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $Path).Path,
        [ref]$Tokens,
        [ref]$Errors
    )

    if (@($Errors).Count -gt 0) {
        $Joined = (@($Errors) | ForEach-Object { $_.ToString() }) -join "`n"
        throw "PowerShell parser errors in ${Path}:`n$Joined"
    }
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

function Add-CompletedCapability {
    param(
        [object]$State,
        [string]$CompletedCapabilityId
    )

    if (@($State.completed_capabilities) -notcontains $CompletedCapabilityId) {
        $State.completed_capabilities += $CompletedCapabilityId
    }
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\materialize_generated_self_build_program_from_family_contract.ps1"
. ".\modules\render_generated_self_build_pack_apply_from_recipe.ps1"
. ".\modules\complete_generated_self_build_program_executable_packs.ps1"
. ".\modules\test_generated_self_build_program_admission_readiness.ps1"

$CapabilityId = "second_generated_program_family_materialization_v1"
$TaskId = "TASK_SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1_001"
$FamilyId = "remediation_intake_agent_v1"
$SourceContractPath = ".\specs\second_generated_program_family\remediation_intake_agent_v1\REMEDIATION_INTAKE_AGENT_V1_GENERATED_PROGRAM_FAMILY_CONTRACT.json"
$ProgramRoot = ".\self_build_programs\generated\remediation_intake_agent_v1"
$ManifestPath = ".\self_build_programs\generated\remediation_intake_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"
$ReportPath = ".\reports\second_generated_program_family_materialization\REMEDIATION_INTAKE_AGENT_V1_MATERIALIZATION.json"
$ProofPath = ".\proofs\SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1.json"
$NextRequiredCapability = "second_generated_program_family_live_admission_v1"

Write-Host "=== SECOND GENERATED PROGRAM FAMILY MATERIALIZATION V1 ==="
Write-Host "Capability: $CapabilityId"
Write-Host "Task: $TaskId"
Write-Host "Run: $RunId"
Write-Host "Family: $FamilyId"

Assert-RequiredPath -Path $SourceContractPath -Label "Second family source contract"
Assert-JsonParse $SourceContractPath

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
$Registry = Get-Content ".\packs\registry.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq $CapabilityId } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq $TaskId } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_62") { throw "Expected state current_phase PHASE_62 before PHASE62 runtime." }
if ($State.current_capability -ne $CapabilityId) { throw "Expected state current_capability $CapabilityId before PHASE62 runtime." }
if ($Queue.active_task_id -ne $TaskId) { throw "Expected active_task_id $TaskId before PHASE62 runtime." }
if ($null -eq $ThisCap) { throw "PHASE62 capability missing from roadmap." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE62 capability must be ACTIVE before runtime." }
if ($null -eq $ThisTask) { throw "PHASE62 task missing from queue." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE62 task must be ACTIVE before runtime." }
if (-not $State.second_generated_program_family_ready) { throw "Second generated program family proof readiness must already be true." }

$PriorProofPath = ".\proofs\SECOND_GENERATED_PROGRAM_FAMILY_PROOF_V1.json"
Assert-RequiredPath -Path $PriorProofPath -Label "PHASE61 proof"
$PriorProof = Get-Content $PriorProofPath -Raw | ConvertFrom-Json
if ($PriorProof.status -ne "PASS") { throw "PHASE61 proof status must be PASS." }
if ($PriorProof.family_id -ne $FamilyId) { throw "PHASE61 proof family_id mismatch." }
if ($PriorProof.next_required_capability -ne $CapabilityId) { throw "PHASE61 proof does not point to $CapabilityId." }

if (Test-Path $ProgramRoot) {
    throw "PHASE62 runtime must begin before remediation_intake_agent_v1 program materialization exists."
}

$Contract = Get-Content $SourceContractPath -Raw | ConvertFrom-Json
if ($Contract.family_id -ne $FamilyId) { throw "Second family contract family_id mismatch." }
if ($Contract.profile_id -ne $FamilyId) { throw "Second family contract profile_id mismatch." }
if ([int]$Contract.generated_program_shape.expected_pack_count -ne 3) { throw "Contract expected_pack_count must be 3." }
if ([int]$Contract.generated_program_shape.expected_capability_count -ne 3) { throw "Contract expected_capability_count must be 3." }
if ([int]$Contract.generated_program_shape.expected_task_count -ne 3) { throw "Contract expected_task_count must be 3." }

Write-Host ""
Write-Host "--- Materializing second generated program family ---"

$Materialization = Materialize-GeneratedSelfBuildProgramFromFamilyContract -FamilyContractPath $SourceContractPath
if ($Materialization.status -ne "PASS") { throw "Family contract materialization failed." }

Write-Host "Materialized Program Root: $($Materialization.materialized_program_root)"
Write-Host "Manifest: $($Materialization.manifest_path)"

Write-Host ""
Write-Host "--- Rendering executable generated packs from recipes ---"

$ExecutableCompletion = Complete-GeneratedSelfBuildProgramExecutablePacks -ProgramManifestPath $ManifestPath
if ($ExecutableCompletion.status -ne "PASS") { throw "Executable generated pack completion failed." }
if ([int]$ExecutableCompletion.materialized_apply_script_count -ne 3) {
    throw "Expected exactly 3 generated APPLY scripts after recipe-driven executable completion."
}

Assert-RequiredPath -Path $ProgramRoot -Label "Second family program root"
Assert-RequiredPath -Path $ManifestPath -Label "Second family program manifest"
Assert-JsonParse $ManifestPath

$Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
if ($Manifest.family_id -ne $FamilyId) { throw "Manifest family_id mismatch." }
if ($Manifest.target_profile_id -ne $FamilyId) { throw "Manifest target_profile_id mismatch." }
if ($Manifest.target_agent_kind -ne $Contract.target_agent_kind) { throw "Manifest target_agent_kind mismatch." }
if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") { throw "Manifest status must be PROGRAM_PACKAGE_MATERIALIZED." }
if ($Manifest.admission_status -ne "NOT_ADMITTED_YET") { throw "Manifest admission_status must remain NOT_ADMITTED_YET." }
if ([int]$Manifest.pack_count -ne 3) { throw "Manifest pack_count must be 3." }
if ([int]$Manifest.capability_count -ne 3) { throw "Manifest capability_count must be 3." }
if ([int]$Manifest.task_count -ne 3) { throw "Manifest task_count must be 3." }

$PatchesRoot = Join-Path $ProgramRoot "patches"
$PacksRoot = Join-Path $ProgramRoot "packs"
$TasksRoot = Join-Path $ProgramRoot "tasks"
$RecipesRoot = Join-Path $ProgramRoot "execution_recipes"

$RegistryPatchPath = Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json"
$RoadmapPatchPath = Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json"
$QueueSeedPath = Join-Path $PatchesRoot "TASK_QUEUE_SEED.json"

foreach ($PatchPath in @($RegistryPatchPath, $RoadmapPatchPath, $QueueSeedPath)) {
    Assert-RequiredPath -Path $PatchPath -Label "Generated admission patch"
    Assert-JsonParse $PatchPath
}

$RegistryPatch = Get-Content $RegistryPatchPath -Raw | ConvertFrom-Json
$RoadmapPatch = Get-Content $RoadmapPatchPath -Raw | ConvertFrom-Json
$QueueSeed = Get-Content $QueueSeedPath -Raw | ConvertFrom-Json

if (@($RegistryPatch.generated_packs).Count -ne 3) { throw "Generated registry patch must include 3 packs." }
if (@($RoadmapPatch.generated_capabilities).Count -ne 3) { throw "Generated roadmap patch must include 3 capabilities." }
if (@($QueueSeed.generated_tasks).Count -ne 3) { throw "Generated task queue seed must include 3 tasks." }
if ($QueueSeed.active_task_id -ne $Contract.generated_program_shape.first_activatable_task_id) {
    throw "Generated task queue seed active_task_id must match contract first activatable task."
}

$TaskFiles = @(Get-ChildItem -Path $TasksRoot -Filter "*.json" -File)
$PackContractFiles = @(Get-ChildItem -Path $PacksRoot -Recurse -Filter "PACK.json" -File)
$RecipeFiles = @(Get-ChildItem -Path $RecipesRoot -Filter "*.json" -File)
$ApplyFiles = @(Get-ChildItem -Path $PacksRoot -Recurse -Filter "APPLY.ps1" -File)

if ($TaskFiles.Count -ne 3) { throw "Expected exactly 3 generated task JSON files." }
if ($PackContractFiles.Count -ne 3) { throw "Expected exactly 3 generated pack PACK.json files." }
if ($RecipeFiles.Count -ne 3) { throw "Expected exactly 3 generated execution recipe JSON files." }
if ($ApplyFiles.Count -ne 3) { throw "Expected exactly 3 generated APPLY.ps1 entry scripts." }

foreach ($TaskFile in $TaskFiles) { Assert-JsonParse $TaskFile.FullName }
foreach ($PackFile in $PackContractFiles) { Assert-JsonParse $PackFile.FullName }
foreach ($RecipeFile in $RecipeFiles) { Assert-JsonParse $RecipeFile.FullName }
foreach ($ApplyFile in $ApplyFiles) { Assert-PowerShellParse $ApplyFile.FullName }

$Readiness = Test-GeneratedSelfBuildProgramAdmissionReadiness -ProgramManifestPath $ManifestPath
if ($Readiness.status -ne "PASS") { throw "Admission readiness evaluator status must be PASS." }
if ($Readiness.admission_decision -ne "ADMISSION_READY") { throw "Admission readiness decision must be ADMISSION_READY." }
if ([int]$Readiness.executable_pack_count -ne 3) { throw "Admission readiness executable_pack_count must be 3." }
if ([int]$Readiness.blocked_pack_count -ne 0) { throw "Admission readiness blocked_pack_count must be 0." }

$GeneratedPackIds = @($RegistryPatch.generated_packs | ForEach-Object { [string]$_.pack_id })
$GeneratedCapabilityIds = @($RoadmapPatch.generated_capabilities | ForEach-Object { [string]$_.capability_id })
$GeneratedTaskIds = @($QueueSeed.generated_tasks | ForEach-Object { [string]$_.task_id })

foreach ($GeneratedPackId in $GeneratedPackIds) {
    if (@($Registry.packs | Where-Object { $_.pack_id -eq $GeneratedPackId }).Count -gt 0) {
        throw "Second-family generated pack must not be admitted to live registry yet: $GeneratedPackId"
    }
    if (Test-Path ".\proofs\$GeneratedPackId.json") {
        throw "Second-family generated pack proof exists before generated pack execution is allowed: $GeneratedPackId"
    }
}
foreach ($GeneratedCapabilityId in $GeneratedCapabilityIds) {
    if (@($Roadmap.capabilities | Where-Object { $_.id -eq $GeneratedCapabilityId }).Count -gt 0) {
        throw "Second-family generated capability must not be admitted to live roadmap yet: $GeneratedCapabilityId"
    }
}
foreach ($GeneratedTaskId in $GeneratedTaskIds) {
    if (@($Queue.tasks | Where-Object { $_.task_id -eq $GeneratedTaskId }).Count -gt 0) {
        throw "Second-family generated task must not be admitted to live queue yet: $GeneratedTaskId"
    }
}

$ReportDir = Split-Path -Parent $ReportPath
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
}

$Report = [pscustomobject][ordered]@{
    report_id = "REMEDIATION_INTAKE_AGENT_V1_MATERIALIZATION"
    run_id = $RunId
    status = "PASS"
    timestamp = (Get-Date -Format 'o')
    family_id = $FamilyId
    source_contract_path = $SourceContractPath
    materialized_program_root = $ProgramRoot
    manifest_path = $ManifestPath
    manifest_identity = $Manifest.target_profile_id
    materialized_pack_count = 3
    materialized_capability_count = 3
    materialized_task_count = 3
    materialized_execution_recipe_count = 3
    materialized_apply_script_count = 3
    admission_readiness_decision = $Readiness.admission_decision
    live_admission_attempted = $false
    generated_pack_execution_attempted = $false
    generated_pack_ids = $GeneratedPackIds
    generated_capability_ids = $GeneratedCapabilityIds
    generated_task_ids = $GeneratedTaskIds
    next_required_capability = $NextRequiredCapability
}

$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

$ProofDir = Split-Path -Parent $ProofPath
if (-not (Test-Path $ProofDir)) {
    New-Item -ItemType Directory -Force -Path $ProofDir | Out-Null
}

$Proof = [pscustomobject][ordered]@{
    proof_id = "SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1"
    run_id = $RunId
    status = "PASS"
    family_id = $FamilyId
    source_contract_path = $SourceContractPath
    materialized_program_root = $ProgramRoot
    manifest_path = $ManifestPath
    materialized_pack_count = 3
    materialized_capability_count = 3
    materialized_task_count = 3
    materialized_execution_recipe_count = 3
    materialized_apply_script_count = 3
    admission_readiness_decision = $Readiness.admission_decision
    live_admission_attempted = $false
    generated_pack_execution_attempted = $false
    next_required_capability = $NextRequiredCapability
    conclusion = "The second generated self-build program family has been materialized into a complete executable program package and is ready for live admission."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content $ProofPath -Encoding UTF8

if ($FinalizePhase) {
    Write-Host ""
    Write-Host "--- Finalizing PHASE62 ---"

    $State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
    $Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
    $Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

    $Phase62Capability = $Roadmap.capabilities |
        Where-Object { $_.id -eq $CapabilityId } |
        Select-Object -First 1

    $Phase62Task = $Queue.tasks |
        Where-Object { $_.task_id -eq $TaskId } |
        Select-Object -First 1

    if ($null -eq $Phase62Capability) { throw "PHASE62 capability missing from roadmap." }
    if ($Phase62Capability.status -ne "ACTIVE") { throw "PHASE62 capability must be ACTIVE." }
    if ($null -eq $Phase62Task) { throw "PHASE62 task missing from queue." }
    if ($Phase62Task.status -ne "ACTIVE") { throw "PHASE62 task must be ACTIVE." }
    if ($Queue.active_task_id -ne $TaskId) { throw "PHASE62 task must be active before finalization." }
    if ($State.current_phase -ne "PHASE_62") { throw "State current_phase must be PHASE_62." }
    if ($State.current_capability -ne $CapabilityId) { throw "State current_capability must be PHASE62 capability." }

    $Phase62Capability.status = "COMPLETED"
    $Phase62Task.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
    $State.current_phase = "PHASE_62"
    $State.current_capability = $CapabilityId
    $State.last_run_status = "PASS"
    $State | Add-Member -NotePropertyName "second_generated_program_family_materialization_ready" -NotePropertyValue $true -Force

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8

    Write-Host "State updated: PHASE_62 COMPLETED"
    Write-Host "PHASE62=FINALIZED"
}

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\packs\registry.json"
Assert-JsonParse $SourceContractPath
Assert-JsonParse $ManifestPath
Assert-JsonParse $ReportPath
Assert-JsonParse $ProofPath

Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_STATUS=PASS"
Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_ID=$FamilyId"
Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_NEXT_REQUIRED_CAPABILITY=$NextRequiredCapability"
