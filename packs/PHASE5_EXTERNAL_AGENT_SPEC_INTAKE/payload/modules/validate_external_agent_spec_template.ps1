function Test-ExternalAgentSpecTemplate {
    param([string]$TemplatePath)

    if (-not (Test-Path $TemplatePath)) {
        throw "Spec template missing: $TemplatePath"
    }

    $Spec = Get-Content $TemplatePath -Raw | ConvertFrom-Json

    $Required = @(
        "agent_id",
        "mission",
        "inputs",
        "outputs",
        "capabilities",
        "validation",
        "forbidden_scope"
    )

    foreach ($Field in $Required) {
        if (-not $Spec.PSObject.Properties.Name.Contains($Field)) {
            throw "Spec template missing field: $Field"
        }
    }

    return "PASS"
}
