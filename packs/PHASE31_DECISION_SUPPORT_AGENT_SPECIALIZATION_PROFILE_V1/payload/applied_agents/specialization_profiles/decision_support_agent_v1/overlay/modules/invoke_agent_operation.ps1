function Invoke-AgentOperation {
    param(
        [object]$Request,
        [object]$Profile
    )

    $Candidates = @()
    if ($null -ne $Request.payload.route_candidates) {
        $Candidates = @($Request.payload.route_candidates)
    }

    $RankedRoutes = @(
        $Candidates |
            Sort-Object -Property @{
                Expression = { [double]$_.priority_score }
                Descending = $true
            } |
            ForEach-Object {
                [ordered]@{
                    id = $_.id
                    priority_score = $_.priority_score
                    rationale = $_.rationale
                }
            }
    )

    $TopRoute = $null
    if (@($RankedRoutes).Count -gt 0) {
        $TopRoute = $RankedRoutes[0]
    }

    return [pscustomobject]@{
        status = "PASS"
        request_id = $Request.request_id
        agent_id = $Profile.agent_id
        result = [ordered]@{
            operation = "decision_route_prioritization"
            mission = $Profile.mission
            route_count = @($RankedRoutes).Count
            ranked_routes = $RankedRoutes
            top_route_id = if ($null -eq $TopRoute) { "NONE" } else { $TopRoute.id }
            recommended_next_action = "EXECUTE_TOP_ROUTE"
        }
        diagnostics = [ordered]@{
            specialization_profile = "decision_support_agent_v1"
            package_profile = $Profile.package_profile
            ranked_route_count = @($RankedRoutes).Count
        }
    }
}
