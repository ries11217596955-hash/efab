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

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE51_BUILDER_GITHUB_ACTION_MANUAL_RUN_SURFACE_V1"

New-Item -ItemType Directory -Force -Path ".\.github\workflows" | Out-Null
Copy-Item ".\packs\PHASE51_BUILDER_GITHUB_ACTION_MANUAL_RUN_SURFACE_V1\payload\github\agent-builder-self-build.yml" ".\.github\workflows\agent-builder-self-build.yml" -Force
Copy-Item ".\packs\PHASE51_BUILDER_GITHUB_ACTION_MANUAL_RUN_SURFACE_V1\payload\validators\validate_builder_github_action_manual_run_surface_v1.ps1" ".\validators\validate_builder_github_action_manual_run_surface_v1.ps1" -Force

& ".\validators\validate_builder_github_action_manual_run_surface_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\.github\workflows\agent-builder-self-build.yml",
    ".\validators\validate_builder_github_action_manual_run_surface_v1.ps1",
    ".\tasks\TASK_GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1_001.json",
    ".\proofs\BUILDER_GITHUB_ACTION_MANUAL_RUN_SURFACE_V1.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 51 builder GitHub Action manual run surface v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"

