$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/DETACHED_DEFERRED_CLEANUP_INVARIANT_REPAIR_TRIAL_V1.json"

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
if ([int]$proof.completed_cycles -ne 30) { Fail "COMPLETED_CYCLES_NOT_30" }
if ([int]$proof.total_accepted -ne 3000) { Fail "TOTAL_ACCEPTED_NOT_3000" }
if ([int]$proof.total_receipts -ne 3000) { Fail "TOTAL_RECEIPTS_NOT_3000" }
if ([int]$proof.failed_cycles -ne 0) { Fail "FAILED_CYCLES_NOT_ZERO" }
if ([bool]$proof.stderr_contains_cycle_invariant_failed -ne $false) { Fail "STDERR_CONTAINS_CYCLE_INVARIANT_FAILED" }
if ([bool]$proof.stderr_contains_retention_cleanup_delete_failed -ne $false) { Fail "STDERR_CONTAINS_RETENTION_CLEANUP_DELETE_FAILED" }
if ([bool]$proof.stderr_contains_retention_cleanup_final_failed -ne $false) { Fail "STDERR_CONTAINS_RETENTION_CLEANUP_FINAL_FAILED" }
if ([bool]$proof.stderr_contains_unauthorized_access -ne $false) { Fail "STDERR_CONTAINS_UNAUTHORIZED_ACCESS" }
if ([int]$proof.pending_cleanup_final_count -ne 0) { Fail "PENDING_CLEANUP_FINAL_COUNT_NOT_ZERO" }
if ([bool]$proof.candidate_material_final_pruned -ne $true) { Fail "CANDIDATE_MATERIAL_FINAL_PRUNED_FALSE" }
if ([bool]$proof.work_current_final_pruned -ne $true) { Fail "WORK_CURRENT_FINAL_PRUNED_FALSE" }
if ([bool]$proof.RuntimeDeltaOnly -ne $true) { Fail "RUNTIME_DELTA_ONLY_FALSE" }
if ([string]$proof.cleanup_lifecycle_mode -ne "DeferredCleanupQueue") { Fail "CLEANUP_LIFECYCLE_MODE_UNEXPECTED" }
if ([bool]$proof.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }

Write-Host "VALIDATION_PASS=DETACHED_DEFERRED_CLEANUP_INVARIANT_REPAIR_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "TOTAL_ACCEPTED=$($proof.total_accepted)"
Write-Host "TOTAL_RECEIPTS=$($proof.total_receipts)"
Write-Host "PENDING_CLEANUP_FINAL_COUNT=$($proof.pending_cleanup_final_count)"
Write-Host "RUNTIME_READY=false"
exit 0
