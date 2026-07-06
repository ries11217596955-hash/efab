$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/CONTROLLED_RUNTIME_30000_DIVERSITY_AND_USE_PROOF_V1.json"

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

if ([string]$proof.status -ne "DIVERSITY_AND_USE_ANALYZED") { Fail "STATUS_NOT_DIVERSITY_AND_USE_ANALYZED" }
if ([int]$proof.total_receipts_seen -ne 30000) { Fail "TOTAL_RECEIPTS_SEEN_NOT_30000" }
if ($null -eq $proof.unique_receipt_hashes -or [string]::IsNullOrWhiteSpace([string]$proof.unique_receipt_hashes)) { Fail "UNIQUE_RECEIPT_HASHES_MISSING" }
if ($null -eq $proof.duplicate_rate -or [string]::IsNullOrWhiteSpace([string]$proof.duplicate_rate)) { Fail "DUPLICATE_RATE_MISSING" }
if ([string]$proof.use_proof_status -ne "PASS") { Fail "USE_PROOF_STATUS_NOT_PASS" }
if ([int]$proof.sample_count -lt 30) { Fail "SAMPLE_COUNT_LT_30" }
if ([int]$proof.samples_retrieved -lt 30) { Fail "SAMPLES_RETRIEVED_LT_30" }
if ([bool]$proof.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([string]::IsNullOrWhiteSpace([string]$proof.next_required)) { Fail "NEXT_REQUIRED_MISSING" }

if ([string]$proof.diversity_classification -eq "NORMALIZED_HIGH") {
  if ($null -eq $proof.normalized_unique_count -or [string]::IsNullOrWhiteSpace([string]$proof.normalized_unique_count)) {
    Fail "NORMALIZED_HIGH_WITHOUT_NORMALIZED_UNIQUE_COUNT"
  }
  if ($null -eq $proof.normalized_duplicate_rate -or [string]::IsNullOrWhiteSpace([string]$proof.normalized_duplicate_rate)) {
    Fail "NORMALIZED_HIGH_WITHOUT_NORMALIZED_DUPLICATE_RATE"
  }
}

if (@($proof.deterministic_sample_30).Count -lt 30) { Fail "DETERMINISTIC_SAMPLE_30_INCOMPLETE" }
if (@($proof.semantic_limitations).Count -eq 0) { Fail "SEMANTIC_LIMITATIONS_MISSING" }

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_30000_DIVERSITY_AND_USE_PROOF_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "TOTAL_RECEIPTS_SEEN=$($proof.total_receipts_seen)"
Write-Host "UNIQUE_RECEIPT_HASHES=$($proof.unique_receipt_hashes)"
Write-Host "DUPLICATE_RATE=$($proof.duplicate_rate)"
Write-Host "DIVERSITY_CLASSIFICATION=$($proof.diversity_classification)"
Write-Host "USE_PROOF_STATUS=$($proof.use_proof_status)"
Write-Host "RUNTIME_READY=false"
exit 0
