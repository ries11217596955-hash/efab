function Materialize-GeneratedSelfBuildProgramFromFamilyContract {
    param(
        [string]$FamilyContractPath
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    if ([string]::IsNullOrWhiteSpace($FamilyContractPath)) {
        throw "FamilyContractPath is required."
    }
    if (-not (Test-Path $FamilyContractPath)) {
        throw "Family contract missing: $FamilyContractPath"
    }

    $RepoRoot = (Resolve-Path ".").Path
    $ResolvedContractPath = (Resolve-Path $FamilyContractPath).Path
    $Contract = Get-Content $ResolvedContractPath -Raw | ConvertFrom-Json

    Assert-FamilyContractMaterializationShape -Contract $Contract -ContractPath $ResolvedContractPath

    $FamilyId = [string]$Contract.family_id
    $TargetProfileId = [string]$Contract.profile_id
    $TargetAgentKind = [string]$Contract.target_agent_kind
    $ProgramRootRelative = Normalize-ContractRelativePath -PathValue ([string]$Contract.formal_identity.program_root)
    $ProgramRoot = Resolve-RepoRelativePath -RepoRoot $RepoRoot -RelativePath $ProgramRootRelative

    Assert-ProgramRootAllowed -RepoRoot $RepoRoot -ProgramRoot $ProgramRoot -FamilyId $FamilyId

    if (Test-Path $ProgramRoot) {
        throw "Generated self-build program root already exists: $ProgramRoot"
    }

    $PatchesRootRelative = Normalize-ContractRelativePath -PathValue ([string]$Contract.formal_identity.patches_root)
    $PacksRootRelative = Normalize-ContractRelativePath -PathValue ([string]$Contract.formal_identity.packs_root)
    $TasksRootRelative = Normalize-ContractRelativePath -PathValue ([string]$Contract.formal_identity.tasks_root)
    $RecipesRootRelative = Normalize-ContractRelativePath -PathValue ([string]$Contract.formal_identity.execution_recipes_root)
    $ManifestRelative = Normalize-ContractRelativePath -PathValue ([string]$Contract.formal_identity.manifest_path)

    $ManifestPath = Resolve-RepoRelativePath -RepoRoot $RepoRoot -RelativePath $ManifestRelative
    $PatchesRoot = Resolve-RepoRelativePath -RepoRoot $RepoRoot -RelativePath $PatchesRootRelative
    $PacksRoot = Resolve-RepoRelativePath -RepoRoot $RepoRoot -RelativePath $PacksRootRelative
    $TasksRoot = Resolve-RepoRelativePath -RepoRoot $RepoRoot -RelativePath $TasksRootRelative
    $RecipesRoot = Resolve-RepoRelativePath -RepoRoot $RepoRoot -RelativePath $RecipesRootRelative

    foreach ($Directory in @($ProgramRoot, $PatchesRoot, $PacksRoot, $TasksRoot, $RecipesRoot)) {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }

    $Shape = $Contract.generated_program_shape
    $Capabilities = @($Contract.planned_generated_capabilities | Sort-Object { [int]$_.order })
    $Tasks = @($Contract.planned_generated_tasks | Sort-Object { [int]$_.order })
    $Packs = @($Contract.planned_generated_packs | Sort-Object { [int]$_.order })

    $Manifest = [ordered]@{
        manifest_id = "$(ConvertTo-IdentifierUpper -Value $FamilyId)_GENERATED_SELF_BUILD_PROGRAM_MATERIALIZED"
        status = [string]$Contract.formal_identity.program_status_target
        family_id = $FamilyId
        target_profile_id = $TargetProfileId
        target_agent_kind = $TargetAgentKind
        contract_id = [string]$Contract.contract_id
        contract_version = [string]$Contract.contract_version
        source_contract_path = ConvertTo-RepoSlashPath -PathValue $FamilyContractPath
        program_root = ConvertTo-RepoSlashPath -PathValue $ProgramRootRelative
        pack_count = [int]$Shape.expected_pack_count
        task_count = [int]$Shape.expected_task_count
        capability_count = [int]$Shape.expected_capability_count
        first_activatable_task_id = [string]$Shape.first_activatable_task_id
        first_activatable_capability_id = [string]$Shape.first_activatable_capability_id
        packs_root = ConvertTo-RepoSlashPath -PathValue $PacksRootRelative
        tasks_root = ConvertTo-RepoSlashPath -PathValue $TasksRootRelative
        patches_root = ConvertTo-RepoSlashPath -PathValue $PatchesRootRelative
        execution_recipes_root = ConvertTo-RepoSlashPath -PathValue $RecipesRootRelative
        admission_status = [string]$Contract.formal_identity.admission_status_target
        live_admission_attempted = $false
        generated_pack_execution_attempted = $false
    }
    Write-JsonFile -Path $ManifestPath -Value $Manifest

    $RegistryPatch = [ordered]@{
        patch_kind = "PACK_REGISTRY_APPEND"
        status = "READY_FOR_ADMISSION"
        family_id = $FamilyId
        generated_packs = @($Packs | ForEach-Object {
            [ordered]@{
                order = [int]$_.order
                pack_id = [string]$_.pack_id
                task_id = [string]$_.task_id
            }
        })
    }
    $RoadmapPatch = [ordered]@{
        patch_kind = "CAPABILITY_ROADMAP_APPEND"
        status = "READY_FOR_ADMISSION"
        family_id = $FamilyId
        generated_capabilities = @($Capabilities | ForEach-Object {
            [ordered]@{
                order = [int]$_.order
                capability_id = [string]$_.capability_id
                semantic_role = [string]$_.semantic_role
                source_capability_hint = [string]$_.source_capability_hint
            }
        })
    }
    $QueueSeed = [ordered]@{
        patch_kind = "TASK_QUEUE_SEED"
        status = "READY_FOR_ADMISSION"
        family_id = $FamilyId
        active_task_id = [string]$Shape.first_activatable_task_id
        generated_tasks = @($Tasks | ForEach-Object {
            [ordered]@{
                order = [int]$_.order
                task_id = [string]$_.task_id
                capability_id = [string]$_.capability_id
                expected_gate = [string]$_.expected_gate
            }
        })
    }

    Write-JsonFile -Path (Join-Path $PatchesRoot "PACK_REGISTRY_PATCH.json") -Value $RegistryPatch
    Write-JsonFile -Path (Join-Path $PatchesRoot "CAPABILITY_ROADMAP_PATCH.json") -Value $RoadmapPatch
    Write-JsonFile -Path (Join-Path $PatchesRoot "TASK_QUEUE_SEED.json") -Value $QueueSeed

    $MaterializedTaskPaths = @()
    $MaterializedPackPaths = @()
    $MaterializedRecipePaths = @()

    for ($Index = 0; $Index -lt $Packs.Count; $Index++) {
        $Pack = $Packs[$Index]
        $Task = $Tasks[$Index]
        $Capability = $Capabilities[$Index]

        Assert-OrderedFamilyContractRow `
            -Pack $Pack `
            -Task $Task `
            -Capability $Capability `
            -ExpectedOrder ($Index + 1)

        $TaskContractPath = Join-Path $TasksRoot "$($Task.task_id).json"
        $TaskContract = [ordered]@{
            task_id = [string]$Task.task_id
            capability_id = [string]$Task.capability_id
            objective = "Generated self-build task for $FamilyId semantic role $($Capability.semantic_role) declared by family contract."
            expected_gate = [string]$Task.expected_gate
            execution_kind = "GENERATED_PROGRAM_PLACEHOLDER"
            materialization_status = "SYNTHESIZED_NOT_ADMITTED"
            family_id = $FamilyId
            semantic_role = [string]$Capability.semantic_role
            source_contract_path = ConvertTo-RepoSlashPath -PathValue $FamilyContractPath
        }
        Write-JsonFile -Path $TaskContractPath -Value $TaskContract
        $MaterializedTaskPaths += $TaskContractPath

        $PackRoot = Join-Path $PacksRoot ([string]$Pack.pack_id)
        New-Item -ItemType Directory -Force -Path $PackRoot | Out-Null
        $PackContractPath = Join-Path $PackRoot "PACK.json"
        $PackContract = [ordered]@{
            pack_id = [string]$Pack.pack_id
            task_id = [string]$Pack.task_id
            entry_script = "APPLY.ps1"
            shell = "PowerShell"
            materialization_status = "SYNTHESIZED_NOT_ADMITTED"
            family_id = $FamilyId
            semantic_role = [string]$Capability.semantic_role
        }
        Write-JsonFile -Path $PackContractPath -Value $PackContract
        $MaterializedPackPaths += $PackContractPath

        $NextCapabilityId = ""
        $NextTaskId = ""
        $QueueAction = "COMPLETE_GENERATED_PROGRAM"
        if ($Index -lt ($Packs.Count - 1)) {
            $NextCapabilityId = [string]$Tasks[$Index + 1].capability_id
            $NextTaskId = [string]$Tasks[$Index + 1].task_id
            $QueueAction = "ACTIVATE_NEXT_GENERATED_TASK"
        }

        $Recipe = New-GeneratedProgramRecipeFromFamilyContract `
            -Contract $Contract `
            -ManifestRelativePath $ManifestRelative `
            -Pack $Pack `
            -Task $Task `
            -Capability $Capability `
            -NextCapabilityId $NextCapabilityId `
            -NextTaskId $NextTaskId `
            -QueueAction $QueueAction

        $RecipePath = Join-Path $RecipesRoot "$($Pack.pack_id)_RECIPE.json"
        Write-JsonFile -Path $RecipePath -Value $Recipe
        $MaterializedRecipePaths += $RecipePath
    }

    return [pscustomobject][ordered]@{
        status = "PASS"
        family_id = $FamilyId
        source_contract_path = $ResolvedContractPath
        materialized_program_root = $ProgramRoot
        manifest_path = $ManifestPath
        materialized_pack_count = @($MaterializedPackPaths).Count
        materialized_capability_count = @($Capabilities).Count
        materialized_task_count = @($MaterializedTaskPaths).Count
        materialized_execution_recipe_count = @($MaterializedRecipePaths).Count
        materialized_task_paths = @($MaterializedTaskPaths)
        materialized_pack_contract_paths = @($MaterializedPackPaths)
        materialized_execution_recipe_paths = @($MaterializedRecipePaths)
    }
}

function Assert-FamilyContractMaterializationShape {
    param(
        [object]$Contract,
        [string]$ContractPath
    )

    foreach ($Field in @(
        "contract_id",
        "contract_version",
        "family_id",
        "target_agent_kind",
        "profile_id",
        "formal_identity",
        "generated_program_shape",
        "planned_generated_capabilities",
        "planned_generated_tasks",
        "planned_generated_packs"
    )) {
        if (-not $Contract.PSObject.Properties.Name.Contains($Field)) {
            throw "Family contract missing required field $Field at $ContractPath"
        }
        if ($null -eq $Contract.$Field) {
            throw "Family contract field $Field must not be null at $ContractPath"
        }
    }

    foreach ($StringField in @("family_id", "target_agent_kind", "profile_id")) {
        if ([string]::IsNullOrWhiteSpace([string]$Contract.$StringField)) {
            throw "Family contract field $StringField must not be empty at $ContractPath"
        }
    }

    $Identity = $Contract.formal_identity
    foreach ($Field in @("program_root", "manifest_path", "patches_root", "packs_root", "tasks_root", "execution_recipes_root", "program_status_target", "admission_status_target")) {
        if (-not $Identity.PSObject.Properties.Name.Contains($Field)) {
            throw "Family contract formal_identity missing $Field at $ContractPath"
        }
        if ([string]::IsNullOrWhiteSpace([string]$Identity.$Field)) {
            throw "Family contract formal_identity.$Field must not be empty at $ContractPath"
        }
    }

    if ($Identity.program_status_target -ne "PROGRAM_PACKAGE_MATERIALIZED") {
        throw "Family contract program_status_target must be PROGRAM_PACKAGE_MATERIALIZED."
    }
    if ($Identity.admission_status_target -ne "NOT_ADMITTED_YET") {
        throw "Family contract admission_status_target must be NOT_ADMITTED_YET."
    }

    $Shape = $Contract.generated_program_shape
    foreach ($Field in @("expected_pack_count", "expected_task_count", "expected_capability_count", "first_activatable_task_id", "first_activatable_capability_id")) {
        if (-not $Shape.PSObject.Properties.Name.Contains($Field)) {
            throw "Family contract generated_program_shape missing $Field at $ContractPath"
        }
    }

    $Capabilities = @($Contract.planned_generated_capabilities)
    $Tasks = @($Contract.planned_generated_tasks)
    $Packs = @($Contract.planned_generated_packs)

    if ($Packs.Count -ne [int]$Shape.expected_pack_count) {
        throw "Family contract planned pack count does not match generated_program_shape."
    }
    if ($Tasks.Count -ne [int]$Shape.expected_task_count) {
        throw "Family contract planned task count does not match generated_program_shape."
    }
    if ($Capabilities.Count -ne [int]$Shape.expected_capability_count) {
        throw "Family contract planned capability count does not match generated_program_shape."
    }
    if ($Capabilities.Count -ne $Tasks.Count -or $Tasks.Count -ne $Packs.Count) {
        throw "Family contract generated pack, task, and capability counts must align."
    }
}

function Assert-OrderedFamilyContractRow {
    param(
        [object]$Pack,
        [object]$Task,
        [object]$Capability,
        [int]$ExpectedOrder
    )

    if ([int]$Pack.order -ne $ExpectedOrder) {
        throw "Generated pack order mismatch at order $ExpectedOrder."
    }
    if ([int]$Task.order -ne $ExpectedOrder) {
        throw "Generated task order mismatch at order $ExpectedOrder."
    }
    if ([int]$Capability.order -ne $ExpectedOrder) {
        throw "Generated capability order mismatch at order $ExpectedOrder."
    }
    if ($Pack.task_id -ne $Task.task_id) {
        throw "Generated pack/task mismatch for $($Pack.pack_id)."
    }
    if ($Task.capability_id -ne $Capability.capability_id) {
        throw "Generated task/capability mismatch for $($Task.task_id)."
    }
}

function New-GeneratedProgramRecipeFromFamilyContract {
    param(
        [object]$Contract,
        [string]$ManifestRelativePath,
        [object]$Pack,
        [object]$Task,
        [object]$Capability,
        [string]$NextCapabilityId,
        [string]$NextTaskId,
        [string]$QueueAction
    )

    $FamilyId = [string]$Contract.family_id
    $TargetProfileId = [string]$Contract.profile_id
    $TargetAgentKind = [string]$Contract.target_agent_kind
    $SemanticRole = [string]$Capability.semantic_role
    $RecipeKind = Get-RecipeKindForSemanticRole -SemanticRole $SemanticRole
    $AgentKindUpper = ConvertTo-IdentifierUpper -Value $TargetAgentKind
    $BuilderCapabilityTarget = ""

    if ($Contract.PSObject.Properties.Name.Contains("growth_purpose") -and
        $null -ne $Contract.growth_purpose -and
        $Contract.growth_purpose.PSObject.Properties.Name.Contains("builder_capability_target")) {
        $BuilderCapabilityTarget = [string]$Contract.growth_purpose.builder_capability_target
    }
    if ([string]::IsNullOrWhiteSpace($BuilderCapabilityTarget)) {
        $BuilderCapabilityTarget = "$TargetAgentKind`_generated_operation"
    }

    $Recipe = [ordered]@{
        recipe_id = "$($Pack.pack_id)_RECIPE"
        program_manifest_path = ConvertTo-RepoSlashPath -PathValue $ManifestRelativePath
        target_profile_id = $TargetProfileId
        target_agent_kind = $TargetAgentKind
        pack_id = [string]$Pack.pack_id
        task_id = [string]$Task.task_id
        capability_id = [string]$Task.capability_id
        expected_gate = [string]$Task.expected_gate
        semantic_role = $SemanticRole
        recipe_kind = $RecipeKind
    }

    if ($SemanticRole -eq "PROFILE_MATERIALIZATION") {
        $Recipe["input_artifacts"] = [ordered]@{
            program_seed_path = ".\remediation_programs\$($AgentKindUpper)_REMEDIATION_PROGRAM_SEED_V1.json"
            profile_proof_spec_path = ".\specs\$($TargetAgentKind)_profile_proof\$($AgentKindUpper)_PROFILE_PROOF_SPEC.json"
            resolver_module_path = ".\modules\resolve_specialization_overlay.ps1"
            external_build_module_path = ".\modules\invoke_external_agent_build.ps1"
        }
        $Recipe["invocation_contract"] = [ordered]@{
            invocation_kind = "MODULE_CALLS"
            resolve_specialization_overlay = [ordered]@{
                agent_kind = $TargetAgentKind
                package_profile = "operational_specialized"
            }
            external_agent_build = [ordered]@{
                spec_path = ".\specs\$($TargetAgentKind)_profile_proof\$($AgentKindUpper)_PROFILE_PROOF_SPEC.json"
                output_root = ".\generated_agents"
                run_root_template = ".\runs\{run_id}\{pack_id}\profile_build"
                overlay_root_source = "resolved_specialization_overlay.overlay_root"
            }
        }
        $Recipe["expected_assertions"] = [ordered]@{
            program_seed_status = "PROGRAM_SEED_READY"
            expected_profile_id = $TargetProfileId
            expected_agent_kind = $TargetAgentKind
            resolver_status = "PASS"
            overlay_status = "PASS"
            operational_result = [ordered]@{
                operation = $BuilderCapabilityTarget
                next_alert_id = "$TargetAgentKind`_intake_request"
                escalation_status = "INTAKE_READY"
            }
        }
        $Recipe["proof_contract"] = [ordered]@{
            proof_id = [string]$Pack.pack_id
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
    }
    elseif ($SemanticRole -eq "SPECIALIZED_CLOSURE_PROOF") {
        $Recipe["input_artifacts"] = [ordered]@{
            raw_idea_path = ".\specs\$($TargetAgentKind)_gap_proof\RAW_IDEA_$($AgentKindUpper)_GAP_PROOF.json"
            orchestrator_path = ".\orchestrator\run.ps1"
        }
        $Recipe["invocation_contract"] = [ordered]@{
            invocation_kind = "ORCHESTRATOR_MODE"
            mode = "BUILD_FROM_RAW_IDEA_SPECIALIZED"
            raw_idea_path = ".\specs\$($TargetAgentKind)_gap_proof\RAW_IDEA_$($AgentKindUpper)_GAP_PROOF.json"
            output_root = ".\generated_agents"
            report_path_template = ".\runs\{run_id}\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1\BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"
        }
        $Recipe["expected_assertions"] = [ordered]@{
            factory_report_status = "PASS"
            expected_specialization_profile_id = $TargetProfileId
            gap_report = $null
            overlay_status = "PASS"
            operational_result = [ordered]@{
                operation = $BuilderCapabilityTarget
                next_alert_id = "$TargetAgentKind`_intake_request"
                escalation_status = "INTAKE_READY"
            }
        }
        $Recipe["proof_contract"] = [ordered]@{
            proof_id = [string]$Pack.pack_id
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
    }
    elseif ($SemanticRole -eq "SEED_CONSUMPTION_PROOF") {
        $ProfilePackId = Find-PackIdBySemanticRole -Contract $Contract -SemanticRole "PROFILE_MATERIALIZATION"
        $ClosurePackId = Find-PackIdBySemanticRole -Contract $Contract -SemanticRole "SPECIALIZED_CLOSURE_PROOF"
        $Recipe["input_artifacts"] = [ordered]@{
            program_seed_path = ".\remediation_programs\$($AgentKindUpper)_REMEDIATION_PROGRAM_SEED_V1.json"
            dependent_generated_profile_proof_path = ".\proofs\$ProfilePackId.json"
            dependent_generated_closure_proof_path = ".\proofs\$ClosurePackId.json"
        }
        $Recipe["invocation_contract"] = [ordered]@{
            invocation_kind = "ARTIFACT_CONSISTENCY_PROOF"
            required_prior_generated_proofs = @(
                ".\proofs\$ProfilePackId.json",
                ".\proofs\$ClosurePackId.json"
            )
        }
        $Recipe["expected_assertions"] = [ordered]@{
            seed_profile_id = $TargetProfileId
            seed_agent_kind = $TargetAgentKind
            cross_proof_consistency_rules = @(
                "profile_proof.status == PASS",
                "profile_proof.selected_profile_id == seed.candidate_profile_id",
                "closure_proof.status == PASS",
                "closure_proof.selected_profile_id == seed.candidate_profile_id",
                "closure_proof.specialized_operation == $BuilderCapabilityTarget"
            )
            expected_specialized_operation = $BuilderCapabilityTarget
        }
        $Recipe["proof_contract"] = [ordered]@{
            proof_id = [string]$Pack.pack_id
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
    }
    else {
        throw "Unsupported generated family semantic role: $SemanticRole"
    }

    $Recipe["next_transition"] = [ordered]@{
        next_capability_id = $NextCapabilityId
        next_task_id = $NextTaskId
        queue_action = $QueueAction
    }

    return [pscustomobject]$Recipe
}

function Find-PackIdBySemanticRole {
    param(
        [object]$Contract,
        [string]$SemanticRole
    )

    $Capabilities = @($Contract.planned_generated_capabilities | Sort-Object { [int]$_.order })
    $Packs = @($Contract.planned_generated_packs | Sort-Object { [int]$_.order })

    for ($Index = 0; $Index -lt $Capabilities.Count; $Index++) {
        if ($Capabilities[$Index].semantic_role -eq $SemanticRole) {
            return [string]$Packs[$Index].pack_id
        }
    }

    throw "Family contract missing pack for semantic role $SemanticRole."
}

function Get-RecipeKindForSemanticRole {
    param([string]$SemanticRole)

    switch ($SemanticRole) {
        "PROFILE_MATERIALIZATION" { return "PROFILE_MATERIALIZATION_RECIPE_V1" }
        "SPECIALIZED_CLOSURE_PROOF" { return "SPECIALIZED_CLOSURE_PROOF_RECIPE_V1" }
        "SEED_CONSUMPTION_PROOF" { return "SEED_CONSUMPTION_PROOF_RECIPE_V1" }
        default { throw "Unsupported generated family semantic role: $SemanticRole" }
    }
}

function Normalize-ContractRelativePath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw "Contract path value must not be empty."
    }

    return ($PathValue.Trim() -replace '^[.\\/]+', '')
}

function Resolve-RepoRelativePath {
    param(
        [string]$RepoRoot,
        [string]$RelativePath
    )

    $Combined = Join-Path $RepoRoot $RelativePath
    $FullPath = [System.IO.Path]::GetFullPath($Combined)
    $RepoFullPath = [System.IO.Path]::GetFullPath($RepoRoot)

    if (-not $RepoFullPath.EndsWith([string][System.IO.Path]::DirectorySeparatorChar)) {
        $RepoFullPath = "$RepoFullPath$([System.IO.Path]::DirectorySeparatorChar)"
    }

    if (-not $FullPath.StartsWith($RepoFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated program path resolves outside repo root: $RelativePath"
    }

    return $FullPath
}

function Assert-ProgramRootAllowed {
    param(
        [string]$RepoRoot,
        [string]$ProgramRoot,
        [string]$FamilyId
    )

    $ExpectedRoot = Join-Path $RepoRoot "self_build_programs/generated/$FamilyId"
    $ExpectedRoot = [System.IO.Path]::GetFullPath($ExpectedRoot)
    $ProgramRootFull = [System.IO.Path]::GetFullPath($ProgramRoot)

    if (-not $ProgramRootFull.Equals($ExpectedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Family contract program_root must resolve to self_build_programs/generated/$FamilyId."
    }
}

function ConvertTo-IdentifierUpper {
    param([string]$Value)

    return ($Value -replace "[^A-Za-z0-9]+", "_").Trim("_").ToUpperInvariant()
}

function ConvertTo-RepoSlashPath {
    param([string]$PathValue)

    return $PathValue.Replace("\", "/")
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path $Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }

    $Value | ConvertTo-Json -Depth 100 |
        Set-Content $Path -Encoding UTF8
}
