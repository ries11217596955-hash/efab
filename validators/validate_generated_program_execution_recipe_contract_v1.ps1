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

function Assert-RecipeContractShape {
    param(
        [object]$Recipe,
        [string]$RecipePath
    )

    $RequiredFields = @(
        "recipe_id",
        "program_manifest_path",
        "target_profile_id",
        "target_agent_kind",
        "pack_id",
        "task_id",
        "capability_id",
        "expected_gate",
        "semantic_role",
        "recipe_kind",
        "input_artifacts",
        "invocation_contract",
        "expected_assertions",
        "proof_contract",
        "next_transition"
    )

    foreach ($Field in $RequiredFields) {
        if (-not $Recipe.PSObject.Properties.Name.Contains($Field)) {
            throw "Recipe missing required field $Field at $RecipePath"
        }
        if ($null -eq $Recipe.$Field) {
            throw "Recipe required field $Field must not be null at $RecipePath"
        }
    }

    foreach ($StringField in @(
        "recipe_id",
        "program_manifest_path",
        "target_profile_id",
        "target_agent_kind",
        "pack_id",
        "task_id",
        "capability_id",
        "expected_gate",
        "semantic_role",
        "recipe_kind"
    )) {
        if ([string]::IsNullOrWhiteSpace([string]$Recipe.$StringField)) {
            throw "Recipe field $StringField must not be empty at $RecipePath"
        }
    }

    if (@("PROFILE_MATERIALIZATION", "SPECIALIZED_CLOSURE_PROOF", "SEED_CONSUMPTION_PROOF") -notcontains $Recipe.semantic_role) {
        throw "Unsupported recipe semantic_role at $RecipePath"
    }
    if (@("PROFILE_MATERIALIZATION_RECIPE_V1", "SPECIALIZED_CLOSURE_PROOF_RECIPE_V1", "SEED_CONSUMPTION_PROOF_RECIPE_V1") -notcontains $Recipe.recipe_kind) {
        throw "Unsupported recipe_kind at $RecipePath"
    }
}

function Assert-MonitoringRecipeFacts {
    param(
        [object]$Recipe,
        [string]$RecipePath
    )

    if ($Recipe.program_manifest_path -ne "self_build_programs/generated/monitoring_agent_v1/SELF_BUILD_PROGRAM_MANIFEST.json") {
        throw "Recipe program manifest path mismatch at $RecipePath"
    }
    if ($Recipe.target_profile_id -ne "monitoring_agent_v1") {
        throw "Recipe target profile id mismatch at $RecipePath"
    }
    if ($Recipe.target_agent_kind -ne "monitoring_agent") {
        throw "Recipe target agent kind mismatch at $RecipePath"
    }

    if ($Recipe.semantic_role -eq "PROFILE_MATERIALIZATION") {
        if ($Recipe.recipe_kind -ne "PROFILE_MATERIALIZATION_RECIPE_V1") { throw "Profile recipe kind mismatch." }
        if ($Recipe.input_artifacts.program_seed_path -ne ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json") { throw "Profile recipe program seed path mismatch." }
        if ($Recipe.input_artifacts.monitoring_profile_proof_spec_path -ne ".\specs\monitoring_profile_proof\MONITORING_AGENT_PROFILE_PROOF_SPEC.json") { throw "Profile recipe proof spec path mismatch." }
        if ($Recipe.invocation_contract.resolve_specialization_overlay.agent_kind -ne "monitoring_agent") { throw "Profile recipe resolver agent kind mismatch." }
        if ($Recipe.invocation_contract.resolve_specialization_overlay.package_profile -ne "operational_specialized") { throw "Profile recipe package profile mismatch." }
        if ($Recipe.expected_assertions.expected_profile_id -ne "monitoring_agent_v1") { throw "Profile recipe expected profile mismatch." }
        if ($Recipe.expected_assertions.expected_agent_kind -ne "monitoring_agent") { throw "Profile recipe expected agent kind mismatch." }
        if ($Recipe.expected_assertions.operational_result.operation -ne "monitoring_alert_triage_queue") { throw "Profile recipe operation mismatch." }
        if ($Recipe.expected_assertions.operational_result.next_alert_id -ne "cpu_spike") { throw "Profile recipe next alert mismatch." }
        if ($Recipe.expected_assertions.operational_result.escalation_status -ne "ESCALATE") { throw "Profile recipe escalation mismatch." }
        if ($Recipe.next_transition.next_task_id -ne "TASK_GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1_001") { throw "Profile recipe next task mismatch." }
        return
    }

    if ($Recipe.semantic_role -eq "SPECIALIZED_CLOSURE_PROOF") {
        if ($Recipe.recipe_kind -ne "SPECIALIZED_CLOSURE_PROOF_RECIPE_V1") { throw "Closure recipe kind mismatch." }
        if ($Recipe.input_artifacts.raw_idea_path -ne ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json") { throw "Closure recipe raw idea path mismatch." }
        if ($Recipe.invocation_contract.mode -ne "BUILD_FROM_RAW_IDEA_SPECIALIZED") { throw "Closure recipe orchestrator mode mismatch." }
        if ($Recipe.expected_assertions.expected_specialization_profile_id -ne "monitoring_agent_v1") { throw "Closure recipe expected profile mismatch." }
        if ($Recipe.expected_assertions.overlay_status -ne "PASS") { throw "Closure recipe overlay status mismatch." }
        if ($Recipe.expected_assertions.operational_result.operation -ne "monitoring_alert_triage_queue") { throw "Closure recipe operation mismatch." }
        if ($Recipe.expected_assertions.operational_result.next_alert_id -ne "cpu_spike") { throw "Closure recipe next alert mismatch." }
        if ($Recipe.expected_assertions.operational_result.escalation_status -ne "ESCALATE") { throw "Closure recipe escalation mismatch." }
        if ($Recipe.next_transition.next_task_id -ne "TASK_GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1_001") { throw "Closure recipe next task mismatch." }
        return
    }

    if ($Recipe.semantic_role -eq "SEED_CONSUMPTION_PROOF") {
        if ($Recipe.recipe_kind -ne "SEED_CONSUMPTION_PROOF_RECIPE_V1") { throw "Seed recipe kind mismatch." }
        if ($Recipe.input_artifacts.program_seed_path -ne ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json") { throw "Seed recipe program seed path mismatch." }
        if ($Recipe.input_artifacts.dependent_generated_profile_proof_path -ne ".\proofs\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1.json") { throw "Seed recipe profile proof dependency mismatch." }
        if ($Recipe.input_artifacts.dependent_generated_closure_proof_path -ne ".\proofs\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1.json") { throw "Seed recipe closure proof dependency mismatch." }
        if ($Recipe.expected_assertions.seed_profile_id -ne "monitoring_agent_v1") { throw "Seed recipe profile id mismatch." }
        if ($Recipe.expected_assertions.seed_agent_kind -ne "monitoring_agent") { throw "Seed recipe agent kind mismatch." }
        if ($Recipe.expected_assertions.expected_specialized_operation -ne "monitoring_alert_triage_queue") { throw "Seed recipe specialized operation mismatch." }
        $Rules = @($Recipe.expected_assertions.cross_proof_consistency_rules)
        foreach ($ExpectedRule in @(
            "profile_proof.status == PASS",
            "profile_proof.selected_profile_id == seed.candidate_profile_id",
            "closure_proof.status == PASS",
            "closure_proof.selected_profile_id == seed.candidate_profile_id",
            "closure_proof.specialized_operation == monitoring_alert_triage_queue"
        )) {
            if ($Rules -notcontains $ExpectedRule) {
                throw "Seed recipe missing consistency rule: $ExpectedRule"
            }
        }
        if ($Recipe.next_transition.queue_action -ne "COMPLETE_GENERATED_PROGRAM") { throw "Seed recipe transition mismatch." }
        return
    }

    throw "Unhandled recipe semantic role at $RecipePath"
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\new_generated_self_build_program_execution_recipe_bundle.ps1"

$CapabilityId = "generated_program_execution_recipe_contract_v1"
$TaskId = "TASK_GENERATED_PROGRAM_EXECUTION_RECIPE_CONTRACT_V1_001"
$ProgramManifestPath = ".\self_build_programs\generated\monitoring_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"
$SchemaPath = ".\contracts\generated_self_build_program_execution_recipe.schema.json"

if (-not (Test-Path $SchemaPath)) {
    throw "Execution recipe schema missing: $SchemaPath"
}

Assert-JsonParse $SchemaPath

$Bundle = New-GeneratedSelfBuildProgramExecutionRecipeBundle -ProgramManifestPath $ProgramManifestPath

if ($Bundle.status -ne "PASS") { throw "Recipe bundle generation status must be PASS." }
if ([int]$Bundle.recipe_count -ne 3) { throw "Recipe bundle count must be 3." }

$Recipes = @()
foreach ($RecipePath in @($Bundle.recipe_paths)) {
    if (-not (Test-Path $RecipePath)) {
        throw "Emitted recipe path missing: $RecipePath"
    }
    Assert-JsonParse $RecipePath
    $Recipe = Get-Content $RecipePath -Raw | ConvertFrom-Json
    Assert-RecipeContractShape -Recipe $Recipe -RecipePath $RecipePath
    Assert-MonitoringRecipeFacts -Recipe $Recipe -RecipePath $RecipePath
    $Recipes += $Recipe
}

$CoveredSemanticRoles = @($Recipes | ForEach-Object { $_.semantic_role } | Sort-Object -Unique)
$CoveredRecipeKinds = @($Recipes | ForEach-Object { $_.recipe_kind } | Sort-Object -Unique)

foreach ($ExpectedRole in @("PROFILE_MATERIALIZATION", "SPECIALIZED_CLOSURE_PROOF", "SEED_CONSUMPTION_PROOF")) {
    if ($CoveredSemanticRoles -notcontains $ExpectedRole) {
        throw "Missing recipe semantic role: $ExpectedRole"
    }
}

foreach ($ExpectedKind in @("PROFILE_MATERIALIZATION_RECIPE_V1", "SPECIALIZED_CLOSURE_PROOF_RECIPE_V1", "SEED_CONSUMPTION_PROOF_RECIPE_V1")) {
    if ($CoveredRecipeKinds -notcontains $ExpectedKind) {
        throw "Missing recipe kind: $ExpectedKind"
    }
}

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq $CapabilityId } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq $TaskId } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_58") { throw "Expected PHASE_58." }
if ($State.current_capability -ne $CapabilityId) { throw "Expected $CapabilityId." }
if ($Queue.active_task_id -ne $TaskId) { throw "Unexpected active task." }
if ($null -eq $ThisCap) { throw "PHASE58 capability missing from roadmap." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE58 capability must be ACTIVE before runtime finalization." }
if ($null -eq $ThisTask) { throw "PHASE58 task missing from queue." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE58 task must be ACTIVE before runtime finalization." }
if (-not $State.generated_program_live_admission_ready) { throw "Generated program live admission must already be ready." }

$ReportRoot = ".\reports\generated_program_execution_recipes"
New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
$ReportPath = Join-Path $ReportRoot "MONITORING_AGENT_V1_EXECUTION_RECIPE_BUNDLE.json"

$Report = [ordered]@{
    report_id = "MONITORING_AGENT_V1_EXECUTION_RECIPE_BUNDLE"
    run_id = $RunId
    status = "PASS"
    source_program_manifest = $Bundle.source_program_manifest
    emitted_recipe_count = $Bundle.recipe_count
    emitted_recipe_paths = $Bundle.recipe_paths
    covered_semantic_roles = $CoveredSemanticRoles
    covered_recipe_kinds = $CoveredRecipeKinds
    canonical_monitoring_facts_preserved = [ordered]@{
        target_profile_id = "monitoring_agent_v1"
        target_agent_kind = "monitoring_agent"
        operation = "monitoring_alert_triage_queue"
        next_alert_id = "cpu_spike"
        escalation_status = "ESCALATE"
    }
}

$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId

    $State.current_phase = "PHASE_58"
    $State.current_capability = $CapabilityId
    $State.last_run_status = "PASS"
    $State | Add-Member -NotePropertyName "generated_program_execution_recipe_contract_ready" -NotePropertyValue $true -Force

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content ".\CAPABILITY_ROADMAP.json" -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content ".\GENESIS_STATE.json" -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content ".\TASK_QUEUE.json" -Encoding UTF8
}

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"

$Proof = [ordered]@{
    proof_id = "GENERATED_PROGRAM_EXECUTION_RECIPE_CONTRACT_V1"
    run_id = $RunId
    status = "PASS"
    source_program_manifest = $Bundle.source_program_manifest
    emitted_recipe_count = 3
    emitted_recipe_paths = $Bundle.recipe_paths
    covered_semantic_roles = $CoveredSemanticRoles
    covered_recipe_kinds = $CoveredRecipeKinds
    next_required_capability = "recipe_driven_generated_program_executable_materialization_v1"
    report_path = $ReportPath
    conclusion = "Builder can now externalize generated self-build pack execution intent into program-owned machine-readable recipe artifacts."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\GENERATED_PROGRAM_EXECUTION_RECIPE_CONTRACT_V1.json" -Encoding UTF8

Write-Host "GENERATED_PROGRAM_EXECUTION_RECIPE_CONTRACT_STATUS=PASS"
Write-Host "GENERATED_PROGRAM_EXECUTION_RECIPE_COUNT=$($Bundle.recipe_count)"
Write-Host "GENERATED_PROGRAM_EXECUTION_RECIPE_ROLES=$($CoveredSemanticRoles -join ',')"
Write-Host "GENERATED_PROGRAM_EXECUTION_RECIPE_KINDS=$($CoveredRecipeKinds -join ',')"
Write-Host "GENERATED_PROGRAM_EXECUTION_RECIPE_NEXT_REQUIRED_CAPABILITY=recipe_driven_generated_program_executable_materialization_v1"
Write-Host "PASS :: generated_program_execution_recipe_contract_v1 checks passed. run_id=$RunId"
