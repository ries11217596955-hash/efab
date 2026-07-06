$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/EPHEMERAL_CANDIDATE_TO_ATOM_RUNTIME_1000_TRIAL_V1.json"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath "tests/accepted_atom_retention/run_ephemeral_candidate_to_atom_runtime_1000_trial_v1.ps1")) {
  Fail "RUNTIME_TRIAL_RUNNER_MISSING"
}
if (-not (Test-Path -LiteralPath "modules/generate_ephemeral_d2b_candidate_batch_v1.ps1")) {
  Fail "GENERATOR_MISSING"
}
if (-not (Test-Path -LiteralPath "modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1")) {
  Fail "LEGACY_RUNNER_MISSING"
}
if (-not (Test-Path -LiteralPath "modules/invoke_protected_surface_transaction_v1.ps1")) {
  Fail "PROTECTED_SURFACE_TRANSACTION_MODULE_MISSING"
}
if (-not (Test-Path -LiteralPath $ProofPath)) {
  Fail "PROOF_MISSING"
}

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json

$RequiredProtectedSurfaceProofFields = @(
  "protected_surface_transaction_enabled",
  "protected_surface_clean_after",
  "protected_surface_snapshot_count",
  "protected_surface_restored_count",
  "protected_surface_deleted_count",
  "protected_surface_guard_failures",
  "runtime_ready"
)
foreach ($field in $RequiredProtectedSurfaceProofFields) {
  if ($p.PSObject.Properties.Name -notcontains $field) {
    Fail "PROTECTED_SURFACE_PROOF_FIELD_MISSING_$field"
  }
}

if ([string]$p.status -ne "PASS") { Fail "PROOF_STATUS_NOT_PASS" }
if (-not [string]::IsNullOrWhiteSpace([string]$p.trial_error)) { Fail "PROOF_CREATED_AFTER_FAILED_RUN" }
if ([bool]$p.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([bool]$p.protected_surface_transaction_enabled -ne $true) { Fail "PROTECTED_SURFACE_TRANSACTION_NOT_ENABLED" }
if ([bool]$p.protected_surface_clean_after -ne $true) { Fail "PROTECTED_SURFACE_NOT_CLEAN_AFTER" }
if ([int]$p.protected_surface_snapshot_count -lt 3) { Fail "PROTECTED_SURFACE_SNAPSHOT_COUNT_LT_3" }
if ([int]$p.protected_surface_restored_count -lt 0) { Fail "PROTECTED_SURFACE_RESTORED_COUNT_INVALID" }
if ([int]$p.protected_surface_deleted_count -lt 0) { Fail "PROTECTED_SURFACE_DELETED_COUNT_INVALID" }
if (@($p.protected_surface_guard_failures).Count -ne 0) { Fail "PROTECTED_SURFACE_GUARD_FAILURES" }
if ([int]$p.total_cycles -ne 10) { Fail "TOTAL_CYCLES_NOT_10" }
if ([int]$p.candidates_per_cycle -ne 100) { Fail "CANDIDATES_PER_CYCLE_NOT_100" }
if ([int]$p.total_candidates -ne 1000) { Fail "TOTAL_CANDIDATES_NOT_1000" }
if ([int]$p.total_accepted -lt 1000) { Fail "TOTAL_ACCEPTED_LT_1000" }
if ([int]$p.total_receipts -ne [int]$p.total_accepted) { Fail "TOTAL_RECEIPTS_MISMATCH" }
if ([int]$p.failed_cycles -ne 0) { Fail "FAILED_CYCLES_NOT_ZERO" }
if ([int]$p.unexpected_git_status_count -ne 0) { Fail "UNEXPECTED_GIT_STATUS" }
if ([bool]$p.active_state_restored -ne $true) { Fail "ACTIVE_STATE_NOT_RESTORED" }

$cycles = @($p.cycle_results)
if ($cycles.Count -ne 10) { Fail "CYCLE_RESULT_COUNT_NOT_10" }

foreach ($cycle in $cycles) {
  $cycleNumber = [int]$cycle.cycle
  if ([int]$cycle.runner_exit_code -ne 0) { Fail "CYCLE_${cycleNumber}_RUNNER_EXIT_CODE" }
  if ([string]$cycle.runner_final_status -ne "PASS_QUEUE_EMPTY") { Fail "CYCLE_${cycleNumber}_RUNNER_FINAL_STATUS" }
  if ([bool]$cycle.direct_candidate_batch_mode -ne $true) { Fail "CYCLE_${cycleNumber}_DIRECT_MODE_FALSE" }
  if ([int]$cycle.accepted_count -ne 100) { Fail "CYCLE_${cycleNumber}_ACCEPTED_COUNT" }
  if ([int]$cycle.receipt_count -ne 100) { Fail "CYCLE_${cycleNumber}_RECEIPT_COUNT" }
  if ([string]$cycle.retention_status -ne "PASS") { Fail "CYCLE_${cycleNumber}_RETENTION_NOT_PASS" }
  if ([bool]$cycle.retention_gate_invoked -ne $true) { Fail "CYCLE_${cycleNumber}_RETENTION_GATE_NOT_INVOKED" }
  if ([bool]$cycle.heavy_trace_pruned -ne $true) { Fail "CYCLE_${cycleNumber}_HEAVY_TRACE_NOT_PRUNED" }
  if ([bool]$cycle.candidate_material_pruned -ne $true) { Fail "CYCLE_${cycleNumber}_CANDIDATE_MATERIAL_LEFT" }
  if ([bool]$cycle.runner_candidate_material_pruned -ne $true) { Fail "CYCLE_${cycleNumber}_RUNNER_CANDIDATE_PRUNE_FALSE" }
  if ([bool]$cycle.work_current_exists_after_success -ne $false) { Fail "CYCLE_${cycleNumber}_WORK_CURRENT_LEFT" }
  if ([bool]$cycle.runtime_ready -ne $false) { Fail "CYCLE_${cycleNumber}_RUNTIME_READY_TRUE" }
}

Write-Host "VALIDATION_PASS=EPHEMERAL_CANDIDATE_TO_ATOM_RUNTIME_1000_TRIAL_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "RUNTIME_READY=false"
exit 0
