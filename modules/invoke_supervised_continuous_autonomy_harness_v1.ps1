param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [ValidateRange(1, 100)]
  [int]$MaxOuterCycles = 3,
  [ValidateRange(2, 100)]
  [int]$InnerMaxCycles = 2,
  [string]$OutputPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-Json {
  param([string]$Path, [object]$Object)
  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 80) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path $RepoRoot).Path
$loopGateModule = Join-Path $root 'modules/invoke_controlled_self_build_loop_gate_v1.ps1'
if (-not (Test-Path -LiteralPath $loopGateModule -PathType Leaf)) {
  throw "MISSING_CONTROLLED_SELF_BUILD_LOOP_GATE_MODULE=$loopGateModule"
}

$cycleRecords = @()
$totalInnerCyclesObserved = 0
$allOuterCyclesPass = $true
$anyCompletionClaim = $false
$anyProtectedMutation = $false
$anyLivePatch = $false
$anyCodexRuntime = $false

for ($outerCycle = 1; $outerCycle -le $MaxOuterCycles; $outerCycle += 1) {
  $gateJson = & $loopGateModule -RepoRoot $root -MaxCycles $InnerMaxCycles
  $gateResult = $gateJson | ConvertFrom-Json

  $gatePass = ([string]$gateResult.status -eq 'CONTROLLED_SELF_BUILD_LOOP_GATE_PASS')
  if (-not $gatePass) { $allOuterCyclesPass = $false }
  if ([bool]$gateResult.self_completion_claimed) { $anyCompletionClaim = $true }
  if ([bool]$gateResult.protected_mutation_done) { $anyProtectedMutation = $true }
  if ([bool]$gateResult.live_patch_done) { $anyLivePatch = $true }
  if ([bool]$gateResult.codex_used_at_runtime) { $anyCodexRuntime = $true }

  $totalInnerCyclesObserved += [int]$gateResult.cycles_executed
  $cycleRecords += [ordered]@{
    checkpoint_id = "supervised_continuous_autonomy_harness.outer_cycle_$outerCycle.checkpoint"
    outer_cycle = [int]$outerCycle
    inner_loop_status = [string]$gateResult.status
    cycles_executed = [int]$gateResult.cycles_executed
    next_action_selected = [string]$gateResult.next_action_selected
    self_completion_claimed = [bool]$gateResult.self_completion_claimed
    continue_required = [bool]$gateResult.continue_required
    protected_mutation_done = [bool]$gateResult.protected_mutation_done
    live_patch_done = [bool]$gateResult.live_patch_done
    codex_used_at_runtime = [bool]$gateResult.codex_used_at_runtime
  }
}

$harnessPass = (
  $allOuterCyclesPass -and
  $cycleRecords.Count -eq $MaxOuterCycles -and
  $totalInnerCyclesObserved -ge ($MaxOuterCycles * $InnerMaxCycles) -and
  (-not $anyCompletionClaim) -and
  (-not $anyProtectedMutation) -and
  (-not $anyLivePatch) -and
  (-not $anyCodexRuntime) -and
  @($cycleRecords | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.next_action_selected) }).Count -eq 0
)

$result = [ordered]@{
  status = if ($harnessPass) { 'SUPERVISED_CONTINUOUS_AUTONOMY_HARNESS_PASS' } else { 'SUPERVISED_CONTINUOUS_AUTONOMY_HARNESS_FAIL' }
  harness_mode = 'lab_shadow'
  max_outer_cycles = [int]$MaxOuterCycles
  outer_cycles_executed = [int]$cycleRecords.Count
  inner_max_cycles = [int]$InnerMaxCycles
  total_inner_cycles_observed = [int]$totalInnerCyclesObserved
  leash_limit_reached = $true
  normal_stop_reason = 'LEASH_LIMIT_REACHED'
  self_completion_claimed = $false
  continue_required = $true
  protected_mutation_done = $false
  live_patch_done = $false
  codex_used_at_runtime = $false
  commit_done = $false
  push_done = $false
  cycle_records = $cycleRecords
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $OutputPath))
  }
  Write-Json -Path $outputFullPath -Object $result
}

$result | ConvertTo-Json -Depth 80
