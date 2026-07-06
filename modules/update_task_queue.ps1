function New-UpdatedTaskQueueForNextTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$TaskQueue,

        [Parameter(Mandatory = $true)]
        [string]$CurrentTaskId,

        [Parameter(Mandatory = $true)]
        [object]$NextTask
    )

    $currentTask = $TaskQueue.tasks | Where-Object { $_.task_id -eq $CurrentTaskId } | Select-Object -First 1
    if ($null -eq $currentTask) {
        throw "Current task '$CurrentTaskId' not found."
    }

    $currentTask.status = 'COMPLETED'
    $TaskQueue.active_task_id = $NextTask.task_id

    $existingNextTask = $TaskQueue.tasks | Where-Object { $_.task_id -eq $NextTask.task_id } | Select-Object -First 1
    if ($null -eq $existingNextTask) {
        $TaskQueue.tasks += $NextTask
    }

    return $TaskQueue
}
