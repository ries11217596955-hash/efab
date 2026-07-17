param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$RuntimeRoot = ".runtime/body_self_inspection_v1"
)

$ErrorActionPreference = "Stop"

function Write-JsonFile {
    param([string]$Path, $Data)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = ($Data | ConvertTo-Json -Depth 30) -replace "`r`n", "`n"
    $json = $json.TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_INPUT: $Path" }
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Items($Value) {
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { if ($Value.Trim() -eq "") { return @() }; return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value) }
    return @($Value)
}

function Prop($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Normalize-Ref([string]$Ref) {
    if (-not $Ref) { return "" }
    $v = $Ref.Trim() -replace "\\", "/"
    return $v.TrimStart("./")
}

function Add-Unique([array]$Array, $Value) {
    $v = Normalize-Ref ([string]$Value)
    if ($v -eq "") { return @($Array) }
    if (@($Array) -notcontains $v) { return @($Array) + $v }
    return @($Array)
}

function New-Boundary {
    [ordered]@{
        repo_mutated = $false
        active_memory_mutated = $false
        accepted_core_mutated = $false
        body_map_mutated = $false
        capability_map_mutated = $false
        passports_mutated = $false
        contracts_mutated = $false
        live_process_touched = $false
        codex_launched = $false
        web_launched = $false
        cleanup_performed = $false
    }
}

function StableId([string]$Prefix, [string]$Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hashBytes = $sha.ComputeHash($bytes)
        $hex = ([System.BitConverter]::ToString($hashBytes) -replace "-", "").Substring(0, 16).ToLowerInvariant()
        return "$Prefix-$hex"
    } finally { $sha.Dispose() }
}

function Ensure-Subject([string]$Id, [string]$Kind, [string]$Name) {
    if (-not $script:Subjects.ContainsKey($Id)) {
        $script:Subjects[$Id] = [ordered]@{
            reconciliation_id = StableId "REC" $Id
            subject_id = $Id
            subject_kind = $Kind
            subject_name = $Name
            source_refs = @($Id)
            evidence_refs = @($Id)
            declared_in_map = $false
            present_in_repo = $false
            candidate_detected = $false
            passport_audited = $false
            signal_audited = $false
            validator_backed = $false
            proof_backed = $false
            similarity_statuses = @()
            reference_statuses = @()
            maturity_boundary = [ordered]@{
                declared_is_present = $false
                present_is_validated = $false
                validated_is_mature = $false
                similar_is_duplicate_proof = $false
                discrepancy_is_repair_draft = $false
            }
            evidence_status = "RECONCILED_CANDIDATE_NOT_MATURE"
            confidence = "MEDIUM"
            recommended_next_cell = "NONE"
            forbidden_now = @(
                "DO_NOT_PROMOTE_CANDIDATE_TO_ORGAN",
                "DO_NOT_TREAT_RECONCILIATION_AS_REPAIR_DRAFT",
                "DO_NOT_TREAT_SIMILARITY_AS_DUPLICATE_PROOF"
            )
        }
    }
    return $script:Subjects[$Id]
}

function Add-Reference([string]$Ref, [string]$Kind, [string]$From) {
    $r = Normalize-Ref $Ref
    if ($r -eq "") { return }
    $key = ($Kind + "|" + $r).ToLowerInvariant()
    if (-not $script:ReferenceIndex.ContainsKey($key)) {
        $exists = Test-Path -LiteralPath (Join-Path $RepoRoot ($r -replace "/", "\"))
        $status = if ($exists) { "REF_PRESENT" } elseif ($r -like ".runtime/*") { "REF_RUNTIME_ONLY" } elseif ($r -match "[/.]") { "REF_MISSING" } else { "REF_DECLARED_ONLY" }
        $script:ReferenceIndex[$key] = [ordered]@{
            ref = $r
            ref_kind = $Kind
            status = $status
            discovered_from = @($From)
            evidence_refs = @($From)
        }
    }
}

function Add-Discrepancy($Subject, [string]$Type, [string]$Severity, [string]$Explanation, [string]$NextCell, [array]$EvidenceRefs) {
    $script:Discrepancies += [ordered]@{
        discrepancy_id = StableId "DISC" ($Type + "|" + $Subject.subject_id)
        subject_id = $Subject.subject_id
        discrepancy_type = $Type
        severity = $Severity
        source_refs = @($Subject.source_refs)
        evidence_refs = @($EvidenceRefs + $Subject.evidence_refs + $Subject.source_refs + $Subject.subject_id | Where-Object { $_ } | Select-Object -Unique)
        explanation = $Explanation
        recommended_next_cell = $NextCell
        forbidden_now = @("DO_NOT_TREAT_DISCREPANCY_AS_REPAIR_DRAFT", "DO_NOT_AUTO_REPAIR", "DO_NOT_PROMOTE_TO_ORGAN")
    }
}

if ([System.IO.Path]::IsPathRooted($RuntimeRoot)) {
    $RuntimeRootPath = $RuntimeRoot
} else {
    $RuntimeRootPath = Join-Path $RepoRoot ($RuntimeRoot -replace "/", "\")
}
New-Item -ItemType Directory -Force -Path $RuntimeRootPath | Out-Null
$paths = [ordered]@{
    repo_inventory = Join-Path $RuntimeRootPath "repo_inventory.json"
    body_map_read = Join-Path $RuntimeRootPath "body_map_read.json"
    capability_map_read = Join-Path $RuntimeRootPath "capability_map_read.json"
    organ_candidates = Join-Path $RuntimeRootPath "organ_candidates.json"
    organ_similarity_index = Join-Path $RuntimeRootPath "organ_similarity_index.json"
    passport_audit = Join-Path $RuntimeRootPath "passport_audit.json"
    signal_readiness_audit = Join-Path $RuntimeRootPath "signal_readiness_audit.json"
}

$inventory = Read-JsonFile $paths.repo_inventory
$bodyMap = Read-JsonFile $paths.body_map_read
$capabilityMap = Read-JsonFile $paths.capability_map_read
$candidates = Read-JsonFile $paths.organ_candidates
$similarity = Read-JsonFile $paths.organ_similarity_index
$passportAudit = Read-JsonFile $paths.passport_audit
$signalAudit = Read-JsonFile $paths.signal_readiness_audit

$script:Subjects = @{}
$script:ReferenceIndex = @{}
$script:Discrepancies = @()

foreach ($rec in @(Items (Prop $inventory "records") | Select-Object -First 1200)) {
    $path = [string](Prop $rec "normalized_path")
    if (-not $path) { $path = [string](Prop $rec "path") }
    if (-not $path) { continue }
    Add-Reference $path "repo_inventory_record" "repo_inventory"
}

foreach ($map in @((Items (Prop $bodyMap "map_records")) + (Items (Prop $capabilityMap "map_records")) | Select-Object -First 400)) {
    $mapPath = [string](Prop $map "path")
    Add-Reference $mapPath "map_record" "map_reader"
    foreach ($decl in @(Items (Prop $map "declared_organs") | Select-Object -First 80)) {
        $id = "declared:" + ([string]$decl).ToLowerInvariant()
        $s = Ensure-Subject $id "MAP_DECLARATION" ([string]$decl)
        $s.declared_in_map = $true
        $s.source_refs = Add-Unique $s.source_refs $mapPath
        $s.evidence_refs = Add-Unique $s.evidence_refs $mapPath
        $s.reference_statuses = Add-Unique $s.reference_statuses "REF_DECLARED_ONLY"
        $s.recommended_next_cell = "MAP_REFRESH_REVIEW"
    }
    foreach ($decl in @(Items (Prop $map "declared_capabilities") | Select-Object -First 80)) {
        $id = "capability:" + ([string]$decl).ToLowerInvariant()
        $s = Ensure-Subject $id "CAPABILITY_DECLARATION" ([string]$decl)
        $s.declared_in_map = $true
        $s.source_refs = Add-Unique $s.source_refs $mapPath
        $s.evidence_refs = Add-Unique $s.evidence_refs $mapPath
        $s.reference_statuses = Add-Unique $s.reference_statuses "REF_DECLARED_ONLY"
    }
}

foreach ($cand in @(Items (Prop $candidates "candidates") | Select-Object -First 800)) {
    $id = [string](Prop $cand "candidate_id")
    if (-not $id) { $id = StableId "CAND" ([string](Prop $cand "primary_path")) }
    $name = [string](Prop $cand "name_guess")
    if (-not $name) { $name = [string](Prop $cand "primary_path") }
    $s = Ensure-Subject $id "ORGAN_CANDIDATE" $name
    $s.present_in_repo = $true
    $s.candidate_detected = $true
    $s.confidence = [string](Prop $cand "confidence")
    $s.source_refs = Add-Unique $s.source_refs (Prop $cand "primary_path")
    $s.evidence_refs = Add-Unique $s.evidence_refs (Prop $cand "primary_path")
    foreach ($r in @(Items (Prop $cand "related_paths") | Select-Object -First 30)) { $s.source_refs = Add-Unique $s.source_refs $r; $s.evidence_refs = Add-Unique $s.evidence_refs $r; Add-Reference $r "candidate_related_path" $id }
    foreach ($r in @(Items (Prop $cand "evidence_refs") | Select-Object -First 30)) { $s.source_refs = Add-Unique $s.source_refs $r; $s.evidence_refs = Add-Unique $s.evidence_refs $r; Add-Reference $r "candidate_evidence" $id }
}

foreach ($pa in @(Items (Prop $passportAudit "audit_records") | Select-Object -First 1400)) {
    $id = [string](Prop $pa "target_id")
    if (-not $id) { continue }
    $s = Ensure-Subject $id "AUDITED_TARGET" $id
    $s.passport_audited = $true
    $s.source_refs = Add-Unique $s.source_refs $id
    $s.evidence_refs = Add-Unique $s.evidence_refs $id
    if ([string](Prop $pa "validator_status") -match "PRESENT|VALIDATED") { $s.validator_backed = $true }
    if ([string](Prop $pa "proof_status") -match "PRESENT|VALIDATED") { $s.proof_backed = $true }
    foreach ($r in @(Items (Prop $pa "evidence_refs") | Select-Object -First 20)) { $s.source_refs = Add-Unique $s.source_refs $r; $s.evidence_refs = Add-Unique $s.evidence_refs $r; Add-Reference $r "passport_audit_evidence" $id }
    $passportStatus = [string](Prop $pa "passport_status")
    $contractStatus = [string](Prop $pa "contract_status")
    if ($passportStatus -match "MISSING") { $s.recommended_next_cell = "BODY_PAIN_REGISTER"; Add-Discrepancy $s "CANDIDATE_WITHOUT_PASSPORT" "MEDIUM" "Passport audit reports missing passport evidence." "BODY_PAIN_REGISTER" @($id) }
    if ($contractStatus -match "MISSING") { $s.recommended_next_cell = "BODY_PAIN_REGISTER"; Add-Discrepancy $s "CANDIDATE_WITHOUT_CONTRACT" "MEDIUM" "Passport audit reports missing contract evidence." "BODY_PAIN_REGISTER" @($id) }
    if ([string](Prop $pa "validator_status") -match "MISSING") { Add-Discrepancy $s "CANDIDATE_WITHOUT_VALIDATOR" "MEDIUM" "Passport audit reports missing validator evidence." "BODY_PAIN_REGISTER" @($id) }
    if ([string](Prop $pa "proof_status") -match "MISSING|BROKEN") { Add-Discrepancy $s "CANDIDATE_WITHOUT_PROOF" "MEDIUM" "Passport audit reports missing/broken proof evidence." "BODY_PAIN_REGISTER" @($id) }
}

foreach ($sa in @(Items (Prop $signalAudit "signal_audit_records") | Select-Object -First 1400)) {
    $id = [string](Prop $sa "target_id")
    if (-not $id) { continue }
    $s = Ensure-Subject $id "SIGNAL_AUDITED_TARGET" $id
    $s.signal_audited = $true
    $s.source_refs = Add-Unique $s.source_refs $id
    $s.evidence_refs = Add-Unique $s.evidence_refs $id
    $status = [string](Prop $sa "signal_contract_status")
    $s.reference_statuses = Add-Unique $s.reference_statuses $status
    foreach ($r in @(Items (Prop $sa "evidence_refs") | Select-Object -First 20)) { $s.source_refs = Add-Unique $s.source_refs $r; $s.evidence_refs = Add-Unique $s.evidence_refs $r; Add-Reference $r "signal_audit_evidence" $id }
    if ($status -eq "SIGNAL_MISSING") { Add-Discrepancy $s "CANDIDATE_WITHOUT_SIGNAL" "LOW" "Signal readiness audit reports missing signal contract." "BODY_PAIN_REGISTER" @($id) }
    if ($status -eq "SIGNAL_CONTRACT_WITHOUT_VALIDATOR") { Add-Discrepancy $s "SIGNAL_CONTRACT_WITHOUT_VALIDATOR" "MEDIUM" "Signal contract evidence exists without validator evidence." "SIGNAL_READINESS_AUDIT" @($id) }
    if ($status -eq "SIGNAL_VALIDATOR_WITHOUT_CONTRACT") { Add-Discrepancy $s "SIGNAL_VALIDATOR_WITHOUT_CONTRACT" "MEDIUM" "Signal validator evidence exists without contract evidence." "SIGNAL_READINESS_AUDIT" @($id) }
}

foreach ($sim in @(Items (Prop $similarity "similarity_records") | Select-Object -First 800)) {
    $status = [string](Prop $sim "similarity_status")
    foreach ($sid in @((Prop $sim "subject_a"), (Prop $sim "subject_b"))) {
        $id = [string]$sid
        if (-not $id) { continue }
        $s = Ensure-Subject $id "SIMILARITY_SUBJECT" $id
        $s.similarity_statuses = Add-Unique $s.similarity_statuses $status
        if ($status -eq "POSSIBLE_DUPLICATE") { Add-Discrepancy $s "POSSIBLE_DUPLICATE_NEEDS_REVIEW" "MEDIUM" "Similarity index flags possible duplicate; not treated as proof." "ORGAN_SIMILARITY_REVIEW" @($id) }
        if ($status -eq "FUNCTIONAL_OVERLAP") { Add-Discrepancy $s "FUNCTIONAL_OVERLAP_NEEDS_REVIEW" "MEDIUM" "Similarity index flags functional overlap; not treated as duplicate proof." "ORGAN_SIMILARITY_REVIEW" @($id) }
    }
}

$records = @($script:Subjects.Values | Sort-Object -Property subject_id)
$discrepancyRecords = @($script:Discrepancies | Sort-Object -Property discrepancy_type, subject_id | Select-Object -First 5000)
$referenceEntries = @($script:ReferenceIndex.Values | Sort-Object -Property ref_kind, ref | Select-Object -First 4000)

$discrepancyTypeCounts = @{}
$severityCounts = @{}
foreach ($d in $discrepancyRecords) {
    $t=[string]$d.discrepancy_type; $sv=[string]$d.severity
    if(-not $discrepancyTypeCounts.ContainsKey($t)){ $discrepancyTypeCounts[$t]=0 }; $discrepancyTypeCounts[$t]++
    if(-not $severityCounts.ContainsKey($sv)){ $severityCounts[$sv]=0 }; $severityCounts[$sv]++
}
$referenceStatusCounts = @{}
foreach ($r in $referenceEntries) { $st=[string]$r.status; if(-not $referenceStatusCounts.ContainsKey($st)){ $referenceStatusCounts[$st]=0 }; $referenceStatusCounts[$st]++ }

$output = [ordered]@{
    schema = "body_self_inspection_reconciliation_v1"
    status = "PASS_BODY_RECONCILIATION_V1"
    version = "1.0"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo_root = $RepoRoot
    input_refs = $paths
    reconciliation_records = $records
    discrepancy_records = $discrepancyRecords
    reference_status_index = $referenceEntries
    aggregates = [ordered]@{
        total_reconciliation_records = @($records).Count
        total_discrepancy_records = @($discrepancyRecords).Count
        reference_status_counts = $referenceStatusCounts
        discrepancy_type_counts = $discrepancyTypeCounts
        severity_counts = $severityCounts
        boundary_note = "DECLARED != PRESENT; PRESENT != VALIDATED; VALIDATED != MATURE; SIMILAR != DUPLICATE_PROVEN; DISCREPANCY != REPAIR_DRAFT"
    }
    boundary_claims = [ordered]@{
        declared_treated_as_present = $false
        present_treated_as_validated = $false
        validated_treated_as_mature = $false
        similarity_treated_as_duplicate_proof = $false
        discrepancy_treated_as_repair_draft = $false
        audit_record_treated_as_pain_register = $false
        candidate_promoted_to_organ = $false
        body_pain_register_implemented = $false
        repair_draft_board_implemented = $false
        next_logic_queue_implemented = $false
    }
    boundary = New-Boundary
}

$outPath = Join-Path $RuntimeRootPath "body_reconciliation.json"
Write-JsonFile -Path $outPath -Data $output
Write-Output $outPath
