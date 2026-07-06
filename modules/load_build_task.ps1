function Read-BuildTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [object]$QueueTask
    )

    if ([string]::IsNullOrWhiteSpace($QueueTask.build_task_path)) {
        throw "Queue task '$($QueueTask.task_id)' has no build_task_path."
    }

    $taskPath = Join-Path $RepoRoot $QueueTask.build_task_path
    if (-not (Test-Path -LiteralPath $taskPath)) {
        throw "Build task spec not found at $taskPath"
    }

    $buildTask = Get-Content -LiteralPath $taskPath -Raw | ConvertFrom-Json

    if ($buildTask.task_id -ne $QueueTask.task_id) {
        throw "Build task spec task_id '$($buildTask.task_id)' does not match queue task '$($QueueTask.task_id)'."
    }

    if ($buildTask.capability_id -ne $QueueTask.capability_id) {
        throw "Build task spec capability '$($buildTask.capability_id)' does not match queue task capability '$($QueueTask.capability_id)'."
    }

    return [ordered]@{
        path = $QueueTask.build_task_path
        content = $buildTask
    }
}
