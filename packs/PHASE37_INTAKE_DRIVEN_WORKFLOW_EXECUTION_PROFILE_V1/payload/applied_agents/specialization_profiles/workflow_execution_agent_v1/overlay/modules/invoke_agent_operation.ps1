function Invoke-AgentOperation {
    param(
        [object]$Request,
        [object]$Profile
    )

    $Steps = @()
    if ($null -ne $Request.payload.workflow_steps) {
        $Steps = @($Request.payload.workflow_steps)
    }

    $OrderedSteps = @(
        $Steps |
            Sort-Object -Property @{
                Expression = { [int]$_.sequence }
                Descending = $false
            } |
            ForEach-Object {
                [ordered]@{
                    id = $_.id
                    sequence = $_.sequence
                    action = $_.action
                }
            }
    )

    $NextStep = $null
    if (@($OrderedSteps).Count -gt 0) {
        $NextStep = $OrderedSteps[0]
    }

    return [pscustomobject]@{
        status = "PASS"
        request_id = $Request.request_id
        agent_id = $Profile.agent_id
        result = [ordered]@{
            operation = "workflow_step_dispatch_plan"
            mission = $Profile.mission
            workflow_id = $Request.payload.workflow_id
            step_count = @($OrderedSteps).Count
            ordered_steps = $OrderedSteps
            next_step_id = if ($null -eq $NextStep) { "NONE" } else { $NextStep.id }
            dispatch_status = "PLAN_READY"
        }
        diagnostics = [ordered]@{
            specialization_profile = "workflow_execution_agent_v1"
            package_profile = $Profile.package_profile
            planned_step_count = @($OrderedSteps).Count
        }
    }
}
