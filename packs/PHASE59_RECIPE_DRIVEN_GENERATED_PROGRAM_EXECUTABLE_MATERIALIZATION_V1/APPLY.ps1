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

Write-Host "PACK=PHASE59_RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1"

Copy-Item ".\packs\PHASE59_RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1\payload\modules\render_generated_self_build_pack_apply_from_recipe.ps1" ".\modules\render_generated_self_build_pack_apply_from_recipe.ps1" -Force
Copy-Item ".\packs\PHASE59_RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1\payload\modules\complete_generated_self_build_program_executable_packs.ps1" ".\modules\complete_generated_self_build_program_executable_packs.ps1" -Force
Copy-Item ".\packs\PHASE59_RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1\payload\validators\validate_recipe_driven_generated_program_executable_materialization_v1.ps1" ".\validators\validate_recipe_driven_generated_program_executable_materialization_v1.ps1" -Force

& ".\validators\validate_recipe_driven_generated_program_executable_materialization_v1.ps1" -FinalizePhase -RunId $RunId

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\modules\render_generated_self_build_pack_apply_from_recipe.ps1",
    ".\modules\complete_generated_self_build_program_executable_packs.ps1",
    ".\validators\validate_recipe_driven_generated_program_executable_materialization_v1.ps1",
    ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_PROFILE_MATERIALIZATION_V1\APPLY.ps1",
    ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_CLOSURE_PROOF_V1\APPLY.ps1",
    ".\self_build_programs\generated\monitoring_agent_v1\packs\GENERATED_MONITORING_AGENT_V1_SEED_CONSUMPTION_PROOF_V1\APPLY.ps1",
    ".\proofs\RECIPE_DRIVEN_GENERATED_PROGRAM_EXECUTABLE_MATERIALIZATION_V1.json",
    ".\reports\recipe_driven_generated_program_materialization\MONITORING_AGENT_V1_RECIPE_RENDERING_PARITY.json",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Self-build PHASE 59 recipe-driven generated program executable materialization v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
