function Read-TaskQueue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $queuePath = Join-Path $RepoRoot 'TASK_QUEUE.json'
    if (-not (Test-Path -LiteralPath $queuePath)) {
        throw "TASK_QUEUE.json not found at $queuePath"
    }

    return (Get-Content -LiteralPath $queuePath -Raw | ConvertFrom-Json)
}
