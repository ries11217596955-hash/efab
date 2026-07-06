function New-SpecializationGapReport {
    param(
        [string]$RunId,
        [string]$ModeRoot,
        [string]$RawIdeaPath,
        [string]$DerivedSpecPath,
        [object]$DerivedSpec,
        [object]$Specialization
    )

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        throw "RunId is required."
    }

    if ([string]::IsNullOrWhiteSpace($ModeRoot)) {
        throw "ModeRoot is required."
    }

    if ($null -eq $DerivedSpec) {
        throw "DerivedSpec is required."
    }

    if ($null -eq $Specialization) {
        throw "Specialization is required."
    }

    New-Item -ItemType Directory -Force -Path $ModeRoot | Out-Null
    $ResolvedModeRoot = (Resolve-Path $ModeRoot).Path

    $ReportPath = Join-Path $ResolvedModeRoot "SPECIALIZATION_GAP_REPORT.json"

    $Report = [ordered]@{
        report_id = "SPECIALIZATION_GAP_REPORT_V1"
        run_id = $RunId
        status = "PASS"
        diagnostic_status = "MISSING_SPECIALIZATION_PROFILE"
        raw_idea_path = $RawIdeaPath
        derived_spec_path = $DerivedSpecPath
        derived_agent_id = $DerivedSpec.agent_id
        missing_agent_kind = $DerivedSpec.agent_kind
        requested_package_profile = $DerivedSpec.package_profile
        resolver_status = $Specialization.status
        resolver_reason = $Specialization.resolution_reason
        required_next_move = "ADD_OR_MAP_SPECIALIZATION_PROFILE"
        operator_summary = "No active specialization profile matched the derived agent family. The factory preserved the idea/spec evidence and emitted a bounded gap report."
        resolver_evidence = [ordered]@{
            profile_id = $Specialization.profile_id
            profile_kind = $Specialization.profile_kind
            overlay_root = $Specialization.overlay_root
        }
    }

    $Report | ConvertTo-Json -Depth 100 |
        Set-Content $ReportPath -Encoding UTF8

    return [pscustomobject]@{
        status = "PASS"
        report_path = $ReportPath
        diagnostic_status = $Report.diagnostic_status
        missing_agent_kind = $Report.missing_agent_kind
        requested_package_profile = $Report.requested_package_profile
    }
}
