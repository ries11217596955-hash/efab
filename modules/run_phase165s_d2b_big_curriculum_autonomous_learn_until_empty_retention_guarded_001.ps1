param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$InputRoot = 'reports/self_development/phase165s_d2_big_curriculum_material_factory',
  [string]$OutputRoot = 'reports/self_development/phase165s_d2b_big_curriculum_autonomous_learning',
  [ValidateSet('LearnUntilEmpty')]
  [string]$Mode = 'LearnUntilEmpty',
  [switch]$Resume,
  [switch]$RepairResumeStateOnly,
  [switch]$SyncSummaryOnly,
  [switch]$EmitJson,
  [ValidateRange(1, 100)]
  [int]$BatchSize = 1,
  [ValidateRange(1, 100000)]
  [int]$CheckpointEvery = 100,
  [ValidateRange(1, 100000)]
  [int]$HeartbeatEvery = 25,
  [string]$WorkRoot = '',
  [ValidateSet('CompactAccepted','FullTrace','Disabled')]
  [string]$RetentionMode = 'CompactAccepted',
  [switch]$DryTrialOnly,
  [string]$BatchEnvelopePath = '',
  [switch]$OwnerApprovedLiveOneBatch
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$legacyRunner = Join-Path $root 'modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1'
$adapter = Join-Path $root 'modules/invoke_real_runner_retention_gate_adapter_v1.ps1'

function Write-GuardedResult {
  param($Value)
  if ($EmitJson) {
    $Value | ConvertTo-Json -Depth 40
  } else {
    foreach ($p in $Value.GetEnumerator()) {
      Write-Host "$($p.Key)=$($p.Value)"
    }
  }
}

if (-not (Test-Path -LiteralPath $legacyRunner)) {
  throw "LEGACY_D2B_RUNNER_MISSING=$legacyRunner"
}

if (-not (Test-Path -LiteralPath $adapter)) {
  throw "RETENTION_ADAPTER_MISSING=$adapter"
}

if ($RetentionMode -ne 'CompactAccepted') {
  Write-GuardedResult ([ordered]@{
    status='BLOCKED_RETENTION_MODE_REQUIRED'
    required_retention_mode='CompactAccepted'
    actual_retention_mode=$RetentionMode
    runtime_ready=$false
    legacy_runner_invoked=$false
    reason='Old D2B runner may not run without retention gate.'
  })
  return
}

if ($DryTrialOnly) {
  if (-not $BatchEnvelopePath) {
    throw "BATCH_ENVELOPE_REQUIRED_FOR_DRY_TRIAL"
  }

  $json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adapter -BatchEnvelopePath $BatchEnvelopePath
  $adapterResult = $json | ConvertFrom-Json

  Write-GuardedResult ([ordered]@{
    status=$adapterResult.status
    mode='DRY_TRIAL_ONLY'
    runtime_ready=$false
    legacy_runner_invoked=$false
    batch_id=$adapterResult.batch_id
    accepted_count=$adapterResult.accepted_count
    receipt_count=$adapterResult.receipt_count
    heavy_trace_pruned=$adapterResult.heavy_trace_pruned
    work_current_preserved=$adapterResult.work_current_preserved
    next_required='OWNER_APPROVED_LIVE_ONE_BATCH_TRIAL'
  })
  return
}

if (-not $OwnerApprovedLiveOneBatch) {
  Write-GuardedResult ([ordered]@{
    status='BLOCKED_OWNER_APPROVAL_REQUIRED_FOR_LIVE_ONE_BATCH'
    runtime_ready=$false
    legacy_runner_invoked=$false
    reason='Live legacy D2B runner call is blocked until OwnerApprovedLiveOneBatch is supplied.'
    next_required='OWNER_APPROVED_LIVE_ONE_BATCH_TRIAL'
  })
  return
}

Write-GuardedResult ([ordered]@{
  status='BLOCKED_LIVE_MODE_NOT_IMPLEMENTED_IN_THIN_REPO'
  runtime_ready=$false
  legacy_runner_invoked=$false
  reason='Thin repo has stubs and no mass curriculum state. Live integration must be done against controlled state clone.'
  next_required='PATCH_LEGACY_RUNNER_POST_BATCH_RETENTION_GATE_IN_CONTROLLED_STATE'
})
return
