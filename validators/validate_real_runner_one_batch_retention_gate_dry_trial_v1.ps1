$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/REAL_RUNNER_ONE_BATCH_RETENTION_GATE_DRY_TRIAL_V1.json"

if (-not (Test-Path "modules/invoke_real_runner_retention_gate_adapter_v1.ps1")) {
    Write-Host "FAIL=ADAPTER_MISSING"
    exit 1
}

if (-not (Test-Path $ProofPath)) {
    Write-Host "FAIL=PROOF_MISSING"
    exit 1
}

$p = Get-Content $ProofPath -Raw | ConvertFrom-Json
$semanticPayloadFields = @(
    "explanation",
    "compact_summary",
    "behavior_change",
    "guided_example",
    "check_prompt",
    "expected_check_result",
    "use_proof"
)

if ($p.status -ne "PASS") { Write-Host "FAIL=PROOF_STATUS"; exit 1 }
if ($p.final_status -ne "REAL_RUNNER_COMPACT_STORAGE_BRIDGE_INTEGRATION_PROVEN") { Write-Host "FAIL=FINAL_STATUS"; exit 1 }
if ([bool]$p.runtime_ready -ne $false) { Write-Host "FAIL=RUNTIME_READY_OVERCLAIM"; exit 1 }

if ($p.success_case.status -ne "PASS") { Write-Host "FAIL=SUCCESS_STATUS"; exit 1 }
if ([int]$p.success_case.accepted_count -ne 7) { Write-Host "FAIL=SUCCESS_ACCEPTED_COUNT"; exit 1 }
if ([int]$p.success_case.receipt_count -ne 7) { Write-Host "FAIL=SUCCESS_RECEIPT_COUNT"; exit 1 }
if ([bool]$p.success_case.heavy_trace_pruned -ne $true) { Write-Host "FAIL=SUCCESS_NOT_PRUNED"; exit 1 }
if ([bool]$p.success_case.work_current_preserved -ne $false) { Write-Host "FAIL=SUCCESS_WORK_PRESERVED"; exit 1 }
if ([bool]$p.success_case.real_runner_compact_storage_bridge_proven -ne $true) { Write-Host "FAIL=SUCCESS_COMPACT_BRIDGE_NOT_PROVEN"; exit 1 }

if ([string]::IsNullOrWhiteSpace([string]$p.success_case.compact_atom_index_path)) { Write-Host "FAIL=SUCCESS_INDEX_PATH_EMPTY"; exit 1 }
if (-not (Test-Path -LiteralPath ([string]$p.success_case.compact_atom_index_path))) { Write-Host "FAIL=SUCCESS_INDEX_PATH_MISSING"; exit 1 }
if ([string]::IsNullOrWhiteSpace([string]$p.success_case.compact_atom_retrieval_proof_path)) { Write-Host "FAIL=SUCCESS_RETRIEVAL_PROOF_PATH_EMPTY"; exit 1 }
if (-not (Test-Path -LiteralPath ([string]$p.success_case.compact_atom_retrieval_proof_path))) { Write-Host "FAIL=SUCCESS_RETRIEVAL_PROOF_PATH_MISSING"; exit 1 }
if ([int]$p.success_case.compact_atom_index_count -ne [int]$p.success_case.accepted_count) { Write-Host "FAIL=SUCCESS_INDEX_COUNT_MISMATCH"; exit 1 }

$index = Get-Content -LiteralPath ([string]$p.success_case.compact_atom_index_path) -Raw | ConvertFrom-Json
$retrievalProof = Get-Content -LiteralPath ([string]$p.success_case.compact_atom_retrieval_proof_path) -Raw | ConvertFrom-Json
if ($index.schema -ne "compact_accepted_atom_index_v1") { Write-Host "FAIL=INDEX_SCHEMA"; exit 1 }
if ([int]$index.record_count -ne [int]$p.success_case.accepted_count) { Write-Host "FAIL=INDEX_RECORD_COUNT"; exit 1 }
if ($retrievalProof.schema -ne "compact_accepted_atom_retrieval_proof_v1") { Write-Host "FAIL=RETRIEVAL_SCHEMA"; exit 1 }
if ($retrievalProof.status -ne "PASS") { Write-Host "FAIL=RETRIEVAL_STATUS"; exit 1 }
if ([bool]$retrievalProof.retrieved_by_atom_id -ne $true) { Write-Host "FAIL=RETRIEVED_BY_ATOM_ID"; exit 1 }

$retrieved = @($index.records | Where-Object { $_.atom_id -eq $retrievalProof.retrieval_atom_id })
if ($retrieved.Count -ne 1) { Write-Host "FAIL=RETRIEVED_ATOM_MISSING"; exit 1 }
$semanticFieldsPresent = @($semanticPayloadFields | Where-Object {
    ($retrieved[0].PSObject.Properties.Name -contains $_) -and
    -not [string]::IsNullOrWhiteSpace([string]$retrieved[0].PSObject.Properties[$_].Value)
})
if ($semanticFieldsPresent.Count -lt 3) { Write-Host "FAIL=SEMANTIC_PAYLOAD_FIELD_COUNT"; exit 1 }
if ([string]::IsNullOrWhiteSpace([string]$retrieved[0].use_proof)) { Write-Host "FAIL=USE_PROOF_EMPTY"; exit 1 }

if ($p.retrieval_status -ne "PASS") { Write-Host "FAIL=PROOF_RETRIEVAL_STATUS"; exit 1 }
if ([bool]$p.retrieved_by_atom_id -ne $true) { Write-Host "FAIL=PROOF_RETRIEVED_BY_ATOM_ID"; exit 1 }
if ([int]$p.semantic_payload_field_count -lt 3) { Write-Host "FAIL=PROOF_SEMANTIC_PAYLOAD_FIELD_COUNT"; exit 1 }
if ([bool]$p.receipts_compact -ne $true) { Write-Host "FAIL=PROOF_RECEIPTS_NOT_COMPACT"; exit 1 }
if ([int]$p.receipt_max_bytes -gt 2000) { Write-Host "FAIL=RECEIPT_TOO_LARGE"; exit 1 }
if ([bool]$p.real_runner_compact_storage_bridge_proven -ne $true) { Write-Host "FAIL=PROOF_COMPACT_BRIDGE_NOT_PROVEN"; exit 1 }

$receiptRoot = Join-Path ([string]$p.success_case.output_root) "receipts"
if (-not (Test-Path -LiteralPath $receiptRoot)) { Write-Host "FAIL=RECEIPT_ROOT_MISSING"; exit 1 }
$receiptFiles = @(Get-ChildItem -LiteralPath $receiptRoot -File -Filter "*.receipt.json")
if ($receiptFiles.Count -ne [int]$p.success_case.receipt_count) { Write-Host "FAIL=RECEIPT_FILE_COUNT"; exit 1 }
foreach ($receiptFile in $receiptFiles) {
    $receipt = Get-Content -LiteralPath $receiptFile.FullName -Raw | ConvertFrom-Json
    if ($receipt.retained_trace -ne "compact_receipt_only") { Write-Host "FAIL=RECEIPT_RETAINED_TRACE"; exit 1 }
    foreach ($semanticField in $semanticPayloadFields) {
        if ($receipt.PSObject.Properties.Name -contains $semanticField) { Write-Host "FAIL=RECEIPT_HAS_SEMANTIC_FIELD"; exit 1 }
    }
}

if ($p.failure_case.status -ne "QUARANTINE_TRACE_REQUIRED") { Write-Host "FAIL=FAILURE_STATUS"; exit 1 }
if ([bool]$p.failure_case.heavy_trace_pruned -ne $false) { Write-Host "FAIL=FAILURE_PRUNED"; exit 1 }
if ([bool]$p.failure_case.work_current_preserved -ne $true) { Write-Host "FAIL=FAILURE_NOT_PRESERVED"; exit 1 }
if ([bool]$p.failure_case.real_runner_compact_storage_bridge_proven -ne $false) { Write-Host "FAIL=FAILURE_FALSE_COMPACT_BRIDGE_CLAIM"; exit 1 }
if ([int]$p.failure_case.compact_atom_index_count -ne 0) { Write-Host "FAIL=FAILURE_COMPACT_INDEX_COUNT"; exit 1 }

if ([int64]$p.repo_growth_bytes -gt 300000) { Write-Host "FAIL=REPO_GROWTH_TOO_HIGH"; exit 1 }

$protectedStatus = @(git status --short -- reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/accepted_change_memory_snapshot.json packs/registry.json)
if ($protectedStatus.Count -ne 0) { Write-Host "FAIL=CANONICAL_ACTIVE_STUBS_MUTATED"; exit 1 }

Write-Host "VALIDATION_PASS=REAL_RUNNER_COMPACT_STORAGE_BRIDGE_INTEGRATION_PROVEN"
Write-Host "REAL_RUNNER_COMPACT_INDEX_COUNT=$($p.success_case.compact_atom_index_count)"
Write-Host "REAL_RUNNER_RETRIEVAL_STATUS=$($p.success_case.retrieval_status)"
Write-Host "REAL_RUNNER_RETRIEVED_BY_ATOM_ID=$($p.success_case.retrieved_by_atom_id)"
Write-Host "REAL_RUNNER_SEMANTIC_PAYLOAD_FIELD_COUNT=$($p.success_case.semantic_payload_field_count)"
Write-Host "REAL_RUNNER_COMPACT_STORAGE_BRIDGE_PROVEN=$($p.success_case.real_runner_compact_storage_bridge_proven)"
Write-Host "RUNTIME_READY=false"
exit 0
