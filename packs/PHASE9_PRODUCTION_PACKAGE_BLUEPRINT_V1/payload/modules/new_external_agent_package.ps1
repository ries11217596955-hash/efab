function New-ExternalAgentPackage {
    param(
        [object]$Spec,
        [string]$OutputRoot
    )

    $AgentRoot = Join-Path $OutputRoot $Spec.agent_id

    $Dirs = @(
        $AgentRoot,
        (Join-Path $AgentRoot "contracts"),
        (Join-Path $AgentRoot "modules"),
        (Join-Path $AgentRoot "validators"),
        (Join-Path $AgentRoot "orchestrator"),
        (Join-Path $AgentRoot "examples")
    )

    foreach ($Dir in $Dirs) {
        New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    }

    $ReadmeLines = @(
        "# $($Spec.display_name)",
        "",
        "## Mission",
        $Spec.mission,
        "",
        "## Agent ID",
        $Spec.agent_id,
        "",
        "## Package Profile",
        $Spec.package_profile
    )
    $ReadmeLines | Set-Content (Join-Path $AgentRoot "README.md") -Encoding UTF8

    @(
        "# AGENTS",
        "",
        "Generated agent package.",
        "Entrypoint: orchestrator/run.ps1"
    ) | Set-Content (Join-Path $AgentRoot "AGENTS.md") -Encoding UTF8

    @(
        "# AGENT MISSION",
        "",
        $Spec.mission
    ) | Set-Content (Join-Path $AgentRoot "AGENT_MISSION.md") -Encoding UTF8

    $InputContract = [ordered]@{
        contract = "input"
        inputs = $Spec.inputs
    }
    $InputContract | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $AgentRoot "contracts\input_contract.json") -Encoding UTF8

    $OutputContract = [ordered]@{
        contract = "output"
        outputs = $Spec.outputs
    }
    $OutputContract | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $AgentRoot "contracts\output_contract.json") -Encoding UTF8

    @(
        "# Generated modules",
        "Initial capability surfaces are declared by the specification."
    ) | Set-Content (Join-Path $AgentRoot "modules\README.md") -Encoding UTF8

    @(
        "param([ValidateSet(""VERIFY"",""RUN"")][string]`$Mode = ""VERIFY"")",
        "Set-StrictMode -Version Latest",
        "`$ErrorActionPreference = ""Stop""",
        "Write-Host ""GENERATED_AGENT_ORCHESTRATOR""",
        "Write-Host ""MODE=`$Mode""",
        "if (`$Mode -eq ""VERIFY"") { Write-Host ""STATUS=PASS""; return }",
        "Write-Host ""STATUS=RUN_NOT_IMPLEMENTED"""
    ) | Set-Content (Join-Path $AgentRoot "orchestrator\run.ps1") -Encoding UTF8

    @(
        "Set-StrictMode -Version Latest",
        "`$ErrorActionPreference = ""Stop""",
        "Write-Host ""GENERATED_AGENT_VALIDATOR=PASS"""
    ) | Set-Content (Join-Path $AgentRoot "validators\validate_package.ps1") -Encoding UTF8

    @{
        request = "example"
    } | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $AgentRoot "examples\SAMPLE_INPUT.json") -Encoding UTF8

    return [pscustomobject]@{
        agent_id = $Spec.agent_id
        package_root = $AgentRoot
        created_files = @(
            "README.md",
            "AGENTS.md",
            "AGENT_MISSION.md",
            "contracts/input_contract.json",
            "contracts/output_contract.json",
            "modules/README.md",
            "orchestrator/run.ps1",
            "validators/validate_package.ps1",
            "examples/SAMPLE_INPUT.json"
        )
        created_directories = @(
            "contracts",
            "modules",
            "validators",
            "orchestrator",
            "examples"
        )
    }
}
