function Complete-GeneratedSelfBuildProgramExecutablePacks {
    param(
        [string]$ProgramManifestPath
    )

    if ([string]::IsNullOrWhiteSpace($ProgramManifestPath)) {
        throw "ProgramManifestPath is required."
    }
    if (-not (Test-Path $ProgramManifestPath)) {
        throw "Program manifest missing: $ProgramManifestPath"
    }

    Import-GeneratedSelfBuildPackRecipeRenderer

    $ManifestPath = (Resolve-Path $ProgramManifestPath).Path
    $ProgramRoot = Split-Path -Parent $ManifestPath
    $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") {
        throw "Program manifest status must be PROGRAM_PACKAGE_MATERIALIZED."
    }
    if (@("NOT_ADMITTED_YET", "ADMITTED_TO_LIVE_EXECUTION") -notcontains [string]$Manifest.admission_status) {
        throw "Program manifest admission_status must be NOT_ADMITTED_YET or ADMITTED_TO_LIVE_EXECUTION."
    }

    $PacksRoot = Join-Path $ProgramRoot "packs"
    $TasksRoot = Join-Path $ProgramRoot "tasks"
    $PatchesRoot = Join-Path $ProgramRoot "patches"
    $RecipesRoot = Join-Path $ProgramRoot "execution_recipes"

    foreach ($RequiredPath in @($PacksRoot, $TasksRoot, $PatchesRoot, $RecipesRoot)) {
        if (-not (Test-Path $RequiredPath)) {
            throw "Generated program path missing: $RequiredPath"
        }
    }

    $RegistryPatchPath = Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json"
    $RoadmapPatchPath = Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json"
    $QueueSeedPath = Join-Path $PatchesRoot "TASK_QUEUE_SEED.json"

    foreach ($PatchPath in @($RegistryPatchPath, $RoadmapPatchPath, $QueueSeedPath)) {
        if (-not (Test-Path $PatchPath)) {
            throw "Generated program patch missing: $PatchPath"
        }
    }

    $RegistryPatch = Get-Content $RegistryPatchPath -Raw | ConvertFrom-Json
    $RoadmapPatch = Get-Content $RoadmapPatchPath -Raw | ConvertFrom-Json
    $QueueSeed = Get-Content $QueueSeedPath -Raw | ConvertFrom-Json

    foreach ($Patch in @($RegistryPatch, $RoadmapPatch, $QueueSeed)) {
        if ($Patch.status -ne "READY_FOR_ADMISSION") {
            throw "Generated program patch status must be READY_FOR_ADMISSION."
        }
    }

    $GeneratedPacks = @($RegistryPatch.generated_packs | Sort-Object { [int]$_.order })
    $GeneratedCapabilities = @($RoadmapPatch.generated_capabilities | Sort-Object { [int]$_.order })
    $GeneratedTasks = @($QueueSeed.generated_tasks | Sort-Object { [int]$_.order })

    if ($GeneratedPacks.Count -ne [int]$Manifest.pack_count) {
        throw "Manifest pack_count does not match generated registry patch."
    }
    if ($GeneratedCapabilities.Count -ne [int]$Manifest.capability_count) {
        throw "Manifest capability_count does not match generated roadmap patch."
    }
    if ($GeneratedTasks.Count -ne [int]$Manifest.task_count) {
        throw "Manifest task_count does not match generated task queue seed."
    }

    $MaterializedPacks = @()

    for ($Index = 0; $Index -lt $GeneratedPacks.Count; $Index++) {
        $PackPatch = $GeneratedPacks[$Index]
        $CapabilityPatch = $GeneratedCapabilities[$Index]
        $TaskSeed = $GeneratedTasks[$Index]

        if ($PackPatch.task_id -ne $TaskSeed.task_id) {
            throw "Generated pack/task order mismatch for pack $($PackPatch.pack_id)."
        }
        if ($CapabilityPatch.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated capability/task order mismatch for task $($TaskSeed.task_id)."
        }

        $PackDir = Join-Path $PacksRoot $PackPatch.pack_id
        $PackContractPath = Join-Path $PackDir "PACK.json"
        $TaskContractPath = Join-Path $TasksRoot "$($TaskSeed.task_id).json"
        $RecipePath = Join-Path $RecipesRoot "$($PackPatch.pack_id)_RECIPE.json"

        foreach ($RequiredPath in @($PackContractPath, $TaskContractPath, $RecipePath)) {
            if (-not (Test-Path $RequiredPath)) {
                throw "Generated executable materialization input missing: $RequiredPath"
            }
        }

        $PackContract = Get-Content $PackContractPath -Raw | ConvertFrom-Json
        $TaskContract = Get-Content $TaskContractPath -Raw | ConvertFrom-Json
        $Recipe = Get-Content $RecipePath -Raw | ConvertFrom-Json

        Assert-GeneratedPackRecipeConsistency `
            -PackPatch $PackPatch `
            -CapabilityPatch $CapabilityPatch `
            -TaskSeed $TaskSeed `
            -PackContract $PackContract `
            -TaskContract $TaskContract `
            -Recipe $Recipe `
            -RecipePath $RecipePath

        $ApplyScript = Render-GeneratedSelfBuildPackApplyFromRecipe -RecipePath $RecipePath
        $ApplyPath = Join-Path $PackDir "APPLY.ps1"
        $ApplyScript | Set-Content $ApplyPath -Encoding UTF8

        $MaterializedPacks += [pscustomobject]@{
            order = [int]$PackPatch.order
            pack_id = [string]$PackPatch.pack_id
            task_id = [string]$TaskSeed.task_id
            capability_id = [string]$TaskSeed.capability_id
            semantic_role = [string]$Recipe.semantic_role
            recipe_kind = [string]$Recipe.recipe_kind
            recipe_path = (Resolve-Path $RecipePath).Path
            apply_script_path = (Resolve-Path $ApplyPath).Path
        }
    }

    return [pscustomobject]@{
        status = "PASS"
        manifest_path = $ManifestPath
        program_root = $ProgramRoot
        materialized_apply_script_count = @($MaterializedPacks).Count
        materialized_packs = @($MaterializedPacks)
    }
}

function Import-GeneratedSelfBuildPackRecipeRenderer {
    if (Get-Command -Name Render-GeneratedSelfBuildPackApplyFromRecipe -ErrorAction SilentlyContinue) {
        return
    }

    $CandidateRoots = @()
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $CandidateRoots += $PSScriptRoot
    }
    $CandidateRoots += (Join-Path (Get-Location).Path "modules")

    foreach ($Root in $CandidateRoots) {
        $RendererPath = Join-Path $Root "render_generated_self_build_pack_apply_from_recipe.ps1"
        if (Test-Path $RendererPath) {
            . $RendererPath
            return
        }
    }

    throw "Recipe-driven generated APPLY renderer module is missing."
}

function Assert-GeneratedPackRecipeConsistency {
    param(
        [object]$PackPatch,
        [object]$CapabilityPatch,
        [object]$TaskSeed,
        [object]$PackContract,
        [object]$TaskContract,
        [object]$Recipe,
        [string]$RecipePath
    )

    if ($PackContract.pack_id -ne $PackPatch.pack_id) {
        throw "Generated pack contract id mismatch for $($PackPatch.pack_id)."
    }
    if ($PackContract.task_id -ne $PackPatch.task_id) {
        throw "Generated pack contract task id mismatch for $($PackPatch.pack_id)."
    }
    if ($PackContract.entry_script -ne "APPLY.ps1") {
        throw "Generated pack entry_script must be APPLY.ps1 for $($PackPatch.pack_id)."
    }
    if ($PackContract.shell -ne "PowerShell") {
        throw "Generated pack shell must be PowerShell for $($PackPatch.pack_id)."
    }
    if ($TaskContract.task_id -ne $TaskSeed.task_id) {
        throw "Generated task contract id mismatch for $($TaskSeed.task_id)."
    }
    if ($TaskContract.capability_id -ne $TaskSeed.capability_id) {
        throw "Generated task contract capability mismatch for $($TaskSeed.task_id)."
    }
    if ($TaskContract.expected_gate -ne $TaskSeed.expected_gate) {
        throw "Generated task contract expected gate mismatch for $($TaskSeed.task_id)."
    }

    foreach ($Field in @("pack_id", "task_id", "capability_id", "expected_gate", "semantic_role", "recipe_kind")) {
        if (-not $Recipe.PSObject.Properties.Name.Contains($Field)) {
            throw "Generated execution recipe missing $Field at $RecipePath"
        }
        if ([string]::IsNullOrWhiteSpace([string]$Recipe.$Field)) {
            throw "Generated execution recipe field $Field must not be empty at $RecipePath"
        }
    }

    if ($Recipe.pack_id -ne $PackPatch.pack_id) {
        throw "Generated execution recipe pack id mismatch at $RecipePath."
    }
    if ($Recipe.task_id -ne $TaskSeed.task_id) {
        throw "Generated execution recipe task id mismatch at $RecipePath."
    }
    if ($Recipe.capability_id -ne $TaskSeed.capability_id) {
        throw "Generated execution recipe capability id mismatch at $RecipePath."
    }
    if ($Recipe.expected_gate -ne $TaskSeed.expected_gate) {
        throw "Generated execution recipe expected gate mismatch at $RecipePath."
    }
    if ($Recipe.semantic_role -ne $CapabilityPatch.semantic_role) {
        throw "Generated execution recipe semantic role mismatch at $RecipePath."
    }
}
