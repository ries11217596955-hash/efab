param(
    [Parameter(Mandatory=$true)][string]$BatchEnvelopePath
)

$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$GatePath = "modules/invoke_accepted_atom_retention_gate_v1.ps1"

if (-not (Test-Path $GatePath)) {
    throw "RETENTION_GATE_MISSING=$GatePath"
}

if (-not (Test-Path $BatchEnvelopePath)) {
    throw "BATCH_ENVELOPE_MISSING=$BatchEnvelopePath"
}

$env = Get-Content $BatchEnvelopePath -Raw | ConvertFrom-Json

$required = @(
    "batch_id",
    "work_current",
    "accepted_atoms_path",
    "output_root",
    "post_validation_status",
    "failed_count",
    "quarantined_count"
)

foreach ($r in $required) {
    if (-not ($env.PSObject.Properties.Name -contains $r)) {
        throw "BATCH_ENVELOPE_MISSING_FIELD=$r"
    }
}

$resultJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GatePath `
    -BatchId ([string]$env.batch_id) `
    -WorkCurrent ([string]$env.work_current) `
    -AcceptedAtomsPath ([string]$env.accepted_atoms_path) `
    -OutputRoot ([string]$env.output_root) `
    -PostValidationStatus ([string]$env.post_validation_status) `
    -FailedCount ([int]$env.failed_count) `
    -QuarantinedCount ([int]$env.quarantined_count) `
    -DurableCompactStoreRoot $(if ($env.PSObject.Properties.Name -contains "durable_compact_store_root") { [string]$env.durable_compact_store_root } else { "" })

$result = $resultJson | ConvertFrom-Json

$adapterResult = [ordered]@{
    schema = "real_runner_retention_gate_adapter_result_v1"
    status = $result.status
    batch_id = $env.batch_id
    source = "real_runner_one_batch_envelope"
    post_validation_status = $env.post_validation_status
    failed_count = [int]$env.failed_count
    quarantined_count = [int]$env.quarantined_count
    accepted_count = if ($result.PSObject.Properties.Name -contains "accepted_count") { [int]$result.accepted_count } else { 0 }
    receipt_count = if ($result.PSObject.Properties.Name -contains "receipt_count") { [int]$result.receipt_count } else { 0 }
    heavy_trace_pruned = [bool]$result.heavy_trace_pruned
    work_current_preserved = [bool]$result.work_current_preserved
    cleanup_pending_count = if ($result.PSObject.Properties.Name -contains "cleanup_pending_count") { [int]$result.cleanup_pending_count } else { 0 }
    cleanup_pending_path = if ($result.PSObject.Properties.Name -contains "cleanup_pending_path") { [string]$result.cleanup_pending_path } else { "" }
    compact_atom_index_path = if ($result.PSObject.Properties.Name -contains "compact_atom_index_path") { [string]$result.compact_atom_index_path } else { "" }
    compact_atom_index_hash = if ($result.PSObject.Properties.Name -contains "compact_atom_index_hash") { [string]$result.compact_atom_index_hash } else { "" }
    compact_atom_index_count = if ($result.PSObject.Properties.Name -contains "compact_atom_index_count") { [int]$result.compact_atom_index_count } else { 0 }
    compact_atom_retrieval_proof_path = if ($result.PSObject.Properties.Name -contains "compact_atom_retrieval_proof_path") { [string]$result.compact_atom_retrieval_proof_path } else { "" }
    durable_compact_store_written = if ($result.PSObject.Properties.Name -contains "durable_compact_store_written") { [bool]$result.durable_compact_store_written } else { $false }
    durable_compact_store_root = if ($result.PSObject.Properties.Name -contains "durable_compact_store_root") { [string]$result.durable_compact_store_root } else { "" }
    durable_compact_store_manifest_path = if ($result.PSObject.Properties.Name -contains "durable_compact_store_manifest_path") { [string]$result.durable_compact_store_manifest_path } else { "" }
    durable_compact_store_index_path = if ($result.PSObject.Properties.Name -contains "durable_compact_store_index_path") { [string]$result.durable_compact_store_index_path } else { "" }
    durable_compact_store_record_count = if ($result.PSObject.Properties.Name -contains "durable_compact_store_record_count") { [int]$result.durable_compact_store_record_count } else { 0 }
    durable_compact_store_batch_count = if ($result.PSObject.Properties.Name -contains "durable_compact_store_batch_count") { [int]$result.durable_compact_store_batch_count } else { 0 }
    durable_compact_store_cycle_count = if ($result.PSObject.Properties.Name -contains "durable_compact_store_cycle_count") { [int]$result.durable_compact_store_cycle_count } else { 0 }
    durable_compact_store_hash = if ($result.PSObject.Properties.Name -contains "durable_compact_store_hash") { [string]$result.durable_compact_store_hash } else { "" }
    manifest_path = $result.manifest_path
    output_root = $result.output_root
    runtime_ready = $false
}

$adapterResult | ConvertTo-Json -Depth 20
