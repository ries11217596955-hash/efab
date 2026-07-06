function New-BuildDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Plan,

        [Parameter(Mandatory = $true)]
        [object]$GenesisState,

        [Parameter(Mandatory = $true)]
        [object]$SelectedCapability,

        [Parameter(Mandatory = $true)]
        [object]$SelectedTask,

        [string]$DecisionId
    )

    $resolvedDecisionId = if ([string]::IsNullOrWhiteSpace($DecisionId)) {
        "BUILD_DECISION_" + (Get-Date -Format 'yyyyMMdd_HHmmss')
    } else {
        $DecisionId
    }

    return [ordered]@{
        decision_id = $resolvedDecisionId
        mode = 'SELF_BUILD_CONTROL_CORE'
        status = 'READY'
        current_phase = $GenesisState.current_phase
        selected_capability = [ordered]@{
            id = $SelectedCapability.id
            phase = $SelectedCapability.phase
            status = $SelectedCapability.status
            gate = $SelectedCapability.gate
        }
        selected_task = [ordered]@{
            task_id = $SelectedTask.task_id
            capability_id = $SelectedTask.capability_id
            status = $SelectedTask.status
            objective = $SelectedTask.objective
            expected_gate = $SelectedTask.expected_gate
        }
        truth_inputs = [ordered]@{
            plan_path = $Plan.path
            state_path = 'GENESIS_STATE.json'
            roadmap_path = 'CAPABILITY_ROADMAP.json'
            queue_path = 'TASK_QUEUE.json'
        }
        reason = 'Selected the unique ACTIVE capability and ACTIVE task aligned to current repo truth.'
        stop_reason = $null
    }
}
