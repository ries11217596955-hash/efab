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
$InvokerPath = Join-Path $RepoRoot "operations\body_self_inspection\invoke_body_self_inspection_slice_b_v1.ps1"
$TrackedProofPath = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_B_V1_PROOF.json"

function New-BodyInspectionBoundary {
    return @{
        repo_mutated = $false
        active_memory_mutated = $false
        accepted_core_mutated = $false
        body_map_mutated = $false
        capability_map_mutated = $false
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

    $json = ($Data | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
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
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        return $null
    }
    return $prop.Value
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

function Test-BoundaryFalse {
    param(
        $Object,
        [string]$Flag
    )

    $boundary = Get-PropertyValue -Object $Object -Name "boundary"
    if ($null -eq $boundary) {
        return $false
    }
    $value = Get-PropertyValue -Object $boundary -Name $Flag
    if ($null -eq $value) {
        return $false
    }
    return (($value -eq $false) -or ([string]$value -eq "False"))
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

function Test-StatusHasForbiddenMutation {
    param([array]$StatusLines)

    foreach ($line in @($StatusLines)) {
        $text = [string]$line
        if ($text -match "^( M|M |A | D|D |R | C|C |MM|AM|AD|RM)") {
            if ($text -match "(CAPABILITY_ROADMAP\.json|GENESIS_STATE\.json|TASK_QUEUE\.json|packs/registry\.json|passport|contract|accepted-core|accepted_core|active_compact_semantic_memory)") {
                return $true
            }
        }
    }
    return $false
}

function Test-RecordFields {
    param(
        $Record,
        [string[]]$Fields
    )

    foreach ($field in $Fields) {
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
    scan_policy_effective = Join-Path $RuntimeRoot "scan_policy_effective.json"
    scan_skipped_surfaces = Join-Path $RuntimeRoot "scan_skipped_surfaces.json"
    repo_inventory = Join-Path $RuntimeRoot "repo_inventory.json"
    slice_a_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"
    body_map_read = Join-Path $RuntimeRoot "body_map_read.json"
    capability_map_read = Join-Path $RuntimeRoot "capability_map_read.json"
    organ_candidates = Join-Path $RuntimeRoot "organ_candidates.json"
    organ_similarity_index = Join-Path $RuntimeRoot "organ_similarity_index.json"
    runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_B_PROOF.json"
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

$scanPolicy = $null
$skipped = $null
$inventory = $null
$sliceAProof = $null
$bodyMap = $null
$capabilityMap = $null
$candidates = $null
$similarity = $null
$runtimeProof = $null

foreach ($entry in @(
    @{ name = "scan_policy"; var = "scanPolicy"; path = $OutputRefs.scan_policy_effective },
    @{ name = "skipped_surfaces"; var = "skipped"; path = $OutputRefs.scan_skipped_surfaces },
    @{ name = "repo_inventory"; var = "inventory"; path = $OutputRefs.repo_inventory },
    @{ name = "slice_a_runtime_proof"; var = "sliceAProof"; path = $OutputRefs.slice_a_runtime_proof },
    @{ name = "body_map_read"; var = "bodyMap"; path = $OutputRefs.body_map_read },
    @{ name = "capability_map_read"; var = "capabilityMap"; path = $OutputRefs.capability_map_read },
    @{ name = "organ_candidates"; var = "candidates"; path = $OutputRefs.organ_candidates },
    @{ name = "organ_similarity_index"; var = "similarity"; path = $OutputRefs.organ_similarity_index },
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

if ($bodyMap -and $capabilityMap) {
    $allMapRecords = @($bodyMap.map_records + $capabilityMap.map_records)
    $mapRecordFields = @(
        "path",
        "map_type",
        "parse_status",
        "schema",
        "status",
        "declared_organs",
        "declared_capabilities",
        "declared_invocation_paths",
        "declared_validators",
        "declared_proof_refs",
        "declared_passport_refs",
        "declared_signal_refs",
        "stale_after",
        "last_updated_if_present",
        "evidence_status",
        "errors"
    )

    $mapFieldsOk = $true
    foreach ($record in @($allMapRecords)) {
        if (-not (Test-RecordFields -Record $record -Fields $mapRecordFields)) {
            $mapFieldsOk = $false
        }
    }
    Add-Check -Name "map_records_required_fields" -Passed $mapFieldsOk -Message "map records include required fields"

    $recordedPaths = @()
    foreach ($record in @($allMapRecords)) {
        $recordedPaths += [string]$record.path
    }
    foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
        Add-Check -Name ("map_reader_records_" + $marker) -Passed ($recordedPaths -contains $marker) -Message ("map reader records root marker: " + $marker)
    }

    Add-Check -Name "map_reader_records_map_like_surfaces" -Passed (@($allMapRecords).Count -gt 0) -Message "map reader records map-like surfaces"

    $declaredMature = $false
    foreach ($source in @($bodyMap, $capabilityMap)) {
        foreach ($organ in @($source.declared_organs)) {
            if ([string]$organ.lifecycle_status -match "MATURE|VALID_ORGAN|PRESENT_ORGAN") {
                $declaredMature = $true
            }
        }
        foreach ($capability in @($source.declared_capabilities)) {
            if ([string]$capability.maturity_status -match "MATURE|USABLE") {
                $declaredMature = $true
            }
        }
    }
    Add-Check -Name "declared_not_claimed_mature" -Passed (-not $declaredMature) -Message "declared organs/capabilities are not claimed mature or usable"
}

if ($candidates) {
    Add-Check -Name "organ_candidate_status_pass" -Passed ($candidates.status -eq "PASS_ORGAN_CANDIDATE_DETECTION_V1") -Message "organ candidate detector status must be PASS"

    $candidateFields = @(
        "candidate_id",
        "candidate_type",
        "primary_path",
        "related_paths",
        "family_root",
        "name_guess",
        "capability_guess",
        "role_guess",
        "evidence_refs",
        "confidence",
        "discovered_from",
        "declared_in_maps",
        "has_contract_ref",
        "has_passport_ref",
        "has_validator_ref",
        "has_proof_ref",
        "has_invocation_ref",
        "has_signal_ref",
        "state_touched_guess",
        "authority_guess",
        "maturity_guess",
        "warnings"
    )

    $candidateFieldsOk = $true
    $candidateEvidenceOk = $true
    $candidatePromoted = $false
    foreach ($candidate in @($candidates.candidates)) {
        if (-not (Test-RecordFields -Record $candidate -Fields $candidateFields)) {
            $candidateFieldsOk = $false
        }
        if (@($candidate.evidence_refs).Count -eq 0) {
            $candidateEvidenceOk = $false
        }
        if ([string]$candidate.candidate_type -eq "ORGAN" -or [string]$candidate.maturity_guess -match "MATURE_ORGAN|VALID_ORGAN|PRESENT_ORGAN") {
            $candidatePromoted = $true
        }
    }
    Add-Check -Name "candidate_records_required_fields" -Passed $candidateFieldsOk -Message "organ candidate records have required fields"
    Add-Check -Name "candidate_records_have_evidence_refs" -Passed $candidateEvidenceOk -Message "candidate records include evidence_refs"
    Add-Check -Name "candidate_not_promoted_to_organ" -Passed (-not $candidatePromoted) -Message "candidate detector does not promote candidates to organs"

    $repoSupportsFamilies = $false
    if ($inventory -and $inventory.aggregates.organ_candidate_count -gt 0) {
        $repoSupportsFamilies = $true
    }
    $familyGroupingOk = $true
    if ($repoSupportsFamilies) {
        $familyGroupingOk = ($candidates.aggregates.candidate_family_count -gt 0 -and $candidates.aggregates.multi_path_family_count -gt 0)
    }
    Add-Check -Name "candidate_family_grouping_exists" -Passed $familyGroupingOk -Message "candidate family grouping exists when repo evidence supports it"
}

if ($similarity) {
    Add-Check -Name "similarity_status_pass" -Passed ($similarity.status -eq "PASS_ORGAN_SIMILARITY_DETECTION_V1") -Message "similarity detector status must be PASS"
    $similarityFields = @(
        "similarity_id",
        "subject_a",
        "subject_b",
        "cluster_id",
        "similarity_status",
        "similarity_score",
        "matching_features",
        "conflicting_features",
        "evidence_refs",
        "risk",
        "recommended_logic_action",
        "forbidden_now"
    )

    $similarityFieldsOk = $true
    $forbiddenNowOk = $true
    $filenameOnlyDuplicate = $false
    foreach ($record in @($similarity.similarity_records)) {
        if (-not (Test-RecordFields -Record $record -Fields $similarityFields)) {
            $similarityFieldsOk = $false
        }
        if (@($record.forbidden_now).Count -eq 0) {
            $forbiddenNowOk = $false
        }
        if ([string]$record.similarity_status -eq "POSSIBLE_DUPLICATE") {
            $features = @($record.matching_features)
            if ($features.Count -eq 1 -and $features[0] -eq "SAME_NORMALIZED_NAME_STEM") {
                $filenameOnlyDuplicate = $true
            }
        }
    }
    Add-Check -Name "similarity_records_required_fields" -Passed $similarityFieldsOk -Message "similarity records include required fields"
    Add-Check -Name "similarity_records_have_forbidden_now" -Passed $forbiddenNowOk -Message "similarity records include forbidden_now"
    Add-Check -Name "similarity_not_filename_only_duplicate" -Passed (-not $filenameOnlyDuplicate) -Message "duplicate is not proven solely from filename"
    Add-Check -Name "similarity_records_exist" -Passed (@($similarity.similarity_records).Count -gt 0) -Message "similarity index has records and statuses"
}

if ($runtimeProof) {
    Add-Check -Name "runtime_proof_status_pass" -Passed ($runtimeProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_B_RUNTIME_V1") -Message "Slice B runtime proof status must be PASS"
}

Add-Check -Name "no_tracked_map_passport_contract_mutation" -Passed (-not (Test-StatusHasForbiddenMutation -StatusLines $gitStatusAfterInvoker)) -Message "no tracked map/passport/contract mutation observed"

$objectsWithBoundaries = @(
    @{ name = "body_map"; value = $bodyMap },
    @{ name = "capability_map"; value = $capabilityMap },
    @{ name = "organ_candidates"; value = $candidates },
    @{ name = "organ_similarity"; value = $similarity },
    @{ name = "runtime_proof"; value = $runtimeProof }
)

$boundaryFlags = @(
    "repo_mutated",
    "active_memory_mutated",
    "accepted_core_mutated",
    "body_map_mutated",
    "capability_map_mutated",
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

$status = "PASS_BODY_SELF_INSPECTION_SLICE_B_V1"
if ($Failures.Count -gt 0) {
    $status = "FAIL_BODY_SELF_INSPECTION_SLICE_B_V1"
}
if ($Blocked) {
    $status = "BLOCKED_BODY_SELF_INSPECTION_SLICE_B_V1"
}

$proof = @{
    schema = "body_self_inspection_slice_b_validator_proof_v1"
    status = $status
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    validator_ref = "validators/validate_body_self_inspection_slice_b_v1.ps1"
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "B"
    output_refs = $OutputRefs
    validator_checks = $Checks
    git_status_before_invoker = @($gitStatusBeforeInvoker)
    git_status_after_invoker = @($gitStatusAfterInvoker)
    aggregate_counts = @{
        body_map_read = $(if ($bodyMap) { $bodyMap.aggregates } else { $null })
        capability_map_read = $(if ($capabilityMap) { $capabilityMap.aggregates } else { $null })
        organ_candidates = $(if ($candidates) { $candidates.aggregates } else { $null })
        organ_similarity_index = $(if ($similarity) { $similarity.aggregates } else { $null })
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
