param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-NativeGitCommand {
    param(
        [string]$Label,
        [string[]]$Arguments
    )

    $PreviousPreference = $ErrorActionPreference
    $Output = @()
    $ExitCode = $null

    try {
        $ErrorActionPreference = "Continue"
        $Output = @(& git @Arguments 2>&1)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    foreach ($Line in $Output) {
        Write-Host ($Line.ToString())
    }

    if ($ExitCode -ne 0) {
        throw "GIT_${Label}_FAILED_EXIT_CODE=$ExitCode"
    }

    Write-Host "GIT_${Label}=PASS"
}

function Copy-PayloadTree {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot
    )

    if (-not (Test-Path -LiteralPath $SourceRoot)) {
        throw "Payload source missing: $SourceRoot"
    }

    New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
    $TrimChars = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $ResolvedSourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd($TrimChars)

    foreach ($SourceFile in Get-ChildItem -LiteralPath $ResolvedSourceRoot -Recurse -File) {
        $RelativePath = $SourceFile.FullName.Substring($ResolvedSourceRoot.Length).TrimStart($TrimChars)
        $DestinationPath = Join-Path $TargetRoot $RelativePath
        $DestinationDirectory = Split-Path -Parent $DestinationPath
        if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
            New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
        }

        Copy-Item -LiteralPath $SourceFile.FullName -Destination $DestinationPath -Force
    }
}

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { throw "RepoRoot is required." }

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$PackRoot = Join-Path $RepoRoot "packs\PHASE67_EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1"
$PayloadAgentRoot = Join-Path $PackRoot "payload\generated_agents\remediation_intake_operator_agent_v1"
$TargetAgentRoot = Join-Path $RepoRoot "generated_agents\remediation_intake_operator_agent_v1"
$PayloadValidatorPath = Join-Path $PackRoot "payload\validators\validate_remediation_intake_operator_agent_v1.ps1"
$RuntimeValidatorPath = Join-Path $RepoRoot "validators\validate_remediation_intake_operator_agent_v1.ps1"

Copy-PayloadTree -SourceRoot $PayloadAgentRoot -TargetRoot $TargetAgentRoot
Copy-Item -LiteralPath $PayloadValidatorPath -Destination $RuntimeValidatorPath -Force

& $RuntimeValidatorPath -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    "-f",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\packs\registry.json",
    ".\GENERATED_PROGRAM_LIVE_ADMISSION_MASTER_PLAN.md",
    ".\tasks\TASK_EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_001.json",
    ".\packs\PHASE67_EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1",
    ".\generated_agents\remediation_intake_operator_agent_v1",
    ".\validators\validate_remediation_intake_operator_agent_v1.ps1",
    ".\proofs\EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1.json",
    ".\reports\external_agent_production\EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 67 external agent production program test v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
