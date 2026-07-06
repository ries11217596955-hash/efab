param(
  [string]$RepoRoot = (Join-Path $env:USERPROFILE "Documents\e-factory-agent-builder")
)

$ErrorActionPreference = "Stop"
$Continue = $true
$Branch = "phase110-idempotent-autonomy-trial-runtime"

Write-Host "RESTORE_AGENT_BUILDER_STATE"
Write-Host "REPO_ROOT=$RepoRoot"

if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
  Write-Host "STOP=USERPROFILE_NOT_SET"
  $Continue = $false
}

if ($Continue -and -not (Test-Path -LiteralPath $RepoRoot)) {
  Write-Host "STOP=REPO_ROOT_NOT_FOUND"
  $Continue = $false
}

if ($Continue) {
  Push-Location $RepoRoot
  try {
    foreach ($identityFile in @(
      "CAPABILITY_ROADMAP.json",
      "GENESIS_STATE.json",
      "TASK_QUEUE.json",
      "packs/registry.json",
      "orchestrator/run.ps1"
    )) {
      if (-not (Test-Path -LiteralPath $identityFile)) {
        Write-Host "STOP=WRONG_AGENT_BUILDER_REPO"
        Write-Host "MISSING=$identityFile"
        $Continue = $false
      }
    }

    if ($Continue) {
      git fetch origin
      git switch $Branch
      git pull --ff-only origin $Branch

      $CurrentBranch = (git branch --show-current).Trim()
      $CurrentHead = (git rev-parse --short HEAD).Trim()
      $StatusLines = @(git status --short)

      Write-Host "BRANCH=$CurrentBranch"
      Write-Host "HEAD=$CurrentHead"
      if ($StatusLines.Count -eq 0) {
        Write-Host "STATUS_SHORT=CLEAN"
      } else {
        foreach ($line in $StatusLines) {
          Write-Host "STATUS_SHORT=$line"
        }
      }

      $NextActionPath = Join-Path $RepoRoot "self_control\NEXT_ACTION.json"
      if (Test-Path -LiteralPath $NextActionPath) {
        $NextAction = Get-Content -LiteralPath $NextActionPath -Raw | ConvertFrom-Json
        Write-Host "NEXT_ALLOWED_STEP=$($NextAction.next_allowed_step)"
      } else {
        Write-Host "NEXT_ALLOWED_STEP=UNKNOWN"
      }
    }
  } finally {
    Pop-Location
  }
}
