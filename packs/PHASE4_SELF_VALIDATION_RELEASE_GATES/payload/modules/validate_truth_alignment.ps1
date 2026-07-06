function Test-TruthAlignment {
    param(
        [object]$GenesisState,
        [object]$Roadmap,
        [object]$TaskQueue
    )

    $ActiveCap = $Roadmap.capabilities | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -First 1
    $ActiveTask = $TaskQueue.tasks | Where-Object { $_.task_id -eq $TaskQueue.active_task_id } | Select-Object -First 1

    if ($null -eq $ActiveCap) { throw "No active capability." }
    if ($null -eq $ActiveTask) { throw "No active task." }
    if ($ActiveCap.id -ne $GenesisState.current_capability) { throw "Capability/state mismatch." }
    if ($ActiveTask.capability_id -ne $GenesisState.current_capability) { throw "Task/state mismatch." }

    return "PASS"
}
