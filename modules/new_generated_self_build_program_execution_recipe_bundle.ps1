function New-GeneratedSelfBuildProgramExecutionRecipeBundle {
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
    if ($Manifest.admission_status -ne "ADMITTED_TO_LIVE_EXECUTION") {
        throw "Program manifest admission_status must be ADMITTED_TO_LIVE_EXECUTION."
    }
    if ($Manifest.target_profile_id -ne "monitoring_agent_v1") {
        throw "PHASE58 execution recipe contract currently supports monitoring_agent_v1 only."
    }
    if ($Manifest.target_agent_kind -ne "monitoring_agent") {
        throw "PHASE58 execution recipe contract target agent kind must be monitoring_agent."
    }

    $PatchesRoot = Join-Path $ProgramRoot "patches"
    $PacksRoot = Join-Path $ProgramRoot "packs"
    $TasksRoot = Join-Path $ProgramRoot "tasks"
    $RecipeRoot = Join-Path $ProgramRoot "execution_recipes"

    foreach ($RequiredPath in @($PatchesRoot, $PacksRoot, $TasksRoot)) {
        if (-not (Test-Path $RequiredPath)) {
            throw "Generated program path missing: $RequiredPath"
        }
    }

    $PatchPaths = [ordered]@{
        pack_registry = Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json"
        roadmap = Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json"
        task_queue = Join-Path $PatchesRoot "TASK_QUEUE_SEED.json"
    }

    foreach ($PatchPath in $PatchPaths.Values) {
        if (-not (Test-Path $PatchPath)) {
            throw "Generated program patch missing: $PatchPath"
        }
    }

    $RegistryPatch = Get-Content $PatchPaths.pack_registry -Raw | ConvertFrom-Json
    $RoadmapPatch = Get-Content $PatchPaths.roadmap -Raw | ConvertFrom-Json
    $QueueSeed = Get-Content $PatchPaths.task_queue -Raw | ConvertFrom-Json

    foreach ($Patch in @($RegistryPatch, $RoadmapPatch, $QueueSeed)) {
        if ($Patch.status -ne "READY_FOR_ADMISSION") {
            throw "Generated program patch status must be READY_FOR_ADMISSION."
        }
    }

    $GeneratedPacks = @($RegistryPatch.generated_packs | Sort-Object { [int]$_.order })
    $GeneratedCapabilities = @($RoadmapPatch.generated_capabilities | Sort-Object { [int]$_.order })
    $GeneratedTasks = @($QueueSeed.generated_tasks | Sort-Object { [int]$_.order })

    if ($GeneratedPacks.Count -ne 3) { throw "Expected exactly three generated packs." }
    if ($GeneratedCapabilities.Count -ne 3) { throw "Expected exactly three generated capabilities." }
    if ($GeneratedTasks.Count -ne 3) { throw "Expected exactly three generated tasks." }

    New-Item -ItemType Directory -Force -Path $RecipeRoot | Out-Null

    $Recipes = @()
    $RecipePaths = @()

    for ($Index = 0; $Index -lt $GeneratedPacks.Count; $Index++) {
        $PackPatch = $GeneratedPacks[$Index]
        $CapabilityPatch = $GeneratedCapabilities[$Index]
        $TaskSeed = $GeneratedTasks[$Index]

        if ($PackPatch.order -ne $CapabilityPatch.order) {
            throw "Generated pack/capability order mismatch for $($PackPatch.pack_id)."
        }
        if ($PackPatch.order -ne $TaskSeed.order) {
            throw "Generated pack/task order mismatch for $($PackPatch.pack_id)."
        }
        if ($PackPatch.task_id -ne $TaskSeed.task_id) {
            throw "Generated pack/task id mismatch for $($PackPatch.pack_id)."
        }
        if ($CapabilityPatch.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated capability/task id mismatch for $($TaskSeed.task_id)."
        }

        $PackDir = Join-Path $PacksRoot $PackPatch.pack_id
        $PackContractPath = Join-Path $PackDir "PACK.json"
        $TaskContractPath = Join-Path $TasksRoot "$($TaskSeed.task_id).json"

        if (-not (Test-Path $PackContractPath)) {
            throw "Generated pack contract missing: $PackContractPath"
        }
        if (-not (Test-Path $TaskContractPath)) {
            throw "Generated task contract missing: $TaskContractPath"
        }

        $PackContract = Get-Content $PackContractPath -Raw | ConvertFrom-Json
        $TaskContract = Get-Content $TaskContractPath -Raw | ConvertFrom-Json

        if ($PackContract.pack_id -ne $PackPatch.pack_id) {
            throw "Generated pack contract id mismatch at $PackContractPath."
        }
        if ($PackContract.task_id -ne $TaskSeed.task_id) {
            throw "Generated pack contract task id mismatch at $PackContractPath."
        }
        if ($PackContract.entry_script -ne "APPLY.ps1") {
            throw "Generated pack contract entry_script must be APPLY.ps1 at $PackContractPath."
        }
        if ($PackContract.shell -ne "PowerShell") {
            throw "Generated pack contract shell must be PowerShell at $PackContractPath."
        }
        if ($TaskContract.task_id -ne $TaskSeed.task_id) {
            throw "Generated task contract id mismatch at $TaskContractPath."
        }
        if ($TaskContract.capability_id -ne $TaskSeed.capability_id) {
            throw "Generated task contract capability mismatch at $TaskContractPath."
        }

        $NextCapabilityId = ""
        $NextTaskId = ""
        if ($Index -lt ($GeneratedPacks.Count - 1)) {
            $NextCapabilityId = [string]$GeneratedTasks[$Index + 1].capability_id
            $NextTaskId = [string]$GeneratedTasks[$Index + 1].task_id
        }

        $Recipe = New-MonitoringAgentExecutionRecipe `
            -ProgramManifestPath "self_build_programs/generated/monitoring_agent_v1/SELF_BUILD_PROGRAM_MANIFEST.json" `
            -TargetProfileId ([string]$Manifest.target_profile_id) `
            -TargetAgentKind ([string]$Manifest.target_agent_kind) `
            -PackId ([string]$PackPatch.pack_id) `
            -TaskId ([string]$TaskSeed.task_id) `
            -CapabilityId ([string]$TaskSeed.capability_id) `
            -ExpectedGate ([string]$TaskSeed.expected_gate) `
            -SemanticRole ([string]$CapabilityPatch.semantic_role) `
            -NextCapabilityId $NextCapabilityId `
            -NextTaskId $NextTaskId

        $RecipePath = Join-Path $RecipeRoot "$($PackPatch.pack_id)_RECIPE.json"
        $Recipe | ConvertTo-Json -Depth 100 |
            Set-Content $RecipePath -Encoding UTF8

        $Recipes += $Recipe
        $RecipePaths += (Resolve-Path $RecipePath).Path
    }

    return [pscustomobject]@{
        status = "PASS"
        recipe_count = @($RecipePaths).Count
        recipe_paths = @($RecipePaths)
        semantic_roles = @($Recipes | ForEach-Object { $_.semantic_role })
        recipe_kinds = @($Recipes | ForEach-Object { $_.recipe_kind })
        source_program_manifest = $ManifestPath
    }
}

function New-MonitoringAgentExecutionRecipe {
    param(
        [string]$ProgramManifestPath,
        [string]$TargetProfileId,
        [string]$TargetAgentKind,
        [string]$PackId,
        [string]$TaskId,
        [string]$CapabilityId,
        [string]$ExpectedGate,
        [string]$SemanticRole,
        [string]$NextCapabilityId,
        [string]$NextTaskId
    )

    $Base = [ordered]@{
        recipe_id = "${PackId}_RECIPE"
        program_manifest_path = $ProgramManifestPath
        target_profile_id = $TargetProfileId
        target_agent_kind = $TargetAgentKind
        pack_id = $PackId
        task_id = $TaskId
        capability_id = $CapabilityId
        expected_gate = $ExpectedGate
        semantic_role = $SemanticRole
    }

    if ($SemanticRole -eq "PROFILE_MATERIALIZATION") {
        $Base.recipe_kind = "PROFILE_MATERIALIZATION_RECIPE_V1"
        $Base.input_artifacts = [ordered]@{
            program_seed_path = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"
            monitoring_profile_proof_spec_path = ".\specs\monitoring_profile_proof\MONITORING_AGENT_PROFILE_PROOF_SPEC.json"
            resolver_module_path = ".\modules\resolve_specialization_overlay.ps1"
            external_build_module_path = ".\modules\invoke_external_agent_build.ps1"
        }
        $Base.invocation_contract = [ordered]@{
            invocation_kind = "MODULE_CALLS"
            resolve_specialization_overlay = [ordered]@{
                agent_kind = "monitoring_agent"
                package_profile = "operational_specialized"
            }
            external_agent_build = [ordered]@{
                spec_path = ".\specs\monitoring_profile_proof\MONITORING_AGENT_PROFILE_PROOF_SPEC.json"
                output_root = ".\generated_agents"
                run_root_template = ".\runs\{run_id}\{pack_id}\profile_build"
                overlay_root_source = "resolved_specialization_overlay.overlay_root"
            }
        }
        $Base.expected_assertions = [ordered]@{
            program_seed_status = "PROGRAM_SEED_READY"
            expected_profile_id = "monitoring_agent_v1"
            expected_agent_kind = "monitoring_agent"
            resolver_status = "PASS"
            overlay_status = "PASS"
            operational_result = [ordered]@{
                operation = "monitoring_alert_triage_queue"
                next_alert_id = "cpu_spike"
                escalation_status = "ESCALATE"
            }
        }
        $Base.proof_contract = [ordered]@{
            proof_id = $PackId
            required_fields = @(
                "proof_id",
                "run_id",
                "status",
                "task_id",
                "capability_id",
                "expected_gate",
                "semantic_role",
                "program_seed_path",
                "selected_profile_id",
                "build_report_path",
                "validation_output",
                "specialized_operation",
                "next_alert_id",
                "escalation_status",
                "conclusion"
            )
            status = "PASS"
        }
        $Base.next_transition = [ordered]@{
            next_capability_id = $NextCapabilityId
            next_task_id = $NextTaskId
            queue_action = "ACTIVATE_NEXT_GENERATED_TASK"
        }
        return [pscustomobject]$Base
    }

    if ($SemanticRole -eq "SPECIALIZED_CLOSURE_PROOF") {
        $Base.recipe_kind = "SPECIALIZED_CLOSURE_PROOF_RECIPE_V1"
        $Base.input_artifacts = [ordered]@{
            raw_idea_path = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"
            orchestrator_path = ".\orchestrator\run.ps1"
        }
        $Base.invocation_contract = [ordered]@{
            invocation_kind = "ORCHESTRATOR_MODE"
            mode = "BUILD_FROM_RAW_IDEA_SPECIALIZED"
            raw_idea_path = ".\specs\monitoring_gap_proof\RAW_IDEA_MONITORING_GAP_PROOF.json"
            output_root = ".\generated_agents"
            report_path_template = ".\runs\{run_id}\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"
        }
        $Base.expected_assertions = [ordered]@{
            factory_report_status = "PASS"
            expected_specialization_profile_id = "monitoring_agent_v1"
            gap_report = $null
            overlay_status = "PASS"
            operational_result = [ordered]@{
                operation = "monitoring_alert_triage_queue"
                next_alert_id = "cpu_spike"
                escalation_status = "ESCALATE"
            }
        }
        $Base.proof_contract = [ordered]@{
            proof_id = $PackId
            required_fields = @(
                "proof_id",
                "run_id",
                "status",
                "task_id",
                "capability_id",
                "expected_gate",
                "semantic_role",
                "raw_idea_path",
                "factory_report_path",
                "selected_profile_id",
                "generated_package_root",
                "validation_output",
                "specialized_operation",
                "next_alert_id",
                "escalation_status",
                "conclusion"
            )
            status = "PASS"
        }
        $Base.next_transition = [ordered]@{
            next_capability_id = $NextCapabilityId
            next_task_id = $NextTaskId
            queue_action = "ACTIVATE_NEXT_GENERATED_TASK"
        }
        return [pscustomobject]$Base
    }

    if ($SemanticRole -eq "SEED_CONSUMPTION_PROOF") {
        $Base.recipe_kind = "SEED_CONSUMPTION_PROOF_RECIPE_V1"
        $Base.input_artifacts = [ordered]@{
            program_seed_path = ".\remediation_programs\MONITORING_AGENT_REMEDIATION_PROGRAM_SEED_V1.json"
            dependent_generated_profile_proof_path = ".\proofs\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1.json"
            dependent_generated_closure_proof_path = ".\proofs\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1.json"
        }
        $Base.invocation_contract = [ordered]@{
            invocation_kind = "ARTIFACT_CONSISTENCY_PROOF"
            required_prior_generated_proofs = @(
                ".\proofs\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1.json",
                ".\proofs\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1.json"
            )
        }
        $Base.expected_assertions = [ordered]@{
            seed_profile_id = "monitoring_agent_v1"
            seed_agent_kind = "monitoring_agent"
            cross_proof_consistency_rules = @(
                "profile_proof.status == PASS",
                "profile_proof.selected_profile_id == seed.candidate_profile_id",
                "closure_proof.status == PASS",
                "closure_proof.selected_profile_id == seed.candidate_profile_id",
                "closure_proof.specialized_operation == monitoring_alert_triage_queue"
            )
            expected_specialized_operation = "monitoring_alert_triage_queue"
        }
        $Base.proof_contract = [ordered]@{
            proof_id = $PackId
            required_fields = @(
                "proof_id",
                "run_id",
                "status",
                "task_id",
                "capability_id",
                "expected_gate",
                "semantic_role",
                "program_seed_path",
                "seed_profile_id",
                "seed_agent_kind",
                "profile_proof_path",
                "profile_selected_id",
                "closure_proof_path",
                "closure_selected_profile_id",
                "closure_specialized_operation",
                "conclusion"
            )
            status = "PASS"
        }
        $Base.next_transition = [ordered]@{
            next_capability_id = ""
            next_task_id = ""
            queue_action = "COMPLETE_GENERATED_PROGRAM"
        }
        return [pscustomobject]$Base
    }

    throw "Unsupported monitoring generated recipe semantic role: $SemanticRole"
}
