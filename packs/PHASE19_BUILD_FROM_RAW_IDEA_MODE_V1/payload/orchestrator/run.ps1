param(
    [ValidateSet("SELF_BUILD", "BUILD_EXTERNAL_AGENT", "BUILD_FROM_RAW_IDEA", "VERIFY")]
    [string]$Mode = "VERIFY",

    [string]$RunId = ("SELF_BUILD_" + (Get-Date -Format "yyyyMMdd_HHmmss")),

    [ValidateRange(1, 25)]
    [int]$MaxPacks = 1,

    [string]$SpecPath,

    [string]$OutputRoot,

    [string]$OverlayRoot = "",

    [string]$RawIdeaPath,

    [string]$DerivedSpecPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

Write-Host "AGENT_BUILDER_ORCHESTRATOR"
Write-Host "MODE=$Mode"
Write-Host "RUN_ID=$RunId"

if ($Mode -eq "VERIFY") {
    Write-Host "STATUS=PASS"
    return
}

if ($Mode -eq "BUILD_EXTERNAL_AGENT") {
    if ([string]::IsNullOrWhiteSpace($SpecPath)) { throw "SpecPath is required." }
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) { throw "OutputRoot is required." }

    . ".\modules\invoke_external_agent_build.ps1"

    $RunRoot = ".\runs\$RunId\BUILD_EXTERNAL_AGENT_MODE_V2"

    $Build = Invoke-ExternalAgentBuild `
        -SpecPath $SpecPath `
        -OutputRoot $OutputRoot `
        -RunRoot $RunRoot `
        -OverlayRoot $OverlayRoot

    Write-Host "BUILD_EXTERNAL_AGENT_STATUS=$($Build.status)"
    Write-Host "BUILD_EXTERNAL_AGENT_PACKAGE_ROOT=$($Build.manifest.package_root)"
    Write-Host "BUILD_EXTERNAL_AGENT_OVERLAY_STATUS=$($Build.overlay.status)"
    Write-Host "BUILD_EXTERNAL_AGENT_OVERLAY_FILE_COUNT=$($Build.overlay.applied_file_count)"
    Write-Host "BUILD_EXTERNAL_AGENT_REPORT_PATH=$($Build.report_path)"
    return
}

if ($Mode -eq "BUILD_FROM_RAW_IDEA") {
    if ([string]::IsNullOrWhiteSpace($RawIdeaPath)) { throw "RawIdeaPath is required." }
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) { throw "OutputRoot is required." }

    . ".\modules\invoke_agent_spec_architect_handoff.ps1"
    . ".\modules\invoke_external_agent_build.ps1"

    $ModeRoot = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_MODE_V1"
    New-Item -ItemType Directory -Force -Path $ModeRoot | Out-Null

    if ([string]::IsNullOrWhiteSpace($DerivedSpecPath)) {
        $DerivedSpecPath = Join-Path $ModeRoot "DERIVED_AGENT_SPEC.json"
    }

    $Handoff = Invoke-AgentSpecArchitectHandoff `
        -ArchitectSpecPath ".\specs\applied_agents\agent_spec_architect\AGENT_SPEC_ARCHITECT_SPEC.json" `
        -ArchitectOverlayRoot ".\applied_agents\agent_spec_architect\overlay" `
        -RawIdeaRequestPath $RawIdeaPath `
        -GeneratedAgentsRoot ".\generated_agents" `
        -RunRoot (Join-Path $ModeRoot "architect_handoff") `
        -DerivedSpecOutputPath $DerivedSpecPath

    if ($Handoff.status -ne "PASS") {
        throw "Raw idea handoff failed."
    }

    $TargetBuild = Invoke-ExternalAgentBuild `
        -SpecPath $Handoff.derived_spec_path `
        -OutputRoot $OutputRoot `
        -RunRoot (Join-Path $ModeRoot "target_build")

    if ($TargetBuild.status -ne "PASS") {
        throw "Derived external agent build failed."
    }

    $Report = [ordered]@{
        report_id = "BUILD_FROM_RAW_IDEA_MODE_V1"
        run_id = $RunId
        status = "PASS"
        raw_idea_path = $RawIdeaPath
        derived_spec_path = $Handoff.derived_spec_path
        derived_agent_id = $Handoff.derived_agent_id
        architect_handoff = $Handoff
        target_build = [ordered]@{
            status = $TargetBuild.status
            package_root = $TargetBuild.manifest.package_root
            report_path = $TargetBuild.report_path
            validation_output = $TargetBuild.validation.output_result_path
        }
    }

    $ReportPath = Join-Path $ModeRoot "BUILD_FROM_RAW_IDEA_REPORT.json"
    $Report | ConvertTo-Json -Depth 100 |
        Set-Content $ReportPath -Encoding UTF8

    Write-Host "BUILD_FROM_RAW_IDEA_STATUS=$($Report.status)"
    Write-Host "BUILD_FROM_RAW_IDEA_DERIVED_AGENT_ID=$($Report.derived_agent_id)"
    Write-Host "BUILD_FROM_RAW_IDEA_DERIVED_SPEC_PATH=$($Report.derived_spec_path)"
    Write-Host "BUILD_FROM_RAW_IDEA_PACKAGE_ROOT=$($Report.target_build.package_root)"
    Write-Host "BUILD_FROM_RAW_IDEA_REPORT_PATH=$ReportPath"
    return
}

. ".\modules\read_pack_registry.ps1"
. ".\modules\select_self_build_pack.ps1"
. ".\modules\execute_self_build_pack.ps1"

Write-Host "MAX_PACKS=$MaxPacks"

$Executed = 0

for ($i = 1; $i -le $MaxPacks; $i++) {
    $Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
    $Registry = Read-SelfBuildPackRegistry -RepoRoot $RepoRoot

    $Pack = $Registry.packs |
        Where-Object { $_.task_id -eq $Queue.active_task_id } |
        Select-Object -First 1

    if ($null -eq $Pack) {
        Write-Host "NO_REGISTERED_PACK_FOR_ACTIVE_TASK=$($Queue.active_task_id)"
        Write-Host "STATUS=PASS_STOPPED_NO_REGISTERED_PACK"
        return
    }

    Write-Host "SELECTED_PACK=$($Pack.pack_id)"
    Write-Host "SELECTED_TASK=$($Pack.task_id)"

    $Result = Invoke-SelfBuildPack `
        -RepoRoot $RepoRoot `
        -Pack $Pack `
        -RunId "$RunId`__PACK_$i"

    Write-Host "PACK_STATUS=$($Result.status)"

    if ($Result.status -ne "PASS") {
        if ($Result.error) {
            Write-Host "PACK_ERROR=$($Result.error)"
        }
        throw "Self-build pack failed."
    }

    $Executed++
}

Write-Host "PACKS_EXECUTED=$Executed"
Write-Host "STATUS=PASS_MAX_PACKS_REACHED"
