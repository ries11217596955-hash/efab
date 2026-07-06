function New-ExecutionRunReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunId,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$TaskExecuted,

        [Parameter(Mandatory = $true)]
        [string]$NextTask,

        [string]$StopReason
    )

    return [ordered]@{
        run_id = $RunId
        mode = 'PHASE_2_CLOSEOUT'
        status = $Status
        task_executed = $TaskExecuted
        validators = @('validators/validate_self_build_execution_loop.ps1')
        next_task = $NextTask
        stop_reason = $StopReason
    }
}
