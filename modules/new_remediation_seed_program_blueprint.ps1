function New-RemediationSeedProgramBlueprint {
    param(
        [object]$ProgramSeed,
        [string]$ProgramSeedPath
    )

    if ($null -eq $ProgramSeed) {
        throw "ProgramSeed is required."
    }

    if ($ProgramSeed.status -ne "PROGRAM_SEED_READY") {
        throw "Program seed status must be PROGRAM_SEED_READY."
    }

    if ([string]::IsNullOrWhiteSpace($ProgramSeed.candidate_profile_id)) {
        throw "Program seed candidate_profile_id missing."
    }

    if ([string]::IsNullOrWhiteSpace($ProgramSeed.candidate_agent_kind)) {
        throw "Program seed candidate_agent_kind missing."
    }

    if ($null -eq $ProgramSeed.recommended_program) {
        throw "Program seed recommended_program missing."
    }

    if ($ProgramSeed.recommended_program.program_kind -ne "SPECIALIZATION_PROFILE_CLOSURE_SERIAL_SELF_BUILD") {
        throw "Unsupported remediation program kind."
    }

    $ProfileId = $ProgramSeed.candidate_profile_id
    $AgentKind = $ProgramSeed.candidate_agent_kind
    $ProfileCapabilityId = $ProgramSeed.recommended_program.profile_capability_id
    $ClosureCapabilityId = $ProgramSeed.recommended_program.closure_capability_id

    if ([string]::IsNullOrWhiteSpace($ProfileCapabilityId)) {
        throw "Program seed profile capability id missing."
    }

    if ([string]::IsNullOrWhiteSpace($ClosureCapabilityId)) {
        throw "Program seed closure capability id missing."
    }

    $Prefix = ($ProfileId.ToUpper() -replace '[^A-Z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($Prefix)) {
        throw "Failed to derive program prefix."
    }

    $GeneratedCapabilities = @(
        [ordered]@{
            order = 1
            capability_id = "generated_${ProfileId}_profile_materialization_v1"
            semantic_role = "PROFILE_MATERIALIZATION"
            source_capability_hint = $ProfileCapabilityId
        },
        [ordered]@{
            order = 2
            capability_id = "generated_${ProfileId}_closure_proof_v1"
            semantic_role = "SPECIALIZED_CLOSURE_PROOF"
            source_capability_hint = $ClosureCapabilityId
        },
        [ordered]@{
            order = 3
            capability_id = "generated_${ProfileId}_seed_consumption_proof_v1"
            semantic_role = "SEED_CONSUMPTION_PROOF"
            source_capability_hint = "remediation_program_seed_consumption_closure_proof_v1"
        }
    )

    $GeneratedTasks = @(
        [ordered]@{
            order = 1
            task_id = "TASK_GENERATED_${Prefix}_PROFILE_MATERIALIZATION_V1_001"
            capability_id = $GeneratedCapabilities[0].capability_id
            expected_gate = "GENERATED_${Prefix}_PROFILE_MATERIALIZATION_V1_READY"
        },
        [ordered]@{
            order = 2
            task_id = "TASK_GENERATED_${Prefix}_CLOSURE_PROOF_V1_001"
            capability_id = $GeneratedCapabilities[1].capability_id
            expected_gate = "GENERATED_${Prefix}_CLOSURE_PROOF_V1"
        },
        [ordered]@{
            order = 3
            task_id = "TASK_GENERATED_${Prefix}_SEED_CONSUMPTION_PROOF_V1_001"
            capability_id = $GeneratedCapabilities[2].capability_id
            expected_gate = "GENERATED_${Prefix}_SEED_CONSUMPTION_PROOF_V1"
        }
    )

    $GeneratedPacks = @(
        [ordered]@{
            order = 1
            pack_id = "GENERATED_${Prefix}_PROFILE_MATERIALIZATION_V1"
            task_id = $GeneratedTasks[0].task_id
        },
        [ordered]@{
            order = 2
            pack_id = "GENERATED_${Prefix}_CLOSURE_PROOF_V1"
            task_id = $GeneratedTasks[1].task_id
        },
        [ordered]@{
            order = 3
            pack_id = "GENERATED_${Prefix}_SEED_CONSUMPTION_PROOF_V1"
            task_id = $GeneratedTasks[2].task_id
        }
    )

    return [pscustomobject]@{
        blueprint_id = "${Prefix}_REMEDIATION_SELF_BUILD_PROGRAM_BLUEPRINT_V1"
        status = "BLUEPRINT_READY"
        source_seed = [ordered]@{
            path = $ProgramSeedPath
            candidate_profile_id = $ProfileId
            candidate_agent_kind = $AgentKind
            program_kind = $ProgramSeed.recommended_program.program_kind
        }
        target = [ordered]@{
            profile_id = $ProfileId
            agent_kind = $AgentKind
        }
        program_kind = "SERIAL_SELF_BUILD_REMEDIATION_PROGRAM"
        generated_capabilities = $GeneratedCapabilities
        generated_tasks = $GeneratedTasks
        generated_packs = $GeneratedPacks
        materialization_contract = [ordered]@{
            expected_capability_count = 3
            expected_task_count = 3
            expected_pack_count = 3
            requires_registry_patch = $true
            requires_roadmap_patch = $true
            requires_queue_seed = $true
            admission_status = "NOT_ADMITTED_YET"
        }
    }
}
