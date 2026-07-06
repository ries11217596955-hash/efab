function Read-CapabilityRoadmap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $roadmapPath = Join-Path $RepoRoot 'CAPABILITY_ROADMAP.json'
    if (-not (Test-Path -LiteralPath $roadmapPath)) {
        throw "CAPABILITY_ROADMAP.json not found at $roadmapPath"
    }

    return (Get-Content -LiteralPath $roadmapPath -Raw | ConvertFrom-Json)
}
