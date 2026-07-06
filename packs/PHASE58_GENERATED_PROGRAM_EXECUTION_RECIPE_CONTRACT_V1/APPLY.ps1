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

Write-Host "PACK=PHASE58_GENERATED_PROGRAM_EXECUTION_RECIPE_CONTRACT_V1"

Copy-Item ".\packs\PHASE58_GENERATED_PROGRAM_EXECUTION_RECIPE_CONTRACT_V1\payload\modules\new_generated_self_build_program_execution_recipe_bundle.ps1" ".\modules\new_generated_self_build_program_execution_recipe_bundle.ps1" -Force
Copy-Item ".\packs\PHASE58_GENERATED_PROGRAM_EXECUTION_RECIPE_CONTRACT_V1\payload\validators\validate_generated_program_execution_recipe_contract_v1.ps1" ".\validators\validate_generated_program_execution_recipe_contract_v1.ps1" -Force

& ".\validators\validate_generated_program_execution_recipe_contract_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\modules\new_generated_self_build_program_execution_recipe_bundle.ps1",
    ".\validators\validate_generated_program_execution_recipe_contract_v1.ps1",
    ".\contracts\generated_self_build_program_execution_recipe.schema.json",
    ".\self_build_programs\generated\monitoring_agent_v1\execution_recipes",
    ".\proofs\GENERATED_PROGRAM_EXECUTION_RECIPE_CONTRACT_V1.json",
    ".\reports\generated_program_execution_recipes\MONITORING_AGENT_V1_EXECUTION_RECIPE_BUNDLE.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 58 generated program execution recipe contract v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
