$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/CONTROLLED_RUNTIME_STRUCTURED_GENERATOR_DIVERSITY_TRIAL_V1.json"

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
if ([string]$proof.generator_mode -ne "StructuredV1") { Fail "GENERATOR_MODE_NOT_STRUCTURED_V1" }
if ([int]$proof.total_accepted -ne 3000) { Fail "TOTAL_ACCEPTED_NOT_3000" }
if ([int]$proof.total_receipts -ne 3000) { Fail "TOTAL_RECEIPTS_NOT_3000" }
if ([int]$proof.unique_receipt_hashes -lt 2990) { Fail "UNIQUE_RECEIPT_HASHES_LT_2990" }
if ([int]$proof.normalized_unique_count -lt 1000) { Fail "NORMALIZED_UNIQUE_COUNT_LT_1000" }
if ([string]$proof.diversity_classification -eq "NORMALIZED_LOW") { Fail "DIVERSITY_CLASSIFICATION_NORMALIZED_LOW" }
if ([int]$proof.category_family_count -lt 12) { Fail "CATEGORY_FAMILY_COUNT_LT_12" }
if ([string]$proof.use_proof_status -ne "PASS") { Fail "USE_PROOF_STATUS_NOT_PASS" }
if ([int]$proof.samples_retrieved -lt 30) { Fail "SAMPLES_RETRIEVED_LT_30" }
if ([bool]$proof.tracked_core_dirty_after_trial -ne $false) { Fail "TRACKED_CORE_DIRTY_AFTER_TRIAL" }
if ([bool]$proof.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([bool]$proof.RuntimeDeltaOnly -ne $true) { Fail "RUNTIME_DELTA_ONLY_FALSE" }
if ([string]::IsNullOrWhiteSpace([string]$proof.next_required)) { Fail "NEXT_REQUIRED_MISSING" }

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_STRUCTURED_GENERATOR_DIVERSITY_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "TOTAL_ACCEPTED=$($proof.total_accepted)"
Write-Host "TOTAL_RECEIPTS=$($proof.total_receipts)"
Write-Host "UNIQUE_RECEIPT_HASHES=$($proof.unique_receipt_hashes)"
Write-Host "NORMALIZED_UNIQUE_COUNT=$($proof.normalized_unique_count)"
Write-Host "DIVERSITY_CLASSIFICATION=$($proof.diversity_classification)"
Write-Host "CATEGORY_FAMILY_COUNT=$($proof.category_family_count)"
Write-Host "USE_PROOF_STATUS=$($proof.use_proof_status)"
Write-Host "RUNTIME_READY=false"
exit 0
