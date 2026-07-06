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
        (Join-Path $AgentRoot "examples"),
        (Join-Path $AgentRoot "deployment"),
        (Join-Path $AgentRoot "deployment\github_actions")
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
        "orchestrator/run.ps1 -Mode RUN -InputPath <request.json> -OutputPath <result.json>",
        "",
        "## GitHub Actions launch surface",
        "Delivery artifact:",
        "deployment/github_actions/run-generated-agent.workflow.yml",
        "",
        "When this agent package becomes its own repository, place the workflow at:",
        ".github/workflows/run-generated-agent.yml",
        "",
        "This creates a manual Run workflow button in GitHub Actions."
    ) | Set-Content (Join-Path $AgentRoot "README.md") -Encoding UTF8

    @(
        "# AGENTS",
        "",
        "Generated operational baseline agent package.",
        "Entrypoint: orchestrator/run.ps1",
        "Validator: validators/validate_package.ps1",
        "Action launch delivery artifact: deployment/github_actions/run-generated-agent.workflow.yml"
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
        "            github_action_launch_surface = ""delivery_artifact_present""",
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
        "        ""modules\invoke_agent_operation.ps1"",",
        "        ""deployment\github_actions\run-generated-agent.workflow.yml""",
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
        "name: Run Generated Agent",
        "",
        "on:",
        "  workflow_dispatch:",
        "    inputs:",
        "      input_path:",
        "        description: 'Request JSON path inside the agent repository.'",
        "        required: true",
        "        default: 'examples/SAMPLE_REQUEST.json'",
        "        type: string",
        "      output_path:",
        "        description: 'Optional result JSON path. Leave blank for automatic runs path.'",
        "        required: false",
        "        default: ''",
        "        type: string",
        "",
        "jobs:",
        "  run-generated-agent:",
        "    runs-on: windows-latest",
        "",
        "    steps:",
        "      - name: Checkout agent repository",
        "        uses: actions/checkout@v6",
        "",
        "      - name: Resolve output path",
        "        id: run_context",
        "        shell: pwsh",
        "        run: |",
        "          `$OutputPath = ""`${{ inputs.output_path }}""",
        "          if ([string]::IsNullOrWhiteSpace(`$OutputPath)) {",
        "              `$OutputPath = ""runs\GHA_AGENT_RUN_`${{ github.run_id }}\OPERATIONAL_RESULT.json""",
        "          }",
        "",
        "          `$OutputDir = Split-Path `$OutputPath -Parent",
        "          if (-not [string]::IsNullOrWhiteSpace(`$OutputDir)) {",
        "              New-Item -ItemType Directory -Force -Path `$OutputDir | Out-Null",
        "          }",
        "",
        "          New-Item -ItemType Directory -Force -Path "".\runs\GHA_AGENT_RUN_`${{ github.run_id }}"" | Out-Null",
        "          ""output_path=`$OutputPath"" >> `$env:GITHUB_OUTPUT",
        "",
        "      - name: Run generated agent",
        "        shell: pwsh",
        "        run: |",
        "          & "".\orchestrator\run.ps1"" ``",
        "              -Mode RUN ``",
        "              -InputPath ""`${{ inputs.input_path }}"" ``",
        "              -OutputPath ""`${{ steps.run_context.outputs.output_path }}"" |",
        "              Tee-Object -FilePath "".\runs\GHA_AGENT_RUN_`${{ github.run_id }}\GITHUB_ACTION_AGENT_RUN.log""",
        "",
        "      - name: Upload generated agent artifacts",
        "        if: always()",
        "        uses: actions/upload-artifact@v7",
        "        with:",
        "          name: generated-agent-run-`${{ github.run_id }}",
        "          path: |",
        "            runs",
        "          if-no-files-found: warn"
    ) | Set-Content (Join-Path $AgentRoot "deployment\github_actions\run-generated-agent.workflow.yml") -Encoding UTF8

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
        "    ""examples\SAMPLE_REQUEST.json"",",
        "    ""deployment\github_actions\run-generated-agent.workflow.yml""",
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
        "`$WorkflowText = Get-Content "".\deployment\github_actions\run-generated-agent.workflow.yml"" -Raw",
        "`$WorkflowMarkers = @(",
        "    ""workflow_dispatch:"",",
        "    ""orchestrator\run.ps1"",",
        "    ""actions/checkout@v6"",",
        "    ""actions/upload-artifact@v7""",
        ")",
        "",
        "foreach (`$Marker in `$WorkflowMarkers) {",
        "    if (`$WorkflowText -notmatch [regex]::Escape(`$Marker)) {",
        "        throw ""Generated agent workflow template missing marker: `$Marker""",
        "    }",
        "}",
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
        github_action_launch_delivery_artifact = "deployment/github_actions/run-generated-agent.workflow.yml"
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
            "examples/SAMPLE_REQUEST.json",
            "deployment/github_actions/run-generated-agent.workflow.yml"
        )
        created_directories = @(
            "contracts",
            "modules",
            "validators",
            "orchestrator",
            "examples",
            "deployment",
            "deployment/github_actions"
        )
    }
}


