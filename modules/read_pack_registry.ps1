function Read-SelfBuildPackRegistry {
    param([string]$RepoRoot)

    $Path = Join-Path $RepoRoot "packs/registry.json"
    if (-not (Test-Path $Path)) {
        throw "Pack registry not found: $Path"
    }

    Get-Content $Path -Raw | ConvertFrom-Json
}
