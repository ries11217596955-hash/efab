function New-ExternalAgentPackage {
    param(
        [object]$Spec,
        [string]$OutputRoot
    )

    $AgentRoot = Join-Path $OutputRoot $Spec.agent_id
    New-Item -ItemType Directory -Force -Path $AgentRoot | Out-Null
    $AgentRoot = (Resolve-Path $AgentRoot).Path

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

    @(
        "# $($Spec.display_name)",
        "",
        "## Mission",
        $Spec.mission,
        "",
        "## Agent ID",
        $Spec.agent_id,
        "",
        "## Package Profile",
        $Spec.package_profile,
        "",
        "## Runtime",
        "orchestrator/run.ps1 -Mode RUN -InputPath <request.json> -OutputPath <result.json>"
    ) | Set-Content (Join-Path $AgentRoot "README.md") -Encoding UTF8

    @(
        "# AGENTS",
        "",
        "Generated operational baseline agent package.",
        "Entrypoint: orchestrator/run.ps1",
        "Validator: validators/validate_package.ps1"
    ) | Set-Content (Join-Path $AgentRoot "AGENTS.md") -Encoding UTF8

    @(
        "# AGENT MISSION",
        "",
        $Spec.mission
    ) | Set-Content (Join-Path $AgentRoot "AGENT_MISSION.md") -Encoding UTF8

    $Profile = [ordered]@{
        agent_id = $Spec.agent_id
        display_name = $Spec.display_name
        mission = $Spec.mission
        package_profile = $Spec.package_profile
        capabilities = $Spec.capabilities
    }

    $Profile | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $AgentRoot "AGENT_PROFILE.json") -Encoding UTF8

    $RequestSchema = [ordered]@{
        '$schema' = "https://json-schema.org/draft/2020-12/schema"
        title = "Generated Agent Request"
        type = "object"
        required = @("request_id", "payload")
        properties = [ordered]@{
            request_id = [ordered]@{ type = "string" }
            payload = [ordered]@{ type = "object" }
            metadata = [ordered]@{ type = "object" }
        }
    }

    $ResultSchema = [ordered]@{
        '$schema' = "https://json-schema.org/draft/2020-12/schema"
        title = "Generated Agent Result"
        type = "object"
        required = @("status", "request_id", "agent_id", "result", "diagnostics")
        properties = [ordered]@{
            status = [ordered]@{ type = "string" }
            request_id = [ordered]@{ type = "string" }
            agent_id = [ordered]@{ type = "string" }
            result = [ordered]@{ type = "object" }
            diagnostics = [ordered]@{ type = "object" }
        }
    }

    $RequestSchema | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $AgentRoot "contracts\request.schema.json") -Encoding UTF8

    $ResultSchema | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $AgentRoot "contracts\result.schema.json") -Encoding UTF8

    @(
        "function Invoke-AgentOperation {",
        "    param(",
        "        [object]`$Request,",
        "        [object]`$Profile",
        "    )",
        "",
        "    `$PayloadKeys = @()",
        "    if (`$null -ne `$Request.payload) {",
        "        `$PayloadKeys = @(`$Request.payload.PSObject.Properties.Name)",
        "    }",
        "",
        "    return [pscustomobject]@{",
        "        status = ""PASS""",
        "        request_id = `$Request.request_id",
        "        agent_id = `$Profile.agent_id",
        "        result = [ordered]@{",
        "            operation = ""baseline_request_processing""",
        "            mission = `$Profile.mission",
        "            payload_key_count = @(`$PayloadKeys).Count",
        "            payload_keys = `$PayloadKeys",
        "        }",
        "        diagnostics = [ordered]@{",
        "            package_profile = `$Profile.package_profile",
        "            capability_count = @(`$Profile.capabilities).Count",
        "        }",
        "    }",
        "}"
    ) | Set-Content (Join-Path $AgentRoot "modules\invoke_agent_operation.ps1") -Encoding UTF8

    @(
        "param(",
        "    [ValidateSet(""VERIFY"",""RUN"")]",
        "    [string]`$Mode = ""VERIFY"",",
        "    [string]`$InputPath,",
        "    [string]`$OutputPath",
        ")",
        "",
        "Set-StrictMode -Version Latest",
        "`$ErrorActionPreference = ""Stop""",
        "",
        "`$AgentRoot = (Resolve-Path (Join-Path `$PSScriptRoot "".."")).Path",
        "`$OriginalLocation = Get-Location",
        "Push-Location `$AgentRoot",
        "try {",
        "",
        "Write-Host ""GENERATED_AGENT_ORCHESTRATOR""",
        "Write-Host ""MODE=`$Mode""",
        "",
        "if (`$Mode -eq ""VERIFY"") {",
        "    `$Required = @(",
        "        ""AGENT_PROFILE.json"",",
        "        ""contracts\request.schema.json"",",
        "        ""contracts\result.schema.json"",",
        "        ""modules\invoke_agent_operation.ps1""",
        "    )",
        "    foreach (`$Rel in `$Required) {",
        "        if (-not (Test-Path (Join-Path `$AgentRoot `$Rel))) {",
        "            throw ""VERIFY missing file: `$Rel""",
        "        }",
        "    }",
        "    Write-Host ""STATUS=PASS""",
        "    return",
        "}",
        "",
        "if ([string]::IsNullOrWhiteSpace(`$InputPath)) { throw ""InputPath is required for RUN."" }",
        "if ([string]::IsNullOrWhiteSpace(`$OutputPath)) { throw ""OutputPath is required for RUN."" }",
        "if (-not (Test-Path `$InputPath)) { throw ""Input file not found: `$InputPath"" }",
        "",
        "`$Request = Get-Content `$InputPath -Raw | ConvertFrom-Json",
        "if ([string]::IsNullOrWhiteSpace(`$Request.request_id)) { throw ""request_id is required."" }",
        "if (`$null -eq `$Request.payload) { throw ""payload is required."" }",
        "",
        "`$Profile = Get-Content "".\AGENT_PROFILE.json"" -Raw | ConvertFrom-Json",
        ". "".\modules\invoke_agent_operation.ps1""",
        "`$Result = Invoke-AgentOperation -Request `$Request -Profile `$Profile",
        "`$Result | ConvertTo-Json -Depth 100 | Set-Content `$OutputPath -Encoding UTF8",
        "",
        "Write-Host ""GENERATED_AGENT_RUN_STATUS=`$(`$Result.status)""",
        "Write-Host ""GENERATED_AGENT_OUTPUT_PATH=`$OutputPath""",
        "}",
        "finally {",
        "    Pop-Location",
        "}"
    ) | Set-Content (Join-Path $AgentRoot "orchestrator\run.ps1") -Encoding UTF8

    @(
        "Set-StrictMode -Version Latest",
        "`$ErrorActionPreference = ""Stop""",
        "",
        "`$AgentRoot = (Resolve-Path (Join-Path `$PSScriptRoot "".."")).Path",
        "`$OriginalLocation = Get-Location",
        "Push-Location `$AgentRoot",
        "try {",
        "",
        "`$Required = @(",
        "    ""AGENT_PROFILE.json"",",
        "    ""contracts\request.schema.json"",",
        "    ""contracts\result.schema.json"",",
        "    ""modules\invoke_agent_operation.ps1"",",
        "    ""orchestrator\run.ps1"",",
        "    ""examples\SAMPLE_REQUEST.json""",
        ")",
        "",
        "foreach (`$Rel in `$Required) {",
        "    if (-not (Test-Path (Join-Path `$AgentRoot `$Rel))) {",
        "        throw ""Package validator missing file: `$Rel""",
        "    }",
        "}",
        "",
        "`$null = Get-Content "".\AGENT_PROFILE.json"" -Raw | ConvertFrom-Json",
        "`$null = Get-Content "".\contracts\request.schema.json"" -Raw | ConvertFrom-Json",
        "`$null = Get-Content "".\contracts\result.schema.json"" -Raw | ConvertFrom-Json",
        "",
        "`$Tokens = `$null",
        "`$Errors = `$null",
        "[System.Management.Automation.Language.Parser]::ParseFile(",
        "    (Resolve-Path "".\orchestrator\run.ps1""),",
        "    [ref]`$Tokens,",
        "    [ref]`$Errors",
        ") | Out-Null",
        "",
        "if (`$Errors.Count -ne 0) { throw ""Generated orchestrator parser check failed."" }",
        "",
        "& "".\orchestrator\run.ps1"" -Mode VERIFY | Out-Host",
        "Write-Host ""GENERATED_AGENT_VALIDATOR=PASS""",
        "}",
        "finally {",
        "    Pop-Location",
        "}"
    ) | Set-Content (Join-Path $AgentRoot "validators\validate_package.ps1") -Encoding UTF8

    [ordered]@{
        request_id = "sample_request_001"
        payload = [ordered]@{
            topic = "baseline operational proof"
            priority = "normal"
        }
        metadata = [ordered]@{
            source = "factory_generated_example"
        }
    } | ConvertTo-Json -Depth 100 |
        Set-Content (Join-Path $AgentRoot "examples\SAMPLE_REQUEST.json") -Encoding UTF8

    return [pscustomobject]@{
        agent_id = $Spec.agent_id
        package_root = $AgentRoot
        runtime_entrypoint = "orchestrator/run.ps1"
        validator_entrypoint = "validators/validate_package.ps1"
        created_files = @(
            "README.md",
            "AGENTS.md",
            "AGENT_MISSION.md",
            "AGENT_PROFILE.json",
            "contracts/request.schema.json",
            "contracts/result.schema.json",
            "modules/invoke_agent_operation.ps1",
            "orchestrator/run.ps1",
            "validators/validate_package.ps1",
            "examples/SAMPLE_REQUEST.json"
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

