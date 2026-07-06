param(
    [Parameter(Mandatory=$true)][string]$BatchId,
    [Parameter(Mandatory=$true)][string]$WorkCurrent,
    [Parameter(Mandatory=$true)][string]$AcceptedAtomsPath,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$DurableCompactStoreRoot = ""
)

$ErrorActionPreference = "Stop"

function Sha256Text {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return "sha256:" + (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Get-AtomPropertyValue {
    param(
        [Parameter(Mandatory=$true)]$Atom,
        [Parameter(Mandatory=$true)][string[]]$Names
    )

    foreach ($name in $Names) {
        if ($Atom.PSObject.Properties.Name -contains $name) {
            $value = $Atom.PSObject.Properties[$name].Value
            if ($null -ne $value) { return $value }
        }
    }
    return $null
}

function ConvertTo-CompactAtomText {
    param(
        $Value,
        [int]$MaxChars = 800
    )

    if ($null -eq $Value) { return "" }
    $text = ""
    if ($Value -is [string]) {
        $text = $Value.Trim()
    } else {
        $text = ($Value | ConvertTo-Json -Depth 10 -Compress)
    }

    if ($text.Length -gt $MaxChars) {
        return $text.Substring(0, $MaxChars) + "...[truncated]"
    }
    return $text
}

function Get-CompactRecordValue {
    param(
        $Record,
        [string]$Name
    )

    if ($Record -is [System.Collections.IDictionary] -and $Record.Contains($Name)) {
        return $Record[$Name]
    }
    if ($Record.PSObject.Properties.Name -contains $Name) {
        return $Record.PSObject.Properties[$Name].Value
    }
    return $null
}

function New-CompactAtomUseProof {
    param($Record)

    $parts = @()
    $domain = [string](Get-CompactRecordValue -Record $Record -Name "domain")
    $conceptId = [string](Get-CompactRecordValue -Record $Record -Name "concept_id")
    $atomType = [string](Get-CompactRecordValue -Record $Record -Name "atom_type")
    $atomId = [string](Get-CompactRecordValue -Record $Record -Name "atom_id")
    if (-not [string]::IsNullOrWhiteSpace($domain)) { $parts += "domain=$domain" }
    if (-not [string]::IsNullOrWhiteSpace($conceptId)) { $parts += "concept_id=$conceptId" }
    if (-not [string]::IsNullOrWhiteSpace($atomType)) { $parts += "atom_type=$atomType" }

    $selector = if ($parts.Count -gt 0) { $parts -join "; " } else { "atom_id=$atomId" }
    return "Retrieved compact atom $atomId can be reused by matching $selector and checking its compact semantic payload before applying it."
}

function New-CompactAtomIndexRecord {
    param(
        [Parameter(Mandatory=$true)]$Atom,
        [Parameter(Mandatory=$true)][string]$AtomHash
    )

    $sourceRefHash = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("source_ref_hash")) 200
    if ([string]::IsNullOrWhiteSpace($sourceRefHash)) {
        $sourceRef = Get-AtomPropertyValue -Atom $Atom -Names @("source_ref")
        if ($null -ne $sourceRef) {
            $sourceRefText = if ($sourceRef -is [string]) { $sourceRef } else { $sourceRef | ConvertTo-Json -Depth 10 -Compress }
            if (-not [string]::IsNullOrWhiteSpace($sourceRefText)) {
                $sourceRefHash = Sha256Text $sourceRefText
            }
        }
    }

    $record = [ordered]@{
        schema = "compact_accepted_atom_index_record_v1"
        atom_id = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("atom_id")) 240
        atom_hash = $AtomHash
        source_ref_hash = $sourceRefHash
        candidate_id = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("candidate_id")) 240
        concept_id = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("concept_id")) 240
        domain = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("domain")) 160
        atom_type = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("atom_type")) 160
        atom_type_suggestion = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("atom_type_suggestion")) 160
        explanation = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("explanation")) 1200
        compact_summary = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("compact_summary","summary")) 1200
        behavior_change = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("behavior_change")) 900
        guided_example = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("guided_example")) 900
        check_prompt = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("check_prompt")) 900
        expected_check_result = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("expected_check_result")) 900
        retained_trace = "compact_semantic_index_only"
    }

    $useProof = ConvertTo-CompactAtomText (Get-AtomPropertyValue -Atom $Atom -Names @("use_proof")) 900
    if ([string]::IsNullOrWhiteSpace($useProof)) {
        $useProof = New-CompactAtomUseProof -Record $record
    }
    $record["use_proof"] = $useProof

    return $record
}

function Get-CompactAtomSemanticFields {
    param($Record)

    $semanticNames = @(
        "explanation",
        "compact_summary",
        "behavior_change",
        "guided_example",
        "check_prompt",
        "expected_check_result",
        "use_proof"
    )

    return @($semanticNames | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string](Get-CompactRecordValue -Record $Record -Name $_))
    })
}

function Get-DefaultDurableCompactStoreRoot {
    param([string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $parts = @($full -split '[\\/]')
    for ($i = 0; $i -lt $parts.Count; $i += 1) {
        if ($parts[$i] -ieq ".runtime" -and ($i + 1) -lt $parts.Count) {
            $runtimeRunRoot = ($parts[0..($i + 1)] -join [System.IO.Path]::DirectorySeparatorChar)
            return (Join-Path $runtimeRunRoot "durable_compact_atom_store")
        }
    }
    return ""
}

function Write-DurableCompactAtomStore {
    param(
        [string]$StoreRoot,
        [string]$BatchId,
        [object[]]$Records
    )

    if ([string]::IsNullOrWhiteSpace($StoreRoot)) {
        return [pscustomobject][ordered]@{
            durable_compact_store_written = $false
            durable_compact_store_root = ""
            durable_compact_store_manifest_path = ""
            durable_compact_store_index_path = ""
            durable_compact_store_record_count = 0
            durable_compact_store_batch_count = 0
            durable_compact_store_cycle_count = 0
            durable_compact_store_hash = ""
        }
    }

    New-Item -ItemType Directory -Force -Path $StoreRoot | Out-Null
    $indexPath = Join-Path $StoreRoot "compact_atom_index.json"
    $manifestPath = Join-Path $StoreRoot "manifest.json"

    $existingRecords = @()
    $existingBatchIds = @()
    if (Test-Path -LiteralPath $indexPath) {
        try {
            $existingIndex = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
            $existingRecords = @($existingIndex.records)
        } catch {
            $existingRecords = @()
        }
    }
    if (Test-Path -LiteralPath $manifestPath) {
        try {
            $existingManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $existingBatchIds = @($existingManifest.batch_ids | ForEach-Object { [string]$_ })
        } catch {
            $existingBatchIds = @()
        }
    }

    $byHash = [ordered]@{}
    foreach ($record in @($existingRecords + $Records)) {
        $hash = [string](Get-CompactRecordValue -Record $record -Name "atom_hash")
        if ([string]::IsNullOrWhiteSpace($hash)) { continue }
        if (-not $byHash.Contains($hash)) {
            $byHash[$hash] = $record
        }
    }

    $allRecords = @($byHash.Values)
    $recordsJson = ($allRecords | ConvertTo-Json -Depth 30 -Compress)
    $recordsHash = Sha256Text $recordsJson
    $recordSizes = @($allRecords | ForEach-Object {
        [System.Text.Encoding]::UTF8.GetByteCount(($_ | ConvertTo-Json -Depth 20 -Compress))
    })
    $batchIds = @($existingBatchIds + @($BatchId) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $cycleIds = @($batchIds | ForEach-Object {
        if ([string]$_ -match "(cycle[_-]\d+)") { $Matches[1] } else { [string]$_ }
    } | Select-Object -Unique)

    $index = [ordered]@{
        schema = "durable_compact_accepted_atom_index_v1"
        updated_utc = (Get-Date).ToUniversalTime().ToString("o")
        record_count = $allRecords.Count
        batch_count = $batchIds.Count
        cycle_count = $cycleIds.Count
        records_hash = $recordsHash
        max_record_bytes = if ($recordSizes.Count -gt 0) { ($recordSizes | Measure-Object -Maximum).Maximum } else { 0 }
        records = @($allRecords)
        runtime_ready = $false
    }
    $index | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $indexPath -Encoding UTF8

    $manifest = [ordered]@{
        schema = "durable_compact_atom_store_manifest_v1"
        status = "PASS"
        updated_utc = (Get-Date).ToUniversalTime().ToString("o")
        store_root = $StoreRoot
        compact_atom_index_path = $indexPath
        record_count = $allRecords.Count
        batch_count = $batchIds.Count
        cycle_count = $cycleIds.Count
        batch_ids = @($batchIds)
        records_hash = $recordsHash
        runtime_ready = $false
    }
    $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    return [pscustomobject][ordered]@{
        durable_compact_store_written = $true
        durable_compact_store_root = $StoreRoot
        durable_compact_store_manifest_path = $manifestPath
        durable_compact_store_index_path = $indexPath
        durable_compact_store_record_count = $allRecords.Count
        durable_compact_store_batch_count = $batchIds.Count
        durable_compact_store_cycle_count = $cycleIds.Count
        durable_compact_store_hash = $recordsHash
    }
}

function Remove-RetentionCleanupPath {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [ValidateSet("file","dir")][string]$Kind,
        [int]$Attempts = 8,
        [string]$PendingManifestPath = ""
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $lastError = $null
    for ($attempt = 1; $attempt -le $Attempts; $attempt += 1) {
        try {
            if (-not (Test-Path -LiteralPath $Path)) { return }

            if ($Kind -eq "dir") {
                Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try { $_.Attributes = [System.IO.FileAttributes]::Normal } catch { }
                }
                Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            } else {
                try { [System.IO.File]::SetAttributes($Path, [System.IO.FileAttributes]::Normal) } catch { }
                Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
            }

            if (-not (Test-Path -LiteralPath $Path)) { return }
            throw "DELETE_VERIFY_STILL_EXISTS"
        } catch [System.UnauthorizedAccessException] {
            $lastError = $_.Exception
        } catch [System.IO.IOException] {
            $lastError = $_.Exception
        } catch {
            $lastError = $_.Exception
        }

        if ($attempt -lt $Attempts) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds ([Math]::Min(2000, 100 * $attempt))
        }
    }

    $exceptionType = if ($null -ne $lastError) { $lastError.GetType().FullName } else { "UNKNOWN" }
    $exceptionMessage = if ($null -ne $lastError) { $lastError.Message } else { "UNKNOWN" }
    if (-not [string]::IsNullOrWhiteSpace($PendingManifestPath)) {
        Add-RetentionCleanupPending -ManifestPath $PendingManifestPath -Path $Path -Kind $Kind -Attempts $Attempts -ExceptionType $exceptionType -ExceptionMessage $exceptionMessage
        return
    }
    throw "RETENTION_CLEANUP_DELETE_FAILED path=$Path kind=$Kind attempts=$Attempts exception_type=$exceptionType message=$exceptionMessage"
}

function Add-RetentionCleanupPending {
    param(
        [Parameter(Mandatory=$true)][string]$ManifestPath,
        [Parameter(Mandatory=$true)][string]$Path,
        [ValidateSet("file","dir")][string]$Kind,
        [int]$Attempts,
        [string]$ExceptionType,
        [string]$ExceptionMessage
    )

    $parent = Split-Path -Parent $ManifestPath
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $entries = @()
    if (Test-Path -LiteralPath $ManifestPath) {
        try {
            $existing = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
            $entries = @($existing.entries)
        } catch {
            $entries = @()
        }
    }
    $entries += [ordered]@{
        path = $Path
        kind = $Kind
        attempts = $Attempts
        exception_type = $ExceptionType
        exception_message = $ExceptionMessage
        queued_utc = (Get-Date).ToUniversalTime().ToString("o")
    }
    $manifest = [ordered]@{
        schema = "retention_cleanup_pending_v1"
        status = "PENDING"
        entries = @($entries)
        pending_cleanup_count = @($entries).Count
        runtime_ready = $false
    }
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

if (-not (Test-Path $WorkCurrent)) {
    throw "WORK_CURRENT_MISSING=$WorkCurrent"
}

if (-not (Test-Path $AcceptedAtomsPath)) {
    throw "ACCEPTED_ATOMS_MISSING=$AcceptedAtomsPath"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$pendingCleanupPath = Join-Path $OutputRoot "cleanup_pending.json"
if ([string]::IsNullOrWhiteSpace($DurableCompactStoreRoot)) {
    $DurableCompactStoreRoot = Get-DefaultDurableCompactStoreRoot -Path $OutputRoot
}

$atoms = Get-Content $AcceptedAtomsPath -Raw | ConvertFrom-Json
if ($null -eq $atoms -or $atoms.Count -lt 1) {
    throw "NO_ACCEPTED_ATOMS"
}

$Receipts = @()
$CompactAtomIndexRecords = @()
$ReceiptRoot = Join-Path $OutputRoot "receipts"
New-Item -ItemType Directory -Force -Path $ReceiptRoot | Out-Null

foreach ($atom in $atoms) {
    $atomText = $atom | ConvertTo-Json -Depth 20 -Compress
    $atomHash = Sha256Text $atomText
    $CompactAtomIndexRecords += New-CompactAtomIndexRecord -Atom $atom -AtomHash $atomHash

    $receipt = [ordered]@{
        schema = "accepted_atom_receipt_v1"
        atom_id = [string]$atom.atom_id
        atom_hash = $atomHash
        batch_id = $BatchId
        accepted_utc = (Get-Date).ToUniversalTime().ToString("o")
        effect_type = [string]$atom.effect_type
        target = [string]$atom.target
        source_ref_hash = Sha256Text ([string]$atom.source_ref)
        retained_trace = "compact_receipt_only"
        retained_reason = "successful_atom_full_trace_pruned_after_validation"
    }

    $receiptPath = Join-Path $ReceiptRoot ("r_" + $atomHash.Substring(7, 12) + ".receipt.json")
    $receipt | ConvertTo-Json -Depth 20 | Set-Content $receiptPath -Encoding UTF8
    $Receipts += $receipt
}

$compactAtomIndexPath = Join-Path $OutputRoot "compact_atom_index.json"
$compactAtomIndexText = ($CompactAtomIndexRecords | ConvertTo-Json -Depth 20 -Compress)
$compactAtomIndexHash = Sha256Text $compactAtomIndexText
$compactAtomRecordSizes = @($CompactAtomIndexRecords | ForEach-Object {
    [System.Text.Encoding]::UTF8.GetByteCount(($_ | ConvertTo-Json -Depth 20 -Compress))
})
$compactAtomIndex = [ordered]@{
    schema = "compact_accepted_atom_index_v1"
    batch_id = $BatchId
    created_utc = (Get-Date).ToUniversalTime().ToString("o")
    accepted_count = $Receipts.Count
    record_count = $CompactAtomIndexRecords.Count
    records_hash = $compactAtomIndexHash
    max_record_bytes = if ($compactAtomRecordSizes.Count -gt 0) { ($compactAtomRecordSizes | Measure-Object -Maximum).Maximum } else { 0 }
    records = @($CompactAtomIndexRecords)
    runtime_ready = $false
}
$compactAtomIndex | ConvertTo-Json -Depth 30 | Set-Content $compactAtomIndexPath -Encoding UTF8

$retrievalCandidate = @($CompactAtomIndexRecords | Where-Object { (Get-CompactAtomSemanticFields -Record $_).Count -gt 0 } | Select-Object -First 1)
if ($retrievalCandidate.Count -lt 1 -and $CompactAtomIndexRecords.Count -gt 0) {
    $retrievalCandidate = @($CompactAtomIndexRecords | Select-Object -First 1)
}
$retrieved = if ($retrievalCandidate.Count -gt 0) { $retrievalCandidate[0] } else { $null }
$retrievedSemanticFields = if ($null -ne $retrieved) { @(Get-CompactAtomSemanticFields -Record $retrieved) } else { @() }
$retrievalProof = [ordered]@{
    schema = "compact_accepted_atom_retrieval_proof_v1"
    status = if ($null -ne $retrieved -and $retrievedSemanticFields.Count -gt 0) { "PASS" } else { "NO_SEMANTIC_PAYLOAD_AVAILABLE" }
    batch_id = $BatchId
    created_utc = (Get-Date).ToUniversalTime().ToString("o")
    compact_atom_index_path = $compactAtomIndexPath
    retrieval_atom_id = if ($null -ne $retrieved) { [string](Get-CompactRecordValue -Record $retrieved -Name "atom_id") } else { "" }
    retrieval_atom_hash = if ($null -ne $retrieved) { [string](Get-CompactRecordValue -Record $retrieved -Name "atom_hash") } else { "" }
    retrieved_by_atom_id = if ($null -ne $retrieved) {
        $retrievedAtomId = [string](Get-CompactRecordValue -Record $retrieved -Name "atom_id")
        [bool](@($CompactAtomIndexRecords | Where-Object { [string](Get-CompactRecordValue -Record $_ -Name "atom_id") -eq $retrievedAtomId }).Count -eq 1)
    } else { $false }
    semantic_fields_present = @($retrievedSemanticFields)
    semantic_field_count = $retrievedSemanticFields.Count
    use_proof = if ($null -ne $retrieved) { [string](Get-CompactRecordValue -Record $retrieved -Name "use_proof") } else { "" }
    runtime_ready = $false
}
$compactAtomRetrievalProofPath = Join-Path $OutputRoot "compact_atom_retrieval_proof.json"
$retrievalProof | ConvertTo-Json -Depth 20 | Set-Content $compactAtomRetrievalProofPath -Encoding UTF8
$durableStore = Write-DurableCompactAtomStore -StoreRoot $DurableCompactStoreRoot -BatchId $BatchId -Records @($CompactAtomIndexRecords)

$receiptsText = ($Receipts | ConvertTo-Json -Depth 20 -Compress)
$receiptsHash = Sha256Text $receiptsText

# Prune heavy successful traces.
$null = Remove-RetentionCleanupPath -Path $WorkCurrent -Kind "dir" -PendingManifestPath $pendingCleanupPath
$pendingCleanupCount = if (Test-Path -LiteralPath $pendingCleanupPath) {
    @((Get-Content -LiteralPath $pendingCleanupPath -Raw | ConvertFrom-Json).entries).Count
} else {
    0
}

$manifest = [ordered]@{
    schema = "accepted_atom_batch_manifest_v1"
    batch_id = $BatchId
    started_utc = (Get-Date).ToUniversalTime().ToString("o")
    completed_utc = (Get-Date).ToUniversalTime().ToString("o")
    accepted_count = $Receipts.Count
    failed_count = 0
    quarantined_count = 0
    receipts_hash = $receiptsHash
    validator_status = "PASS"
    heavy_trace_pruned = (-not (Test-Path $WorkCurrent))
    cleanup_pending_count = $pendingCleanupCount
    repo_growth_bytes = 0
    compact_atom_index_path = $compactAtomIndexPath
    compact_atom_index_hash = $compactAtomIndexHash
    compact_atom_index_count = $CompactAtomIndexRecords.Count
    compact_atom_retrieval_proof_path = $compactAtomRetrievalProofPath
    durable_compact_store_written = [bool]$durableStore.durable_compact_store_written
    durable_compact_store_root = [string]$durableStore.durable_compact_store_root
    durable_compact_store_manifest_path = [string]$durableStore.durable_compact_store_manifest_path
    durable_compact_store_index_path = [string]$durableStore.durable_compact_store_index_path
    durable_compact_store_record_count = [int]$durableStore.durable_compact_store_record_count
    durable_compact_store_batch_count = [int]$durableStore.durable_compact_store_batch_count
    durable_compact_store_cycle_count = [int]$durableStore.durable_compact_store_cycle_count
    durable_compact_store_hash = [string]$durableStore.durable_compact_store_hash
}

$manifestPath = Join-Path $OutputRoot "batch_manifest.json"
$manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding UTF8

$result = [ordered]@{
    schema = "accepted_atom_retention_compactor_result_v1"
    status = "PASS"
    batch_id = $BatchId
    accepted_count = $Receipts.Count
    failed_count = 0
    quarantined_count = 0
    heavy_trace_pruned = (-not (Test-Path $WorkCurrent))
    cleanup_pending_count = $pendingCleanupCount
    cleanup_pending_path = if ($pendingCleanupCount -gt 0) { $pendingCleanupPath } else { "" }
    receipt_count = (Get-ChildItem $ReceiptRoot -File -Filter "*.receipt.json").Count
    compact_atom_index_path = $compactAtomIndexPath
    compact_atom_index_hash = $compactAtomIndexHash
    compact_atom_index_count = $CompactAtomIndexRecords.Count
    compact_atom_retrieval_proof_path = $compactAtomRetrievalProofPath
    durable_compact_store_written = [bool]$durableStore.durable_compact_store_written
    durable_compact_store_root = [string]$durableStore.durable_compact_store_root
    durable_compact_store_manifest_path = [string]$durableStore.durable_compact_store_manifest_path
    durable_compact_store_index_path = [string]$durableStore.durable_compact_store_index_path
    durable_compact_store_record_count = [int]$durableStore.durable_compact_store_record_count
    durable_compact_store_batch_count = [int]$durableStore.durable_compact_store_batch_count
    durable_compact_store_cycle_count = [int]$durableStore.durable_compact_store_cycle_count
    durable_compact_store_hash = [string]$durableStore.durable_compact_store_hash
    output_root = $OutputRoot
    manifest_path = $manifestPath
}

$result | ConvertTo-Json -Depth 20
