$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/STRUCTURED_RUNTIME_CLEANUP_RESILIENCE_REPAIR_TRIAL_V1.json"

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
if ([int]$proof.completed_cycles -ne 12) { Fail "COMPLETED_CYCLES_NOT_12" }
if ([int]$proof.total_accepted -ne 1200) { Fail "TOTAL_ACCEPTED_NOT_1200" }
if ([int]$proof.total_receipts -ne 1200) { Fail "TOTAL_RECEIPTS_NOT_1200" }
if ([bool]$proof.stderr_contains_unauthorized_access -ne $false) { Fail "STDERR_CONTAINS_UNAUTHORIZED_ACCESS" }
if ([bool]$proof.stderr_contains_cleanup_delete_failed -ne $false) { Fail "STDERR_CONTAINS_RETENTION_CLEANUP_DELETE_FAILED" }
if ([bool]$proof.work_current_pruned_all_successful_cycles -ne $true) { Fail "WORK_CURRENT_PRUNED_FALSE" }
if ([bool]$proof.candidate_material_pruned_all_successful_cycles -ne $true) { Fail "CANDIDATE_MATERIAL_PRUNED_FALSE" }
if ([bool]$proof.RuntimeDeltaOnly -ne $true) { Fail "RUNTIME_DELTA_ONLY_FALSE" }
if ([bool]$proof.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }

Write-Host "VALIDATION_PASS=STRUCTURED_RUNTIME_CLEANUP_RESILIENCE_REPAIR_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "TOTAL_ACCEPTED=$($proof.total_accepted)"
Write-Host "TOTAL_RECEIPTS=$($proof.total_receipts)"
Write-Host "RUNTIME_READY=false"
exit 0
