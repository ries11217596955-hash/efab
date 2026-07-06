function Invoke-AgentOperation {
    param(
        [object]$Request,
        [object]$Profile
    )

    $Signals = @()
    if ($null -ne $Request.payload.signals) {
        $Signals = @($Request.payload.signals)
    }

    $NormalizedSignals = @(
        $Signals |
            ForEach-Object {
                $Severity = ([string]$_.severity).ToUpperInvariant()
                $SeverityRank = switch ($Severity) {
                    "CRITICAL" { 4 }
                    "HIGH"     { 3 }
                    "MEDIUM"   { 2 }
                    "LOW"      { 1 }
                    default    { 0 }
                }

                [pscustomobject]@{
                    id = $_.id
                    severity = $Severity
                    severity_rank = $SeverityRank
                    status = ([string]$_.status).ToUpperInvariant()
                    message = $_.message
                }
            }
    )

    $AlertQueue = @(
        $NormalizedSignals |
            Where-Object { $_.status -ne "CLEAR" } |
            Sort-Object -Property @(
                @{
                    Expression = { [int]$_.severity_rank }
                    Descending = $true
                },
                @{
                    Expression = { [string]$_.id }
                    Descending = $false
                }
            ) |
            ForEach-Object {
                [ordered]@{
                    id = $_.id
                    severity = $_.severity
                    status = $_.status
                    severity_rank = $_.severity_rank
                    message = $_.message
                }
            }
    )

    $TopAlert = $null
    if (@($AlertQueue).Count -gt 0) {
        $TopAlert = $AlertQueue[0]
    }

    $HighestSeverity = if ($null -eq $TopAlert) { "NONE" } else { $TopAlert.severity }

    $EscalationStatus = "NONE"
    if ($HighestSeverity -eq "CRITICAL" -or $HighestSeverity -eq "HIGH") {
        $EscalationStatus = "ESCALATE"
    }
    elseif (@($AlertQueue).Count -gt 0) {
        $EscalationStatus = "OBSERVE"
    }

    return [pscustomobject]@{
        status = "PASS"
        request_id = $Request.request_id
        agent_id = $Profile.agent_id
        result = [ordered]@{
            operation = "monitoring_alert_triage_queue"
            mission = $Profile.mission
            system_id = $Request.payload.system_id
            signal_count = @($NormalizedSignals).Count
            alert_count = @($AlertQueue).Count
            alert_queue = $AlertQueue
            highest_severity = $HighestSeverity
            next_alert_id = if ($null -eq $TopAlert) { "NONE" } else { $TopAlert.id }
            escalation_status = $EscalationStatus
        }
        diagnostics = [ordered]@{
            specialization_profile = "monitoring_agent_v1"
            package_profile = $Profile.package_profile
            active_alert_count = @($AlertQueue).Count
        }
    }
}
