function Test-ProductionExternalAgentSpec {
    param([string]$SpecPath)

    if (-not (Test-Path $SpecPath)) {
        throw "Spec file missing: $SpecPath"
    }

    $Spec = Get-Content $SpecPath -Raw | ConvertFrom-Json

    $Required = @(
        "agent_id",
        "display_name",
        "mission",
        "agent_kind",
        "package_profile",
        "runtime",
        "inputs",
        "outputs",
        "capabilities",
        "validation",
        "forbidden_scope"
    )

    foreach ($Field in $Required) {
        if (-not $Spec.PSObject.Properties.Name.Contains($Field)) {
            throw "Production spec missing field: $Field"
        }
    }

    if ([string]::IsNullOrWhiteSpace($Spec.agent_id)) {
        throw "agent_id must not be empty."
    }

    if ([string]::IsNullOrWhiteSpace($Spec.display_name)) {
        throw "display_name must not be empty."
    }

    if ([string]::IsNullOrWhiteSpace($Spec.mission)) {
        throw "mission must not be empty."
    }

    if ($null -eq $Spec.runtime.entrypoint) {
        throw "runtime.entrypoint must exist."
    }

    return "PASS"
}
