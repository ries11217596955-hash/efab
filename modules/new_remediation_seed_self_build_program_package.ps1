function New-RemediationSeedSelfBuildProgramPackage {
    param(
        [object]$Blueprint,
        [string]$OutputRoot
    )

    if ($null -eq $Blueprint) {
        throw "Blueprint is required."
    }

    if ($Blueprint.status -ne "BLUEPRINT_READY") {
        throw "Blueprint status must be BLUEPRINT_READY."
    }

    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        throw "OutputRoot is required."
    }

    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

    $ProgramRoot = Join-Path $OutputRoot $Blueprint.target.profile_id
    $PacksRoot = Join-Path $ProgramRoot "packs"
    $TasksRoot = Join-Path $ProgramRoot "tasks"
    $PatchesRoot = Join-Path $ProgramRoot "patches"

    foreach ($Dir in @($ProgramRoot, $PacksRoot, $TasksRoot, $PatchesRoot)) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    }

    foreach ($Pack in @($Blueprint.generated_packs)) {
        $PackDir = Join-Path $PacksRoot $Pack.pack_id
        New-Item -ItemType Directory -Force -Path $PackDir | Out-Null

        $PackContract = [ordered]@{
            pack_id = $Pack.pack_id
            task_id = $Pack.task_id
            entry_script = "APPLY.ps1"
            shell = "PowerShell"
            materialization_status = "SYNTHESIZED_NOT_ADMITTED"
        }

        $PackContract | ConvertTo-Json -Depth 100 |
            Set-Content (Join-Path $PackDir "PACK.json") -Encoding UTF8
    }

    foreach ($Task in @($Blueprint.generated_tasks)) {
        $TaskContract = [ordered]@{
            task_id = $Task.task_id
            capability_id = $Task.capability_id
            objective = "Generated remediation self-build task for semantic role derived from remediation program seed."
            expected_gate = $Task.expected_gate
            execution_kind = "GENERATED_PROGRAM_PLACEHOLDER"
            materialization_status = "SYNTHESIZED_NOT_ADMITTED"
        }

        $TaskContract | ConvertTo-Json -Depth 100 |
            Set-Content (Join-Path $TasksRoot "$($Task.task_id).json") -Encoding UTF8
    }

    $RegistryPatch = [ordered]@{
        patch_kind = "PACK_REGISTRY_APPEND"
        status = "READY_FOR_ADMISSION"
        generated_packs = @($Blueprint.generated_packs)
    }

    $RoadmapPatch = [ordered]@{
        patch_kind = "CAPABILITY_ROADMAP_APPEND"
        status = "READY_FOR_ADMISSION"
        generated_capabilities = @($Blueprint.generated_capabilities)
    }

    $QueueSeed = [ordered]@{
        patch_kind = "TASK_QUEUE_SEED"
        status = "READY_FOR_ADMISSION"
        active_task_id = $Blueprint.generated_tasks[0].task_id
        generated_tasks = @($Blueprint.generated_tasks)
    }

    $RegistryPatch | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json") -Encoding UTF8

    $RoadmapPatch | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json") -Encoding UTF8

    $QueueSeed | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $PatchesRoot "TASK_QUEUE_SEED.json") -Encoding UTF8

    $Manifest = [ordered]@{
        manifest_id = "$($Blueprint.blueprint_id)_MATERIALIZED_PROGRAM"
        status = "PROGRAM_PACKAGE_MATERIALIZED"
        target_profile_id = $Blueprint.target.profile_id
        target_agent_kind = $Blueprint.target.agent_kind
        blueprint_id = $Blueprint.blueprint_id
        program_root = $ProgramRoot
        pack_count = @($Blueprint.generated_packs).Count
        task_count = @($Blueprint.generated_tasks).Count
        capability_count = @($Blueprint.generated_capabilities).Count
        packs_root = $PacksRoot
        tasks_root = $TasksRoot
        patches_root = $PatchesRoot
        admission_status = "NOT_ADMITTED_YET"
    }

    $ManifestPath = Join-Path $ProgramRoot "SELF_BUILD_PROGRAM_MANIFEST.json"

    $Manifest | ConvertTo-Json -Depth 100 |
        Set-Content $ManifestPath -Encoding UTF8

    return [pscustomobject]@{
        status = "PASS"
        program_root = $ProgramRoot
        manifest_path = $ManifestPath
        packs_root = $PacksRoot
        tasks_root = $TasksRoot
        patches_root = $PatchesRoot
        pack_count = @($Blueprint.generated_packs).Count
        task_count = @($Blueprint.generated_tasks).Count
        capability_count = @($Blueprint.generated_capabilities).Count
    }
}
