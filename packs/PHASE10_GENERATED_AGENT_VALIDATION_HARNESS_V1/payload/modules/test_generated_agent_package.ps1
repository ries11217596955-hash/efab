function Test-GeneratedAgentPackage {
    param([string]$PackageRoot)

    $RequiredFiles = @(
        "README.md",
        "AGENTS.md",
        "AGENT_MISSION.md",
        "contracts\input_contract.json",
        "contracts\output_contract.json",
        "modules\README.md",
        "orchestrator\run.ps1",
        "validators\validate_package.ps1",
        "examples\SAMPLE_INPUT.json"
    )

    foreach ($Rel in $RequiredFiles) {
        $Path = Join-Path $PackageRoot $Rel
        if (-not (Test-Path $Path)) {
            throw "Generated package missing file: $Rel"
        }
    }

    $GeneratedRun = Join-Path $PackageRoot "orchestrator\run.ps1"

    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $GeneratedRun),
        [ref]$Tokens,
        [ref]$Errors
    ) | Out-Null

    if ($Errors.Count -ne 0) {
        throw "Generated orchestrator parser check failed."
    }

    & $GeneratedRun -Mode VERIFY | Out-Host

    return [pscustomobject]@{
        status = "PASS"
        package_root = $PackageRoot
        checked_files = $RequiredFiles
        smoke_run_status = "PASS"
    }
}
