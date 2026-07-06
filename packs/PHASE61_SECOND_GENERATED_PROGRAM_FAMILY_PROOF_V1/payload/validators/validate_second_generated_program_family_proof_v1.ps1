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

function Assert-Property {
    param(
        [object]$Object,
        [string]$PropertyName,
        [string]$Label
    )

    if ($null -eq $Object) {
        throw "$Label is missing."
    }
    if (-not $Object.PSObject.Properties.Name.Contains($PropertyName)) {
        throw "$Label missing property $PropertyName."
    }
    if ($null -eq $Object.$PropertyName) {
        throw "$Label property $PropertyName must not be null."
    }
}

function Assert-RequiredString {
    param(
        [object]$Value,
        [string]$Label
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        throw "$Label must not be empty."
    }
}

function Assert-NoMonitoringReuse {
    param(
        [object]$Value,
        [string]$Label
    )

    $Text = ($Value | ConvertTo-Json -Depth 100)
    if ($Text -match "monitoring_agent_v1|monitoring_agent|monitoring_alert|cpu_spike") {
        throw "$Label reuses monitoring-specific identity, path, or description."
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

$CapabilityId = "second_generated_program_family_proof_v1"
$TaskId = "TASK_SECOND_GENERATED_PROGRAM_FAMILY_PROOF_V1_001"
$FamilyId = "remediation_intake_agent_v1"
$DistinctFromFamilyId = "monitoring_agent_v1"
$CompatibilityTarget = "generalized_generated_program_pipeline_v1"
$NextRequiredCapability = "second_generated_program_family_materialization_v1"
$SourceContractPath = ".\specs\second_generated_program_family\remediation_intake_agent_v1\REMEDIATION_INTAKE_AGENT_V1_GENERATED_PROGRAM_FAMILY_CONTRACT.json"
$ReportPath = ".\reports\second_generated_program_family_proof\REMEDIATION_INTAKE_AGENT_V1_SECOND_FAMILY.json"
$ProofPath = ".\proofs\SECOND_GENERATED_PROGRAM_FAMILY_PROOF_V1.json"

Write-Host "=== SECOND GENERATED PROGRAM FAMILY PROOF V1 ==="
Write-Host "Capability: $CapabilityId"
Write-Host "Task: $TaskId"
Write-Host "Run: $RunId"
Write-Host "Family: $FamilyId"

if (-not (Test-Path $SourceContractPath)) {
    throw "Second generated program family source contract missing: $SourceContractPath"
}

Assert-JsonParse $SourceContractPath
$Contract = Get-Content $SourceContractPath -Raw | ConvertFrom-Json

foreach ($Field in @(
    "contract_id",
    "contract_version",
    "contract_status",
    "family_id",
    "distinct_from_family_id",
    "target_agent_kind",
    "profile_id",
    "source_phase",
    "compatibility_target",
    "growth_purpose",
    "formal_identity",
    "generated_program_shape",
    "planned_generated_capabilities",
    "planned_generated_tasks",
    "planned_generated_packs",
    "pipeline_compatibility",
    "readiness_assertions"
)) {
    Assert-Property -Object $Contract -PropertyName $Field -Label "Second family contract"
}

if ($Contract.contract_status -ne "READY_FOR_SECOND_FAMILY_PROOF") {
    throw "Second family contract status must be READY_FOR_SECOND_FAMILY_PROOF."
}
if ($Contract.family_id -ne $FamilyId) {
    throw "Second family id mismatch."
}
if ($Contract.distinct_from_family_id -ne $DistinctFromFamilyId) {
    throw "Second family distinct_from_family_id mismatch."
}
if ($Contract.family_id -eq $Contract.distinct_from_family_id) {
    throw "Second family must be distinct from the first generated program family."
}
if ($Contract.target_agent_kind -ne "remediation_intake_agent") {
    throw "Second family target_agent_kind mismatch."
}
if ($Contract.profile_id -ne $FamilyId) {
    throw "Second family profile_id must match family_id."
}
if ($Contract.source_phase -ne "PHASE_61") {
    throw "Second family source phase must be PHASE_61."
}
if ($Contract.compatibility_target -ne $CompatibilityTarget) {
    throw "Second family compatibility target mismatch."
}

Assert-NoMonitoringReuse -Value $Contract.growth_purpose -Label "Second family growth purpose"
Assert-NoMonitoringReuse -Value $Contract.formal_identity -Label "Second family formal identity"
Assert-NoMonitoringReuse -Value $Contract.generated_program_shape -Label "Second family generated program shape"
Assert-NoMonitoringReuse -Value $Contract.planned_generated_capabilities -Label "Second family planned capabilities"
Assert-NoMonitoringReuse -Value $Contract.planned_generated_tasks -Label "Second family planned tasks"
Assert-NoMonitoringReuse -Value $Contract.planned_generated_packs -Label "Second family planned packs"

Assert-RequiredString -Value $Contract.growth_purpose.summary -Label "Growth purpose summary"
Assert-RequiredString -Value $Contract.growth_purpose.builder_capability_target -Label "Growth purpose builder capability target"
Assert-RequiredString -Value $Contract.formal_identity.program_root -Label "Formal identity program root"
Assert-RequiredString -Value $Contract.formal_identity.manifest_path -Label "Formal identity manifest path"

if ($Contract.formal_identity.program_root -ne "self_build_programs/generated/remediation_intake_agent_v1") {
    throw "Second family program_root mismatch."
}
if ($Contract.formal_identity.manifest_path -ne "self_build_programs/generated/remediation_intake_agent_v1/SELF_BUILD_PROGRAM_MANIFEST.json") {
    throw "Second family manifest_path mismatch."
}
if ($Contract.formal_identity.program_status_target -ne "PROGRAM_PACKAGE_MATERIALIZED") {
    throw "Second family program_status_target mismatch."
}
if ($Contract.formal_identity.admission_status_target -ne "NOT_ADMITTED_YET") {
    throw "Second family admission_status_target mismatch."
}

$Shape = $Contract.generated_program_shape
if ([int]$Shape.expected_pack_count -ne 3) { throw "Second family expected_pack_count must be 3." }
if ([int]$Shape.expected_task_count -ne 3) { throw "Second family expected_task_count must be 3." }
if ([int]$Shape.expected_capability_count -ne 3) { throw "Second family expected_capability_count must be 3." }
if ($Shape.first_activatable_task_id -ne "TASK_GENERATED_REMEDIATION_INTAKE_AGENT_V1_PROFILE_MATERIALIZATION_V1_001") {
    throw "Second family first activatable task mismatch."
}
if ($Shape.first_activatable_capability_id -ne "generated_remediation_intake_agent_v1_profile_materialization_v1") {
    throw "Second family first activatable capability mismatch."
}

$ExpectedRoles = @("PROFILE_MATERIALIZATION", "SPECIALIZED_CLOSURE_PROOF", "SEED_CONSUMPTION_PROOF")
$ObservedRoles = @($Shape.semantic_roles)
foreach ($Role in $ExpectedRoles) {
    if ($ObservedRoles -notcontains $Role) {
        throw "Second family missing semantic role: $Role"
    }
}

$PlannedCapabilities = @($Contract.planned_generated_capabilities | Sort-Object { [int]$_.order })
$PlannedTasks = @($Contract.planned_generated_tasks | Sort-Object { [int]$_.order })
$PlannedPacks = @($Contract.planned_generated_packs | Sort-Object { [int]$_.order })

if ($PlannedCapabilities.Count -ne 3) { throw "Second family must define 3 planned capabilities." }
if ($PlannedTasks.Count -ne 3) { throw "Second family must define 3 planned tasks." }
if ($PlannedPacks.Count -ne 3) { throw "Second family must define 3 planned packs." }

for ($Index = 0; $Index -lt 3; $Index++) {
    $ExpectedOrder = $Index + 1
    $Capability = $PlannedCapabilities[$Index]
    $Task = $PlannedTasks[$Index]
    $Pack = $PlannedPacks[$Index]

    if ([int]$Capability.order -ne $ExpectedOrder) { throw "Second family planned capability order mismatch." }
    if ([int]$Task.order -ne $ExpectedOrder) { throw "Second family planned task order mismatch." }
    if ([int]$Pack.order -ne $ExpectedOrder) { throw "Second family planned pack order mismatch." }
    if ($Task.capability_id -ne $Capability.capability_id) {
        throw "Second family planned task/capability mismatch for order $ExpectedOrder."
    }
    if ($Pack.task_id -ne $Task.task_id) {
        throw "Second family planned pack/task mismatch for order $ExpectedOrder."
    }
    if ($ExpectedRoles -notcontains [string]$Capability.semantic_role) {
        throw "Second family planned capability has unsupported semantic role."
    }
}

if ($PlannedTasks[0].task_id -ne $Shape.first_activatable_task_id) {
    throw "Second family first task must match first planned task."
}
if ($PlannedCapabilities[0].capability_id -ne $Shape.first_activatable_capability_id) {
    throw "Second family first capability must match first planned capability."
}

$Compatibility = $Contract.pipeline_compatibility
if ($Compatibility.materialization_next_capability -ne $NextRequiredCapability) {
    throw "Second family materialization next capability mismatch."
}
foreach ($RequiredPhase in @("PHASE_58", "PHASE_59", "PHASE_60")) {
    if (@($Compatibility.established_by_phases) -notcontains $RequiredPhase) {
        throw "Second family compatibility missing established phase $RequiredPhase."
    }
}
foreach ($BooleanField in @(
    "requires_manifest_rooted_program_paths",
    "requires_patch_derived_counts",
    "requires_program_owned_execution_recipes",
    "requires_contract_validation_before_live_admission"
)) {
    Assert-Property -Object $Compatibility -PropertyName $BooleanField -Label "Second family pipeline compatibility"
    if ($Compatibility.$BooleanField -ne $true) {
        throw "Second family pipeline compatibility $BooleanField must be true."
    }
}

$RequiredPriorProofs = @(
    ".\proofs\GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1.json",
    ".\proofs\RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1.json",
    ".\proofs\GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1.json"
)

foreach ($PriorProofPath in $RequiredPriorProofs) {
    if (-not (Test-Path $PriorProofPath)) {
        throw "Required prior generated-program proof missing: $PriorProofPath"
    }
    Assert-JsonParse $PriorProofPath
    $PriorProof = Get-Content $PriorProofPath -Raw | ConvertFrom-Json
    if ($PriorProof.status -ne "PASS") {
        throw "Required prior generated-program proof must be PASS: $PriorProofPath"
    }
}

$Phase60Proof = Get-Content ".\proofs\GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1.json" -Raw | ConvertFrom-Json
if ($Phase60Proof.next_required_capability -ne $CapabilityId) {
    throw "PHASE60 proof does not point to second_generated_program_family_proof_v1."
}

if (Test-Path ".\self_build_programs\generated\remediation_intake_agent_v1") {
    throw "PHASE61 must not materialize remediation_intake_agent_v1 generated program artifacts."
}

$ReportDir = Split-Path -Parent $ReportPath
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
}

$Report = [pscustomobject][ordered]@{
    report_id = "REMEDIATION_INTAKE_AGENT_V1_SECOND_FAMILY"
    run_id = $RunId
    status = "PASS"
    timestamp = (Get-Date -Format 'o')
    family_id = $FamilyId
    distinct_from_family_id = $DistinctFromFamilyId
    source_contract_path = $SourceContractPath
    compatibility_target = $CompatibilityTarget
    second_family_readiness = "PASS"
    target_agent_kind = $Contract.target_agent_kind
    growth_purpose = $Contract.growth_purpose.summary
    planned_pack_count = $PlannedPacks.Count
    planned_capability_count = $PlannedCapabilities.Count
    planned_task_count = $PlannedTasks.Count
    semantic_roles = $ExpectedRoles
    materialized_program_exists = $false
    live_admission_attempted = $false
    second_family_pack_execution_attempted = $false
    next_required_capability = $NextRequiredCapability
}

$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

$ProofDir = Split-Path -Parent $ProofPath
if (-not (Test-Path $ProofDir)) {
    New-Item -ItemType Directory -Force -Path $ProofDir | Out-Null
}

$Proof = [pscustomobject][ordered]@{
    proof_id = "SECOND_GENERATED_PROGRAM_FAMILY_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    family_id = $FamilyId
    distinct_from_family_id = $DistinctFromFamilyId
    compatibility_target = $CompatibilityTarget
    second_family_readiness = "PASS"
    source_contract_path = $SourceContractPath
    target_agent_kind = $Contract.target_agent_kind
    planned_pack_count = $PlannedPacks.Count
    planned_capability_count = $PlannedCapabilities.Count
    planned_task_count = $PlannedTasks.Count
    materialized_program_exists = $false
    live_admission_attempted = $false
    second_family_pack_execution_attempted = $false
    report_path = $ReportPath
    next_required_capability = "second_generated_program_family_materialization_v1"
    conclusion = "A second generated self-build program family is formally defined and ready to enter the generalized generated-program materialization contour."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content $ProofPath -Encoding UTF8

if ($FinalizePhase) {
    Write-Host ""
    Write-Host "--- Finalizing PHASE61 ---"

    $State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
    $Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
    $Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

    $Phase61Capability = $Roadmap.capabilities |
        Where-Object { $_.id -eq $CapabilityId } |
        Select-Object -First 1

    $Phase61Task = $Queue.tasks |
        Where-Object { $_.task_id -eq $TaskId } |
        Select-Object -First 1

    if ($null -eq $Phase61Capability) { throw "PHASE61 capability missing from roadmap." }
    if ($Phase61Capability.status -ne "ACTIVE") { throw "PHASE61 capability must be ACTIVE." }
    if ($null -eq $Phase61Task) { throw "PHASE61 task missing from queue." }
    if ($Phase61Task.status -ne "ACTIVE") { throw "PHASE61 task must be ACTIVE." }
    if ($Queue.active_task_id -ne $TaskId) { throw "PHASE61 task must be active before finalization." }
    if ($State.current_phase -ne "PHASE_61") { throw "State current_phase must be PHASE_61." }
    if ($State.current_capability -ne $CapabilityId) { throw "State current_capability must be PHASE61 capability." }

    $Phase61Capability.status = "COMPLETED"
    $Phase61Task.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
    $State.current_phase = "PHASE_61"
    $State.current_capability = $CapabilityId
    $State.last_run_status = "PASS"
    $State | Add-Member -NotePropertyName "second_generated_program_family_ready" -NotePropertyValue $true -Force

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8

    Write-Host "State updated: PHASE_61 COMPLETED"
    Write-Host "PHASE61=FINALIZED"
}

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\packs\registry.json"
Assert-JsonParse $SourceContractPath
Assert-JsonParse $ReportPath
Assert-JsonParse $ProofPath

Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_STATUS=PASS"
Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_ID=$FamilyId"
Write-Host "SECOND_GENERATED_PROGRAM_FAMILY_NEXT_REQUIRED_CAPABILITY=$NextRequiredCapability"
