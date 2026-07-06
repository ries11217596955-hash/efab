$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/SMALL_SCALE_DURABLE_COMPACT_STORE_INTEGRATION_PROOF_V1.json"
$RunnerPath = "tests/accepted_atom_retention/run_small_scale_durable_compact_store_integration_proof_v1.ps1"
$AdapterPath = "modules/invoke_real_runner_retention_gate_adapter_v1.ps1"
$GatePath = "modules/invoke_accepted_atom_retention_gate_v1.ps1"
$CompactorPath = "modules/invoke_accepted_atom_retention_compactor_v1.ps1"
$SemanticFields = @("explanation","compact_summary","behavior_change","guided_example","check_prompt","expected_check_result","use_proof")
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

foreach ($path in @($ProofPath,$RunnerPath,$AdapterPath,$GatePath,$CompactorPath)) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "MISSING_$path" }
}

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
if ($p.status -ne "PASS") { Fail "PROOF_STATUS" }
if ($p.final_status -ne "COMPACT_DURABLE_STORE_SMALL_SCALE_INTEGRATION_PROVEN") { Fail "FINAL_STATUS" }
if ([bool]$p.runtime_ready -ne $false) { Fail "RUNTIME_READY_OVERCLAIM" }
if ([bool]$p.module_files_changed -ne $false) { Fail "MODULE_FILES_CHANGED" }

if ([int]$p.total_cycles -lt 3 -or [int]$p.total_cycles -gt 5) { Fail "TOTAL_CYCLES_RANGE" }
if ([int]$p.atoms_per_cycle -lt 1) { Fail "ATOMS_PER_CYCLE" }
if ([int]$p.total_accepted -ne ([int]$p.total_cycles * [int]$p.atoms_per_cycle)) { Fail "TOTAL_ACCEPTED" }
if ([int]$p.total_receipts -ne [int]$p.total_accepted) { Fail "TOTAL_RECEIPTS" }

if ([bool]$p.durable_compact_store_exists -ne $true) { Fail "DURABLE_COMPACT_STORE_EXISTS" }
if ([string]::IsNullOrWhiteSpace([string]$p.durable_compact_store_manifest_path)) { Fail "DURABLE_MANIFEST_PATH_EMPTY" }
if ([string]::IsNullOrWhiteSpace([string]$p.durable_compact_store_index_path)) { Fail "DURABLE_INDEX_PATH_EMPTY" }
if (-not (Test-Path -LiteralPath ([string]$p.durable_compact_store_manifest_path))) { Fail "DURABLE_MANIFEST_MISSING" }
if (-not (Test-Path -LiteralPath ([string]$p.durable_compact_store_index_path))) { Fail "DURABLE_INDEX_MISSING" }

$manifest = Get-Content -LiteralPath ([string]$p.durable_compact_store_manifest_path) -Raw | ConvertFrom-Json
$index = Get-Content -LiteralPath ([string]$p.durable_compact_store_index_path) -Raw | ConvertFrom-Json
if ($manifest.schema -ne "durable_compact_atom_store_manifest_v1") { Fail "MANIFEST_SCHEMA" }
if ($index.schema -ne "durable_compact_accepted_atom_index_v1") { Fail "INDEX_SCHEMA" }
if ([bool]$manifest.runtime_ready -ne $false) { Fail "MANIFEST_RUNTIME_READY" }
if ([bool]$index.runtime_ready -ne $false) { Fail "INDEX_RUNTIME_READY" }
if ([int]$index.record_count -ne [int]$p.total_accepted) { Fail "INDEX_RECORD_COUNT" }
if ([int]$manifest.record_count -ne [int]$p.total_accepted) { Fail "MANIFEST_RECORD_COUNT" }
if ([int]$p.durable_record_count -ne [int]$p.total_accepted) { Fail "PROOF_DURABLE_RECORD_COUNT" }
if ([int]$p.durable_batch_count -ne [int]$p.total_cycles) { Fail "PROOF_DURABLE_BATCH_COUNT" }
if ([int]$p.durable_cycle_count -ne [int]$p.total_cycles) { Fail "PROOF_DURABLE_CYCLE_COUNT" }
if ([int]$manifest.batch_count -ne [int]$p.total_cycles) { Fail "MANIFEST_BATCH_COUNT" }
if ([int]$manifest.cycle_count -ne [int]$p.total_cycles) { Fail "MANIFEST_CYCLE_COUNT" }
if ([int]$index.max_record_bytes -gt 7000) { Fail "DURABLE_RECORD_TOO_LARGE" }

if ($p.retrieval_status -ne "PASS") { Fail "RETRIEVAL_STATUS" }
if ([bool]$p.retrieved_by_atom_id -ne $true) { Fail "RETRIEVED_BY_ATOM_ID" }
if ([int]$p.semantic_payload_field_count -lt 3) { Fail "SEMANTIC_PAYLOAD_FIELD_COUNT" }
if ([string]::IsNullOrWhiteSpace([string]$p.retrieved_use_proof)) { Fail "USE_PROOF_EMPTY" }
$retrieved = @($index.records | Where-Object { $_.atom_id -eq $p.retrieval_atom_id })
if ($retrieved.Count -ne 1) { Fail "RETRIEVED_ATOM_MISSING" }
$semanticPresent = @($SemanticFields | Where-Object {
    ($retrieved[0].PSObject.Properties.Name -contains $_) -and
    -not [string]::IsNullOrWhiteSpace([string]$retrieved[0].PSObject.Properties[$_].Value)
})
if ($semanticPresent.Count -lt 3) { Fail "DURABLE_SEMANTIC_FIELDS" }

if ([bool]$p.cycle_roots_pruned -ne $true) { Fail "CYCLE_ROOTS_PRUNED" }
if ([bool]$p.receipts_compact -ne $true) { Fail "RECEIPTS_COMPACT" }
if ([int]$p.receipt_max_bytes -gt 2000) { Fail "RECEIPT_TOO_LARGE" }
if ([bool]$p.heavy_traces_pruned -ne $true) { Fail "HEAVY_TRACES_PRUNED" }
if ([bool]$p.retention_gate_invoked_all_cycles -ne $true) { Fail "RETENTION_GATE_INVOKED" }
if ([bool]$p.runtime_bounded -ne $true) { Fail "RUNTIME_BOUNDED" }
if ([int64]$p.runtime_bytes_after -gt [int64]$p.max_runtime_bytes) { Fail "RUNTIME_BYTES_AFTER" }

$cycleResults = @($p.cycle_results)
if ($cycleResults.Count -ne [int]$p.total_cycles) { Fail "CYCLE_RESULT_COUNT" }
foreach ($cycle in $cycleResults) {
    if ([int]$cycle.accepted_count -ne [int]$p.atoms_per_cycle) { Fail "CYCLE_ACCEPTED_COUNT" }
    if ([int]$cycle.receipt_count -ne [int]$p.atoms_per_cycle) { Fail "CYCLE_RECEIPT_COUNT" }
    if ([bool]$cycle.retention_gate_invoked -ne $true) { Fail "CYCLE_RETENTION_GATE" }
    if ([string]$cycle.retention_status -ne "PASS") { Fail "CYCLE_RETENTION_STATUS" }
    if ([bool]$cycle.heavy_trace_pruned -ne $true) { Fail "CYCLE_HEAVY_TRACE" }
    if ([bool]$cycle.receipts_compact -ne $true) { Fail "CYCLE_RECEIPTS_COMPACT" }
    if ([bool]$cycle.cycle_root_pruned -ne $true) { Fail "CYCLE_ROOT_PRUNED" }
    if (Test-Path -LiteralPath ([string]$cycle.cycle_root)) { Fail "CYCLE_ROOT_STILL_EXISTS" }
}

if ([bool]$p.canonical_stub_status_expected -ne $true) { Fail "CANONICAL_STUB_STATUS_EXPECTED" }
if ([bool]$p.canonical_stub_hashes_unchanged -ne $true) { Fail "CANONICAL_STUB_HASHES_CHANGED" }
foreach ($path in $CanonicalStubPaths) {
    if ((Get-JsonStatus -Path $path) -ne "THINNED_REQUIRES_STORAGE_ORGAN_BEFORE_RUNTIME_USE") {
        Fail "CANONICAL_STUB_STATUS_$path"
    }
}
$protectedStatus = @(git status --short -- reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/accepted_change_memory_snapshot.json packs/registry.json)
if ($protectedStatus.Count -ne 0) { Fail "CANONICAL_ACTIVE_STUBS_MUTATED" }

Write-Host "VALIDATION_PASS=COMPACT_DURABLE_STORE_SMALL_SCALE_INTEGRATION_PROVEN"
Write-Host "SMALL_SCALE_STATUS=$($p.status)"
Write-Host "TOTAL_CYCLES=$($p.total_cycles)"
Write-Host "TOTAL_ACCEPTED=$($p.total_accepted)"
Write-Host "DURABLE_RECORD_COUNT=$($p.durable_record_count)"
Write-Host "DURABLE_BATCH_COUNT=$($p.durable_batch_count)"
Write-Host "DURABLE_CYCLE_COUNT=$($p.durable_cycle_count)"
Write-Host "DURABLE_COMPACT_STORE_EXISTS=$($p.durable_compact_store_exists)"
Write-Host "CYCLE_ROOTS_PRUNED=$($p.cycle_roots_pruned)"
Write-Host "RETRIEVAL_STATUS=$($p.retrieval_status)"
Write-Host "RETRIEVED_BY_ATOM_ID=$($p.retrieved_by_atom_id)"
Write-Host "SEMANTIC_PAYLOAD_FIELD_COUNT=$($p.semantic_payload_field_count)"
Write-Host "RECEIPTS_COMPACT=$($p.receipts_compact)"
Write-Host "RUNTIME_BOUNDED=$($p.runtime_bounded)"
Write-Host "RUNTIME_READY=false"
exit 0
