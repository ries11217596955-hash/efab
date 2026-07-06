function Select-SelfBuildPack {
    param(
        [object]$Registry,
        [string]$ActiveTaskId
    )

    $Pack = $Registry.packs | Where-Object { $_.task_id -eq $ActiveTaskId } | Select-Object -First 1
    if ($null -eq $Pack) {
        throw "No pack registered for active task: $ActiveTaskId"
    }

    $Pack
}
