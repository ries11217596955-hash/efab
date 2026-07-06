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

Write-Host "PACK=PHASE57_GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1"

Copy-Item ".\packs\PHASE57_GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1\payload\modules\admit_generated_self_build_program_to_live_execution.ps1" ".\modules\admit_generated_self_build_program_to_live_execution.ps1" -Force
Copy-Item ".\packs\PHASE57_GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1\payload\validators\validate_generated_program_live_admission_proof_v1.ps1" ".\validators\validate_generated_program_live_admission_proof_v1.ps1" -Force

& ".\validators\validate_generated_program_live_admission_proof_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\modules\admit_generated_self_build_program_to_live_execution.ps1",
    ".\validators\validate_generated_program_live_admission_proof_v1.ps1",
    ".\proofs\GENERATED_PROGRAM_LIVE_ADMISSION_PROOF_V1.json",
    ".\reports\generated_program_live_admission\MONITORING_AGENT_V1_LIVE_ADMISSION.json",
    ".\self_build_programs\generated\monitoring_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json",
    ".\packs\registry.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 57 generated program live admission proof v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
