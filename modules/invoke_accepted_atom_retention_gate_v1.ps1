param(
    [Parameter(Mandatory=$true)][string]$BatchId,
    [Parameter(Mandatory=$true)][string]$WorkCurrent,
    [Parameter(Mandatory=$true)][string]$AcceptedAtomsPath,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [Parameter(Mandatory=$true)][string]$PostValidationStatus,
    [int]$FailedCount = 0,
    [int]$QuarantinedCount = 0,
    [string]$DurableCompactStoreRoot = ""
)

$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
$CompactorPath = Join-Path $Repo "modules/invoke_accepted_atom_retention_compactor_v1.ps1"

if (-not (Test-Path $CompactorPath)) {
    throw "COMPACTOR_MISSING=$CompactorPath"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

if ($PostValidationStatus -ne "PASS" -or $FailedCount -gt 0 -or $QuarantinedCount -gt 0) {
    $manifest = [ordered]@{
        schema = "accepted_atom_retention_gate_manifest_v1"
        batch_id = $BatchId
        status = "QUARANTINE_TRACE_REQUIRED"
        post_validation_status = $PostValidationStatus
        failed_count = $FailedCount
        quarantined_count = $QuarantinedCount
        heavy_trace_pruned = $false
        work_current_preserved = (Test-Path $WorkCurrent)
        reason = "Failed or quarantined traces must be preserved. Retention gate refuses prune."
        durable_compact_store_written = $false
        durable_compact_store_root = ""
    }

    $manifestPath = Join-Path $OutputRoot "gate_manifest.json"
    $manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding UTF8

    $result = [ordered]@{
        schema = "accepted_atom_retention_gate_result_v1"
        status = "QUARANTINE_TRACE_REQUIRED"
        batch_id = $BatchId
        heavy_trace_pruned = $false
        work_current_preserved = (Test-Path $WorkCurrent)
        durable_compact_store_written = $false
        durable_compact_store_root = ""
        manifest_path = $manifestPath
        output_root = $OutputRoot
    }

    $result | ConvertTo-Json -Depth 20
    return
}

$resultJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CompactorPath `
    -BatchId $BatchId `
    -WorkCurrent $WorkCurrent `
    -AcceptedAtomsPath $AcceptedAtomsPath `
    -OutputRoot $OutputRoot `
    -DurableCompactStoreRoot $DurableCompactStoreRoot

$result = $resultJson | ConvertFrom-Json

$gateManifest = [ordered]@{
    schema = "accepted_atom_retention_gate_manifest_v1"
    batch_id = $BatchId
    status = "PASS"
    post_validation_status = $PostValidationStatus
    failed_count = 0
    quarantined_count = 0
    accepted_count = [int]$result.accepted_count
    receipt_count = [int]$result.receipt_count
    heavy_trace_pruned = [bool]$result.heavy_trace_pruned
    work_current_preserved = (Test-Path $WorkCurrent)
    compactor_manifest_path = $result.manifest_path
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
}

$gateManifestPath = Join-Path $OutputRoot "gate_manifest.json"
$gateManifest | ConvertTo-Json -Depth 20 | Set-Content $gateManifestPath -Encoding UTF8

$gateResult = [ordered]@{
    schema = "accepted_atom_retention_gate_result_v1"
    status = "PASS"
    batch_id = $BatchId
    accepted_count = [int]$result.accepted_count
    receipt_count = [int]$result.receipt_count
    heavy_trace_pruned = [bool]$result.heavy_trace_pruned
    work_current_preserved = (Test-Path $WorkCurrent)
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
    manifest_path = $gateManifestPath
    output_root = $OutputRoot
}

$gateResult | ConvertTo-Json -Depth 20
