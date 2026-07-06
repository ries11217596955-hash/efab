param(
    [ValidateSet("SELF_BUILD", "BUILD_EXTERNAL_AGENT", "VERIFY")]
    [string]$Mode = "VERIFY",

    [string]$RunId = ("SELF_BUILD_" + (Get-Date -Format "yyyyMMdd_HHmmss")),

    [ValidateRange(1, 25)]
    [int]$MaxPacks = 1,

    [string]$SpecPath,

    [string]$OutputRoot
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
        -RunRoot $RunRoot

    Write-Host "BUILD_EXTERNAL_AGENT_STATUS=$($Build.status)"
    Write-Host "BUILD_EXTERNAL_AGENT_PACKAGE_ROOT=$($Build.manifest.package_root)"
    Write-Host "BUILD_EXTERNAL_AGENT_REPORT_PATH=$($Build.report_path)"
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
