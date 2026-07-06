param(
  [string]$SessionId = "LIVE_AFTER_PHASE145_001",
  [int]$MaxCycles = 30,
  [int]$CheckpointEvery = 5,
  [int]$SleepSeconds = 0
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Continue = $true

Set-Location $RepoRoot

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
  . (Join-Path $RepoRoot "modules/invoke_builder_observation_only_live_runner_001.ps1")

  $Result = Invoke-BuilderObservationOnlyLiveRunner001 `
    -RepoRoot $RepoRoot `
    -SessionId $SessionId `
    -MaxCycles $MaxCycles `
    -CheckpointEvery $CheckpointEvery `
    -SleepSeconds $SleepSeconds

  Write-Host "BUILDER_OBSERVATION_SESSION_STARTED=$($Result.observation_session_id)"
  Write-Host "OBSERVATION_SESSION_ROOT=$($Result.observation_root)"
  Write-Host "OBSERVATION_COMPLETED_CYCLES=$($Result.completed_cycles)"
  Write-Host "BUILDER_RUNTIME_DECISION_AUTHOR=$($Result.builder_runtime_decision_author)"
  Write-Host "SUPERVISOR_LIFECYCLE_ONLY=$($Result.supervisor_lifecycle_only)"
  Write-Host "ROUTED_PHASE_RUNTIME_INVOKED=$($Result.routed_phase_runtime_invoked)"
  Write-Host "STATUS=$($Result.status)"
}
