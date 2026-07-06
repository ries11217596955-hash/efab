function Invoke-BuildValidationStack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$BuildTask,

        [Parameter(Mandatory = $true)]
        [object]$ExecutionResult,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $checks = [System.Collections.ArrayList]::new()

    $checks.Add([ordered]@{
        name = 'execution_result.status'
        status = if ($ExecutionResult.status -eq 'PASS') { 'PASS' } else { 'FAIL' }
        detail = "Expected PASS; actual $($ExecutionResult.status)"
    }) | Out-Null

    $checks.Add([ordered]@{
        name = 'execution_result.task_alignment'
        status = if ($ExecutionResult.task_id -eq $BuildTask.content.task_id) { 'PASS' } else { 'FAIL' }
        detail = "Expected $($BuildTask.content.task_id); actual $($ExecutionResult.task_id)"
    }) | Out-Null

    $proofPath = Join-Path $RepoRoot $ExecutionResult.proof_artifact
    $checks.Add([ordered]@{
        name = 'execution_result.proof_artifact_exists'
        status = if (Test-Path -LiteralPath $proofPath) { 'PASS' } else { 'FAIL' }
        detail = "Expected proof artifact at $proofPath"
    }) | Out-Null

    $failed = @($checks | Where-Object { $_.status -eq 'FAIL' })
    $status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

    return [ordered]@{
        status = $status
        checks = $checks
    }
}
