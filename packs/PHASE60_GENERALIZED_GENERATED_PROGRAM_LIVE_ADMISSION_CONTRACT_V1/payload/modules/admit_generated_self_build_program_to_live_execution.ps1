function Admit-GeneratedSelfBuildProgramToLiveExecution {
    param(
        [string]$ProgramManifestPath,
        [switch]$ContractValidationOnly
    )

    function ConvertTo-RepoRelativePath {
        param(
            [string]$BasePath,
            [string]$TargetPath
        )

        $BaseFullPath = [System.IO.Path]::GetFullPath($BasePath)
        $TargetFullPath = [System.IO.Path]::GetFullPath($TargetPath)
        $DirectorySeparator = [System.IO.Path]::DirectorySeparatorChar

        if (-not $BaseFullPath.EndsWith([string]$DirectorySeparator)) {
            $BaseFullPath = "$BaseFullPath$DirectorySeparator"
        }

        $BaseUri = [System.Uri]$BaseFullPath
        $TargetUri = [System.Uri]$TargetFullPath
        $RelativeUri = $BaseUri.MakeRelativeUri($TargetUri)

        return [System.Uri]::UnescapeDataString($RelativeUri.ToString()).Replace('/', $DirectorySeparator)
    }

    function Read-JsonFile {
        param([string]$Path)
        return Get-Content $Path -Raw | ConvertFrom-Json
    }

    if ([string]::IsNullOrWhiteSpace($ProgramManifestPath)) {
        throw "ProgramManifestPath is required."
    }

    if (-not (Test-Path $ProgramManifestPath)) {
        throw "Program manifest missing: $ProgramManifestPath"
    }

    $RepoRoot = (Resolve-Path ".").Path
    foreach ($RequiredRootFile in @("GENESIS_STATE.json", "CAPABILITY_ROADMAP.json", "TASK_QUEUE.json", "packs/registry.json")) {
        $RequiredPath = Join-Path $RepoRoot $RequiredRootFile
        if (-not (Test-Path $RequiredPath)) {
            throw "Repo root file missing: $RequiredPath"
        }
    }

    $ManifestPath = (Resolve-Path $ProgramManifestPath).Path
    $ProgramRoot = Split-Path -Parent $ManifestPath
    $ProgramRootRelative = ConvertTo-RepoRelativePath -BasePath $RepoRoot -TargetPath $ProgramRoot
    $ProgramRootRelativeForRepo = ($ProgramRootRelative -replace "\\", "/").TrimEnd("/")

    if ($ProgramRootRelativeForRepo -eq "" -or $ProgramRootRelativeForRepo -eq "." -or $ProgramRootRelativeForRepo.StartsWith("../")) {
        throw "Program root must resolve inside repo root: $ProgramRoot"
    }

    $Manifest = Read-JsonFile $ManifestPath

    if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") {
        throw "Program manifest status must be PROGRAM_PACKAGE_MATERIALIZED."
    }
    if (-not $ContractValidationOnly) {
        if ($Manifest.admission_status -ne "NOT_ADMITTED_YET") {
            throw "Program manifest admission_status must be NOT_ADMITTED_YET."
        }
    }

    $TargetProfileId = [string]$Manifest.target_profile_id
    $TargetAgentKind = [string]$Manifest.target_agent_kind

    if ([string]::IsNullOrWhiteSpace($TargetProfileId)) {
        throw "Program manifest target_profile_id must not be empty."
    }
    if ([string]::IsNullOrWhiteSpace($TargetAgentKind)) {
        throw "Program manifest target_agent_kind must not be empty."
    }

    $PatchesRoot = Join-Path $ProgramRoot "patches"
    $PacksRoot = Join-Path $ProgramRoot "packs"
    $TasksRoot = Join-Path $ProgramRoot "tasks"
    $RecipesRoot = Join-Path $ProgramRoot "execution_recipes"

    foreach ($RequiredProgramRoot in @($PatchesRoot, $PacksRoot, $TasksRoot, $RecipesRoot)) {
        if (-not (Test-Path $RequiredProgramRoot)) {
            throw "Generated program root component missing: $RequiredProgramRoot"
        }
    }

    $RegistryPatchPath = Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json"
    $RoadmapPatchPath = Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json"
    $QueueSeedPath = Join-Path $PatchesRoot "TASK_QUEUE_SEED.json"

    foreach ($Path in @($RegistryPatchPath, $RoadmapPatchPath, $QueueSeedPath)) {
        if (-not (Test-Path $Path)) {
            throw "Generated admission patch missing: $Path"
        }
    }

    $RegistryPatch = Read-JsonFile $RegistryPatchPath
    $RoadmapPatch = Read-JsonFile $RoadmapPatchPath
    $QueueSeed = Read-JsonFile $QueueSeedPath

    foreach ($Patch in @($RegistryPatch, $RoadmapPatch, $QueueSeed)) {
        if ($Patch.status -ne "READY_FOR_ADMISSION") {
            throw "Generated admission patch status must be READY_FOR_ADMISSION."
        }
    }

    $GeneratedPacks = @($RegistryPatch.generated_packs | Sort-Object { [int]$_.order })
    $GeneratedCapabilities = @($RoadmapPatch.generated_capabilities | Sort-Object { [int]$_.order })
    $GeneratedTasks = @($QueueSeed.generated_tasks | Sort-Object { [int]$_.order })

    $PackCount = $GeneratedPacks.Count
    $CapabilityCount = $GeneratedCapabilities.Count
    $TaskCount = $GeneratedTasks.Count

    if ($PackCount -le 0) {
        throw "Generated registry patch must include at least one generated pack."
    }
    if ($CapabilityCount -ne $PackCount) {
        throw "Generated capability count must match generated pack count."
    }
    if ($TaskCount -ne $PackCount) {
        throw "Generated task count must match generated pack count."
    }
    if ($PackCount -ne [int]$Manifest.pack_count) {
        throw "Manifest pack_count ($($Manifest.pack_count)) does not match generated registry patch ($PackCount)."
    }
    if ($CapabilityCount -ne [int]$Manifest.capability_count) {
        throw "Manifest capability_count ($($Manifest.capability_count)) does not match generated roadmap patch ($CapabilityCount)."
    }
    if ($TaskCount -ne [int]$Manifest.task_count) {
        throw "Manifest task_count ($($Manifest.task_count)) does not match generated task queue seed ($TaskCount)."
    }
    if ($QueueSeed.active_task_id -ne $GeneratedTasks[0].task_id) {
        throw "Generated queue seed active_task_id must point to the first generated task."
    }

    $PackContractsById = @{}
    $TaskContractsById = @{}
    $RecipeContractsByPackId = @{}
    $BlockedPacks = @()
    $ExecutablePackCount = 0

    for ($Index = 0; $Index -lt $PackCount; $Index++) {
        $PackPatch = $GeneratedPacks[$Index]
        $CapabilityPatch = $GeneratedCapabilities[$Index]
        $TaskSeed = $GeneratedTasks[$Index]
        $Order = [int]$PackPatch.order

        if ([int]$CapabilityPatch.order -ne $Order) {
            throw "Generated capability order mismatch for $($CapabilityPatch.capability_id)."
        }
        if ([int]$TaskSeed.order -ne $Order) {
            throw "Generated task order mismatch for $($TaskSeed.task_id)."
        }
        if ($PackPatch.task_id -ne $TaskSeed.task_id) {
            throw "Generated pack/task id mismatch for pack $($PackPatch.pack_id)."
        }
        if ($CapabilityPatch.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated capability/task id mismatch for task $($TaskSeed.task_id)."
        }

        $PackRoot = Join-Path $PacksRoot $PackPatch.pack_id
        $PackContractPath = Join-Path $PackRoot "PACK.json"
        $TaskContractPath = Join-Path $TasksRoot "$($TaskSeed.task_id).json"
        $RecipePath = Join-Path $RecipesRoot "$($PackPatch.pack_id)_RECIPE.json"

        foreach ($RequiredGeneratedArtifact in @($PackContractPath, $TaskContractPath, $RecipePath)) {
            if (-not (Test-Path $RequiredGeneratedArtifact)) {
                throw "Generated admission target missing: $RequiredGeneratedArtifact"
            }
        }

        $PackContract = Read-JsonFile $PackContractPath
        if ($PackContract.pack_id -ne $PackPatch.pack_id) {
            throw "Generated pack contract id mismatch: $PackContractPath"
        }
        if ($PackContract.task_id -ne $TaskSeed.task_id) {
            throw "Generated pack contract task mismatch: $PackContractPath"
        }
        if ($PackContract.entry_script -ne "APPLY.ps1") {
            throw "Generated pack contract entry_script must be APPLY.ps1: $PackContractPath"
        }
        if ($PackContract.shell -ne "PowerShell") {
            throw "Generated pack contract shell must be PowerShell: $PackContractPath"
        }

        $EntryScriptPath = Join-Path $PackRoot ([string]$PackContract.entry_script)
        if (-not (Test-Path $EntryScriptPath)) {
            $BlockedPacks += [pscustomobject][ordered]@{
                pack_id = [string]$PackPatch.pack_id
                expected_entry_script = [string]$PackContract.entry_script
                missing_path = $EntryScriptPath
            }
        }
        else {
            $ExecutablePackCount++
        }

        $TaskContract = Read-JsonFile $TaskContractPath
        if ($TaskContract.task_id -ne $TaskSeed.task_id) {
            throw "Generated task contract id mismatch: $TaskContractPath"
        }
        if ($TaskContract.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated task contract capability mismatch: $TaskContractPath"
        }
        if ($TaskContract.expected_gate -ne $TaskSeed.expected_gate) {
            throw "Generated task contract expected_gate mismatch: $TaskContractPath"
        }

        $RecipeContract = Read-JsonFile $RecipePath
        if ($RecipeContract.pack_id -ne $PackPatch.pack_id) {
            throw "Generated execution recipe pack id mismatch: $RecipePath"
        }
        if ($RecipeContract.task_id -ne $TaskSeed.task_id) {
            throw "Generated execution recipe task id mismatch: $RecipePath"
        }
        if ($RecipeContract.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated execution recipe capability id mismatch: $RecipePath"
        }
        if ($RecipeContract.target_profile_id -ne $TargetProfileId) {
            throw "Generated execution recipe target_profile_id mismatch: $RecipePath"
        }
        if ($RecipeContract.target_agent_kind -ne $TargetAgentKind) {
            throw "Generated execution recipe target_agent_kind mismatch: $RecipePath"
        }

        $PackContractsById[[string]$PackPatch.pack_id] = $PackContract
        $TaskContractsById[[string]$TaskSeed.task_id] = $TaskContract
        $RecipeContractsByPackId[[string]$PackPatch.pack_id] = $RecipeContract
    }

    $ComputedAdmissionDecision = if (@($BlockedPacks).Count -eq 0) { "ADMISSION_READY" } else { "ADMISSION_BLOCKED_NON_EXECUTABLE_PACKS" }
    $Readiness = [pscustomobject][ordered]@{
        status = "PASS"
        admission_decision = $ComputedAdmissionDecision
        executable_pack_count = $ExecutablePackCount
        blocked_pack_count = @($BlockedPacks).Count
        blocked_packs = @($BlockedPacks)
        manifest_path = $ManifestPath
        program_root = $ProgramRoot
    }

    if (-not $ContractValidationOnly) {
        $ReadinessModulePath = Join-Path $RepoRoot "modules/test_generated_self_build_program_admission_readiness.ps1"
        if (-not (Test-Path $ReadinessModulePath)) {
            throw "Admission readiness evaluator missing: $ReadinessModulePath"
        }

        . $ReadinessModulePath

        $Readiness = Test-GeneratedSelfBuildProgramAdmissionReadiness -ProgramManifestPath $ManifestPath
        if ($Readiness.status -ne "PASS") {
            throw "Admission readiness status must be PASS."
        }
    }

    if ($Readiness.admission_decision -ne "ADMISSION_READY") {
        throw "Admission readiness decision must be ADMISSION_READY."
    }
    if ([int]$Readiness.blocked_pack_count -ne 0) {
        throw "Admission readiness blocked_pack_count must be 0."
    }
    if ([int]$Readiness.executable_pack_count -ne $PackCount) {
        throw "Admission readiness executable_pack_count ($($Readiness.executable_pack_count)) does not match expected pack count ($PackCount)."
    }

    $RegistryPath = Join-Path $RepoRoot "packs/registry.json"
    $RoadmapPath = Join-Path $RepoRoot "CAPABILITY_ROADMAP.json"
    $QueuePath = Join-Path $RepoRoot "TASK_QUEUE.json"
    $StatePath = Join-Path $RepoRoot "GENESIS_STATE.json"

    $Registry = Read-JsonFile $RegistryPath
    $Roadmap = Read-JsonFile $RoadmapPath
    $Queue = Read-JsonFile $QueuePath
    $State = Read-JsonFile $StatePath

    $DuplicatePackCount = 0
    foreach ($PackPatch in $GeneratedPacks) {
        if (@($Registry.packs | Where-Object { $_.pack_id -eq $PackPatch.pack_id }).Count -gt 0) {
            $DuplicatePackCount++
        }
    }

    $DuplicateCapabilityCount = 0
    foreach ($CapabilityPatch in $GeneratedCapabilities) {
        if (@($Roadmap.capabilities | Where-Object { $_.id -eq $CapabilityPatch.capability_id }).Count -gt 0) {
            $DuplicateCapabilityCount++
        }
    }

    $DuplicateTaskCount = 0
    foreach ($TaskSeed in $GeneratedTasks) {
        if (@($Queue.tasks | Where-Object { $_.task_id -eq $TaskSeed.task_id }).Count -gt 0) {
            $DuplicateTaskCount++
        }
    }

    if ($ContractValidationOnly) {
        $AnyDuplicate = ($DuplicatePackCount + $DuplicateCapabilityCount + $DuplicateTaskCount) -gt 0
        $AllExpectedDuplicates = (
            $DuplicatePackCount -eq $PackCount -and
            $DuplicateCapabilityCount -eq $CapabilityCount -and
            $DuplicateTaskCount -eq $TaskCount
        )

        if ($AnyDuplicate -and -not $AllExpectedDuplicates) {
            throw "Duplicate guard detected partial live admission state for generated program."
        }
    }

    $FirstActivatableTaskId = [string]$GeneratedTasks[0].task_id
    $FirstActivatableCapabilityId = [string]$GeneratedCapabilities[0].capability_id

    $ValidationResult = [pscustomobject][ordered]@{
        status = "PASS"
        mode = if ($ContractValidationOnly) { "CONTRACT_VALIDATION_ONLY" } else { "LIVE_ADMISSION" }
        source_program_manifest = $ManifestPath
        program_root = $ProgramRoot
        target_profile_id = $TargetProfileId
        target_agent_kind = $TargetAgentKind
        resolved_pack_count = $PackCount
        resolved_capability_count = $CapabilityCount
        resolved_task_count = $TaskCount
        first_activatable_task_id = $FirstActivatableTaskId
        first_activatable_capability_id = $FirstActivatableCapabilityId
        admission_readiness_decision = $Readiness.admission_decision
        duplicate_guard_status = "PASS"
    }

    if ($ContractValidationOnly) {
        return $ValidationResult
    }

    $Phase57CapabilityId = "generated_program_live_admission_proof_v1"
    $Phase57TaskId = "TASK_GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1_001"

    $Phase57Capability = $Roadmap.capabilities |
        Where-Object { $_.id -eq $Phase57CapabilityId } |
        Select-Object -First 1

    $Phase57Task = $Queue.tasks |
        Where-Object { $_.task_id -eq $Phase57TaskId } |
        Select-Object -First 1

    if ($null -eq $Phase57Capability) { throw "PHASE57 capability missing from roadmap." }
    if ($Phase57Capability.status -ne "ACTIVE") { throw "PHASE57 capability must be ACTIVE before live admission." }
    if ($null -eq $Phase57Task) { throw "PHASE57 task missing from queue." }
    if ($Phase57Task.status -ne "ACTIVE") { throw "PHASE57 task must be ACTIVE before live admission." }
    if ($Queue.active_task_id -ne $Phase57TaskId) { throw "PHASE57 task must be the active task before live admission." }
    if ($State.current_phase -ne "PHASE_57") { throw "Expected state current_phase PHASE_57 before live admission." }
    if ($State.current_capability -ne $Phase57CapabilityId) { throw "Expected state current_capability $Phase57CapabilityId before live admission." }

    foreach ($PackPatch in $GeneratedPacks) {
        if (@($Registry.packs | Where-Object { $_.pack_id -eq $PackPatch.pack_id }).Count -gt 0) {
            throw "Generated pack already exists in live registry: $($PackPatch.pack_id)"
        }
    }

    foreach ($CapabilityPatch in $GeneratedCapabilities) {
        if (@($Roadmap.capabilities | Where-Object { $_.id -eq $CapabilityPatch.capability_id }).Count -gt 0) {
            throw "Generated capability already exists in live roadmap: $($CapabilityPatch.capability_id)"
        }
    }

    foreach ($TaskSeed in $GeneratedTasks) {
        if (@($Queue.tasks | Where-Object { $_.task_id -eq $TaskSeed.task_id }).Count -gt 0) {
            throw "Generated task already exists in live queue: $($TaskSeed.task_id)"
        }
    }

    $AdmittedRegistryEntries = @()
    $AdmittedCapabilities = @()
    $AdmittedTasks = @()
    $GeneratedPhasePrefix = "GENERATED_$(($TargetProfileId).ToUpper())_PHASE"

    for ($Index = 0; $Index -lt $PackCount; $Index++) {
        $PackPatch = $GeneratedPacks[$Index]
        $CapabilityPatch = $GeneratedCapabilities[$Index]
        $TaskSeed = $GeneratedTasks[$Index]
        $Order = [int]$PackPatch.order

        $RelativePackPath = "packs/$($PackPatch.pack_id)"
        $PackContractPath = "$ProgramRootRelativeForRepo/$RelativePackPath/PACK.json"
        $EntryScriptPath = "$ProgramRootRelativeForRepo/$RelativePackPath/APPLY.ps1"
        $TaskContractPath = "$ProgramRootRelativeForRepo/tasks/$($TaskSeed.task_id).json"

        $Status = if ($Index -eq 0) { "ACTIVE" } else { "QUEUED" }
        $TaskContract = $TaskContractsById[[string]$TaskSeed.task_id]

        $AdmittedRegistryEntries += [pscustomobject][ordered]@{
            pack_id = [string]$PackPatch.pack_id
            task_id = [string]$TaskSeed.task_id
            pack_contract_path = $PackContractPath
            entry_script = $EntryScriptPath
            shell = "PowerShell"
        }

        $AdmittedCapabilities += [pscustomobject][ordered]@{
            id = [string]$CapabilityPatch.capability_id
            phase = "$GeneratedPhasePrefix`_$Order"
            status = $Status
            gate = [string]$TaskSeed.expected_gate
            semantic_role = [string]$CapabilityPatch.semantic_role
            source_capability_hint = [string]$CapabilityPatch.source_capability_hint
        }

        $AdmittedTasks += [pscustomobject][ordered]@{
            task_id = [string]$TaskSeed.task_id
            capability_id = [string]$TaskSeed.capability_id
            status = $Status
            objective = [string]$TaskContract.objective
            expected_gate = [string]$TaskSeed.expected_gate
            build_task_path = $TaskContractPath
        }
    }

    foreach ($Entry in $AdmittedRegistryEntries) {
        $Registry.packs += $Entry
    }

    foreach ($Capability in $AdmittedCapabilities) {
        $Roadmap.capabilities += $Capability
    }

    foreach ($Task in $AdmittedTasks) {
        $Queue.tasks += $Task
    }

    $ActivatedTaskId = [string]$AdmittedTasks[0].task_id
    $ActivatedCapabilityId = [string]$AdmittedCapabilities[0].id

    $Phase57Capability.status = "COMPLETED"
    $Phase57Task.status = "COMPLETED"
    if (@($State.completed_capabilities) -notcontains $Phase57CapabilityId) {
        $State.completed_capabilities += $Phase57CapabilityId
    }

    $Queue.active_task_id = $ActivatedTaskId
    $State.current_phase = [string]$AdmittedCapabilities[0].phase
    $State.current_capability = $ActivatedCapabilityId
    $State.last_run_status = "PASS"
    $State | Add-Member -NotePropertyName "generated_program_live_admission_ready" -NotePropertyValue $true -Force

    $Manifest.admission_status = "ADMITTED_TO_LIVE_EXECUTION"

    $Registry | ConvertTo-Json -Depth 100 |
        Set-Content $RegistryPath -Encoding UTF8

    $Roadmap | ConvertTo-Json -Depth 100 |
        Set-Content $RoadmapPath -Encoding UTF8

    $Queue | ConvertTo-Json -Depth 100 |
        Set-Content $QueuePath -Encoding UTF8

    $State | ConvertTo-Json -Depth 100 |
        Set-Content $StatePath -Encoding UTF8

    $Manifest | ConvertTo-Json -Depth 100 |
        Set-Content $ManifestPath -Encoding UTF8

    return [pscustomobject][ordered]@{
        status = "PASS"
        mode = "LIVE_ADMISSION"
        admitted_program_manifest = $ManifestPath
        admitted_registry_entry_count = @($AdmittedRegistryEntries).Count
        admitted_capability_count = @($AdmittedCapabilities).Count
        admitted_task_count = @($AdmittedTasks).Count
        activated_task_id = $ActivatedTaskId
        activated_capability_id = $ActivatedCapabilityId
        manifest_admission_status_after = $Manifest.admission_status
        admitted_registry_entries = @($AdmittedRegistryEntries)
        admitted_capabilities = @($AdmittedCapabilities)
        admitted_tasks = @($AdmittedTasks)
    }
}
