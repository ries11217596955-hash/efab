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
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { throw "RepoRoot is required." }

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$PackRoot = Join-Path $RepoRoot "packs\PHASE68_AGENT_GITHUB_ACTION_LAUNCH_V1"
$WorkflowPayloadPath = Join-Path $PackRoot "payload\.github\workflows\run-remediation-intake-operator-agent-v1.yml"
$WorkflowTargetDirectory = Join-Path $RepoRoot ".github\workflows"
$WorkflowTargetPath = Join-Path $WorkflowTargetDirectory "run-remediation-intake-operator-agent-v1.yml"
$ValidatorPayloadPath = Join-Path $PackRoot "payload\validators\validate_agent_github_action_launch_v1.ps1"
$ValidatorTargetPath = Join-Path $RepoRoot "validators\validate_agent_github_action_launch_v1.ps1"

if (-not (Test-Path -LiteralPath $WorkflowPayloadPath)) {
    throw "Workflow payload missing: $WorkflowPayloadPath"
}
if (-not (Test-Path -LiteralPath $ValidatorPayloadPath)) {
    throw "Validator payload missing: $ValidatorPayloadPath"
}

New-Item -ItemType Directory -Force -Path $WorkflowTargetDirectory | Out-Null
Copy-Item -LiteralPath $WorkflowPayloadPath -Destination $WorkflowTargetPath -Force
Copy-Item -LiteralPath $ValidatorPayloadPath -Destination $ValidatorTargetPath -Force

& $ValidatorTargetPath -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\packs\registry.json",
    ".\tasks\TASK_AGENT_GITHUB_ACTION_LAUNCH_V1_001.json",
    ".\packs\PHASE68_AGENT_GITHUB_ACTION_LAUNCH_V1",
    ".\.github\workflows\run-remediation-intake-operator-agent-v1.yml",
    ".\validators\validate_agent_github_action_launch_v1.ps1",
    ".\proofs\AGENT_GITHUB_ACTION_LAUNCH_V1.json",
    ".\reports\external_agent_production\AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Add GitHub Action launch for remediation intake operator agent"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
