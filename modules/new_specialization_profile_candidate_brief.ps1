function New-SpecializationProfileCandidateBrief {
    param(
        [string]$RunId,
        [string]$GapReportPath,
        [string]$CandidateOutputPath
    )

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        throw "RunId is required."
    }

    if (-not (Test-Path $GapReportPath)) {
        throw "Gap report path missing: $GapReportPath"
    }

    if ([string]::IsNullOrWhiteSpace($CandidateOutputPath)) {
        throw "CandidateOutputPath is required."
    }

    $Gap = Get-Content $GapReportPath -Raw | ConvertFrom-Json

    if ($Gap.diagnostic_status -ne "MISSING_SPECIALIZATION_PROFILE") {
        throw "Gap report must be a missing specialization profile diagnostic."
    }

    if ($Gap.required_next_move -ne "ADD_OR_MAP_SPECIALIZATION_PROFILE") {
        throw "Gap report next move is not eligible for profile candidate generation."
    }

    $MissingKind = [string]$Gap.missing_agent_kind
    if ([string]::IsNullOrWhiteSpace($MissingKind)) {
        throw "Gap missing_agent_kind is required."
    }

    $CandidateProfileId = "$MissingKind`_v1"

    $CandidateParent = Split-Path $CandidateOutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($CandidateParent)) {
        New-Item -ItemType Directory -Force -Path $CandidateParent | Out-Null
    }

    $Candidate = [ordered]@{
        candidate_id = "SPECIALIZATION_PROFILE_CANDIDATE_$($CandidateProfileId.ToUpper())"
        candidate_version = "1.0"
        status = "PROFILE_CANDIDATE_READY"
        source_gap_report_path = $GapReportPath
        source_gap_run_id = $Gap.run_id
        candidate_profile_id = $CandidateProfileId
        candidate_agent_kind = $MissingKind
        candidate_package_profile = $Gap.requested_package_profile
        source_derived_agent_id = $Gap.derived_agent_id
        resolver_status = $Gap.resolver_status
        resolver_reason = $Gap.resolver_reason
        required_build_move = "CREATE_SPECIALIZATION_PROFILE_AND_REGISTRY_MAPPING"
        candidate_scope = "repo_defined_overlay"
        operator_summary = "A missing specialization family was detected and normalized into a bounded profile candidate for self-build execution."
    }

    $Candidate | ConvertTo-Json -Depth 100 |
        Set-Content $CandidateOutputPath -Encoding UTF8

    return [pscustomobject]@{
        status = "PASS"
        candidate_path = $CandidateOutputPath
        candidate_profile_id = $Candidate.candidate_profile_id
        candidate_agent_kind = $Candidate.candidate_agent_kind
        required_build_move = $Candidate.required_build_move
    }
}
