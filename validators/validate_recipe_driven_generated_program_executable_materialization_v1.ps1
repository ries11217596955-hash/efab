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

function Assert-TextContains {
    param(
        [string]$Text,
        [string]$Expected,
        [string]$Path
    )

    if (-not $Text.Contains($Expected)) {
        throw "Expected marker '$Expected' missing from $Path"
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

function Test-ReadinessOnPreAdmissionScratchCopy {
    param(
        [string]$ProgramManifestPath
    )

    $ProgramRoot = Split-Path -Parent (Resolve-Path $ProgramManifestPath).Path
    $ScratchParent = Join-Path ([System.IO.Path]::GetTempPath()) ("efactory_recipe_render_readiness_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $ScratchParent | Out-Null

    try {
        Copy-Item -LiteralPath $ProgramRoot -Destination $ScratchParent -Recurse -Force
        $ScratchProgramRoot = Join-Path $ScratchParent (Split-Path -Leaf $ProgramRoot)
        $ScratchManifestPath = Join-Path $ScratchProgramRoot "SELF_BUILD_PROGRAM_MANIFEST.json"
        $ScratchManifest = Get-Content $ScratchManifestPath -Raw | ConvertFrom-Json
        $ScratchManifest.admission_status = "NOT_ADMITTED_YET"
        $ScratchManifest | ConvertTo-Json -Depth 100 |
            Set-Content $ScratchManifestPath -Encoding UTF8

        return Test-GeneratedSelfBuildProgramAdmissionReadiness -ProgramManifestPath $ScratchManifestPath
    }
    finally {
        if (Test-Path $ScratchParent) {
            Remove-Item -LiteralPath $ScratchParent -Recurse -Force
        }
    }
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\render_generated_self_build_pack_apply_from_recipe.ps1"
. ".\modules\complete_generated_self_build_program_executable_packs.ps1"
. ".\modules\test_generated_self_build_program_admission_readiness.ps1"

$CapabilityId = "recipe_driven_generated_program_executable_materialization_v1"
$TaskId = "TASK_RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1_001"
$ProgramManifestPath = ".\self_build_programs\generated\monitoring_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"

$ExpectedRecipeRows = @(
    [pscustomobject]@{
        pack_id = "GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1"
        task_id = "TASK_GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1_001"
        semantic_role = "PROFILE_MATERIALIZATION"
        recipe_kind = "PROFILE_MATERIALIZATION_RECIPE_V1"
        recipe_path = ".\self_build_programs\generated\monitoring_agent_v1\execution_recipes\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1_RECIPE.json"
        apply_path = ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1\APPLY.ps1"
    },
    [pscustomobject]@{
        pack_id = "GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1"
        task_id = "TASK_GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1_001"
        semantic_role = "SPECIALIZED_CLOSURE_PROOF"
        recipe_kind = "SPECIALIZED_CLOSURE_PROOF_RECIPE_V1"
        recipe_path = ".\self_build_programs\generated\monitoring_agent_v1\execution_recipes\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1_RECIPE.json"
        apply_path = ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1\APPLY.ps1"
    },
    [pscustomobject]@{
        pack_id = "GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1"
        task_id = "TASK_GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1_001"
        semantic_role = "SEED_CONSUMPTION_PROOF"
        recipe_kind = "SEED_CONSUMPTION_PROOF_RECIPE_V1"
        recipe_path = ".\self_build_programs\generated\monitoring_agent_v1\execution_recipes\GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1_RECIPE.json"
        apply_path = ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1\APPLY.ps1"
    }
)

foreach ($Row in $ExpectedRecipeRows) {
    if (-not (Test-Path $Row.recipe_path)) {
        throw "Required execution recipe missing: $($Row.recipe_path)"
    }
    Assert-JsonParse $Row.recipe_path
    $Recipe = Get-Content $Row.recipe_path -Raw | ConvertFrom-Json
    Assert-GeneratedSelfBuildExecutionRecipe -Recipe $Recipe -RecipePath $Row.recipe_path
    if ($Recipe.pack_id -ne $Row.pack_id) { throw "Recipe pack_id mismatch at $($Row.recipe_path)" }
    if ($Recipe.task_id -ne $Row.task_id) { throw "Recipe task_id mismatch at $($Row.recipe_path)" }
    if ($Recipe.semantic_role -ne $Row.semantic_role) { throw "Recipe semantic_role mismatch at $($Row.recipe_path)" }
    if ($Recipe.recipe_kind -ne $Row.recipe_kind) { throw "Recipe recipe_kind mismatch at $($Row.recipe_path)" }
}

$MaterializerSource = Get-Content ".\modules\complete_generated_self_build_program_executable_packs.ps1" -Raw
if ($MaterializerSource -match "New-GeneratedMonitoringAgentApplyScript") {
    throw "Executable materializer must not call the old monitoring-specific APPLY script builder."
}
if (-not $MaterializerSource.Contains("Render-GeneratedSelfBuildPackApplyFromRecipe")) {
    throw "Executable materializer must depend on the recipe-driven renderer."
}
if (-not $MaterializerSource.Contains("execution_recipes")) {
    throw "Executable materializer must locate generated execution recipe artifacts."
}

$Materialization = Complete-GeneratedSelfBuildProgramExecutablePacks -ProgramManifestPath $ProgramManifestPath
if ($Materialization.status -ne "PASS") { throw "Recipe-driven executable materialization status must be PASS." }
if ([int]$Materialization.materialized_apply_script_count -ne 3) { throw "Expected exactly three rendered generated APPLY scripts." }

$MarkerParity = @()
foreach ($Row in $ExpectedRecipeRows) {
    if (-not (Test-Path $Row.apply_path)) {
        throw "Rendered generated APPLY script missing: $($Row.apply_path)"
    }

    Assert-PowerShellParse $Row.apply_path
    $Text = Get-Content $Row.apply_path -Raw
    Assert-TextContains -Text $Text -Expected "PACK=$($Row.pack_id)" -Path $Row.apply_path
    Assert-TextContains -Text $Text -Expected "GENERATED_PACK_ROLE=$($Row.semantic_role)" -Path $Row.apply_path
    Assert-TextContains -Text $Text -Expected "GENERATED_PACK_TASK=$($Row.task_id)" -Path $Row.apply_path
    Assert-TextContains -Text $Text -Expected "PACK_COMMIT_PUSH=PASS" -Path $Row.apply_path

    $MarkerParity += [pscustomobject]@{
        pack_id = $Row.pack_id
        semantic_role = $Row.semantic_role
        task_id = $Row.task_id
        apply_path = (Resolve-Path $Row.apply_path).Path
        marker_parity = "PASS"
    }
}

$Readiness = Test-ReadinessOnPreAdmissionScratchCopy -ProgramManifestPath $ProgramManifestPath
if ($Readiness.status -ne "PASS") { throw "Admission-readiness evaluator status must be PASS after recipe rendering." }
if ($Readiness.admission_decision -ne "ADMISSION_READY") { throw "Admission-readiness decision after recipe rendering must be ADMISSION_READY." }
if ([int]$Readiness.executable_pack_count -ne 3) { throw "Admission-readiness executable_pack_count must be 3." }
if ([int]$Readiness.blocked_pack_count -ne 0) { throw "Admission-readiness blocked_pack_count must be 0." }

$State = Get-Content ".\GENESIS_STATE.json" -Raw | ConvertFrom-Json
$Roadmap = Get-Content ".\CAPABILITY_ROADMAP.json" -Raw | ConvertFrom-Json
$Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
$Manifest = Get-Content $ProgramManifestPath -Raw | ConvertFrom-Json

$ThisCap = $Roadmap.capabilities |
    Where-Object { $_.id -eq $CapabilityId } |
    Select-Object -First 1

$ThisTask = $Queue.tasks |
    Where-Object { $_.task_id -eq $TaskId } |
    Select-Object -First 1

if ($State.current_phase -ne "PHASE_59") { throw "Expected PHASE_59." }
if ($State.current_capability -ne $CapabilityId) { throw "Expected current capability $CapabilityId." }
if ($Queue.active_task_id -ne $TaskId) { throw "Expected active task $TaskId." }
if ($null -eq $ThisCap) { throw "PHASE59 capability missing from roadmap." }
if ($ThisCap.status -ne "ACTIVE") { throw "PHASE59 capability must be ACTIVE before runtime finalization." }
if ($null -eq $ThisTask) { throw "PHASE59 task missing from queue." }
if ($ThisTask.status -ne "ACTIVE") { throw "PHASE59 task must be ACTIVE before runtime finalization." }
if ($Manifest.admission_status -ne "ADMITTED_TO_LIVE_EXECUTION") { throw "Generated program admission state must remain admitted." }
if (-not $State.generated_program_execution_recipe_contract_ready) { throw "Execution recipe contract must already be ready." }

$SupportedRecipeKinds = @($ExpectedRecipeRows | ForEach-Object { $_.recipe_kind } | Sort-Object -Unique)

$ReportRoot = ".\reports\recipe_driven_generated_program_materialization"
New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
$ReportPath = Join-Path $ReportRoot "MONITORING_AGENT_V1_RECIPE_RENDERING_PARITY.json"

$Report = [ordered]@{
    report_id = "MONITORING_AGENT_V1_RECIPE_RENDERING_PARITY"
    run_id = $RunId
    status = "PASS"
    source_program_manifest = (Resolve-Path $ProgramManifestPath).Path
    rendered_apply_script_count = [int]$Materialization.materialized_apply_script_count
    rendered_apply_scripts = @($MarkerParity)
    supported_recipe_kinds = $SupportedRecipeKinds
    admission_readiness_after_recipe_rendering = $Readiness.admission_decision
    executable_pack_count_after_recipe_rendering = [int]$Readiness.executable_pack_count
    blocked_pack_count_after_recipe_rendering = [int]$Readiness.blocked_pack_count
    materializer_dependency = "Render-GeneratedSelfBuildPackApplyFromRecipe"
}

$Report | ConvertTo-Json -Depth 100 |
    Set-Content $ReportPath -Encoding UTF8

if ($FinalizePhase) {
    $ThisCap.status = "COMPLETED"
    $ThisTask.status = "COMPLETED"
    $Queue.active_task_id = "NONE"

    Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId

    $State.current_phase = "PHASE_59"
    $State.current_capability = $CapabilityId
    $State.last_run_status = "PASS"
    $State | Add-Member -NotePropertyName "recipe_driven_generated_program_executable_materialization_ready" -NotePropertyValue $true -Force

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
    proof_id = "RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1"
    run_id = $RunId
    status = "PASS"
    source_program_manifest = (Resolve-Path $ProgramManifestPath).Path
    rendered_apply_script_count = 3
    supported_recipe_kinds = $SupportedRecipeKinds
    admission_readiness_after_recipe_rendering = $Readiness.admission_decision
    report_path = $ReportPath
    next_required_capability = "generalized_generated_program_live_admission_contract_v1"
    conclusion = "Builder can now render executable generated self-build pack entry scripts from program-owned execution recipes rather than from fixture-owned hardcoded builder semantics."
}

$Proof | ConvertTo-Json -Depth 100 |
    Set-Content ".\proofs\RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1.json" -Encoding UTF8

Write-Host "RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_STATUS=PASS"
Write-Host "RECIPE_DRIVEN_RENDERED_APPLY_SCRIPT_COUNT=3"
Write-Host "RECIPE_DRIVEN_ADMISSION_READINESS=$($Readiness.admission_decision)"
Write-Host "RECIPE_DRIVEN_NEXT_REQUIRED_CAPABILITY=generalized_generated_program_live_admission_contract_v1"
Write-Host "PASS :: recipe_driven_generated_program_executable_materialization_v1 checks passed. run_id=$RunId"
