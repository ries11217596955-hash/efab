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

Write-Host "PACK=PHASE62_SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1"

Copy-Item ".\packs\PHASE62_SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1\payload\modules\materialize_generated_self_build_program_from_family_contract.ps1" ".\modules\materialize_generated_self_build_program_from_family_contract.ps1" -Force
Copy-Item ".\packs\PHASE62_SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1\payload\validators\validate_second_generated_program_family_materialization_v1.ps1" ".\validators\validate_second_generated_program_family_materialization_v1.ps1" -Force

& ".\validators\validate_second_generated_program_family_materialization_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\modules\materialize_generated_self_build_program_from_family_contract.ps1",
    ".\validators\validate_second_generated_program_family_materialization_v1.ps1",
    ".\self_build_programs\generated\remediation_intake_agent_v1",
    ".\proofs\SECOND_GENERATED_PROGRAM_FAMILY_MATERIALIZATION_V1.json",
    ".\reports\second_generated_program_family_materialization\REMEDIATION_INTAKE_AGENT_V1_MATERIALIZATION.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 62 second generated program family materialization v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
