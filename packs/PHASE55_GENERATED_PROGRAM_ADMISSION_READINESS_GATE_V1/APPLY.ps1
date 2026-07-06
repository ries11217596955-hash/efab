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

Write-Host "PACK=PHASE55_GENERATED_PROGRAM_ADMISSION_READINESS_GATE_V1"

Copy-Item ".\packs\PHASE55_GENERATED_PROGRAM_ADMISSION_READINESS_GATE_V1\payload\modules\test_generated_self_build_program_admission_readiness.ps1" ".\modules\test_generated_self_build_program_admission_readiness.ps1" -Force
Copy-Item ".\packs\PHASE55_GENERATED_PROGRAM_ADMISSION_READINESS_GATE_V1\payload\validators\validate_generated_program_admission_readiness_gate_v1.ps1" ".\validators\validate_generated_program_admission_readiness_gate_v1.ps1" -Force

& ".\validators\validate_generated_program_admission_readiness_gate_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\modules\test_generated_self_build_program_admission_readiness.ps1",
    ".\validators\validate_generated_program_admission_readiness_gate_v1.ps1",
    ".\reports\generated_program_admission_readiness\MONITORING_AGENT_V1_ADMISSION_READINESS.json",
    ".\proofs\GENERATED_PROGRAM_ADMISSION_READINESS_GATE_V1.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 55 generated program admission readiness gate v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
