function Test-GeneratedAgentPackageOperational {
    param(
        [string]$PackageRoot,
        [string]$RunRoot
    )

    if (-not (Test-Path $PackageRoot)) {
        throw "Package root not found: $PackageRoot"
    }

    $PackageRoot = (Resolve-Path $PackageRoot).Path

    New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
    $RunRoot = (Resolve-Path $RunRoot).Path

    $Validator = Join-Path $PackageRoot "validators\validate_package.ps1"
    $Orchestrator = Join-Path $PackageRoot "orchestrator\run.ps1"
    $SampleRequest = Join-Path $PackageRoot "examples\SAMPLE_REQUEST.json"

    foreach ($Path in @($Validator, $Orchestrator, $SampleRequest)) {
        if (-not (Test-Path $Path)) {
            throw "Operational harness missing required package file: $Path"
        }
    }

    & $Validator | Out-Host

    $OutputPath = Join-Path $RunRoot "OPERATIONAL_RESULT.json"

    & $Orchestrator `
        -Mode RUN `
        -InputPath $SampleRequest `
        -OutputPath $OutputPath |
        Out-Host

    if (-not (Test-Path $OutputPath)) {
        throw "Operational result file missing."
    }

    $Result = Get-Content $OutputPath -Raw | ConvertFrom-Json

    if ($Result.status -ne "PASS") {
        throw "Operational result status must be PASS."
    }

    if ([string]::IsNullOrWhiteSpace($Result.request_id)) {
        throw "Operational result request_id missing."
    }

    if ([string]::IsNullOrWhiteSpace($Result.agent_id)) {
        throw "Operational result agent_id missing."
    }

    return [pscustomobject]@{
        status = "PASS"
        package_root = $PackageRoot
        output_result_path = $OutputPath
        request_id = $Result.request_id
        agent_id = $Result.agent_id
    }
}
