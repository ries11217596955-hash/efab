param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

$RuntimeRoot = Join-Path $RepoRoot ".runtime\body_self_inspection_v1"
$InvokerPath = Join-Path $RepoRoot "operations\body_self_inspection\invoke_body_self_inspection_slice_d_v1.ps1"
$TrackedProofPath = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_D_V1_PROOF.json"

function New-BodyInspectionBoundary {
    return @{
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

function Write-JsonFile {
    param(
        [string]$Path,
        $Data
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $json = ($Data | ConvertTo-Json -Depth 80) -replace "`r`n", "`n"
    $json = $json.TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Test-HasProperty {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $false
    }
    if ($Object -is [System.Collections.IDictionary]) {
        return $Object.Contains($Name)
    }
    return (@($Object.PSObject.Properties.Name) -contains $Name)
}

function ConvertTo-ItemArray {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [string]) {
        if ($Value.Trim() -eq "") {
            return @()
        }
        return @($Value)
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value)
    }
    return @($Value)
}

function Test-BoundaryFalse {
    param(
        $Object,
        [string]$Flag
    )

    $boundary = Get-PropertyValue -Object $Object -Name "boundary"
    if ($null -eq $boundary) {
        return $false
    }
    if (-not (Test-HasProperty -Object $boundary -Name $Flag)) {
        return $false
    }
    $value = Get-PropertyValue -Object $boundary -Name $Flag
    return ($value -eq $false -or [string]$value -eq "False")
}

function Test-ClaimFalse {
    param(
        $Object,
        [string]$Flag
    )

    $claims = Get-PropertyValue -Object $Object -Name "boundary_claims"
    if ($null -eq $claims) {
        return $false
    }
    if (-not (Test-HasProperty -Object $claims -Name $Flag)) {
        return $false
    }
    $value = Get-PropertyValue -Object $claims -Name $Flag
    return ($value -eq $false -or [string]$value -eq "False")
}

function Add-Failure {
    param([string]$Message)
    $script:Failures += $Message
}

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message
    )

    $script:Checks += @{
        name = $Name
        passed = $Passed
        message = $Message
    }
    if (-not $Passed) {
        Add-Failure -Message $Message
    }
}

function Get-GitStatusLines {
    param([string]$Root)

    $output = & git -C $Root status --short --untracked-files=all
    if ($LASTEXITCODE -ne 0) {
        return @("GIT_STATUS_FAILED")
    }
    return @($output)
}

function Get-StatusPath {
    param([string]$Line)

    if (-not $Line -or $Line.Length -lt 4) {
        return ""
    }
    return ($Line.Substring(3) -replace "\\", "/")
}

function Test-StatusHasForbiddenMutation {
    param([array]$StatusLines)

    foreach ($line in @($StatusLines)) {
        $path = Get-StatusPath -Line ([string]$line)
        if (-not $path) {
            continue
        }
        if ($path -in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json")) {
            return $true
        }
        if ($path -like "contracts/*") {
            return $true
        }
        if ($path -like "accepted-core/*" -or $path -like "accepted_core/*") {
            return $true
        }
        if ($path -like ".runtime/active_compact_semantic_memory_v1*") {
            return $true
        }
        if ($path -like "operations/autonomous_inner_motor/*" -or $path -like "operations/reasoning/*" -or $path -like "operations/school/*") {
            return $true
        }
    }
    return $false
}

function Test-RecordFields {
    param(
        $Record,
        [string[]]$Fields
    )

    foreach ($field in @($Fields)) {
        if (-not (Test-HasProperty -Object $Record -Name $field)) {
            return $false
        }
    }
    return $true
}

$Failures = @()
$Checks = @()
$Blocked = $false
$OutputRefs = @{
    repo_inventory = Join-Path $RuntimeRoot "repo_inventory.json"
    body_map_read = Join-Path $RuntimeRoot "body_map_read.json"
    capability_map_read = Join-Path $RuntimeRoot "capability_map_read.json"
    organ_candidates = Join-Path $RuntimeRoot "organ_candidates.json"
    organ_similarity_index = Join-Path $RuntimeRoot "organ_similarity_index.json"
    passport_audit = Join-Path $RuntimeRoot "passport_audit.json"
    signal_readiness_audit = Join-Path $RuntimeRoot "signal_readiness_audit.json"
    slice_a_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"
    slice_b_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_B_PROOF.json"
    slice_c_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_C_PROOF.json"
    body_reconciliation = Join-Path $RuntimeRoot "body_reconciliation.json"
    runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_D_PROOF.json"
}

$gitStatusBeforeInvoker = Get-GitStatusLines -Root $RepoRoot

try {
    if (-not (Test-Path -LiteralPath $InvokerPath)) {
        $Blocked = $true
        throw "Missing invoker: $InvokerPath"
    }
    & $InvokerPath -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
} catch {
    $Blocked = $true
    Add-Failure -Message ("Invoker failed: " + $_.Exception.Message)
}

$gitStatusAfterInvoker = Get-GitStatusLines -Root $RepoRoot

$repoInventory = $null
$bodyMap = $null
$capabilityMap = $null
$candidates = $null
$similarity = $null
$passportAudit = $null
$signalAudit = $null
$sliceAProof = $null
$sliceBProof = $null
$sliceCProof = $null
$reconciliation = $null
$runtimeProof = $null

foreach ($entry in @(
    @{ name = "repo_inventory"; var = "repoInventory"; path = $OutputRefs.repo_inventory },
    @{ name = "body_map_read"; var = "bodyMap"; path = $OutputRefs.body_map_read },
    @{ name = "capability_map_read"; var = "capabilityMap"; path = $OutputRefs.capability_map_read },
    @{ name = "organ_candidates"; var = "candidates"; path = $OutputRefs.organ_candidates },
    @{ name = "organ_similarity_index"; var = "similarity"; path = $OutputRefs.organ_similarity_index },
    @{ name = "passport_audit"; var = "passportAudit"; path = $OutputRefs.passport_audit },
    @{ name = "signal_readiness_audit"; var = "signalAudit"; path = $OutputRefs.signal_readiness_audit },
    @{ name = "slice_a_runtime_proof"; var = "sliceAProof"; path = $OutputRefs.slice_a_runtime_proof },
    @{ name = "slice_b_runtime_proof"; var = "sliceBProof"; path = $OutputRefs.slice_b_runtime_proof },
    @{ name = "slice_c_runtime_proof"; var = "sliceCProof"; path = $OutputRefs.slice_c_runtime_proof },
    @{ name = "body_reconciliation"; var = "reconciliation"; path = $OutputRefs.body_reconciliation },
    @{ name = "runtime_proof"; var = "runtimeProof"; path = $OutputRefs.runtime_proof }
)) {
    $entryName = [string]$entry["name"]
    $entryVar = [string]$entry["var"]
    $entryPath = [string]$entry["path"]
    try {
        $parsed = Read-JsonFile -Path $entryPath
        Set-Variable -Name $entryVar -Value $parsed
        Add-Check -Name ($entryName + "_parses") -Passed $true -Message ($entryName + " exists and parses")
    } catch {
        Add-Check -Name ($entryName + "_parses") -Passed $false -Message $_.Exception.Message
    }
}

if ($sliceAProof) {
    Add-Check -Name "slice_a_runtime_status_pass" -Passed ($sliceAProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_A_RUNTIME_V1") -Message "Slice A runtime proof status must be PASS"
}
if ($sliceBProof) {
    Add-Check -Name "slice_b_runtime_status_pass" -Passed ($sliceBProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_B_RUNTIME_V1") -Message "Slice B runtime proof status must be PASS"
}
if ($sliceCProof) {
    Add-Check -Name "slice_c_runtime_status_pass" -Passed ($sliceCProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_C_RUNTIME_V1") -Message "Slice C runtime proof status must be PASS"
}
if ($runtimeProof) {
    Add-Check -Name "slice_d_runtime_status_pass" -Passed ($runtimeProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_D_RUNTIME_V1") -Message "Slice D runtime proof status must be PASS"
}

if ($reconciliation) {
    Add-Check -Name "reconciliation_status_pass" -Passed ($reconciliation.status -eq "PASS_BODY_RECONCILIATION_V1") -Message "body reconciliation status must be PASS_BODY_RECONCILIATION_V1"

    $topFields = @("schema", "status", "version", "generated_at", "repo_root", "input_refs", "reconciliation_records", "discrepancy_records", "reference_status_index", "aggregates", "boundary_claims", "boundary")
    foreach ($field in $topFields) {
        Add-Check -Name ("top_field_" + $field) -Passed (Test-HasProperty -Object $reconciliation -Name $field) -Message ("body_reconciliation top-level field exists: " + $field)
    }

    Add-Check -Name "reconciliation_records_exist" -Passed (@($reconciliation.reconciliation_records).Count -gt 0) -Message "reconciliation records exist"
    Add-Check -Name "reference_status_index_exists" -Passed (@($reconciliation.reference_status_index).Count -gt 0) -Message "reference status index exists"

    $passportPainCount = 0
    if ($passportAudit -and (Test-HasProperty -Object $passportAudit -Name "aggregates")) {
        $passportPainCount = [int](Get-PropertyValue -Object $passportAudit.aggregates -Name "pain_candidate_count")
    }
    $signalPainCount = 0
    if ($signalAudit -and (Test-HasProperty -Object $signalAudit -Name "aggregates")) {
        $signalPainCount = [int](Get-PropertyValue -Object $signalAudit.aggregates -Name "pain_candidate_count")
    }
    Add-Check -Name "discrepancy_records_exist_when_audits_report_gaps" -Passed (($passportPainCount + $signalPainCount -eq 0) -or @($reconciliation.discrepancy_records).Count -gt 0) -Message "discrepancy records exist when prior audits provide missing evidence"

    $reconciliationFields = @(
        "reconciliation_id",
        "subject_id",
        "subject_kind",
        "subject_name",
        "source_refs",
        "evidence_refs",
        "declared_in_map",
        "present_in_repo",
        "candidate_detected",
        "passport_audited",
        "signal_audited",
        "validator_backed",
        "proof_backed",
        "similarity_statuses",
        "reference_statuses",
        "maturity_boundary",
        "evidence_status",
        "confidence",
        "recommended_next_cell",
        "forbidden_now"
    )
    $recordFieldsOk = $true
    $recordRefsOk = $true
    $recordForbiddenOk = $true
    $candidatePromoted = $false
    $matureClaimed = $false
    foreach ($record in @($reconciliation.reconciliation_records)) {
        if (-not (Test-RecordFields -Record $record -Fields $reconciliationFields)) {
            $recordFieldsOk = $false
        }
        if (@(ConvertTo-ItemArray -Value $record.source_refs).Count -eq 0 -or @(ConvertTo-ItemArray -Value $record.evidence_refs).Count -eq 0) {
            $recordRefsOk = $false
        }
        if (@(ConvertTo-ItemArray -Value $record.forbidden_now).Count -eq 0) {
            $recordForbiddenOk = $false
        }
        if ($record.candidate_detected -eq $true -and [string]$record.subject_kind -eq "ORGAN") {
            $candidatePromoted = $true
        }
        $mature = Get-PropertyValue -Object $record.maturity_boundary -Name "mature_claimed"
        if ($mature -eq $true -or [string]$mature -eq "True") {
            $matureClaimed = $true
        }
    }
    Add-Check -Name "reconciliation_record_required_fields" -Passed $recordFieldsOk -Message "reconciliation records include required fields"
    Add-Check -Name "reconciliation_records_have_source_and_evidence_refs" -Passed $recordRefsOk -Message "reconciliation records include source_refs and evidence_refs"
    Add-Check -Name "reconciliation_records_have_forbidden_now" -Passed $recordForbiddenOk -Message "reconciliation records include forbidden_now"
    Add-Check -Name "candidate_not_promoted_to_organ" -Passed (-not $candidatePromoted) -Message "Slice D does not promote candidates to organs"
    Add-Check -Name "validated_not_treated_as_mature" -Passed (-not $matureClaimed) -Message "maturity boundary does not claim mature organ"

    $discrepancyFields = @("discrepancy_id", "subject_id", "discrepancy_type", "severity", "source_refs", "evidence_refs", "explanation", "recommended_next_cell", "forbidden_now")
    $allowedTypes = @("DECLARED_NOT_FOUND_IN_REPO", "PRESENT_NOT_DECLARED", "CANDIDATE_WITHOUT_PASSPORT", "CANDIDATE_WITHOUT_CONTRACT", "CANDIDATE_WITHOUT_VALIDATOR", "CANDIDATE_WITHOUT_PROOF", "CANDIDATE_WITHOUT_SIGNAL", "PASSPORT_WITHOUT_CONTRACT", "CONTRACT_WITHOUT_PASSPORT", "SIGNAL_CONTRACT_WITHOUT_VALIDATOR", "SIGNAL_VALIDATOR_WITHOUT_CONTRACT", "POSSIBLE_DUPLICATE_NEEDS_REVIEW", "FUNCTIONAL_OVERLAP_NEEDS_REVIEW", "BROKEN_REFERENCE", "STALE_REFERENCE", "MAP_DECLARATION_AMBIGUOUS", "UNKNOWN_RECONCILIATION_GAP")
    $allowedSeverity = @("INFO", "LOW", "MEDIUM", "HIGH", "BLOCKER_CANDIDATE")
    $allowedNext = @("BODY_PAIN_REGISTER", "REPAIR_DRAFT_BOARD", "NEXT_LOGIC_QUEUE", "PASSPORT_AUDIT", "SIGNAL_READINESS_AUDIT", "ORGAN_SIMILARITY_REVIEW", "MAP_REFRESH_REVIEW", "HUMAN_REVIEW", "NONE")
    $discrepancyFieldsOk = $true
    $discrepancyRefsOk = $true
    $discrepancyForbiddenOk = $true
    $discrepancyTypeOk = $true
    $severityOk = $true
    $nextCellOk = $true
    $repairDraftFieldsFound = $false
    foreach ($record in @($reconciliation.discrepancy_records)) {
        if (-not (Test-RecordFields -Record $record -Fields $discrepancyFields)) {
            $discrepancyFieldsOk = $false
        }
        if (@(ConvertTo-ItemArray -Value $record.source_refs).Count -eq 0 -or @(ConvertTo-ItemArray -Value $record.evidence_refs).Count -eq 0) {
            $discrepancyRefsOk = $false
        }
        if (@(ConvertTo-ItemArray -Value $record.forbidden_now).Count -eq 0) {
            $discrepancyForbiddenOk = $false
        }
        if ($allowedTypes -notcontains [string]$record.discrepancy_type) {
            $discrepancyTypeOk = $false
        }
        if ($allowedSeverity -notcontains [string]$record.severity) {
            $severityOk = $false
        }
        if ($allowedNext -notcontains [string]$record.recommended_next_cell) {
            $nextCellOk = $false
        }
        if (Test-HasProperty -Object $record -Name "repair_draft_id") {
            $repairDraftFieldsFound = $true
        }
    }
    Add-Check -Name "discrepancy_record_required_fields" -Passed $discrepancyFieldsOk -Message "discrepancy records include required fields"
    Add-Check -Name "discrepancy_records_have_source_and_evidence_refs" -Passed $discrepancyRefsOk -Message "discrepancy records include source_refs and evidence_refs"
    Add-Check -Name "discrepancy_records_have_forbidden_now" -Passed $discrepancyForbiddenOk -Message "discrepancy records include forbidden_now"
    Add-Check -Name "discrepancy_types_allowed" -Passed $discrepancyTypeOk -Message "discrepancy_type values are allowed"
    Add-Check -Name "discrepancy_severity_allowed" -Passed $severityOk -Message "severity values are allowed"
    Add-Check -Name "recommended_next_cells_allowed" -Passed $nextCellOk -Message "recommended next cells only point to allowed cells"
    Add-Check -Name "discrepancies_not_repair_drafts" -Passed (-not $repairDraftFieldsFound) -Message "discrepancy records are not repair drafts"

    $referenceFields = @("ref", "ref_kind", "status", "discovered_from", "evidence_refs")
    $allowedRefStatus = @("REF_PRESENT", "REF_MISSING", "REF_PARSE_FAILED", "REF_DECLARED_ONLY", "REF_RUNTIME_ONLY", "REF_UNKNOWN")
    $referenceFieldsOk = $true
    $referenceStatusOk = $true
    $referenceEvidenceOk = $true
    foreach ($entry in @($reconciliation.reference_status_index)) {
        if (-not (Test-RecordFields -Record $entry -Fields $referenceFields)) {
            $referenceFieldsOk = $false
        }
        if ($allowedRefStatus -notcontains [string]$entry.status) {
            $referenceStatusOk = $false
        }
        if (@(ConvertTo-ItemArray -Value $entry.evidence_refs).Count -eq 0) {
            $referenceEvidenceOk = $false
        }
    }
    Add-Check -Name "reference_status_index_required_fields" -Passed $referenceFieldsOk -Message "reference status index entries include required fields"
    Add-Check -Name "reference_status_values_allowed" -Passed $referenceStatusOk -Message "reference status values are allowed"
    Add-Check -Name "reference_status_entries_have_evidence_refs" -Passed $referenceEvidenceOk -Message "reference status entries include evidence_refs"

    foreach ($claim in @(
        "declared_treated_as_present",
        "present_treated_as_validated",
        "validated_treated_as_mature",
        "similarity_treated_as_duplicate_proof",
        "audit_record_treated_as_pain_register",
        "discrepancy_treated_as_repair_draft",
        "candidate_promoted_to_organ",
        "body_pain_register_implemented",
        "repair_draft_board_implemented",
        "next_logic_queue_implemented"
    )) {
        Add-Check -Name ("boundary_claim_false_" + $claim) -Passed (Test-ClaimFalse -Object $reconciliation -Flag $claim) -Message ("boundary claim is false: " + $claim)
    }
}

if ($runtimeProof) {
    foreach ($claim in @(
        "declared_treated_as_present",
        "present_treated_as_validated",
        "validated_treated_as_mature",
        "similarity_treated_as_duplicate_proof",
        "audit_record_treated_as_pain_register",
        "discrepancy_treated_as_repair_draft",
        "candidate_promoted_to_organ"
    )) {
        Add-Check -Name ("runtime_boundary_claim_false_" + $claim) -Passed (Test-ClaimFalse -Object $runtimeProof -Flag $claim) -Message ("runtime proof boundary claim is false: " + $claim)
    }
}

Add-Check -Name "no_tracked_map_passport_contract_mutation" -Passed (-not (Test-StatusHasForbiddenMutation -StatusLines $gitStatusAfterInvoker)) -Message "no tracked map/passport/contract/active-memory/accepted-core/live-script mutation observed"

$objectsWithBoundaries = @(
    @{ name = "body_reconciliation"; value = $reconciliation },
    @{ name = "runtime_proof"; value = $runtimeProof }
)
$boundaryFlags = @(
    "repo_mutated",
    "active_memory_mutated",
    "accepted_core_mutated",
    "body_map_mutated",
    "capability_map_mutated",
    "passports_mutated",
    "contracts_mutated",
    "live_process_touched",
    "codex_launched",
    "web_launched",
    "cleanup_performed"
)

foreach ($entry in @($objectsWithBoundaries)) {
    foreach ($flag in @($boundaryFlags)) {
        Add-Check -Name ("boundary_" + $entry["name"] + "_" + $flag) -Passed (Test-BoundaryFalse -Object $entry["value"] -Flag $flag) -Message ($entry["name"] + " boundary flag is false: " + $flag)
    }
}

$negativeResults = @(
    @{
        name = "candidate_is_not_promoted_to_organ"
        passed = ($Failures -notcontains "Slice D does not promote candidates to organs")
        evidence = "candidate_detected records checked for subject_kind ORGAN"
    },
    @{
        name = "declared_not_treated_as_present"
        passed = $(if ($reconciliation) { Test-ClaimFalse -Object $reconciliation -Flag "declared_treated_as_present" } else { $false })
        evidence = "boundary_claims.declared_treated_as_present"
    },
    @{
        name = "present_not_treated_as_validated"
        passed = $(if ($reconciliation) { Test-ClaimFalse -Object $reconciliation -Flag "present_treated_as_validated" } else { $false })
        evidence = "boundary_claims.present_treated_as_validated"
    },
    @{
        name = "validated_not_treated_as_mature"
        passed = $(if ($reconciliation) { Test-ClaimFalse -Object $reconciliation -Flag "validated_treated_as_mature" } else { $false })
        evidence = "boundary_claims.validated_treated_as_mature"
    },
    @{
        name = "similarity_not_duplicate_proof"
        passed = $(if ($reconciliation) { Test-ClaimFalse -Object $reconciliation -Flag "similarity_treated_as_duplicate_proof" } else { $false })
        evidence = "boundary_claims.similarity_treated_as_duplicate_proof"
    },
    @{
        name = "discrepancy_not_repair_draft"
        passed = $(if ($reconciliation) { Test-ClaimFalse -Object $reconciliation -Flag "discrepancy_treated_as_repair_draft" } else { $false })
        evidence = "boundary_claims.discrepancy_treated_as_repair_draft"
    }
)

$status = "PASS_BODY_SELF_INSPECTION_SLICE_D_V1"
if ($Failures.Count -gt 0) {
    $status = "FAIL_BODY_SELF_INSPECTION_SLICE_D_V1"
}
if ($Blocked) {
    $status = "BLOCKED_BODY_SELF_INSPECTION_SLICE_D_V1"
}

$proof = @{
    schema = "body_self_inspection_slice_d_validator_proof_v1"
    status = $status
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    validator_ref = "validators/validate_body_self_inspection_slice_d_v1.ps1"
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "D"
    output_refs = $OutputRefs
    validator_checks = $Checks
    negative_test_results = $negativeResults
    git_status_before_invoker = @($gitStatusBeforeInvoker)
    git_status_after_invoker = @($gitStatusAfterInvoker)
    aggregate_counts = @{
        body_reconciliation = $(if ($reconciliation) { $reconciliation.aggregates } else { $null })
    }
    boundary = New-BodyInspectionBoundary
    errors = $Failures
}

Write-JsonFile -Path $TrackedProofPath -Data $proof

if ($Failures.Count -gt 0) {
    Write-Output ("STATUS=" + $status)
    foreach ($failure in @($Failures)) {
        Write-Output ("FAIL=" + $failure)
    }
    exit 1
}

Write-Output ("STATUS=" + $status)
Write-Output ("PROOF=" + $TrackedProofPath)
exit 0
