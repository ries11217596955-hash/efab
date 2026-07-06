function Invoke-ExternalAgentBuild {
    param(
        [string]$SpecPath,
        [string]$OutputRoot
    )

    if (-not (Test-Path $SpecPath)) {
        throw "Spec path not found: $SpecPath"
    }

    . ".\modules\new_external_agent_package.ps1"
    . ".\modules\test_generated_agent_package.ps1"

    $Spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
    $Manifest = New-ExternalAgentPackage -Spec $Spec -OutputRoot $OutputRoot
    $Validation = Test-GeneratedAgentPackage -PackageRoot $Manifest.package_root

    if ($Validation.status -ne "PASS") {
        throw "Generated agent validation failed."
    }

    return [pscustomobject]@{
        status = "PASS"
        manifest = $Manifest
        validation = $Validation
    }
}
