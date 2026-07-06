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

Write-Host "PACK=PHASE60_GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1"

Copy-Item ".\packs\PHASE60_GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1\payload\modules\admit_generated_self_build_program_to_live_execution.ps1" ".\modules\admit_generated_self_build_program_to_live_execution.ps1" -Force
Copy-Item ".\packs\PHASE60_GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1\payload\validators\validate_generalized_generated_program_live_admission_contract_v1.ps1" ".\validators\validate_generalized_generated_program_live_admission_contract_v1.ps1" -Force

& ".\validators\validate_generalized_generated_program_live_admission_contract_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\modules\admit_generated_self_build_program_to_live_execution.ps1",
    ".\validators\validate_generalized_generated_program_live_admission_contract_v1.ps1",
    ".\proofs\GENERALIZED_GENERATED_PROGRAM_LIVE_ADMISSION_CONTRACT_V1.json",
    ".\reports\generalized_generated_program_live_admission\MONITORING_AGENT_V1_GENERALIZED_ADMISSION_CONTRACT.json",
    ".\packs\registry.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 60 generalized generated program live admission contract v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
