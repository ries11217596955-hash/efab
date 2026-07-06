function Read-GenesisState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $statePath = Join-Path $RepoRoot 'GENESIS_STATE.json'
    if (-not (Test-Path -LiteralPath $statePath)) {
        throw "GENESIS_STATE.json not found at $statePath"
    }

    return (Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json)
}
