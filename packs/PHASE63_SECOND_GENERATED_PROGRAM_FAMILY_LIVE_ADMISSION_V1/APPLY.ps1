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

Write-Host "PACK=PHASE63_SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_V1"

Copy-Item ".\packs\PHASE63_SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_V1\payload\validators\validate_second_generated_program_family_live_admission_v1.ps1" ".\validators\validate_second_generated_program_family_live_admission_v1.ps1" -Force

& ".\validators\validate_second_generated_program_family_live_admission_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\validators\validate_second_generated_program_family_live_admission_v1.ps1",
    ".\proofs\SECOND_GENERATED_PROGRAM_FAMILY_LIVE_ADMISSION_V1.json",
    ".\reports\second_generated_program_family_live_admission\REMEDIATION_INTAKE_AGENT_V1_LIVE_ADMISSION.json",
    ".\packs\registry.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\self_build_programs\generated\remediation_intake_agent_v1\SELF_BUILD_PROGRAM_MANIFEST.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 63 second generated program family live admission v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
