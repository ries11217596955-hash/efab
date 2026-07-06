function New-FailureDiagnostic {
    param(
        [string]$DiagnosticId,
        [string]$RunId,
        [string]$StopReason
    )

    [ordered]@{
        diagnostic_id = $DiagnosticId
        run_id = $RunId
        status = "FAIL"
        stop_reason = $StopReason
    }
}
