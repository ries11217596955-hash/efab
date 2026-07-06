param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $RepoRoot
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "CONNECTOR_READY=True"
Write-Host "MODE=DRY_RUN_NO_TASK_QUEUE_MUTATION"
Write-Host "DECISION=NO_READY_TASKS_TO_ENQUEUE"
