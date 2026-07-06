function Invoke-ExternalAgentBuild {
    param(
        [string]$SpecPath,
        [string]$OutputRoot,
        [string]$RunRoot
    )

    if (-not (Test-Path $SpecPath)) {
        throw "Spec path not found: $SpecPath"
    }

    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        throw "OutputRoot is required."
    }

    if ([string]::IsNullOrWhiteSpace($RunRoot)) {
        throw "RunRoot is required."
    }

    . ".\modules\validate_production_external_agent_spec.ps1"
    . ".\modules\new_external_agent_package.ps1"
    . ".\modules\test_generated_agent_package_operational.ps1"

    $SpecProof = Test-ProductionExternalAgentSpec -SpecPath $SpecPath
    if ($SpecProof -ne "PASS") {
        throw "Production spec validation failed."
    }

    $Spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
    $Manifest = New-ExternalAgentPackage -Spec $Spec -OutputRoot $OutputRoot

    $ValidationRoot = Join-Path $RunRoot "operational_validation"
    $Validation = Test-GeneratedAgentPackageOperational `
        -PackageRoot $Manifest.package_root `
        -RunRoot $ValidationRoot

    if ($Validation.status -ne "PASS") {
        throw "Operational validation failed."
    }

    $BuildReport = [ordered]@{
        status = "PASS"
        agent_id = $Spec.agent_id
        package_root = $Manifest.package_root
        manifest = $Manifest
        validation = $Validation
    }

    New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
    $ReportPath = Join-Path $RunRoot "BUILD_EXTERNAL_AGENT_REPORT.json"

    $BuildReport | ConvertTo-Json -Depth 100 |
        Set-Content $ReportPath -Encoding UTF8

    return [pscustomobject]@{
        status = "PASS"
        manifest = $Manifest
        validation = $Validation
        report_path = $ReportPath
    }
}
