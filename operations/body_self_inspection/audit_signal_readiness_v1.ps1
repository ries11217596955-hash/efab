param(
    [string]$RepoRoot,
    [string]$RuntimeRoot
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

if (-not $RuntimeRoot -or $RuntimeRoot.Trim() -eq "") {
    $RuntimeRoot = Join-Path $RepoRoot ".runtime\body_self_inspection_v1"
}

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

function ConvertTo-RepoRelativePath {
    param([string]$Path)

    if (-not $Path -or $Path.Trim() -eq "") {
        return ""
    }
    $clean = $Path.Trim() -replace "\\", "/"
    $repoClean = $RepoRoot -replace "\\", "/"
    if ($clean.StartsWith($repoClean, [System.StringComparison]::OrdinalIgnoreCase)) {
        $clean = $clean.Substring($repoClean.Length).TrimStart("/")
    }
    return $clean.TrimStart("./")
}

function Resolve-RepoPath {
    param([string]$Path)

    if (-not $Path -or $Path.Trim() -eq "") {
        return ""
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return ($Path -replace "/", "\")
    }
    return (Join-Path $RepoRoot ($Path -replace "/", "\"))
}

function Sanitize-Id {
    param([string]$Value)

    $text = [string]$Value
    $text = $text.ToLowerInvariant() -replace "[^a-z0-9]+", "_"
    $text = $text.Trim("_")
    if ($text.Length -gt 100) {
        $text = $text.Substring(0, 100).Trim("_")
    }
    if ($text -eq "") {
        return "unknown_target"
    }
    return $text
}

function Get-PathsByPattern {
    param(
        [array]$Paths,
        [string]$Pattern
    )

    $matchedPaths = @()
    foreach ($path in @($Paths)) {
        if ([string]$path -match $Pattern) {
            $matchedPaths += [string]$path
        }
    }
    return @($matchedPaths | Select-Object -Unique)
}

function Test-AnyPathExists {
    param([array]$Paths)

    foreach ($path in @($Paths)) {
        if ($path -and (Test-Path -LiteralPath (Resolve-RepoPath -Path $path))) {
            return $true
        }
    }
    return $false
}

$inventoryPath = Join-Path $RuntimeRoot "repo_inventory.json"
$bodyMapPath = Join-Path $RuntimeRoot "body_map_read.json"
$capabilityMapPath = Join-Path $RuntimeRoot "capability_map_read.json"
$candidatePath = Join-Path $RuntimeRoot "organ_candidates.json"
$passportAuditPath = Join-Path $RuntimeRoot "passport_audit.json"
$outputPath = Join-Path $RuntimeRoot "signal_readiness_audit.json"

$inventory = Read-JsonFile -Path $inventoryPath
$bodyMap = Read-JsonFile -Path $bodyMapPath
$capabilityMap = Read-JsonFile -Path $capabilityMapPath
$candidates = Read-JsonFile -Path $candidatePath
$passportAudit = Read-JsonFile -Path $passportAuditPath

$candidateById = @{}
foreach ($candidate in @($candidates.candidates)) {
    $candidateById[[string]$candidate.candidate_id] = $candidate
}

$mapSignalRefsByPath = @{}
foreach ($source in @($bodyMap, $capabilityMap)) {
    foreach ($record in @($source.map_records)) {
        $path = ConvertTo-RepoRelativePath -Path ([string]$record.path)
        $refs = @()
        foreach ($signalRef in @($record.declared_signal_refs)) {
            if ($signalRef) {
                $refs += [string]$signalRef
            }
        }
        if (@($refs).Count -gt 0) {
            $mapSignalRefsByPath[$path] = @($refs)
        }
    }
}

$signalRecords = @()
$errors = @()

foreach ($passportRecord in @($passportAudit.audit_records)) {
    $targetId = [string]$passportRecord.target_id
    $targetKind = [string]$passportRecord.target_kind
    $candidate = $null
    if ($candidateById.ContainsKey($targetId)) {
        $candidate = $candidateById[$targetId]
    }

    $refs = @()
    $refs += @($passportRecord.target_refs | ForEach-Object { ConvertTo-RepoRelativePath -Path ([string]$_) })
    $refs += @($passportRecord.evidence_refs | ForEach-Object { ConvertTo-RepoRelativePath -Path ([string]$_) })
    foreach ($ref in @($refs)) {
        if ($mapSignalRefsByPath.ContainsKey($ref)) {
            $refs += @($mapSignalRefsByPath[$ref])
        }
    }
    if ($candidate -and (Get-PropertyValue -Object $candidate -Name "has_signal_ref") -eq $true) {
        $refs += "candidate_declared_signal_ref"
    }
    $refs = @($refs | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Unique)

    $signalRefs = @(Get-PathsByPattern -Paths $refs -Pattern "signal|self_inspection_signal|event_type|emitter_organ_id")
    $signalSchemaRefs = @(Get-PathsByPattern -Paths $refs -Pattern "signal.*schema|schema.*signal|self_inspection_signal\.json")
    $signalValidatorRefs = @(Get-PathsByPattern -Paths $refs -Pattern "(^|/)validators/.*signal|validate_.*signal.*\.ps1")
    $signalProofRefs = @(Get-PathsByPattern -Paths $refs -Pattern "signal.*proof|proof.*signal|_PROOF\.json")

    $organLikeKinds = @(
        "ORGAN_CONTRACT_CANDIDATE",
        "ORGAN_SCRIPT_CANDIDATE",
        "VALIDATOR_CLUSTER_CANDIDATE",
        "MEMORY_TOOL_CANDIDATE",
        "MAP_TOOL_CANDIDATE",
        "AUTHORITY_PASSPORT_CANDIDATE",
        "CAPABILITY_PASSPORT_CANDIDATE",
        "ORGAN_CONTRACT_FILE",
        "AUTHORITY_PASSPORT_FILE",
        "CAPABILITY_PASSPORT_FILE",
        "MAP_DECLARED_ORGAN",
        "KNOWN_REFERENCE_ORGAN_CANDIDATE"
    )
    $requiresSignal = ($organLikeKinds -contains $targetKind)
    if ([string]$passportRecord.passport_status -eq "NOT_ORGAN_NO_PASSPORT_REQUIRED_YET") {
        $requiresSignal = $false
    }

    $hasSignalContract = @($signalRefs).Count -gt 0
    $hasSignalValidator = @($signalValidatorRefs).Count -gt 0
    $hasSignalProof = @($signalProofRefs).Count -gt 0
    $proofRefsBroken = $false
    foreach ($proofRef in @($signalProofRefs)) {
        if ($proofRef -match "\.(json|ps1|md)$" -and -not (Test-Path -LiteralPath (Resolve-RepoPath -Path $proofRef))) {
            $proofRefsBroken = $true
        }
    }

    $signalStatus = "SIGNAL_UNKNOWN"
    if (-not $requiresSignal) {
        $signalStatus = "SIGNAL_NOT_REQUIRED_FOR_NON_ORGAN"
    } elseif (-not $hasSignalContract -and -not $hasSignalValidator) {
        $signalStatus = "SIGNAL_MISSING"
    } elseif ($hasSignalValidator -and -not $hasSignalContract) {
        $signalStatus = "SIGNAL_VALIDATOR_WITHOUT_CONTRACT"
    } elseif ($hasSignalContract -and -not $hasSignalValidator) {
        $signalStatus = "SIGNAL_CONTRACT_WITHOUT_VALIDATOR"
    } elseif ($proofRefsBroken) {
        $signalStatus = "SIGNAL_PROOF_REF_BROKEN"
    } elseif (@($signalSchemaRefs).Count -gt 0 -and -not (Test-AnyPathExists -Paths $signalSchemaRefs) -and @($signalSchemaRefs | Where-Object { $_ -match "\.(json|md)$" }).Count -gt 0) {
        $signalStatus = "SIGNAL_SCHEMA_REF_BROKEN"
    } elseif (@($signalRefs | Where-Object { $_ -match "placeholder|self_inspection_signal|\.runtime" }).Count -gt 0) {
        $signalStatus = "SIGNAL_EMITS_TO_PLACEHOLDER"
    } elseif ($hasSignalContract -and $hasSignalValidator -and $hasSignalProof) {
        $signalStatus = "NATIVE_SIGNAL_EMITTER"
    } elseif ($hasSignalContract) {
        $signalStatus = "LEGACY_SIGNAL_ADAPTED"
    }

    $expectedEmitted = @()
    $expectedConsumed = @()
    if ($signalStatus -in @("NATIVE_SIGNAL_EMITTER", "SIGNAL_EMITS_TO_PLACEHOLDER", "LEGACY_SIGNAL_ADAPTED", "SIGNAL_CONTRACT_WITHOUT_VALIDATOR")) {
        $expectedEmitted += "self_inspection_or_candidate_status_signal"
    }
    if ($targetId -match "validator|contract|passport") {
        $expectedConsumed += "validation_or_contract_state"
    }

    $signalSinkStatus = "NO_SIGNAL_SINK_DECLARED"
    if (-not $requiresSignal) {
        $signalSinkStatus = "SIGNAL_SINK_NOT_REQUIRED_FOR_NON_ORGAN"
    } elseif ($signalStatus -eq "SIGNAL_EMITS_TO_PLACEHOLDER") {
        $signalSinkStatus = "PLACEHOLDER_RUNTIME_FILE"
    } elseif ($hasSignalContract) {
        $signalSinkStatus = "SINK_DECLARED_NOT_CONNECTED"
    }

    $signalAdapterStatus = "NO_ADAPTER_DECLARED"
    if (-not $requiresSignal) {
        $signalAdapterStatus = "ADAPTER_NOT_REQUIRED_FOR_NON_ORGAN"
    } elseif ($signalStatus -eq "LEGACY_SIGNAL_ADAPTED") {
        $signalAdapterStatus = "LEGACY_ADAPTER_PATH_DECLARED"
    } elseif (-not $hasSignalContract -and ([string]$passportRecord.validator_status -match "VALIDATOR" -or [string]$passportRecord.proof_status -match "PROOF_REF_VALID")) {
        $signalAdapterStatus = "ADAPTER_REQUIRED_FOR_LEGACY_OUTPUT"
    }

    $nervousStatus = "NERVOUS_SYSTEM_NOT_CONNECTED_BY_DESIGN"
    if (-not $requiresSignal) {
        $nervousStatus = "NOT_REQUIRED_FOR_NON_ORGAN"
    } elseif ($signalStatus -eq "SIGNAL_MISSING") {
        $nervousStatus = "FUTURE_DEPENDENCY_BLOCKED_BY_MISSING_SIGNAL"
    } elseif ($signalStatus -eq "SIGNAL_EMITS_TO_PLACEHOLDER") {
        $nervousStatus = "FUTURE_DEPENDENCY_PLACEHOLDER_ONLY"
    }

    $painCandidates = @()
    if ($signalStatus -eq "SIGNAL_MISSING") {
        $painCandidates += "organ_missing_signal_contract"
    }
    if ($signalStatus -eq "SIGNAL_CONTRACT_WITHOUT_VALIDATOR") {
        $painCandidates += "signal_contract_without_validator"
    }
    if ($signalStatus -eq "SIGNAL_VALIDATOR_WITHOUT_CONTRACT") {
        $painCandidates += "signal_validator_without_contract"
    }
    if ($signalStatus -eq "SIGNAL_SCHEMA_REF_BROKEN") {
        $painCandidates += "signal_schema_ref_broken"
    }
    if ($signalStatus -eq "SIGNAL_PROOF_REF_BROKEN") {
        $painCandidates += "signal_emission_proof_broken"
    }
    if ($signalAdapterStatus -eq "ADAPTER_REQUIRED_FOR_LEGACY_OUTPUT") {
        $painCandidates += "signal_adapter_needed_for_legacy_organ"
    }
    if ($signalSinkStatus -eq "NO_SIGNAL_SINK_DECLARED" -and $requiresSignal) {
        $painCandidates += "signal_sink_missing_future_dependency"
    }

    $recommended = "monitor_only"
    if ($signalStatus -eq "SIGNAL_MISSING") {
        $recommended = "create_signal_contract_requirement_draft"
    } elseif ($signalStatus -eq "SIGNAL_CONTRACT_WITHOUT_VALIDATOR") {
        $recommended = "create_signal_validator_requirement_draft"
    } elseif ($signalAdapterStatus -eq "ADAPTER_REQUIRED_FOR_LEGACY_OUTPUT") {
        $recommended = "create_legacy_signal_adapter_draft"
    } elseif (-not $requiresSignal) {
        $recommended = "mark_signal_not_required_for_non_organ"
    } elseif ($signalStatus -eq "SIGNAL_EMITS_TO_PLACEHOLDER") {
        $recommended = "wait_for_nervous_system_layer"
    }

    $signalRecords += @{
        audit_id = "signal_audit_" + (Sanitize-Id -Value $targetId)
        target_id = $targetId
        target_kind = $targetKind
        signal_contract_status = $signalStatus
        expected_signals_emitted = @($expectedEmitted | Select-Object -Unique)
        expected_signals_consumed = @($expectedConsumed | Select-Object -Unique)
        signal_schema_ref = $(if (@($signalSchemaRefs).Count -gt 0) { @($signalSchemaRefs)[0] } else { $null })
        signal_validator_ref = $(if (@($signalValidatorRefs).Count -gt 0) { @($signalValidatorRefs)[0] } else { $null })
        signal_emission_proof_ref = $(if (@($signalProofRefs).Count -gt 0) { @($signalProofRefs)[0] } else { $null })
        signal_sink_status = $signalSinkStatus
        signal_adapter_status = $signalAdapterStatus
        nervous_system_dependency_status = $nervousStatus
        evidence_refs = @($refs)
        pain_candidates = @($painCandidates | Select-Object -Unique)
        recommended_logic_action = $recommended
        forbidden_now = @(
            "claim nervous system connected",
            "mutate organ to emit signal",
            "mutate active memory",
            "wire signal consumer",
            "launch live action from signal"
        )
        boundary_flags = @{
            signal_field_presence_claims_nervous_system_connection = $false
            signal_ready_claims_nervous_system_connected = $false
        }
    }
}

$statusCounts = @{}
foreach ($record in @($signalRecords)) {
    $value = [string]$record.signal_contract_status
    if (-not $statusCounts.ContainsKey($value)) {
        $statusCounts[$value] = 0
    }
    $statusCounts[$value] = [int]$statusCounts[$value] + 1
}

$output = @{
    schema = "body_self_inspection_signal_readiness_audit_v1"
    status = "PASS_BODY_SELF_INSPECTION_SIGNAL_READINESS_AUDIT_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "C"
    source_refs = @{
        repo_inventory = $inventoryPath
        body_map_read = $bodyMapPath
        capability_map_read = $capabilityMapPath
        organ_candidates = $candidatePath
        passport_audit = $passportAuditPath
    }
    signal_audit_records = @($signalRecords)
    aggregates = @{
        target_count = @($signalRecords).Count
        signal_contract_status_counts = $statusCounts
        pain_candidate_count = @($signalRecords | Where-Object { @($_.pain_candidates).Count -gt 0 }).Count
        inventory_signal_like_records_seen = @($inventory.records | Where-Object { [string]$_.normalized_path -match "signal" }).Count
    }
    boundary_statement = @{
        signal_field_present = "SIGNAL_FIELD_PRESENT != SIGNAL_READY"
        signal_ready = "SIGNAL_READY != NERVOUS_SYSTEM_CONNECTED"
        placeholder_policy = "EMITS_TO_PLACEHOLDER is allowed but must be explicit"
    }
    boundary_claims = @{
        signal_field_presence_claims_nervous_system_connection = $false
        signal_ready_claims_nervous_system_connected = $false
    }
    boundary = New-BodyInspectionBoundary
    errors = @($errors)
}

Write-JsonFile -Path $outputPath -Data $output
Write-Output $outputPath
