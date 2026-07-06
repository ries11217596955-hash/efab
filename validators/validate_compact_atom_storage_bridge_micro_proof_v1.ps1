$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/COMPACT_ATOM_STORAGE_BRIDGE_MICRO_PROOF_V1.json"
$ModulePath = "modules/invoke_accepted_atom_retention_compactor_v1.ps1"
$GatePath = "modules/invoke_accepted_atom_retention_gate_v1.ps1"

if (-not (Test-Path $ModulePath)) { Write-Host "FAIL=COMPACTOR_MISSING"; exit 1 }
if (-not (Test-Path $GatePath)) { Write-Host "FAIL=GATE_MISSING"; exit 1 }
if (-not (Test-Path $ProofPath)) { Write-Host "FAIL=PROOF_MISSING"; exit 1 }

$p = Get-Content $ProofPath -Raw | ConvertFrom-Json

if ($p.status -ne "PASS") { Write-Host "FAIL=PROOF_STATUS"; exit 1 }
if ($p.final_status -ne "COMPACT_ATOM_STORAGE_BRIDGE_MICRO_PROVEN") { Write-Host "FAIL=FINAL_STATUS"; exit 1 }
if ([bool]$p.runtime_ready -ne $false) { Write-Host "FAIL=RUNTIME_READY_OVERCLAIM"; exit 1 }

if ([int]$p.accepted_count -ne 3) { Write-Host "FAIL=ACCEPTED_COUNT"; exit 1 }
if ([int]$p.receipt_count -ne 3) { Write-Host "FAIL=RECEIPT_COUNT"; exit 1 }
if ([int]$p.compact_atom_index_count -ne [int]$p.accepted_count) { Write-Host "FAIL=INDEX_COUNT_MISMATCH"; exit 1 }

if ([string]::IsNullOrWhiteSpace([string]$p.compact_atom_index_path)) { Write-Host "FAIL=INDEX_PATH_EMPTY"; exit 1 }
if (-not (Test-Path -LiteralPath ([string]$p.compact_atom_index_path))) { Write-Host "FAIL=INDEX_PATH_MISSING"; exit 1 }
if ([string]::IsNullOrWhiteSpace([string]$p.compact_atom_retrieval_proof_path)) { Write-Host "FAIL=RETRIEVAL_PROOF_PATH_EMPTY"; exit 1 }
if (-not (Test-Path -LiteralPath ([string]$p.compact_atom_retrieval_proof_path))) { Write-Host "FAIL=RETRIEVAL_PROOF_PATH_MISSING"; exit 1 }

$index = Get-Content -LiteralPath ([string]$p.compact_atom_index_path) -Raw | ConvertFrom-Json
$retrievalProof = Get-Content -LiteralPath ([string]$p.compact_atom_retrieval_proof_path) -Raw | ConvertFrom-Json

if ($index.schema -ne "compact_accepted_atom_index_v1") { Write-Host "FAIL=INDEX_SCHEMA"; exit 1 }
if ([int]$index.record_count -ne [int]$p.accepted_count) { Write-Host "FAIL=INDEX_RECORD_COUNT"; exit 1 }
if ([int]$index.max_record_bytes -gt 7000) { Write-Host "FAIL=COMPACT_RECORD_TOO_LARGE"; exit 1 }
if ([bool]$index.runtime_ready -ne $false) { Write-Host "FAIL=INDEX_RUNTIME_READY_OVERCLAIM"; exit 1 }

$retrieved = @($index.records | Where-Object { $_.atom_id -eq $p.retrieval_atom_id })
if ($retrieved.Count -ne 1) { Write-Host "FAIL=RETRIEVAL_BY_ATOM_ID"; exit 1 }
if ($retrievalProof.status -ne "PASS") { Write-Host "FAIL=RETRIEVAL_PROOF_STATUS"; exit 1 }
if ([bool]$retrievalProof.retrieved_by_atom_id -ne $true) { Write-Host "FAIL=RETRIEVED_BY_ATOM_ID_FALSE"; exit 1 }
if ([bool]$retrievalProof.runtime_ready -ne $false) { Write-Host "FAIL=RETRIEVAL_RUNTIME_READY_OVERCLAIM"; exit 1 }

$semanticFields = @("explanation","compact_summary","behavior_change","guided_example","check_prompt","expected_check_result","use_proof")
$recordsWithSemanticPayload = @($index.records | Where-Object {
    $record = $_
    @($semanticFields | Where-Object {
        ($record.PSObject.Properties.Name -contains $_) -and
        -not [string]::IsNullOrWhiteSpace([string]$record.PSObject.Properties[$_].Value)
    }).Count -ge 3
})
if ($recordsWithSemanticPayload.Count -lt 1) { Write-Host "FAIL=NO_SEMANTIC_PAYLOAD"; exit 1 }
if ([int]$p.semantic_payload_field_count -lt 3) { Write-Host "FAIL=PROOF_SEMANTIC_PAYLOAD_TOO_SMALL"; exit 1 }
if ([string]::IsNullOrWhiteSpace([string]$p.retrieved_use_proof)) { Write-Host "FAIL=USE_PROOF_MISSING"; exit 1 }

if ([bool]$p.receipts_compact -ne $true) { Write-Host "FAIL=RECEIPTS_NOT_COMPACT"; exit 1 }
if ([int]$p.receipt_max_bytes -gt 2000) { Write-Host "FAIL=RECEIPT_TOO_LARGE"; exit 1 }
if ([bool]$p.heavy_trace_pruned -ne $true) { Write-Host "FAIL=HEAVY_TRACE_NOT_PRUNED"; exit 1 }
if ([bool]$p.work_current_preserved -ne $false) { Write-Host "FAIL=WORK_CURRENT_PRESERVED"; exit 1 }
if ([bool]$p.protected_paths_unchanged -ne $true) { Write-Host "FAIL=PROTECTED_PATHS_MUTATED"; exit 1 }

$protectedStatus = @(git status --short -- reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/accepted_change_memory_snapshot.json packs/registry.json)
if ($protectedStatus.Count -ne 0) { Write-Host "FAIL=PROTECTED_GIT_STATUS_DIRTY"; exit 1 }

Write-Host "VALIDATION_PASS=COMPACT_ATOM_STORAGE_BRIDGE_MICRO_PROVEN"
Write-Host "INDEX_PATH=$($p.compact_atom_index_path)"
Write-Host "RETRIEVAL_PROOF_PATH=$($p.compact_atom_retrieval_proof_path)"
Write-Host "RUNTIME_READY=false"
exit 0
