function Read-GenesisPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $planPath = Join-Path $RepoRoot 'GENESIS_MASTER_PLAN.md'
    if (-not (Test-Path -LiteralPath $planPath)) {
        throw "GENESIS_MASTER_PLAN.md not found at $planPath"
    }

    $content = Get-Content -LiteralPath $planPath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "GENESIS_MASTER_PLAN.md is empty."
    }

    return [ordered]@{
        path = 'GENESIS_MASTER_PLAN.md'
        full_path = $planPath
        contains_phase_1 = ($content -match 'PHASE 1')
        contains_gate = ($content -match 'SELF_BUILD_CONTROL_CORE_READY')
        content = $content
    }
}
