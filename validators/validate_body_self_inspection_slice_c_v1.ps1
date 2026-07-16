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
$InvokerPath = Join-Path $RepoRoot "operations\body_self_inspection\invoke_body_self_inspection_slice_c_v1.ps1"
$TrackedProofPath = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_C_V1_PROOF.json"

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
        if ($path -like "operations/autonomous_inner_motor/*contract*.json" -or $path -like "operations/autonomous_inner_motor/*passport*.json") {
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
    scan_policy_effective = Join-Path $RuntimeRoot "scan_policy_effective.json"
    scan_skipped_surfaces = Join-Path $RuntimeRoot "scan_skipped_surfaces.json"
    repo_inventory = Join-Path $RuntimeRoot "repo_inventory.json"
    body_map_read = Join-Path $RuntimeRoot "body_map_read.json"
    capability_map_read = Join-Path $RuntimeRoot "capability_map_read.json"
    organ_candidates = Join-Path $RuntimeRoot "organ_candidates.json"
    organ_similarity_index = Join-Path $RuntimeRoot "organ_similarity_index.json"
    slice_a_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"
    slice_b_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_B_PROOF.json"
    passport_audit = Join-Path $RuntimeRoot "passport_audit.json"
    signal_readiness_audit = Join-Path $RuntimeRoot "signal_readiness_audit.json"
    runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_C_PROOF.json"
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
$bodyMap = $null
$capabilityMap = $null
$candidates = $null
$similarity = $null
$sliceAProof = $null
$sliceBProof = $null
$passportAudit = $null
$signalAudit = $null
$runtimeProof = $null

foreach ($entry in @(
    @{ name = "scan_policy"; var = "scanPolicy"; path = $OutputRefs.scan_policy_effective },
    @{ name = "skipped_surfaces"; var = "skipped"; path = $OutputRefs.scan_skipped_surfaces },
    @{ name = "repo_inventory"; var = "inventory"; path = $OutputRefs.repo_inventory },
    @{ name = "body_map_read"; var = "bodyMap"; path = $OutputRefs.body_map_read },
    @{ name = "capability_map_read"; var = "capabilityMap"; path = $OutputRefs.capability_map_read },
    @{ name = "organ_candidates"; var = "candidates"; path = $OutputRefs.organ_candidates },
    @{ name = "organ_similarity_index"; var = "similarity"; path = $OutputRefs.organ_similarity_index },
    @{ name = "slice_a_runtime_proof"; var = "sliceAProof"; path = $OutputRefs.slice_a_runtime_proof },
    @{ name = "slice_b_runtime_proof"; var = "sliceBProof"; path = $OutputRefs.slice_b_runtime_proof },
    @{ name = "passport_audit"; var = "passportAudit"; path = $OutputRefs.passport_audit },
    @{ name = "signal_readiness_audit"; var = "signalAudit"; path = $OutputRefs.signal_readiness_audit },
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
if ($runtimeProof) {
    Add-Check -Name "slice_c_runtime_status_pass" -Passed ($runtimeProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_C_RUNTIME_V1") -Message "Slice C runtime proof status must be PASS"
}

if ($passportAudit) {
    Add-Check -Name "passport_audit_status_pass" -Passed ($passportAudit.status -eq "PASS_BODY_SELF_INSPECTION_PASSPORT_CONTRACT_AUDIT_V1") -Message "passport audit status must be PASS"
    Add-Check -Name "passport_audit_targets_exist" -Passed (@($passportAudit.audit_records).Count -gt 0) -Message "passport audit has records"

    $passportFields = @(
        "audit_id",
        "target_id",
        "target_kind",
        "target_refs",
        "passport_status",
        "contract_status",
        "authority_status",
        "capability_passport_status",
        "validator_status",
        "proof_status",
        "required_fields_checked",
        "missing_fields",
        "parse_errors",
        "evidence_refs",
        "pain_candidates",
        "recommended_logic_action",
        "forbidden_now"
    )
    $allowedPassportStatuses = @(
        "PASSPORT_PRESENT_VALIDATED",
        "PASSPORT_PRESENT_UNVALIDATED",
        "PASSPORT_PRESENT_PARSE_FAILED",
        "PASSPORT_MISSING",
        "PASSPORT_INDEX_ONLY",
        "CONTRACT_PRESENT_PASSPORT_MISSING",
        "PASSPORT_PRESENT_CONTRACT_MISSING",
        "AUTHORITY_PASSPORT_MISSING",
        "CAPABILITY_PASSPORT_MISSING",
        "PASSPORT_REQUIRED_FIELD_MISSING",
        "PASSPORT_SCHEMA_UNKNOWN",
        "NOT_ORGAN_NO_PASSPORT_REQUIRED_YET"
    )

    $fieldsOk = $true
    $evidenceOk = $true
    $forbiddenOk = $true
    $statusOk = $true
    $candidatePromoted = $false
    $missingPassportHasPain = $true
    $missingValidatorHasPain = $true
    $missingProofHasPain = $true
    foreach ($record in @($passportAudit.audit_records)) {
        if (-not (Test-RecordFields -Record $record -Fields $passportFields)) {
            $fieldsOk = $false
        }
        if (@($record.evidence_refs).Count -eq 0) {
            $evidenceOk = $false
        }
        if (@($record.forbidden_now).Count -eq 0) {
            $forbiddenOk = $false
        }
        if ($allowedPassportStatuses -notcontains [string]$record.passport_status) {
            $statusOk = $false
        }
        if ([string]$record.target_kind -eq "ORGAN" -or [string]$record.target_kind -match "PROMOTED") {
            $candidatePromoted = $true
        }
        if ([string]$record.passport_status -in @("PASSPORT_MISSING", "CONTRACT_PRESENT_PASSPORT_MISSING") -and @($record.pain_candidates).Count -eq 0) {
            $missingPassportHasPain = $false
        }
        if ([string]$record.validator_status -eq "VALIDATOR_MISSING" -and @($record.pain_candidates).Count -eq 0) {
            $missingValidatorHasPain = $false
        }
        if ([string]$record.proof_status -in @("PROOF_REF_MISSING", "PROOF_REF_BROKEN") -and @($record.pain_candidates).Count -eq 0) {
            $missingProofHasPain = $false
        }
    }
    Add-Check -Name "passport_records_required_fields" -Passed $fieldsOk -Message "every passport audit record has required fields"
    Add-Check -Name "passport_records_have_evidence_refs" -Passed $evidenceOk -Message "every passport audit record has evidence_refs"
    Add-Check -Name "passport_records_have_forbidden_now" -Passed $forbiddenOk -Message "every passport audit record has forbidden_now"
    Add-Check -Name "passport_status_values_allowed" -Passed $statusOk -Message "passport_status values are from allowed set"
    Add-Check -Name "candidate_not_promoted_to_organ" -Passed (-not $candidatePromoted) -Message "Slice C does not promote candidates to organs"
    Add-Check -Name "missing_passport_cases_have_pain_candidates" -Passed $missingPassportHasPain -Message "missing passport cases have pain candidates"
    Add-Check -Name "missing_validator_cases_have_pain_candidates" -Passed $missingValidatorHasPain -Message "missing validator cases have pain candidates"
    Add-Check -Name "missing_proof_cases_have_pain_candidates" -Passed $missingProofHasPain -Message "missing proof cases have pain candidates"

    Add-Check -Name "passport_presence_not_maturity" -Passed (Test-ClaimFalse -Object $passportAudit -Flag "passport_presence_claims_maturity") -Message "passport presence is not claimed as maturity"
    Add-Check -Name "contract_presence_not_wiring" -Passed (Test-ClaimFalse -Object $passportAudit -Flag "contract_presence_claims_wiring") -Message "contract presence is not claimed as wiring"
    Add-Check -Name "passport_distinguishes_missing_unvalidated" -Passed ($passportAudit.aggregates.passport_status_counts.PSObject.Properties.Name -contains "CONTRACT_PRESENT_PASSPORT_MISSING" -or $passportAudit.aggregates.passport_status_counts.PSObject.Properties.Name -contains "PASSPORT_MISSING" -or $passportAudit.aggregates.passport_status_counts.PSObject.Properties.Name -contains "PASSPORT_REQUIRED_FIELD_MISSING") -Message "passport audit distinguishes missing/unvalidated/problem states"
}

if ($signalAudit) {
    Add-Check -Name "signal_audit_status_pass" -Passed ($signalAudit.status -eq "PASS_BODY_SELF_INSPECTION_SIGNAL_READINESS_AUDIT_V1") -Message "signal readiness audit status must be PASS"
    Add-Check -Name "signal_audit_targets_exist" -Passed (@($signalAudit.signal_audit_records).Count -gt 0) -Message "signal readiness audit has records"

    $signalFields = @(
        "audit_id",
        "target_id",
        "target_kind",
        "signal_contract_status",
        "expected_signals_emitted",
        "expected_signals_consumed",
        "signal_schema_ref",
        "signal_validator_ref",
        "signal_emission_proof_ref",
        "signal_sink_status",
        "signal_adapter_status",
        "nervous_system_dependency_status",
        "evidence_refs",
        "pain_candidates",
        "recommended_logic_action",
        "forbidden_now"
    )
    $allowedSignalStatuses = @(
        "NATIVE_SIGNAL_EMITTER",
        "LEGACY_SIGNAL_ADAPTED",
        "SIGNAL_MISSING",
        "SIGNAL_UNKNOWN",
        "SIGNAL_CONTRACT_WITHOUT_VALIDATOR",
        "SIGNAL_VALIDATOR_WITHOUT_CONTRACT",
        "SIGNAL_SCHEMA_REF_BROKEN",
        "SIGNAL_PROOF_REF_BROKEN",
        "SIGNAL_EMITS_TO_PLACEHOLDER",
        "SIGNAL_NOT_REQUIRED_FOR_NON_ORGAN"
    )
    $fieldsOk = $true
    $evidenceOk = $true
    $forbiddenOk = $true
    $statusOk = $true
    $missingSignalHasPain = $true
    $nervousClaimed = $false
    foreach ($record in @($signalAudit.signal_audit_records)) {
        if (-not (Test-RecordFields -Record $record -Fields $signalFields)) {
            $fieldsOk = $false
        }
        if (@($record.evidence_refs).Count -eq 0) {
            $evidenceOk = $false
        }
        if (@($record.forbidden_now).Count -eq 0) {
            $forbiddenOk = $false
        }
        if ($allowedSignalStatuses -notcontains [string]$record.signal_contract_status) {
            $statusOk = $false
        }
        if ([string]$record.signal_contract_status -eq "SIGNAL_MISSING" -and @($record.pain_candidates).Count -eq 0) {
            $missingSignalHasPain = $false
        }
        if (@("NERVOUS_SYSTEM_CONNECTED", "CONNECTED_TO_NERVOUS_SYSTEM", "SIGNAL_CONSUMED_BY_NERVOUS_SYSTEM") -contains [string]$record.nervous_system_dependency_status) {
            $nervousClaimed = $true
        }
    }
    Add-Check -Name "signal_records_required_fields" -Passed $fieldsOk -Message "every signal audit record has required fields"
    Add-Check -Name "signal_records_have_evidence_refs" -Passed $evidenceOk -Message "every signal audit record has evidence_refs"
    Add-Check -Name "signal_records_have_forbidden_now" -Passed $forbiddenOk -Message "every signal audit record has forbidden_now"
    Add-Check -Name "signal_status_values_allowed" -Passed $statusOk -Message "signal_contract_status values are from allowed set"
    Add-Check -Name "missing_signal_cases_have_pain_candidates" -Passed $missingSignalHasPain -Message "missing signal cases have pain candidates"
    Add-Check -Name "signal_field_presence_not_nervous_connection" -Passed (Test-ClaimFalse -Object $signalAudit -Flag "signal_field_presence_claims_nervous_system_connection") -Message "signal field presence is not claimed as nervous system connection"
    Add-Check -Name "nervous_system_not_claimed_connected" -Passed (-not $nervousClaimed) -Message "signal audit does not claim nervous-system connection"
    Add-Check -Name "signal_distinguishes_missing_or_placeholder" -Passed ($signalAudit.aggregates.signal_contract_status_counts.PSObject.Properties.Name -contains "SIGNAL_MISSING" -or $signalAudit.aggregates.signal_contract_status_counts.PSObject.Properties.Name -contains "SIGNAL_EMITS_TO_PLACEHOLDER" -or $signalAudit.aggregates.signal_contract_status_counts.PSObject.Properties.Name -contains "SIGNAL_NOT_REQUIRED_FOR_NON_ORGAN") -Message "signal audit distinguishes readiness from non-connection"
}

if ($runtimeProof) {
    Add-Check -Name "runtime_passport_presence_not_maturity" -Passed (Test-ClaimFalse -Object $runtimeProof -Flag "passport_presence_claims_maturity") -Message "runtime proof does not claim passport presence as maturity"
    Add-Check -Name "runtime_contract_presence_not_wiring" -Passed (Test-ClaimFalse -Object $runtimeProof -Flag "contract_presence_claims_wiring") -Message "runtime proof does not claim contract presence as wiring"
    Add-Check -Name "runtime_signal_presence_not_nervous_connection" -Passed (Test-ClaimFalse -Object $runtimeProof -Flag "signal_field_presence_claims_nervous_system_connection") -Message "runtime proof does not claim signal field as nervous system connection"
}

Add-Check -Name "audit_targets_derived_from_candidates_maps_contracts" -Passed ($passportAudit -and $candidates -and @($passportAudit.audit_records).Count -ge @($candidates.candidates).Count) -Message "audit target count covers candidates plus contract/passport surfaces"
Add-Check -Name "no_tracked_map_passport_contract_mutation" -Passed (-not (Test-StatusHasForbiddenMutation -StatusLines $gitStatusAfterInvoker)) -Message "no tracked map/passport/contract/active-memory mutation observed"

$objectsWithBoundaries = @(
    @{ name = "passport_audit"; value = $passportAudit },
    @{ name = "signal_audit"; value = $signalAudit },
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
        passed = ($Failures -notcontains "Slice C does not promote candidates to organs")
        evidence = "target_kind checked for ORGAN/PROMOTED claims"
    },
    @{
        name = "passport_presence_not_maturity"
        passed = $(if ($passportAudit) { Test-ClaimFalse -Object $passportAudit -Flag "passport_presence_claims_maturity" } else { $false })
        evidence = "passport audit boundary_claims"
    },
    @{
        name = "contract_presence_not_wiring"
        passed = $(if ($passportAudit) { Test-ClaimFalse -Object $passportAudit -Flag "contract_presence_claims_wiring" } else { $false })
        evidence = "passport audit boundary_claims"
    },
    @{
        name = "signal_field_not_nervous_system_connection"
        passed = $(if ($signalAudit) { Test-ClaimFalse -Object $signalAudit -Flag "signal_field_presence_claims_nervous_system_connection" } else { $false })
        evidence = "signal readiness boundary_claims"
    }
)

$status = "PASS_BODY_SELF_INSPECTION_SLICE_C_V1"
if ($Failures.Count -gt 0) {
    $status = "FAIL_BODY_SELF_INSPECTION_SLICE_C_V1"
}
if ($Blocked) {
    $status = "BLOCKED_BODY_SELF_INSPECTION_SLICE_C_V1"
}

$proof = @{
    schema = "body_self_inspection_slice_c_validator_proof_v1"
    status = $status
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    validator_ref = "validators/validate_body_self_inspection_slice_c_v1.ps1"
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "C"
    output_refs = $OutputRefs
    validator_checks = $Checks
    negative_test_results = $negativeResults
    git_status_before_invoker = @($gitStatusBeforeInvoker)
    git_status_after_invoker = @($gitStatusAfterInvoker)
    aggregate_counts = @{
        passport_audit = $(if ($passportAudit) { $passportAudit.aggregates } else { $null })
        signal_readiness_audit = $(if ($signalAudit) { $signalAudit.aggregates } else { $null })
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
