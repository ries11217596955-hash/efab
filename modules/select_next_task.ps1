function Select-NextTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$TaskQueue,

        [Parameter(Mandatory = $true)]
        [object]$SelectedCapability
    )

    $activeTask = $TaskQueue.tasks |
        Where-Object { $_.task_id -eq $TaskQueue.active_task_id } |
        Select-Object -First 1

    if ($null -eq $activeTask) {
        throw "No task matches active_task_id '$($TaskQueue.active_task_id)'."
    }

    if ($activeTask.status -ne 'ACTIVE') {
        throw "Active queue task '$($activeTask.task_id)' must have status ACTIVE; actual '$($activeTask.status)'."
    }

    if ($activeTask.capability_id -ne $SelectedCapability.id) {
        throw "Active task capability '$($activeTask.capability_id)' does not match selected capability '$($SelectedCapability.id)'."
    }

    if ($activeTask.expected_gate -ne $SelectedCapability.gate) {
        throw "Active task expected gate '$($activeTask.expected_gate)' does not match selected capability gate '$($SelectedCapability.gate)'."
    }

    return $activeTask
}
