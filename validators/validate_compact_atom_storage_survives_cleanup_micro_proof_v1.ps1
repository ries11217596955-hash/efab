$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/COMPACT_ATOM_STORAGE_SURVIVES_CLEANUP_MICRO_PROOF_V1.json"
$RunnerPath = "tests/accepted_atom_retention/run_compact_atom_storage_survives_cleanup_micro_proof_v1.ps1"
$CompactorPath = "modules/invoke_accepted_atom_retention_compactor_v1.ps1"
$GatePath = "modules/invoke_accepted_atom_retention_gate_v1.ps1"
$AdapterPath = "modules/invoke_real_runner_retention_gate_adapter_v1.ps1"
$SemanticFields = @("explanation","compact_summary","behavior_change","guided_example","check_prompt","expected_check_result","use_proof")

if (-not (Test-Path -LiteralPath $RunnerPath)) { Write-Host "FAIL=RUNNER_MISSING"; exit 1 }
if (-not (Test-Path -LiteralPath $CompactorPath)) { Write-Host "FAIL=COMPACTOR_MISSING"; exit 1 }
if (-not (Test-Path -LiteralPath $GatePath)) { Write-Host "FAIL=GATE_MISSING"; exit 1 }
if (-not (Test-Path -LiteralPath $AdapterPath)) { Write-Host "FAIL=ADAPTER_MISSING"; exit 1 }
if (-not (Test-Path -LiteralPath $ProofPath)) { Write-Host "FAIL=PROOF_MISSING"; exit 1 }

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json

if ($p.status -ne "PASS") { Write-Host "FAIL=PROOF_STATUS"; exit 1 }
if ($p.final_status -ne "COMPACT_ATOM_STORAGE_SURVIVES_CLEANUP_MICRO_PROVEN") { Write-Host "FAIL=FINAL_STATUS"; exit 1 }
if ([bool]$p.runtime_ready -ne $false) { Write-Host "FAIL=RUNTIME_READY_OVERCLAIM"; exit 1 }
if ([bool]$p.compact_storage_survives_cleanup -ne $true) { Write-Host "FAIL=COMPACT_STORAGE_SURVIVES_CLEANUP_FALSE"; exit 1 }
if ([bool]$p.durable_compact_store_exists -ne $true) { Write-Host "FAIL=DURABLE_STORE_EXISTS_FALSE"; exit 1 }
if ([bool]$p.cycle_roots_pruned -ne $true) { Write-Host "FAIL=CYCLE_ROOTS_NOT_PRUNED"; exit 1 }
if ([bool]$p.receipts_compact -ne $true) { Write-Host "FAIL=RECEIPTS_NOT_COMPACT"; exit 1 }
if ([int]$p.receipt_max_bytes -gt 2000) { Write-Host "FAIL=RECEIPT_TOO_LARGE"; exit 1 }
if ([bool]$p.protected_paths_unchanged -ne $true) { Write-Host "FAIL=PROTECTED_PATHS_MUTATED"; exit 1 }

if ([string]::IsNullOrWhiteSpace([string]$p.durable_compact_store_manifest_path)) { Write-Host "FAIL=DURABLE_MANIFEST_PATH_EMPTY"; exit 1 }
if ([string]::IsNullOrWhiteSpace([string]$p.durable_compact_store_index_path)) { Write-Host "FAIL=DURABLE_INDEX_PATH_EMPTY"; exit 1 }
if (-not (Test-Path -LiteralPath ([string]$p.durable_compact_store_manifest_path))) { Write-Host "FAIL=DURABLE_MANIFEST_MISSING"; exit 1 }
if (-not (Test-Path -LiteralPath ([string]$p.durable_compact_store_index_path))) { Write-Host "FAIL=DURABLE_INDEX_MISSING"; exit 1 }

$manifest = Get-Content -LiteralPath ([string]$p.durable_compact_store_manifest_path) -Raw | ConvertFrom-Json
$index = Get-Content -LiteralPath ([string]$p.durable_compact_store_index_path) -Raw | ConvertFrom-Json
if ($manifest.schema -ne "durable_compact_atom_store_manifest_v1") { Write-Host "FAIL=DURABLE_MANIFEST_SCHEMA"; exit 1 }
if ($index.schema -ne "durable_compact_accepted_atom_index_v1") { Write-Host "FAIL=DURABLE_INDEX_SCHEMA"; exit 1 }
if ([bool]$manifest.runtime_ready -ne $false) { Write-Host "FAIL=DURABLE_MANIFEST_RUNTIME_READY_OVERCLAIM"; exit 1 }
if ([bool]$index.runtime_ready -ne $false) { Write-Host "FAIL=DURABLE_INDEX_RUNTIME_READY_OVERCLAIM"; exit 1 }
if ([int]$manifest.record_count -ne [int]$index.record_count) { Write-Host "FAIL=DURABLE_RECORD_COUNT_MISMATCH"; exit 1 }
if ([int]$index.record_count -ne [int]$p.durable_record_count) { Write-Host "FAIL=PROOF_RECORD_COUNT_MISMATCH"; exit 1 }
if ([int]$p.durable_record_count -ne 6) { Write-Host "FAIL=DURABLE_RECORD_COUNT"; exit 1 }
if ([int]$p.durable_batch_count -ne 3) { Write-Host "FAIL=DURABLE_BATCH_COUNT"; exit 1 }
if ([int]$p.durable_cycle_count -ne 3) { Write-Host "FAIL=DURABLE_CYCLE_COUNT"; exit 1 }
if ([int]$index.max_record_bytes -gt 7000) { Write-Host "FAIL=DURABLE_RECORD_TOO_LARGE"; exit 1 }

if ($p.retrieval_status -ne "PASS") { Write-Host "FAIL=RETRIEVAL_STATUS"; exit 1 }
if ([bool]$p.retrieved_by_atom_id -ne $true) { Write-Host "FAIL=RETRIEVED_BY_ATOM_ID"; exit 1 }
if ([int]$p.semantic_payload_field_count -lt 3) { Write-Host "FAIL=SEMANTIC_PAYLOAD_FIELD_COUNT"; exit 1 }
if ([string]::IsNullOrWhiteSpace([string]$p.retrieved_use_proof)) { Write-Host "FAIL=USE_PROOF_EMPTY"; exit 1 }

$retrieved = @($index.records | Where-Object { $_.atom_id -eq $p.retrieval_atom_id })
if ($retrieved.Count -ne 1) { Write-Host "FAIL=RETRIEVED_ATOM_MISSING"; exit 1 }
$semanticPresent = @($SemanticFields | Where-Object {
    ($retrieved[0].PSObject.Properties.Name -contains $_) -and
    -not [string]::IsNullOrWhiteSpace([string]$retrieved[0].PSObject.Properties[$_].Value)
})
if ($semanticPresent.Count -lt 3) { Write-Host "FAIL=DURABLE_SEMANTIC_FIELDS_MISSING"; exit 1 }

$cycleResults = @($p.cycle_results)
if ($cycleResults.Count -ne 3) { Write-Host "FAIL=CYCLE_RESULT_COUNT"; exit 1 }
foreach ($cycle in $cycleResults) {
    if ([int]$cycle.accepted_count -ne 2) { Write-Host "FAIL=CYCLE_ACCEPTED_COUNT"; exit 1 }
    if ([int]$cycle.receipt_count -ne 2) { Write-Host "FAIL=CYCLE_RECEIPT_COUNT"; exit 1 }
    if ([bool]$cycle.heavy_trace_pruned -ne $true) { Write-Host "FAIL=CYCLE_HEAVY_TRACE_NOT_PRUNED"; exit 1 }
    if ([bool]$cycle.cycle_root_pruned -ne $true) { Write-Host "FAIL=CYCLE_ROOT_NOT_PRUNED"; exit 1 }
    if ([bool]$cycle.receipts_compact -ne $true) { Write-Host "FAIL=CYCLE_RECEIPTS_NOT_COMPACT"; exit 1 }
    if (Test-Path -LiteralPath ([string]$cycle.cycle_root)) { Write-Host "FAIL=CYCLE_ROOT_STILL_EXISTS"; exit 1 }
}

$protectedStatus = @(git status --short -- reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/accepted_change_memory_snapshot.json packs/registry.json)
if ($protectedStatus.Count -ne 0) { Write-Host "FAIL=CANONICAL_ACTIVE_STUBS_MUTATED"; exit 1 }

Write-Host "VALIDATION_PASS=COMPACT_ATOM_STORAGE_SURVIVES_CLEANUP_MICRO_PROVEN"
Write-Host "COMPACT_STORAGE_SURVIVES_CLEANUP=$($p.compact_storage_survives_cleanup)"
Write-Host "DURABLE_COMPACT_STORE_EXISTS=$($p.durable_compact_store_exists)"
Write-Host "RETRIEVAL_STATUS=$($p.retrieval_status)"
Write-Host "RETRIEVED_BY_ATOM_ID=$($p.retrieved_by_atom_id)"
Write-Host "SEMANTIC_PAYLOAD_FIELD_COUNT=$($p.semantic_payload_field_count)"
Write-Host "CYCLE_ROOTS_PRUNED=$($p.cycle_roots_pruned)"
Write-Host "RECEIPTS_COMPACT=$($p.receipts_compact)"
Write-Host "RUNTIME_READY=false"
exit 0
