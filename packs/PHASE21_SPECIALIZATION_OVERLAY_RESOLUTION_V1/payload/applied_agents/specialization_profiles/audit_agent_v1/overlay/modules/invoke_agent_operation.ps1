function Invoke-AgentOperation {
    param(
        [object]$Request,
        [object]$Profile
    )

    $EvidenceItems = @()
    if ($null -ne $Request.payload.evidence_items) {
        $EvidenceItems = @($Request.payload.evidence_items)
    }

    $FindingCount = @($EvidenceItems).Count

    $RiskBand = "LOW"
    if ($FindingCount -ge 3) {
        $RiskBand = "HIGH"
    }
    elseif ($FindingCount -ge 1) {
        $RiskBand = "MEDIUM"
    }

    $PriorityFindings = @(
        $EvidenceItems |
            ForEach-Object {
                [ordered]@{
                    id = $_.id
                    severity = $_.severity
                    signal = $_.signal
                }
            }
    )

    return [pscustomobject]@{
        status = "PASS"
        request_id = $Request.request_id
        agent_id = $Profile.agent_id
        result = [ordered]@{
            operation = "audit_signal_triage"
            mission = $Profile.mission
            finding_count = $FindingCount
            risk_band = $RiskBand
            priority_findings = $PriorityFindings
            recommended_next_action = "PRIORITIZE_AND_REPAIR"
        }
        diagnostics = [ordered]@{
            specialization_profile = "audit_agent_v1"
            package_profile = $Profile.package_profile
            evidence_item_count = $FindingCount
        }
    }
}
