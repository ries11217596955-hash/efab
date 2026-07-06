param([string]$RepoRoot,[string]$RunId,[switch]$InvokedByOrchestrator)
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

Copy-Item ".\packs\PHASE64_GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_CONTRACT_V1\payload\validators\validate_generated_family_autonomous_conveyor_contract_v1.ps1" ".\validators\validate_generated_family_autonomous_conveyor_contract_v1.ps1" -Force
& ".\validators\validate_generated_family_autonomous_conveyor_contract_v1.ps1" -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\packs\registry.json",
    ".\modules\invoke_generated_family_autonomous_conveyor.ps1",
    ".\validators\validate_generated_family_autonomous_conveyor_contract_v1.ps1",
    ".\proofs\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_CONTRACT_V1.json",
    ".\reports\generated_family_autonomous_conveyor\GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_CONTRACT_V1_REPORT.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 64 generated family autonomous conveyor contract v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
