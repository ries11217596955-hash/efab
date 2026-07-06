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

Copy-Item ".\packs\PHASE66_GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1\payload\validators\validate_generated_family_autonomous_conveyor_failure_recovery_v1.ps1" ".\validators\validate_generated_family_autonomous_conveyor_failure_recovery_v1.ps1" -Force

& ".\validators\validate_generated_family_autonomous_conveyor_failure_recovery_v1.ps1" -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\packs\registry.json",
    ".\GENERATED_PROGRAM_LIVE_ADMISSION_MASTER_PLAN.md",
    ".\tasks\TASK_GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1_001.json",
    ".\tasks\TASK_GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1_001.json",
    ".\packs\PHASE66_GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1",
    ".\self_build_programs\generated\conveyor_failure_trial_family_v1",
    ".\validators\validate_generated_family_autonomous_conveyor_failure_recovery_v1.ps1",
    ".\proofs\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_FAILURE_RECOVERY_V1.json",
    ".\proofs\GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1.json",
    ".\reports\generated_family_autonomous_conveyor\*FAILURE_RECOVERY*.json",
    ".\reports\generated_family_autonomous_conveyor\GENERATED_CONVEYOR_FAILURE_TRIAL_FAMILY_V1_FAILURE_PACK_V1_REPORT.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 66 generated family autonomous conveyor failure recovery v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
