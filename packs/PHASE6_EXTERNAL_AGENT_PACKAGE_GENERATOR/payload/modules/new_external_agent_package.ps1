function New-ExternalAgentPackage {
    param(
        [object]$Spec,
        [string]$OutputRoot
    )

    $AgentRoot = Join-Path $OutputRoot $Spec.agent_id
    New-Item -ItemType Directory -Force -Path $AgentRoot | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $AgentRoot "contracts") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $AgentRoot "modules") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $AgentRoot "validators") | Out-Null

    "# $($Spec.agent_id)" | Set-Content (Join-Path $AgentRoot "README.md") -Encoding UTF8
    "Agent mission: $($Spec.mission)" | Set-Content (Join-Path $AgentRoot "AGENT_MISSION.md") -Encoding UTF8

    return [pscustomobject]@{
        agent_id = $Spec.agent_id
        package_root = $AgentRoot
        created_files = @(
            "README.md",
            "AGENT_MISSION.md"
        )
    }
}
