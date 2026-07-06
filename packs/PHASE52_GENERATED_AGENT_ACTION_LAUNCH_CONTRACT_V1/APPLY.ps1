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

Write-Host "PACK=PHASE52_GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1"

Copy-Item ".\packs\PHASE52_GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1\payload\contracts\generated_agent_github_action_launch_surface.contract.json" ".\contracts\generated_agent_github_action_launch_surface.contract.json" -Force
Copy-Item ".\packs\PHASE52_GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1\payload\modules\new_external_agent_package.ps1" ".\modules\new_external_agent_package.ps1" -Force
Copy-Item ".\packs\PHASE52_GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1\payload\validators\validate_generated_agent_action_launch_contract_v1.ps1" ".\validators\validate_generated_agent_action_launch_contract_v1.ps1" -Force

& ".\validators\validate_generated_agent_action_launch_contract_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\contracts\generated_agent_github_action_launch_surface.contract.json",
    ".\modules\new_external_agent_package.ps1",
    ".\validators\validate_generated_agent_action_launch_contract_v1.ps1",
    ".\tasks\TASK_ACTION_READY_GENERATED_AGENT_PROOF_V1_001.json",
    ".\proofs\GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 52 generated agent Action launch contract v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"

