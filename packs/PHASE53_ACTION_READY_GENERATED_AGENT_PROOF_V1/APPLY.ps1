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

Write-Host "PACK=PHASE53_ACTION_READY_GENERATED_AGENT_PROOF_V1"

New-Item -ItemType Directory -Force -Path ".\specs\github_action_surface_proof" | Out-Null
Copy-Item ".\packs\PHASE53_ACTION_READY_GENERATED_AGENT_PROOF_V1\payload\specs\github_action_surface_proof\ACTION_READY_AGENT_PROOF_SPEC.json" ".\specs\github_action_surface_proof\ACTION_READY_AGENT_PROOF_SPEC.json" -Force
Copy-Item ".\packs\PHASE53_ACTION_READY_GENERATED_AGENT_PROOF_V1\payload\validators\validate_action_ready_generated_agent_proof_v1.ps1" ".\validators\validate_action_ready_generated_agent_proof_v1.ps1" -Force

& ".\validators\validate_action_ready_generated_agent_proof_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\specs\github_action_surface_proof\ACTION_READY_AGENT_PROOF_SPEC.json",
    ".\validators\validate_action_ready_generated_agent_proof_v1.ps1",
    ".\proofs\ACTION_READY_GENERATED_AGENT_PROOF_V1.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 53 Action-ready generated agent proof v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"

