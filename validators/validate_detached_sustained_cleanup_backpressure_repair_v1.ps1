$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/DETACHED_SUSTAINED_CLEANUP_BACKPRESSURE_REPAIR_TRIAL_V1.json"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath $ProofPath)) { Fail "PROOF_MISSING" }

try {
  $proof = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
} catch {
  Fail "PROOF_JSON_PARSE_FAILED"
}

if ([string]$proof.status -ne "PASS") { Fail "STATUS_NOT_PASS" }
if ([bool]$proof.detached_process_used -ne $true) { Fail "DETACHED_PROCESS_USED_FALSE" }
if ([int]$proof.completed_cycles -ne 45) { Fail "COMPLETED_CYCLES_NOT_45" }
if ([int]$proof.total_accepted -ne 4500) { Fail "TOTAL_ACCEPTED_NOT_4500" }
if ([int]$proof.total_receipts -ne 4500) { Fail "TOTAL_RECEIPTS_NOT_4500" }
if ([int]$proof.failed_cycles -ne 0) { Fail "FAILED_CYCLES_NOT_ZERO" }
if ([int]$proof.cleanup_pressure_events -lt 5) { Fail "CLEANUP_PRESSURE_EVENTS_LT_5" }
if ([int]$proof.cleanup_backpressure_events -lt 1) { Fail "CLEANUP_BACKPRESSURE_EVENTS_LT_1" }
if ([int]$proof.cleanup_drain_iterations_total -le 0) { Fail "CLEANUP_DRAIN_ITERATIONS_TOTAL_NOT_POSITIVE" }
if ([int]$proof.cleanup_backpressure_wait_seconds_total -le 0) { Fail "CLEANUP_BACKPRESSURE_WAIT_SECONDS_TOTAL_NOT_POSITIVE" }
if ([int64]$proof.pending_cleanup_peak_bytes -le [int64]$proof.cleanup_soft_byte_bound) { Fail "PENDING_CLEANUP_PEAK_NOT_ABOVE_SOFT_BOUND" }
if ([int64]$proof.max_pending_before_backpressure -le [int64]$proof.cleanup_soft_byte_bound) { Fail "MAX_PENDING_BEFORE_BACKPRESSURE_NOT_ABOVE_SOFT_BOUND" }
if ([bool]$proof.stderr_contains_pending_cleanup_hard_bound -ne $false) { Fail "STDERR_CONTAINS_PENDING_CLEANUP_HARD_BOUND" }
if ([bool]$proof.summary_contains_pending_cleanup_hard_bound -ne $false) { Fail "SUMMARY_CONTAINS_PENDING_CLEANUP_HARD_BOUND" }
if ([bool]$proof.stderr_contains_retention_cleanup_delete_failed -ne $false) { Fail "STDERR_CONTAINS_RETENTION_CLEANUP_DELETE_FAILED" }
if ([bool]$proof.stderr_contains_retention_cleanup_final_failed -ne $false) { Fail "STDERR_CONTAINS_RETENTION_CLEANUP_FINAL_FAILED" }
if ([bool]$proof.stderr_contains_cycle_invariant_failed -ne $false) { Fail "STDERR_CONTAINS_CYCLE_INVARIANT_FAILED" }
if ([bool]$proof.stderr_contains_unauthorized_access -ne $false) { Fail "STDERR_CONTAINS_UNAUTHORIZED_ACCESS" }
if ([int]$proof.pending_cleanup_final_count -ne 0) { Fail "PENDING_CLEANUP_FINAL_COUNT_NOT_ZERO" }
if ([int64]$proof.pending_cleanup_final_bytes -ne 0) { Fail "PENDING_CLEANUP_FINAL_BYTES_NOT_ZERO" }
if ([bool]$proof.candidate_material_final_pruned -ne $true) { Fail "CANDIDATE_MATERIAL_FINAL_PRUNED_FALSE" }
if ([bool]$proof.work_current_final_pruned -ne $true) { Fail "WORK_CURRENT_FINAL_PRUNED_FALSE" }
if ([bool]$proof.RuntimeDeltaOnly -ne $true) { Fail "RUNTIME_DELTA_ONLY_FALSE" }
if ([bool]$proof.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }

Write-Host "VALIDATION_PASS=DETACHED_SUSTAINED_CLEANUP_BACKPRESSURE_REPAIR_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "TOTAL_ACCEPTED=$($proof.total_accepted)"
Write-Host "TOTAL_RECEIPTS=$($proof.total_receipts)"
Write-Host "CLEANUP_PRESSURE_EVENTS=$($proof.cleanup_pressure_events)"
Write-Host "CLEANUP_BACKPRESSURE_EVENTS=$($proof.cleanup_backpressure_events)"
Write-Host "CLEANUP_DRAIN_ITERATIONS_TOTAL=$($proof.cleanup_drain_iterations_total)"
Write-Host "CLEANUP_BACKPRESSURE_WAIT_SECONDS_TOTAL=$($proof.cleanup_backpressure_wait_seconds_total)"
Write-Host "PENDING_CLEANUP_PEAK_BYTES=$($proof.pending_cleanup_peak_bytes)"
Write-Host "PENDING_CLEANUP_FINAL_COUNT=$($proof.pending_cleanup_final_count)"
Write-Host "PENDING_CLEANUP_FINAL_BYTES=$($proof.pending_cleanup_final_bytes)"
Write-Host "RUNTIME_READY=false"
exit 0
