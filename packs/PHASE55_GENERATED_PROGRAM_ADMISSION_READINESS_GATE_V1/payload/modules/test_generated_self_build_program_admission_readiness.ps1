function Test-GeneratedSelfBuildProgramAdmissionReadiness {
    param(
        [string]$ProgramManifestPath
    )

    if ([string]::IsNullOrWhiteSpace($ProgramManifestPath)) {
        throw "ProgramManifestPath is required."
    }

    if (-not (Test-Path $ProgramManifestPath)) {
        throw "Program manifest missing: $ProgramManifestPath"
    }

    $ManifestPath = (Resolve-Path $ProgramManifestPath).Path
    $ProgramRoot = Split-Path -Parent $ManifestPath

    $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") {
        throw "Program manifest status must be PROGRAM_PACKAGE_MATERIALIZED."
    }
    if ($Manifest.admission_status -ne "NOT_ADMITTED_YET") {
        throw "Program manifest admission_status must be NOT_ADMITTED_YET."
    }

    $PatchesRoot = Join-Path $ProgramRoot "patches"
    $PacksRoot = Join-Path $ProgramRoot "packs"
    $TasksRoot = Join-Path $ProgramRoot "tasks"

    $PatchPaths = [ordered]@{
        pack_registry = Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json"
        roadmap = Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json"
        task_queue = Join-Path $PatchesRoot "TASK_QUEUE_SEED.json"
    }

    foreach ($Name in $PatchPaths.Keys) {
        if (-not (Test-Path $PatchPaths[$Name])) {
            throw "Program admission patch missing: $($PatchPaths[$Name])"
        }
    }

    $PackRegistryPatch = Get-Content $PatchPaths.pack_registry -Raw | ConvertFrom-Json
    $RoadmapPatch = Get-Content $PatchPaths.roadmap -Raw | ConvertFrom-Json
    $TaskQueueSeed = Get-Content $PatchPaths.task_queue -Raw | ConvertFrom-Json

    foreach ($Patch in @($PackRegistryPatch, $RoadmapPatch, $TaskQueueSeed)) {
        if ($Patch.status -ne "READY_FOR_ADMISSION") {
            throw "Program admission patch status must be READY_FOR_ADMISSION."
        }
    }

    if (-not (Test-Path $PacksRoot)) {
        throw "Generated packs root missing: $PacksRoot"
    }
    if (-not (Test-Path $TasksRoot)) {
        throw "Generated tasks root missing: $TasksRoot"
    }

    $PackContractFiles = @(Get-ChildItem -Path $PacksRoot -Recurse -Filter "PACK.json" -File)
    $TaskContractFiles = @(Get-ChildItem -Path $TasksRoot -Filter "*.json" -File)

    if ([int]$Manifest.pack_count -ne $PackContractFiles.Count) {
        throw "Manifest pack_count does not match physical generated pack contracts."
    }
    if ([int]$Manifest.task_count -ne $TaskContractFiles.Count) {
        throw "Manifest task_count does not match physical generated task contracts."
    }
    if ([int]$Manifest.capability_count -ne @($RoadmapPatch.generated_capabilities).Count) {
        throw "Manifest capability_count does not match roadmap patch capabilities."
    }
    if ([int]$Manifest.pack_count -ne @($PackRegistryPatch.generated_packs).Count) {
        throw "Manifest pack_count does not match registry patch packs."
    }
    if ([int]$Manifest.task_count -ne @($TaskQueueSeed.generated_tasks).Count) {
        throw "Manifest task_count does not match queue seed tasks."
    }

    $BlockedPacks = @()
    $ExecutablePackCount = 0

    foreach ($PackFile in $PackContractFiles) {
        $Pack = Get-Content $PackFile.FullName -Raw | ConvertFrom-Json
        foreach ($Field in @("pack_id", "task_id", "entry_script", "shell")) {
            if (-not $Pack.PSObject.Properties.Name.Contains($Field)) {
                throw "Generated pack contract missing field $Field at $($PackFile.FullName)"
            }
            if ([string]::IsNullOrWhiteSpace([string]$Pack.$Field)) {
                throw "Generated pack contract field $Field must not be empty at $($PackFile.FullName)"
            }
        }

        $ExpectedEntryScript = [string]$Pack.entry_script
        $EntryScriptPath = Join-Path $PackFile.DirectoryName $ExpectedEntryScript
        if ($ExpectedEntryScript -eq "APPLY.ps1" -and -not (Test-Path $EntryScriptPath)) {
            $BlockedPacks += [pscustomobject]@{
                pack_id = [string]$Pack.pack_id
                expected_entry_script = $ExpectedEntryScript
                missing_path = $EntryScriptPath
            }
        }
        else {
            $ExecutablePackCount++
        }
    }

    foreach ($TaskFile in $TaskContractFiles) {
        $Task = Get-Content $TaskFile.FullName -Raw | ConvertFrom-Json
        foreach ($Field in @("task_id", "capability_id", "expected_gate")) {
            if (-not $Task.PSObject.Properties.Name.Contains($Field)) {
                throw "Generated task contract missing field $Field at $($TaskFile.FullName)"
            }
            if ([string]::IsNullOrWhiteSpace([string]$Task.$Field)) {
                throw "Generated task contract field $Field must not be empty at $($TaskFile.FullName)"
            }
        }
    }

    $AdmissionDecision = "ADMISSION_READY"
    $NextRequiredCapability = ""
    if (@($BlockedPacks).Count -gt 0) {
        $AdmissionDecision = "ADMISSION_BLOCKED_NON_EXECUTABLE_PACKS"
        $NextRequiredCapability = "executable_generated_program_materialization_v1"
    }

    return [pscustomobject]@{
        status = "PASS"
        admission_decision = $AdmissionDecision
        executable_pack_count = $ExecutablePackCount
        blocked_pack_count = @($BlockedPacks).Count
        blocked_packs = @($BlockedPacks)
        manifest_path = $ManifestPath
        program_root = $ProgramRoot
        next_required_capability = $NextRequiredCapability
        observed_counts = [ordered]@{
            pack_count = $PackContractFiles.Count
            task_count = $TaskContractFiles.Count
            capability_count = @($RoadmapPatch.generated_capabilities).Count
        }
    }
}
