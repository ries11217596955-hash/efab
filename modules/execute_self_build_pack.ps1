function Invoke-SelfBuildPack {
    param(
        [string]$RepoRoot,
        [object]$Pack,
        [string]$RunId
    )

    if ($Pack.shell -ne "PowerShell") {
        throw "Unsupported shell: $($Pack.shell)"
    }

    $Entry = Join-Path $RepoRoot $Pack.entry_script
    if (-not (Test-Path $Entry)) {
        throw "Pack entry script not found: $Entry"
    }

    $PackOutput = @()

    try {
        & $Entry -RepoRoot $RepoRoot -RunId $RunId -InvokedByOrchestrator *>&1 |
            Tee-Object -Variable PackOutput |
            Out-Host

        return [pscustomobject]@{
            pack_id = $Pack.pack_id
            task_id = $Pack.task_id
            status = "PASS"
            output_line_count = @($PackOutput).Count
        }
    }
    catch {
        return [pscustomobject]@{
            pack_id = $Pack.pack_id
            task_id = $Pack.task_id
            status = "FAIL"
            error = $_.Exception.Message
            output_line_count = @($PackOutput).Count
        }
    }
}
