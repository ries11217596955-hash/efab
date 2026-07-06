$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$MatrixPath = "tests/accepted_atom_retention/RETENTION_PROOF_PATH_MATRIX_V1.json"
$ExpectedCanonicalLane = "small_scale_durable_compact_store_integration_proof"
$ExpectedStubStatus = "THINNED_REQUIRES_STORAGE_ORGAN_BEFORE_RUNTIME_USE"
$StubPaths = @(
    "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
    "reports/self_development/accepted_change_memory_snapshot.json",
    "packs/registry.json"
)

function Fail {
    param([string]$Code)
    Write-Host "FAIL=$Code"
    exit 1
}

function Get-Entry {
    param($Matrix, [string]$ProofId)
    $matches = @($Matrix.entries | Where-Object { [string]$_.proof_id -eq $ProofId })
    if ($matches.Count -ne 1) { Fail "ENTRY_COUNT_$ProofId" }
    return $matches[0]
}

if (-not (Test-Path -LiteralPath $MatrixPath)) { Fail "MATRIX_MISSING" }
$matrix = Get-Content -LiteralPath $MatrixPath -Raw | ConvertFrom-Json

if ($matrix.schema -ne "retention_proof_path_matrix_v1") { Fail "MATRIX_SCHEMA" }
if ($matrix.status -ne "RETENTION_PROOF_PATH_MATRIX_VALID") { Fail "MATRIX_STATUS" }
if ([bool]$matrix.runtime_ready -ne $false) { Fail "MATRIX_RUNTIME_READY_OVERCLAIM" }
if ([string]$matrix.canonical_lane -ne $ExpectedCanonicalLane) { Fail "MATRIX_CANONICAL_LANE" }

$canonicalEntries = @($matrix.entries | Where-Object { [string]$_.classification -eq "ACTIVE_CANONICAL" })
if ($canonicalEntries.Count -ne 1) { Fail "ACTIVE_CANONICAL_COUNT" }
if ([string]$canonicalEntries[0].proof_id -ne $ExpectedCanonicalLane) { Fail "ACTIVE_CANONICAL_ID" }
if ([bool]$canonicalEntries[0].runtime_ready -ne $false) { Fail "CANONICAL_RUNTIME_READY_OVERCLAIM" }
if ([bool]$canonicalEntries[0].current_canonical_lane -ne $true) { Fail "CANONICAL_FLAG_FALSE" }

$legacy1000 = Get-Entry -Matrix $matrix -ProofId "ephemeral_candidate_to_atom_runtime_1000_trial"
if ([string]$legacy1000.classification -ne "LEGACY_BLOCKED_UNDER_DURABLE_CONTRACT") { Fail "LEGACY_1000_CLASSIFICATION" }
if ([bool]$legacy1000.do_not_use_for_new_retention_acceptance -ne $true) { Fail "LEGACY_1000_ACCEPTANCE_FLAG" }
if ([bool]$legacy1000.current_canonical_lane -ne $false) { Fail "LEGACY_1000_CANONICAL_FLAG" }

$old5k = Get-Entry -Matrix $matrix -ProofId "old_5k_sustained_retention_proofs"
if ([string]$old5k.classification -eq "ACTIVE_CANONICAL") { Fail "OLD_5K_CANONICAL" }
if ([bool]$old5k.do_not_use_for_new_retention_acceptance -ne $true) { Fail "OLD_5K_ACCEPTANCE_FLAG" }

$old30k = Get-Entry -Matrix $matrix -ProofId "old_30k_sustained_retention_proofs"
if ([string]$old30k.classification -eq "ACTIVE_CANONICAL") { Fail "OLD_30K_CANONICAL" }
if ([bool]$old30k.do_not_use_for_new_retention_acceptance -ne $true) { Fail "OLD_30K_ACCEPTANCE_FLAG" }

foreach ($entry in @($matrix.entries)) {
    if ([bool]$entry.runtime_ready -ne $false) { Fail "ENTRY_RUNTIME_READY_$($entry.proof_id)" }
    if ([string]$entry.proof_id -ne $ExpectedCanonicalLane -and [bool]$entry.current_canonical_lane -eq $true) {
        Fail "NON_CANONICAL_FLAG_$($entry.proof_id)"
    }
}

foreach ($path in $StubPaths) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "STUB_MISSING_$path" }
    $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if (-not ($json.PSObject.Properties.Name -contains "status")) { Fail "STUB_STATUS_MISSING_$path" }
    if ([string]$json.status -ne $ExpectedStubStatus) { Fail "STUB_STATUS_$path" }
}

$protectedStatus = @(git status --short -- reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/accepted_change_memory_snapshot.json packs/registry.json)
if ($protectedStatus.Count -ne 0) { Fail "ACTIVE_STUBS_DIRTY" }

Write-Host "VALIDATION_PASS=RETENTION_PROOF_PATH_MATRIX_VALID"
Write-Host "CANONICAL_LANE=$ExpectedCanonicalLane"
Write-Host "RUNTIME_READY=false"
exit 0
