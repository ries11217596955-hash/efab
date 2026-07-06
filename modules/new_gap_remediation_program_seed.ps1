function New-GapRemediationProgramSeed {
    param(
        [string]$RunId,
        [string]$ModeRoot,
        [string]$GapReportPath,
        [string]$CandidatePath,
        [string]$IntakeReportPath
    )

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        throw "RunId is required."
    }

    if ([string]::IsNullOrWhiteSpace($ModeRoot)) {
        throw "ModeRoot is required."
    }

    if (-not (Test-Path $GapReportPath)) {
        throw "Gap report path missing: $GapReportPath"
    }

    if (-not (Test-Path $CandidatePath)) {
        throw "Candidate path missing: $CandidatePath"
    }

    if (-not (Test-Path $IntakeReportPath)) {
        throw "Intake report path missing: $IntakeReportPath"
    }

    New-Item -ItemType Directory -Force -Path $ModeRoot | Out-Null
    $ResolvedModeRoot = (Resolve-Path $ModeRoot).Path

    $Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json
    $Intake = Get-Content $IntakeReportPath -Raw | ConvertFrom-Json

    if ($Intake.status -ne "PASS") {
        throw "Intake report must be PASS."
    }

    if ($Candidate.candidate_profile_id -ne $Intake.candidate_profile_id) {
        throw "Candidate/intake profile id mismatch."
    }

    if ($Candidate.candidate_agent_kind -ne $Intake.candidate_agent_kind) {
        throw "Candidate/intake agent kind mismatch."
    }

    $CandidateProfileId = [string]$Candidate.candidate_profile_id
    $CandidateAgentKind = [string]$Candidate.candidate_agent_kind
    $CandidatePackageProfile = [string]$Candidate.candidate_package_profile

    if ([string]::IsNullOrWhiteSpace($CandidateProfileId)) {
        throw "candidate_profile_id is required."
    }

    if ([string]::IsNullOrWhiteSpace($CandidateAgentKind)) {
        throw "candidate_agent_kind is required."
    }

    $ProfileStemUpper = $CandidateProfileId.ToUpper()
    $AgentStemUpper = $CandidateAgentKind.ToUpper()

    $SeedPath = Join-Path $ResolvedModeRoot "GAP_REMEDIATION_PROGRAM_SEED.json"

    $Seed = [ordered]@{
        seed_id = "GAP_REMEDIATION_PROGRAM_SEED_$ProfileStemUpper"
        seed_version = "1.0"
        status = "PROGRAM_SEED_READY"
        source_gap_report_path = $GapReportPath
        source_candidate_path = $CandidatePath
        source_intake_report_path = $IntakeReportPath
        candidate_profile_id = $CandidateProfileId
        candidate_agent_kind = $CandidateAgentKind
        candidate_package_profile = $CandidatePackageProfile
        required_build_move = $Intake.required_build_move
        recommended_program = [ordered]@{
            program_kind = "SPECIALIZATION_PROFILE_CLOSURE_SERIAL_SELF_BUILD"
            profile_capability_id = "$($CandidateAgentKind)_specialization_profile_v1"
            closure_capability_id = "$($CandidateAgentKind)_gap_closure_proof_v1"
            recommended_task_sequence = @(
                [ordered]@{
                    task_id = "TASK_$($AgentStemUpper)_SPECIALIZATION_PROFILE_V1_001"
                    capability_id = "$($CandidateAgentKind)_specialization_profile_v1"
                    objective = "Build and prove $CandidateProfileId from the remediation program seed."
                },
                [ordered]@{
                    task_id = "TASK_$($AgentStemUpper)_GAP_CLOSURE_PROOF_V1_001"
                    capability_id = "$($CandidateAgentKind)_gap_closure_proof_v1"
                    objective = "Rerun the original raw-idea path and prove the prior gap now closes through $CandidateProfileId."
                }
            )
        }
        required_operator_move = "AUTHOR_OR_SELECT_REPO_DEFINED_PACKS_FOR_PROGRAM"
        operator_summary = "The Builder normalized a complete remediation packet into a serial self-build program seed. Arbitrary overlay coding is not claimed; repo-defined packs remain the execution substrate."
    }

    $Seed | ConvertTo-Json -Depth 100 |
        Set-Content $SeedPath -Encoding UTF8

    return [pscustomobject]@{
        status = "PASS"
        seed_path = $SeedPath
        program_id = $Seed.seed_id
        candidate_profile_id = $CandidateProfileId
        candidate_agent_kind = $CandidateAgentKind
        program_kind = $Seed.recommended_program.program_kind
        required_operator_move = $Seed.required_operator_move
    }
}
