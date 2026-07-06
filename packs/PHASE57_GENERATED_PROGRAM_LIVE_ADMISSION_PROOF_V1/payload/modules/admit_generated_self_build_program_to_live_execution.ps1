function Admit-GeneratedSelfBuildProgramToLiveExecution {
    param(
        [string]$ProgramManifestPath
    )

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
    $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    if ($Manifest.status -ne "PROGRAM_PACKAGE_MATERIALIZED") {
        throw "Program manifest status must be PROGRAM_PACKAGE_MATERIALIZED."
    }
    if ($Manifest.admission_status -ne "NOT_ADMITTED_YET") {
        throw "Program manifest admission_status must be NOT_ADMITTED_YET."
    }
    if ($Manifest.target_profile_id -ne "monitoring_agent_v1") {
        throw "PHASE57 live admission currently supports monitoring_agent_v1 only."
    }

    $ReadinessModulePath = Join-Path $RepoRoot "modules/test_generated_self_build_program_admission_readiness.ps1"
    if (-not (Test-Path $ReadinessModulePath)) {
        throw "Admission readiness evaluator missing: $ReadinessModulePath"
    }

    . $ReadinessModulePath

    $Readiness = Test-GeneratedSelfBuildProgramAdmissionReadiness -ProgramManifestPath $ManifestPath
    if ($Readiness.status -ne "PASS") {
        throw "Admission readiness status must be PASS."
    }
    if ($Readiness.admission_decision -ne "ADMISSION_READY") {
        throw "Admission readiness decision must be ADMISSION_READY."
    }
    if ([int]$Readiness.executable_pack_count -ne 3) {
        throw "Admission readiness executable_pack_count must be 3."
    }
    if ([int]$Readiness.blocked_pack_count -ne 0) {
        throw "Admission readiness blocked_pack_count must be 0."
    }

    $PatchesRoot = Join-Path $ProgramRoot "patches"
    $PacksRoot = Join-Path $ProgramRoot "packs"
    $TasksRoot = Join-Path $ProgramRoot "tasks"

    $RegistryPatchPath = Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json"
    $RoadmapPatchPath = Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json"
    $QueueSeedPath = Join-Path $PatchesRoot "TASK_QUEUE_SEED.json"

    foreach ($Path in @($RegistryPatchPath, $RoadmapPatchPath, $QueueSeedPath)) {
        if (-not (Test-Path $Path)) {
            throw "Generated admission patch missing: $Path"
        }
    }

    $RegistryPatch = Get-Content $RegistryPatchPath -Raw | ConvertFrom-Json
    $RoadmapPatch = Get-Content $RoadmapPatchPath -Raw | ConvertFrom-Json
    $QueueSeed = Get-Content $QueueSeedPath -Raw | ConvertFrom-Json

    foreach ($Patch in @($RegistryPatch, $RoadmapPatch, $QueueSeed)) {
        if ($Patch.status -ne "READY_FOR_ADMISSION") {
            throw "Generated admission patch status must be READY_FOR_ADMISSION."
        }
    }

    $GeneratedPacks = @($RegistryPatch.generated_packs | Sort-Object { [int]$_.order })
    $GeneratedCapabilities = @($RoadmapPatch.generated_capabilities | Sort-Object { [int]$_.order })
    $GeneratedTasks = @($QueueSeed.generated_tasks | Sort-Object { [int]$_.order })

    if ($GeneratedPacks.Count -ne 3) {
        throw "Expected exactly three generated packs."
    }
    if ($GeneratedCapabilities.Count -ne 3) {
        throw "Expected exactly three generated capabilities."
    }
    if ($GeneratedTasks.Count -ne 3) {
        throw "Expected exactly three generated tasks."
    }
    if ([int]$Manifest.pack_count -ne $GeneratedPacks.Count) {
        throw "Manifest pack_count does not match generated registry patch."
    }
    if ([int]$Manifest.capability_count -ne $GeneratedCapabilities.Count) {
        throw "Manifest capability_count does not match generated roadmap patch."
    }
    if ([int]$Manifest.task_count -ne $GeneratedTasks.Count) {
        throw "Manifest task_count does not match generated task queue seed."
    }
    if ($QueueSeed.active_task_id -ne $GeneratedTasks[0].task_id) {
        throw "Generated queue seed active_task_id must point to the first generated task."
    }

    $RegistryPath = Join-Path $RepoRoot "packs/registry.json"
    $RoadmapPath = Join-Path $RepoRoot "CAPABILITY_ROADMAP.json"
    $QueuePath = Join-Path $RepoRoot "TASK_QUEUE.json"
    $StatePath = Join-Path $RepoRoot "GENESIS_STATE.json"

    $Registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json
    $Roadmap = Get-Content $RoadmapPath -Raw | ConvertFrom-Json
    $Queue = Get-Content $QueuePath -Raw | ConvertFrom-Json
    $State = Get-Content $StatePath -Raw | ConvertFrom-Json

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
    $GeneratedPhasePrefix = "GENERATED_MONITORING_AGENT_V1_PHASE"

    for ($Index = 0; $Index -lt $GeneratedPacks.Count; $Index++) {
        $PackPatch = $GeneratedPacks[$Index]
        $CapabilityPatch = $GeneratedCapabilities[$Index]
        $TaskSeed = $GeneratedTasks[$Index]
        $Order = [int]$PackPatch.order

        if ($CapabilityPatch.order -ne $Order) {
            throw "Generated capability order mismatch for $($CapabilityPatch.capability_id)."
        }
        if ($TaskSeed.order -ne $Order) {
            throw "Generated task order mismatch for $($TaskSeed.task_id)."
        }
        if ($PackPatch.task_id -ne $TaskSeed.task_id) {
            throw "Generated pack/task id mismatch for pack $($PackPatch.pack_id)."
        }
        if ($CapabilityPatch.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated capability/task id mismatch for task $($TaskSeed.task_id)."
        }

        $PackContractPath = "self_build_programs/generated/monitoring_agent_v1/packs/$($PackPatch.pack_id)/PACK.json"
        $EntryScriptPath = "self_build_programs/generated/monitoring_agent_v1/packs/$($PackPatch.pack_id)/APPLY.ps1"
        $TaskContractPath = "self_build_programs/generated/monitoring_agent_v1/tasks/$($TaskSeed.task_id).json"

        foreach ($RelativePath in @($PackContractPath, $EntryScriptPath, $TaskContractPath)) {
            $AbsolutePath = Join-Path $RepoRoot $RelativePath
            if (-not (Test-Path $AbsolutePath)) {
                throw "Generated live admission target missing: $RelativePath"
            }
        }

        $PackContract = Get-Content (Join-Path $RepoRoot $PackContractPath) -Raw | ConvertFrom-Json
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

        $TaskContract = Get-Content (Join-Path $RepoRoot $TaskContractPath) -Raw | ConvertFrom-Json
        if ($TaskContract.task_id -ne $TaskSeed.task_id) {
            throw "Generated task contract id mismatch: $TaskContractPath"
        }
        if ($TaskContract.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated task contract capability mismatch: $TaskContractPath"
        }

        $Status = "QUEUED"
        if ($Index -eq 0) {
            $Status = "ACTIVE"
        }

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

    return [pscustomobject]@{
        status = "PASS"
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
