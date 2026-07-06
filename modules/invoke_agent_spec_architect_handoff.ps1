function Invoke-AgentSpecArchitectHandoff {
    param(
        [string]$ArchitectSpecPath,
        [string]$ArchitectOverlayRoot,
        [string]$RawIdeaRequestPath,
        [string]$GeneratedAgentsRoot,
        [string]$RunRoot,
        [string]$DerivedSpecOutputPath
    )

    if (-not (Test-Path $ArchitectSpecPath)) {
        throw "Architect spec missing: $ArchitectSpecPath"
    }

    if (-not (Test-Path $ArchitectOverlayRoot)) {
        throw "Architect overlay missing: $ArchitectOverlayRoot"
    }

    if (-not (Test-Path $RawIdeaRequestPath)) {
        throw "Raw idea request missing: $RawIdeaRequestPath"
    }

    $ArchitectSpecPath = (Resolve-Path $ArchitectSpecPath).Path
    $ArchitectOverlayRoot = (Resolve-Path $ArchitectOverlayRoot).Path
    $RawIdeaRequestPath = (Resolve-Path $RawIdeaRequestPath).Path

    if (-not (Test-Path $GeneratedAgentsRoot)) {
        New-Item -ItemType Directory -Force -Path $GeneratedAgentsRoot | Out-Null
    }
    $GeneratedAgentsRoot = (Resolve-Path $GeneratedAgentsRoot).Path

    if (-not (Test-Path $RunRoot)) {
        New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
    }
    $RunRoot = (Resolve-Path $RunRoot).Path

    $DerivedSpecParent = Split-Path $DerivedSpecOutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($DerivedSpecParent)) {
        New-Item -ItemType Directory -Force -Path $DerivedSpecParent | Out-Null
    }

    $DerivedSpecOutputPath = Join-Path `
        (Resolve-Path (Split-Path $DerivedSpecOutputPath -Parent)).Path `
        (Split-Path $DerivedSpecOutputPath -Leaf)

    . ".\modules\invoke_external_agent_build.ps1"
    . ".\modules\validate_production_external_agent_spec.ps1"

    $ArchitectBuildRoot = Join-Path $RunRoot "architect_build"

    $ArchitectBuild = Invoke-ExternalAgentBuild `
        -SpecPath $ArchitectSpecPath `
        -OutputRoot $GeneratedAgentsRoot `
        -RunRoot $ArchitectBuildRoot `
        -OverlayRoot $ArchitectOverlayRoot

    if ($ArchitectBuild.status -ne "PASS") {
        throw "Architect package build failed."
    }

    $ArchitectPackageRoot = $ArchitectBuild.manifest.package_root
    $ArchitectOrchestrator = Join-Path $ArchitectPackageRoot "orchestrator\run.ps1"

    if (-not (Test-Path $ArchitectOrchestrator)) {
        throw "Generated Agent Spec Architect orchestrator missing."
    }

    $ArchitectResultRoot = Join-Path $RunRoot "architect_result"
    New-Item -ItemType Directory -Force -Path $ArchitectResultRoot | Out-Null
    $ArchitectResultRoot = (Resolve-Path $ArchitectResultRoot).Path

    $ArchitectResultPath = Join-Path $ArchitectResultRoot "AGENT_SPEC_ARCHITECT_RESULT.json"

    & $ArchitectOrchestrator `
        -Mode RUN `
        -InputPath $RawIdeaRequestPath `
        -OutputPath $ArchitectResultPath |
        Out-Host

    if (-not (Test-Path $ArchitectResultPath)) {
        throw "Agent Spec Architect result missing."
    }

    $ArchitectResult = Get-Content $ArchitectResultPath -Raw | ConvertFrom-Json

    if ($ArchitectResult.status -ne "PASS") {
        throw "Agent Spec Architect result status must be PASS."
    }

    $DraftSpec = $ArchitectResult.result.architecture.production_spec_draft

    if ($null -eq $DraftSpec) {
        throw "production_spec_draft missing from architect result."
    }

    $DraftSpec | ConvertTo-Json -Depth 100 |
        Set-Content $DerivedSpecOutputPath -Encoding UTF8

    $SpecValidation = Test-ProductionExternalAgentSpec -SpecPath $DerivedSpecOutputPath
    if ($SpecValidation -ne "PASS") {
        throw "Derived production spec validation failed."
    }

    return [pscustomobject]@{
        status = "PASS"
        architect_package_root = $ArchitectPackageRoot
        architect_result_path = $ArchitectResultPath
        derived_spec_path = $DerivedSpecOutputPath
        derived_agent_id = $DraftSpec.agent_id
        build_readiness = $ArchitectResult.result.architecture.build_readiness
    }
}
