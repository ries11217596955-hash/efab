function Invoke-BuildTaskExecution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$BuildTask,

        [Parameter(Mandatory = $true)]
        [string]$RunDir,

        [Parameter(Mandatory = $true)]
        [string]$RunId
    )

    if ($BuildTask.content.execution_kind -ne 'CONTROLLED_PROOF') {
        throw "Unsupported execution_kind '$($BuildTask.content.execution_kind)'."
    }

    $proofArtifactRelPath = "runs/$RunId/EXECUTION_PROOF_MARKER.json"
    $proofArtifactFullPath = Join-Path (Split-Path -Parent $RunDir) "$RunId/EXECUTION_PROOF_MARKER.json"

    $proofMarker = [ordered]@{
        run_id = $RunId
        task_id = $BuildTask.content.task_id
        capability_id = $BuildTask.content.capability_id
        proof = 'CONTROLLED_EXECUTION_DISPATCH_COMPLETED'
    }

    ($proofMarker | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath $proofArtifactFullPath -Encoding UTF8

    return [ordered]@{
        execution_id = "EXECUTION_$RunId"
        task_id = $BuildTask.content.task_id
        capability_id = $BuildTask.content.capability_id
        status = 'PASS'
        execution_kind = $BuildTask.content.execution_kind
        proof_artifact = $proofArtifactRelPath
        message = 'Controlled build task execution produced the declared proof marker.'
    }
}
