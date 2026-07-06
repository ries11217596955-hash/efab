param(
  [string]$SessionId = "",
  [int]$MaxCycles = 10,
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
  if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
    $env:BUILDER_LIFE_LOOP_SESSION_ID = $SessionId
  }
  $env:BUILDER_LIFE_LOOP_MAX_CYCLES = "$MaxCycles"
  $env:BUILDER_LIFE_LOOP_CHECKPOINT_EVERY = "$CheckpointEvery"
  $env:BUILDER_LIFE_LOOP_SLEEP_SECONDS = "$SleepSeconds"

  & (Join-Path $RepoRoot "orchestrator/run.ps1") `
    -Mode SELF_BUILD `
    -RunId "PHASE142_BUILDER_NEXT_GAP_SELECTOR_OBSERVABLE_LIFE_LOOP_001" `
    -MaxPacks 1
}
