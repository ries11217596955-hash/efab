$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/USEFUL_BUILDER_ATOMS_DURABLE_RETRIEVAL_100_PROOF_V1.json"
$RunnerPath = "tests/accepted_atom_retention/run_useful_builder_atoms_durable_retrieval_100_proof_v1.ps1"
$RequiredDomains = @(
    "evidence_and_acceptance",
    "live_lab_boundary",
    "codex_boundary",
    "retention_and_memory",
    "organ_construction",
    "path_selection",
    "input_x_restore",
    "runtime_safety",
    "settings_governance",
    "owner_guidance"
)
$CanonicalStubPaths = @(
    "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
    "reports/self_development/accepted_change_memory_snapshot.json",
    "packs/registry.json"
)

function Fail {
    param([string]$Code)
    Write-Host "FAIL=$Code"
    exit 1
}

function Get-JsonStatus {
    param([string]$Path)
    $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($json.PSObject.Properties.Name -contains "status") { return [string]$json.status }
    return ""
}

foreach ($path in @($ProofPath,$RunnerPath)) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "MISSING_$path" }
}

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
if ($p.schema -ne "useful_builder_atoms_durable_retrieval_100_proof_v1") { Fail "SCHEMA" }
if ($p.status -ne "PASS") { Fail "STATUS" }
if ($p.final_status -ne "USEFUL_BUILDER_ATOMS_DURABLE_RETRIEVAL_100_PROVEN") { Fail "FINAL_STATUS" }
if ([bool]$p.runtime_ready -ne $false) { Fail "RUNTIME_READY_OVERCLAIM" }
if ([bool]$p.module_files_changed -ne $false) { Fail "MODULE_FILES_CHANGED" }

if ([int]$p.total_atom_count -ne 100) { Fail "TOTAL_ATOM_COUNT" }
if ([int]$p.unique_atom_id_count -ne 100) { Fail "UNIQUE_ATOM_ID_COUNT" }
if ([int]$p.durable_record_count -ne 100) { Fail "DURABLE_RECORD_COUNT" }
if ([int]$p.durable_unique_atom_id_count -ne 100) { Fail "DURABLE_UNIQUE_ATOM_ID_COUNT" }
if ([int]$p.domain_count -lt 10) { Fail "DOMAIN_COUNT" }
if ([bool]$p.required_domain_counts_pass -ne $true) { Fail "REQUIRED_DOMAIN_COUNTS_PASS" }

foreach ($domain in $RequiredDomains) {
    if (-not ($p.domain_counts.PSObject.Properties.Name -contains $domain)) { Fail "DOMAIN_MISSING_$domain" }
    if ([int]$p.domain_counts.PSObject.Properties[$domain].Value -lt 8) { Fail "DOMAIN_COUNT_$domain" }
}

if ([string]::IsNullOrWhiteSpace([string]$p.compact_atom_index_path)) { Fail "COMPACT_INDEX_PATH_EMPTY" }
if ([bool]$p.compact_atom_index_existed_before_cleanup -ne $true) { Fail "COMPACT_INDEX_EXISTED_BEFORE_CLEANUP" }
if ([int]$p.compact_atom_index_count -ne 100) { Fail "COMPACT_INDEX_COUNT" }
if ([string]::IsNullOrWhiteSpace([string]$p.compact_atom_index_hash)) { Fail "COMPACT_INDEX_HASH" }

if ([bool]$p.durable_store_survives_cleanup -ne $true) { Fail "DURABLE_STORE_SURVIVES_CLEANUP" }
if ([bool]$p.durable_manifest_exists -ne $true) { Fail "DURABLE_MANIFEST_EXISTS" }
if ([bool]$p.durable_index_exists -ne $true) { Fail "DURABLE_INDEX_EXISTS" }
if (-not (Test-Path -LiteralPath ([string]$p.durable_compact_store_manifest_path))) { Fail "DURABLE_MANIFEST_MISSING" }
if (-not (Test-Path -LiteralPath ([string]$p.durable_compact_store_index_path))) { Fail "DURABLE_INDEX_MISSING" }

$manifest = Get-Content -LiteralPath ([string]$p.durable_compact_store_manifest_path) -Raw | ConvertFrom-Json
$index = Get-Content -LiteralPath ([string]$p.durable_compact_store_index_path) -Raw | ConvertFrom-Json
if ($manifest.schema -ne "durable_compact_atom_store_manifest_v1") { Fail "DURABLE_MANIFEST_SCHEMA" }
if ($index.schema -ne "durable_compact_accepted_atom_index_v1") { Fail "DURABLE_INDEX_SCHEMA" }
if ([bool]$manifest.runtime_ready -ne $false) { Fail "MANIFEST_RUNTIME_READY" }
if ([bool]$index.runtime_ready -ne $false) { Fail "INDEX_RUNTIME_READY" }
if ([int]$manifest.record_count -ne 100) { Fail "MANIFEST_RECORD_COUNT" }
if ([int]$index.record_count -ne 100) { Fail "INDEX_RECORD_COUNT" }
if ([int]$index.max_record_bytes -gt 7000) { Fail "DURABLE_RECORD_TOO_LARGE" }

if ($p.retrieval_by_atom_id_status -ne "PASS") { Fail "RETRIEVAL_BY_ATOM_ID_STATUS" }
if ($p.retrieval_by_concept_status -ne "PASS") { Fail "RETRIEVAL_BY_CONCEPT_STATUS" }
if ($p.retrieval_by_tag_status -ne "PASS") { Fail "RETRIEVAL_BY_TAG_STATUS" }
if ($p.retrieval_by_domain_status -ne "PASS") { Fail "RETRIEVAL_BY_DOMAIN_STATUS" }
if ([int]$p.semantic_payload_field_count -lt 7) { Fail "SEMANTIC_PAYLOAD_FIELD_COUNT" }
if ([bool]$p.all_use_proof_present -ne $true) { Fail "ALL_USE_PROOF_PRESENT" }

$atomIdSamples = @($p.retrieval_by_atom_id_samples)
if ($atomIdSamples.Count -lt 5) { Fail "ATOM_ID_SAMPLE_COUNT" }
foreach ($sample in $atomIdSamples) {
    if ($sample.status -ne "PASS") { Fail "ATOM_ID_SAMPLE_STATUS" }
    if ([int]$sample.semantic_payload_field_count -lt 7) { Fail "ATOM_ID_SAMPLE_SEMANTIC_FIELDS" }
    if ([string]::IsNullOrWhiteSpace([string]$sample.use_proof)) { Fail "ATOM_ID_SAMPLE_USE_PROOF" }
}

$scenarios = @($p.retrieval_scenarios)
if ($scenarios.Count -lt 5) { Fail "RETRIEVAL_SCENARIO_COUNT" }
foreach ($scenario in $scenarios) {
    if ([bool]$scenario.retrieval_by_concept -ne $true) { Fail "SCENARIO_CONCEPT_$($scenario.scenario)" }
    if ([bool]$scenario.retrieval_by_tag -ne $true) { Fail "SCENARIO_TAG_$($scenario.scenario)" }
    if ([bool]$scenario.retrieval_by_domain -ne $true) { Fail "SCENARIO_DOMAIN_$($scenario.scenario)" }
}

if ([bool]$p.receipts_compact -ne $true) { Fail "RECEIPTS_COMPACT" }
if ([int]$p.receipt_count -ne 100) { Fail "RECEIPT_COUNT" }
if ([int]$p.receipt_max_bytes -gt 2000) { Fail "RECEIPT_TOO_LARGE" }
if (-not ($p.PSObject.Properties.Name -contains "heavy_trace_pruned")) { Fail "HEAVY_TRACE_PRUNED_DIAGNOSTIC_MISSING" }
if (-not ($p.PSObject.Properties.Name -contains "cleanup_pending_count")) { Fail "CLEANUP_PENDING_COUNT_MISSING" }
if (-not ($p.PSObject.Properties.Name -contains "cleanup_pending_path")) { Fail "CLEANUP_PENDING_PATH_MISSING" }
if ([bool]$p.active_stubs_unchanged -ne $true) { Fail "ACTIVE_STUBS_UNCHANGED" }
if ([bool]$p.canonical_stub_hashes_unchanged -ne $true) { Fail "CANONICAL_STUB_HASHES_UNCHANGED" }
if ([bool]$p.runtime_bounded -ne $true) { Fail "RUNTIME_BOUNDED" }
if ([int64]$p.runtime_bytes_after -gt [int64]$p.max_runtime_bytes) { Fail "RUNTIME_BYTES_AFTER" }

foreach ($path in $CanonicalStubPaths) {
    if ((Get-JsonStatus -Path $path) -ne "THINNED_REQUIRES_STORAGE_ORGAN_BEFORE_RUNTIME_USE") {
        Fail "CANONICAL_STUB_STATUS_$path"
    }
}
$protectedStatus = @(git status --short -- reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/accepted_change_memory_snapshot.json packs/registry.json)
if ($protectedStatus.Count -ne 0) { Fail "CANONICAL_ACTIVE_STUBS_MUTATED" }

Write-Host "VALIDATION_PASS=USEFUL_BUILDER_ATOMS_DURABLE_RETRIEVAL_100_PROVEN"
Write-Host "TOTAL_ATOM_COUNT=$($p.total_atom_count)"
Write-Host "UNIQUE_ATOM_ID_COUNT=$($p.unique_atom_id_count)"
Write-Host "DURABLE_RECORD_COUNT=$($p.durable_record_count)"
Write-Host "DOMAIN_COUNT=$($p.domain_count)"
Write-Host "RETRIEVAL_BY_ATOM_ID_STATUS=$($p.retrieval_by_atom_id_status)"
Write-Host "RETRIEVAL_BY_CONCEPT_STATUS=$($p.retrieval_by_concept_status)"
Write-Host "RETRIEVAL_BY_TAG_STATUS=$($p.retrieval_by_tag_status)"
Write-Host "RETRIEVAL_BY_DOMAIN_STATUS=$($p.retrieval_by_domain_status)"
Write-Host "HEAVY_TRACE_PRUNED=$($p.heavy_trace_pruned)"
Write-Host "RUNTIME_READY=false"
exit 0
