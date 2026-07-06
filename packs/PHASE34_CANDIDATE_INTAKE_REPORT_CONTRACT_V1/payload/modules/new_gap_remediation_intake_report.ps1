function New-GapRemediationIntakeReport {
    param(
        [string]$RunId,
        [string]$ModeRoot,
        [string]$GapReportPath,
        [string]$CandidatePath
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

    New-Item -ItemType Directory -Force -Path $ModeRoot | Out-Null
    $ResolvedModeRoot = (Resolve-Path $ModeRoot).Path

    $Gap = Get-Content $GapReportPath -Raw | ConvertFrom-Json
    $Candidate = Get-Content $CandidatePath -Raw | ConvertFrom-Json

    $ReportPath = Join-Path $ResolvedModeRoot "GAP_REMEDIATION_INTAKE_REPORT.json"

    $Report = [ordered]@{
        report_id = "GAP_REMEDIATION_INTAKE_REPORT_V1"
        run_id = $RunId
        status = "PASS"
        source_gap_report_path = $GapReportPath
        candidate_path = $CandidatePath
        candidate_profile_id = $Candidate.candidate_profile_id
        candidate_agent_kind = $Candidate.candidate_agent_kind
        candidate_package_profile = $Candidate.candidate_package_profile
        required_build_move = $Candidate.required_build_move
        operator_summary = "The Builder converted a missing specialization gap into a normalized profile candidate intake artifact."
        source_gap = [ordered]@{
            diagnostic_status = $Gap.diagnostic_status
            missing_agent_kind = $Gap.missing_agent_kind
            requested_package_profile = $Gap.requested_package_profile
        }
    }

    $Report | ConvertTo-Json -Depth 100 |
        Set-Content $ReportPath -Encoding UTF8

    return [pscustomobject]@{
        status = "PASS"
        report_path = $ReportPath
        candidate_profile_id = $Report.candidate_profile_id
        candidate_agent_kind = $Report.candidate_agent_kind
        required_build_move = $Report.required_build_move
    }
}
