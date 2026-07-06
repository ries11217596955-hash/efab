param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [ValidateRange(2, 100)]
  [int]$MaxCycles = 2,
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
  $json = ($Object | ConvertTo-Json -Depth 60) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path $RepoRoot).Path
$shadowRouteModule = Join-Path $root 'modules/invoke_startup_selector_shadow_route_v1.ps1'
if (-not (Test-Path -LiteralPath $shadowRouteModule -PathType Leaf)) {
  throw "MISSING_SHADOW_ROUTE_MODULE=$shadowRouteModule"
}

$cycles = @()
$checkpoints = @()

$cycle1Checkpoint = [ordered]@{
  checkpoint_id = 'controlled_self_build_loop_gate.cycle_1.checkpoint'
  cycle = 1
  created_at = (Get-Date).ToString('o')
  loop_mode = 'lab_shadow'
  purpose = 'route_selector_and_capture_selected_local_organ'
  protected_mutation_done = $false
  live_patch_done = $false
}
$checkpoints += $cycle1Checkpoint

$routeJson = & $shadowRouteModule `
  -RepoRoot $root `
  -TaskKind 'proof_energy_record_validation' `
  -RequestedCapability 'validate_law_kernel_matrix_cell_proof_energy_record' `
  -ContextHint 'law_kernel_matrix_cell'

$routeResult = $routeJson | ConvertFrom-Json
$schemaFullPath = Join-Path $root ([string]$routeResult.selected_schema_path)
$validatorFullPath = Join-Path $root ([string]$routeResult.selected_validator_path)
$schemaExists = Test-Path -LiteralPath $schemaFullPath -PathType Leaf
$validatorExists = Test-Path -LiteralPath $validatorFullPath -PathType Leaf

$cycles += [ordered]@{
  cycle = 1
  checkpoint_id = [string]$cycle1Checkpoint.checkpoint_id
  action = 'startup_selector_shadow_route'
  selector_route_status = [string]$routeResult.status
  selected_atom_id = [string]$routeResult.selected_atom_id
  selected_schema_path = [string]$routeResult.selected_schema_path
  selected_validator_path = [string]$routeResult.selected_validator_path
  selected_schema_exists = [bool]$schemaExists
  selected_validator_exists = [bool]$validatorExists
  protected_mutation_done = $false
  live_patch_done = $false
}

$cycle2Checkpoint = [ordered]@{
  checkpoint_id = 'controlled_self_build_loop_gate.cycle_2.checkpoint'
  cycle = 2
  created_at = (Get-Date).ToString('o')
  loop_mode = 'lab_shadow'
  purpose = 'read_cycle_1_result_and_select_controlled_continuation'
  protected_mutation_done = $false
  live_patch_done = $false
}
$checkpoints += $cycle2Checkpoint

$cycle1Pass = (
  ([string]$routeResult.status -eq 'SHADOW_ROUTE_SELECTOR_PASS') -and
  $schemaExists -and
  $validatorExists
)

$nextAction = if ($cycle1Pass) {
  'CONTROLLED_SELF_BUILD_CONTINUE_WITH_SELECTED_PROOF_ENERGY_VALIDATOR_LAB_SHADOW'
} else {
  'CONTROLLED_SELF_BUILD_CONTINUE_WITH_SELECTOR_ROUTE_REPAIR_LAB_SHADOW'
}

$cycles += [ordered]@{
  cycle = 2
  checkpoint_id = [string]$cycle2Checkpoint.checkpoint_id
  action = 'select_next_controlled_self_build_action'
  source_cycle = 1
  next_action_selected = $nextAction
  self_completion_claimed = $false
  continue_required = $true
  protected_mutation_done = $false
  live_patch_done = $false
}

for ($cycleNumber = 3; $cycleNumber -le $MaxCycles; $cycleNumber += 1) {
  $checkpoint = [ordered]@{
    checkpoint_id = "controlled_self_build_loop_gate.cycle_$cycleNumber.checkpoint"
    cycle = $cycleNumber
    created_at = (Get-Date).ToString('o')
    loop_mode = 'lab_shadow'
    purpose = 'hold_controlled_continuation_without_live_execution'
    protected_mutation_done = $false
    live_patch_done = $false
  }
  $checkpoints += $checkpoint
  $cycles += [ordered]@{
    cycle = $cycleNumber
    checkpoint_id = [string]$checkpoint.checkpoint_id
    action = 'hold_controlled_continuation'
    next_action_selected = $nextAction
    self_completion_claimed = $false
    continue_required = $true
    protected_mutation_done = $false
    live_patch_done = $false
  }
}

$gatePass = (
  $cycle1Pass -and
  $cycles.Count -ge 2 -and
  $checkpoints.Count -ge 2 -and
  -not [string]::IsNullOrWhiteSpace($nextAction)
)

$result = [ordered]@{
  status = if ($gatePass) { 'CONTROLLED_SELF_BUILD_LOOP_GATE_PASS' } else { 'CONTROLLED_SELF_BUILD_LOOP_GATE_FAIL' }
  loop_mode = 'lab_shadow'
  cycles_requested = [int]$MaxCycles
  cycles_executed = [int]$cycles.Count
  checkpoints_created = [int]$checkpoints.Count
  selector_route_status = [string]$routeResult.status
  selected_atom_id = [string]$routeResult.selected_atom_id
  selected_schema_path = [string]$routeResult.selected_schema_path
  selected_validator_path = [string]$routeResult.selected_validator_path
  next_action_selected = $nextAction
  self_completion_claimed = $false
  continue_required = $true
  protected_mutation_done = $false
  live_patch_done = $false
  codex_used_at_runtime = $false
  commit_done = $false
  push_done = $false
  checkpoints = $checkpoints
  cycles = $cycles
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $OutputPath))
  }
  Write-Json -Path $outputFullPath -Object $result
}

$result | ConvertTo-Json -Depth 60
