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

function Add-UniqueString {
    param(
        [array]$Values,
        [string]$Value
    )

    $result = @()
    foreach ($item in @($Values)) {
        if ($null -ne $item -and [string]$item -ne "" -and $result -notcontains [string]$item) {
            $result += [string]$item
        }
    }
    if ($Value -and $Value.Trim() -ne "" -and $result -notcontains $Value) {
        $result += $Value
    }
    return @($result)
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

function Test-PathLooksLikeReference {
    param([string]$Value)

    if (-not $Value) {
        return $false
    }
    return ($Value -match "[/\\]" -or $Value -match "\.(json|ps1|md|jsonl)$")
}

function Get-ReferencedPathValues {
    param(
        $Object,
        [string]$PropertyPattern,
        [int]$Depth = 0
    )

    $values = @()
    if ($null -eq $Object -or $Depth -gt 8) {
        return @($values)
    }
    if ($Object -is [string]) {
        if (Test-PathLooksLikeReference -Value $Object) {
            $values += (ConvertTo-RepoRelativePath -Path $Object)
        }
        return @($values)
    }
    if ($Object -is [System.Collections.IEnumerable] -and -not ($Object -is [string])) {
        foreach ($item in @($Object)) {
            $values += @(Get-ReferencedPathValues -Object $item -PropertyPattern $PropertyPattern -Depth ($Depth + 1))
        }
        return @($values)
    }

    foreach ($property in @($Object.PSObject.Properties)) {
        $name = [string]$property.Name
        $value = $property.Value
        if ($name -match $PropertyPattern) {
            if ($value -is [string]) {
                if (Test-PathLooksLikeReference -Value $value) {
                    $values += (ConvertTo-RepoRelativePath -Path $value)
                }
            } elseif ($value -is [System.Collections.IEnumerable]) {
                foreach ($item in @($value)) {
                    if ($item -is [string] -and (Test-PathLooksLikeReference -Value $item)) {
                        $values += (ConvertTo-RepoRelativePath -Path $item)
                    }
                }
            }
        }
        if ($null -ne $value -and -not ($value -is [string])) {
            $values += @(Get-ReferencedPathValues -Object $value -PropertyPattern $PropertyPattern -Depth ($Depth + 1))
        }
    }
    return @($values | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Unique)
}

function Test-ConceptPresent {
    param(
        $Object,
        [string[]]$Names,
        [int]$Depth = 0
    )

    if ($null -eq $Object -or $Depth -gt 8) {
        return $false
    }
    if ($Object -is [string]) {
        return $false
    }
    if ($Object -is [System.Collections.IEnumerable]) {
        foreach ($item in @($Object)) {
            if (Test-ConceptPresent -Object $item -Names $Names -Depth ($Depth + 1)) {
                return $true
            }
        }
        return $false
    }

    foreach ($property in @($Object.PSObject.Properties)) {
        if ($Names -contains [string]$property.Name) {
            return $true
        }
        $value = $property.Value
        if ($null -ne $value -and -not ($value -is [string])) {
            if (Test-ConceptPresent -Object $value -Names $Names -Depth ($Depth + 1)) {
                return $true
            }
        }
    }
    return $false
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

function Read-JsonMaybe {
    param([string]$Path)

    $result = @{
        path = $Path
        exists = $false
        parse_status = "MISSING"
        data = $null
        errors = @()
    }
    if (-not $Path -or $Path.Trim() -eq "") {
        $result.errors += "empty_path"
        return $result
    }
    $full = Resolve-RepoPath -Path $Path
    if (-not (Test-Path -LiteralPath $full)) {
        $result.errors += ("missing:" + $Path)
        return $result
    }
    $result.exists = $true
    try {
        $result.data = Get-Content -Raw -LiteralPath $full | ConvertFrom-Json
        $result.parse_status = "PARSED"
    } catch {
        $result.parse_status = "PARSE_FAILED"
        $result.errors += ("parse_failed:" + $Path + ":" + $_.Exception.Message)
    }
    return $result
}

function New-Target {
    param(
        [string]$TargetId,
        [string]$TargetKind,
        [array]$Refs,
        [string]$SourceKind,
        $SourceObject
    )

    if (-not $TargetId -or $TargetId.Trim() -eq "") {
        $firstRef = ""
        if (@($Refs).Count -gt 0) {
            $firstRef = [string]@($Refs)[0]
        }
        $TargetId = "target_" + (Sanitize-Id -Value ($TargetKind + "_" + $firstRef))
    }
    if (-not $TargetKind -or $TargetKind.Trim() -eq "") {
        $TargetKind = "UNKNOWN_TARGET"
    }
    if (-not $script:Targets.ContainsKey($TargetId)) {
        $script:Targets[$TargetId] = @{
            target_id = $TargetId
            target_kind = $TargetKind
            target_refs = @()
            evidence_refs = @()
            source_kinds = @()
            source_flags = @{
                has_contract_ref = $false
                has_passport_ref = $false
                has_validator_ref = $false
                has_proof_ref = $false
                has_signal_ref = $false
                declared_in_maps = $false
            }
        }
    }

    $target = $script:Targets[$TargetId]
    foreach ($ref in @($Refs)) {
        $normalized = ConvertTo-RepoRelativePath -Path ([string]$ref)
        if ($normalized -and $normalized.Trim() -ne "") {
            $target.target_refs = Add-UniqueString -Values $target.target_refs -Value $normalized
            $target.evidence_refs = Add-UniqueString -Values $target.evidence_refs -Value $normalized
        }
    }
    if ($SourceKind) {
        $target.source_kinds = Add-UniqueString -Values $target.source_kinds -Value $SourceKind
    }
    if ($SourceObject) {
        foreach ($flag in @("has_contract_ref", "has_passport_ref", "has_validator_ref", "has_proof_ref", "has_signal_ref", "declared_in_maps")) {
            $value = Get-PropertyValue -Object $SourceObject -Name $flag
            if ($value -eq $true -or [string]$value -eq "True") {
                $target.source_flags[$flag] = $true
            }
        }
    }
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

function Get-PassportStatus {
    param(
        [bool]$RequiresPassport,
        [array]$PassportRefs,
        [array]$PassportIndexRefs,
        [bool]$ContractPresent,
        [array]$MissingFields,
        [array]$ParseErrors,
        [string]$ValidatorStatus,
        [string]$ProofStatus
    )

    if (@($ParseErrors | Where-Object { $_ -match "passport_parse_failed" }).Count -gt 0) {
        return "PASSPORT_PRESENT_PARSE_FAILED"
    }
    if (@($PassportRefs).Count -eq 0 -and @($PassportIndexRefs).Count -gt 0) {
        return "PASSPORT_INDEX_ONLY"
    }
    if (@($PassportRefs).Count -eq 0 -and $ContractPresent) {
        return "CONTRACT_PRESENT_PASSPORT_MISSING"
    }
    if (@($PassportRefs).Count -eq 0 -and $RequiresPassport) {
        return "PASSPORT_MISSING"
    }
    if (@($PassportRefs).Count -eq 0) {
        return "NOT_ORGAN_NO_PASSPORT_REQUIRED_YET"
    }
    if (@($MissingFields).Count -gt 0) {
        return "PASSPORT_REQUIRED_FIELD_MISSING"
    }
    if (-not $ContractPresent) {
        return "PASSPORT_PRESENT_CONTRACT_MISSING"
    }
    if ($ValidatorStatus -eq "VALIDATOR_PRESENT_AND_REFERENCED" -and $ProofStatus -eq "PROOF_REF_VALID") {
        return "PASSPORT_PRESENT_VALIDATED"
    }
    return "PASSPORT_PRESENT_UNVALIDATED"
}

$inventoryPath = Join-Path $RuntimeRoot "repo_inventory.json"
$bodyMapPath = Join-Path $RuntimeRoot "body_map_read.json"
$capabilityMapPath = Join-Path $RuntimeRoot "capability_map_read.json"
$candidatePath = Join-Path $RuntimeRoot "organ_candidates.json"
$similarityPath = Join-Path $RuntimeRoot "organ_similarity_index.json"
$outputPath = Join-Path $RuntimeRoot "passport_audit.json"

$inventory = Read-JsonFile -Path $inventoryPath
$bodyMap = Read-JsonFile -Path $bodyMapPath
$capabilityMap = Read-JsonFile -Path $capabilityMapPath
$candidates = Read-JsonFile -Path $candidatePath
$similarity = Read-JsonFile -Path $similarityPath

$Targets = @{}

foreach ($candidate in @($candidates.candidates)) {
    $refs = @()
    $refs += ConvertTo-RepoRelativePath -Path ([string](Get-PropertyValue -Object $candidate -Name "primary_path"))
    $refs += @((Get-PropertyValue -Object $candidate -Name "related_paths") | ForEach-Object { ConvertTo-RepoRelativePath -Path ([string]$_) })
    $refs += @((Get-PropertyValue -Object $candidate -Name "evidence_refs") | ForEach-Object { ConvertTo-RepoRelativePath -Path ([string]$_) })
    New-Target -TargetId ([string]$candidate.candidate_id) -TargetKind ([string]$candidate.candidate_type) -Refs $refs -SourceKind "organ_candidates" -SourceObject $candidate
}

foreach ($family in @($candidates.candidate_families)) {
    $familyRoot = [string](Get-PropertyValue -Object $family -Name "family_root")
    if (-not $familyRoot) {
        $familyRoot = [string](Get-PropertyValue -Object $family -Name "family_id")
    }
    if (-not $familyRoot) {
        $familyRoot = [string](Get-PropertyValue -Object $family -Name "name")
    }
    $refs = @()
    foreach ($field in @("primary_path", "related_paths", "member_paths", "evidence_refs")) {
        $value = Get-PropertyValue -Object $family -Name $field
        foreach ($item in @($value)) {
            $refs += ConvertTo-RepoRelativePath -Path ([string]$item)
        }
    }
    New-Target -TargetId ("candidate_family_" + (Sanitize-Id -Value $familyRoot)) -TargetKind "CANDIDATE_FAMILY" -Refs $refs -SourceKind "candidate_families" -SourceObject $family
}

foreach ($record in @($inventory.records)) {
    $role = [string]$record.role_guess
    $path = ConvertTo-RepoRelativePath -Path ([string]$record.normalized_path)
    if ($role -in @("ORGAN_CONTRACT_FILE", "ORGAN_PASSPORT_FILE", "AUTHORITY_PASSPORT_FILE", "CAPABILITY_PASSPORT_FILE", "VALIDATOR_FILE")) {
        $targetKind = $role
        if ($role -eq "VALIDATOR_FILE") {
            $targetKind = "VALIDATOR_CLUSTER_FILE"
        }
        New-Target -TargetId ("surface_" + (Sanitize-Id -Value ($role + "_" + $path))) -TargetKind $targetKind -Refs @($path) -SourceKind "repo_inventory_role" -SourceObject $null
    }
}

foreach ($source in @($bodyMap, $capabilityMap)) {
    foreach ($organ in @($source.declared_organs)) {
        $organId = [string](Get-PropertyValue -Object $organ -Name "declared_organ_id")
        if (-not $organId) {
            $organId = [string](Get-PropertyValue -Object $organ -Name "organ_id")
        }
        $refs = @()
        foreach ($field in @("implementation_refs", "contract_refs", "passport_refs", "validator_refs", "proof_refs", "authority_refs", "signal_refs", "invocation_paths")) {
            foreach ($item in @((Get-PropertyValue -Object $organ -Name $field))) {
                $refs += ConvertTo-RepoRelativePath -Path ([string]$item)
            }
        }
        New-Target -TargetId ("map_declared_organ_" + (Sanitize-Id -Value $organId)) -TargetKind "MAP_DECLARED_ORGAN" -Refs $refs -SourceKind "map_declared_organs" -SourceObject $organ
    }
}

New-Target -TargetId "accepted_atom_retention_organ" -TargetKind "KNOWN_REFERENCE_ORGAN_CANDIDATE" -Refs @(
    "contracts/accepted_atom_retention_organ/passports/ORGAN_PASSPORT.json",
    "contracts/accepted_atom_retention_organ/passports/PASSPORT_INDEX.json",
    "contracts/accepted_atom_retention_organ/passports/CAPABILITY_PASSPORT.json",
    "validators/validate_accepted_atom_retention_passports_v1.ps1"
) -SourceKind "known_reference_surface" -SourceObject $null

New-Target -TargetId "AUTONOMOUS_INNER_MOTOR_ORGAN" -TargetKind "KNOWN_REFERENCE_ORGAN_CANDIDATE" -Refs @(
    "operations/autonomous_inner_motor/organ_contract.json",
    "operations/autonomous_inner_motor/execution_authority_passport_v1.json",
    "validators/validate_autonomous_inner_motor_organ_contract.ps1"
) -SourceKind "known_reference_surface" -SourceObject $null

$requiredPassportConcepts = @{
    organ_id = @("organ_id", "declared_organ_id")
    organ_name = @("organ_name", "name")
    organ_type = @("organ_type", "type", "role")
    purpose = @("purpose")
    capabilities = @("capabilities", "capability_ids")
    input_contract = @("input_contract", "allowed_inputs")
    output_contract = @("output_contract", "allowed_outputs")
    state_touched = @("state_touched", "state_boundaries")
    authority = @("authority", "authority_scope", "execution_authority_passport_v1")
    invocation_contract = @("invocation_contract", "module_path", "single_runner_rule")
    validator_refs = @("validator_refs", "validator_ref", "required_validator_refs")
    proof_refs = @("proof_refs", "proof_ref", "proof_path", "required_proof")
    maturity_status = @("maturity_status", "status", "maturity")
    owner_or_parent_ref = @("owner_or_parent_ref", "owner", "parent_ref")
    rollback_or_quarantine_rule = @("rollback_or_quarantine_rule", "quarantine_rule", "rollback_required")
    last_validated_at_or_evidence_timestamp = @("last_validated_at", "evidence_timestamp", "proof_commit", "checked_at", "generated_at")
}

$contractConcepts = @{
    organ_id = @("organ_id")
    contract_schema = @("contract_schema", "schema")
    mode = @("mode", "allowed_modes")
    allowed_inputs = @("allowed_inputs", "input_contract")
    allowed_outputs = @("allowed_outputs", "output_contract")
    forbidden_actions = @("forbidden_actions", "forbidden")
    state_boundaries = @("state_boundaries")
    memory_boundaries = @("memory_boundaries")
    live_boundaries = @("live_boundaries")
    validator_contract = @("validator_contract", "validator_ref")
    proof_expectations = @("proof_expectations", "proof_ref", "required_proof")
    failure_modes = @("failure_modes")
    quarantine_rule = @("quarantine_rule")
}

$authorityConcepts = @{
    organ_id = @("organ_id")
    authority_scope = @("authority_scope", "authority_classes")
    allowed_actions = @("allowed_actions", "allowed_action_types")
    forbidden_actions = @("forbidden_actions", "hard_denies")
    state_mutation_authority = @("state_mutation_authority")
    live_runtime_authority = @("live_runtime_authority")
    repo_mutation_authority = @("repo_mutation_authority")
    memory_mutation_authority = @("memory_mutation_authority")
    codex_authority = @("codex_authority")
    web_authority = @("web_authority")
    validator_required = @("validator_required", "required_validator_refs")
    proof_required = @("proof_required", "required_proof")
    rollback_required = @("rollback_required")
}

$auditRecords = @()
$errors = @()

foreach ($targetId in @($Targets.Keys | Sort-Object)) {
    $target = $Targets[$targetId]
    $refs = @($target.target_refs | Where-Object { $_ -and $_.Trim() -ne "" } | Select-Object -Unique)
    $passportRefs = @(Get-PathsByPattern -Paths $refs -Pattern "(^|/)ORGAN_PASSPORT\.json$")
    $passportIndexRefs = @(Get-PathsByPattern -Paths $refs -Pattern "(^|/)PASSPORT_INDEX\.json$")
    $capabilityPassportRefs = @(Get-PathsByPattern -Paths $refs -Pattern "(^|/)CAPABILITY_PASSPORT\.json$|capability_passport")
    $contractRefs = @(Get-PathsByPattern -Paths $refs -Pattern "(^|/)organ_contract\.json$|ORGAN_CONTRACT|contract")
    $authorityRefs = @(Get-PathsByPattern -Paths $refs -Pattern "authority_passport|execution_authority_passport")
    $validatorRefs = @(Get-PathsByPattern -Paths $refs -Pattern "(^|/)validators/|(^|/)validate_[^/]+\.ps1$|validator")
    $proofRefs = @(Get-PathsByPattern -Paths $refs -Pattern "proof|_PROOF\.json$")

    $parseErrors = @()
    $missingFields = @()
    $requiredFieldsChecked = @()
    $jsonRefsToRead = @($passportRefs + $passportIndexRefs + $capabilityPassportRefs + $contractRefs + $authorityRefs + $proofRefs | Where-Object { $_ -match "\.json$" } | Select-Object -Unique)
    $parsedJson = @()

    foreach ($jsonRef in @($jsonRefsToRead)) {
        $parsed = Read-JsonMaybe -Path $jsonRef
        $parsedJson += $parsed
        if ($parsed.parse_status -eq "PARSE_FAILED") {
            if ($passportRefs -contains $jsonRef -or $passportIndexRefs -contains $jsonRef -or $capabilityPassportRefs -contains $jsonRef) {
                $parseErrors += ("passport_parse_failed:" + $jsonRef)
            } elseif ($contractRefs -contains $jsonRef) {
                $parseErrors += ("contract_parse_failed:" + $jsonRef)
            } elseif ($authorityRefs -contains $jsonRef) {
                $parseErrors += ("authority_parse_failed:" + $jsonRef)
            } else {
                $parseErrors += ("json_parse_failed:" + $jsonRef)
            }
        }
        if ($parsed.parse_status -eq "PARSED") {
            foreach ($extra in @(Get-ReferencedPathValues -Object $parsed.data -PropertyPattern "(proof|validator|passport|contract|authority|signal|schema).*?(path|ref|refs)?$|.*?(path|ref|refs)$")) {
                if ($extra -match "proof|_PROOF\.json$") {
                    $proofRefs = Add-UniqueString -Values $proofRefs -Value $extra
                }
                if ($extra -match "(^|/)validators/|validate_[^/]+\.ps1$") {
                    $validatorRefs = Add-UniqueString -Values $validatorRefs -Value $extra
                }
                if ($extra -match "contract") {
                    $contractRefs = Add-UniqueString -Values $contractRefs -Value $extra
                }
            }
        }
    }

    foreach ($passportRef in @($passportRefs)) {
        $parsed = $parsedJson | Where-Object { $_.path -eq $passportRef } | Select-Object -First 1
        if ($parsed -and $parsed.parse_status -eq "PARSED") {
            foreach ($concept in @($requiredPassportConcepts.Keys | Sort-Object)) {
                $requiredFieldsChecked += $concept
                if (-not (Test-ConceptPresent -Object $parsed.data -Names $requiredPassportConcepts[$concept])) {
                    $missingFields += $concept
                }
            }
        }
    }

    $contractMissingFields = @()
    foreach ($contractRef in @($contractRefs | Where-Object { $_ -match "\.json$" })) {
        $parsed = $parsedJson | Where-Object { $_.path -eq $contractRef } | Select-Object -First 1
        if ($parsed -and $parsed.parse_status -eq "PARSED") {
            foreach ($concept in @($contractConcepts.Keys | Sort-Object)) {
                if (-not (Test-ConceptPresent -Object $parsed.data -Names $contractConcepts[$concept])) {
                    $contractMissingFields += $concept
                }
            }
        }
    }

    $authorityMissingFields = @()
    foreach ($authorityRef in @($authorityRefs | Where-Object { $_ -match "\.json$" })) {
        $parsed = $parsedJson | Where-Object { $_.path -eq $authorityRef } | Select-Object -First 1
        if ($parsed -and $parsed.parse_status -eq "PARSED") {
            foreach ($concept in @($authorityConcepts.Keys | Sort-Object)) {
                if (-not (Test-ConceptPresent -Object $parsed.data -Names $authorityConcepts[$concept])) {
                    $authorityMissingFields += $concept
                }
            }
        }
    }

    $flags = $target.source_flags
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
    $requiresPassport = ($organLikeKinds -contains [string]$target.target_kind) -or $flags.has_contract_ref -or $flags.has_passport_ref -or $flags.declared_in_maps
    $contractPresent = (@($contractRefs).Count -gt 0) -or $flags.has_contract_ref
    $validatorPresent = (Test-AnyPathExists -Paths $validatorRefs) -or $flags.has_validator_ref
    $proofPresent = (Test-AnyPathExists -Paths $proofRefs) -or $flags.has_proof_ref

    $contractStatus = "CONTRACT_MISSING"
    if (-not $requiresPassport -and -not $contractPresent) {
        $contractStatus = "CONTRACT_NOT_REQUIRED_FOR_NON_ORGAN"
    } elseif ($contractPresent -and @($parseErrors | Where-Object { $_ -match "contract_parse_failed" }).Count -gt 0) {
        $contractStatus = "CONTRACT_PRESENT_PARSE_FAILED"
    } elseif ($contractPresent -and @($contractMissingFields).Count -gt 0) {
        $contractStatus = "CONTRACT_PRESENT_REQUIRED_FIELD_MISSING"
    } elseif ($contractPresent) {
        $contractStatus = "CONTRACT_PRESENT_UNWIRED"
    }

    $authorityStatus = "AUTHORITY_PASSPORT_MISSING"
    if (-not $requiresPassport) {
        $authorityStatus = "AUTHORITY_NOT_REQUIRED_FOR_NON_ORGAN"
    } elseif (@($authorityRefs).Count -gt 0 -and @($parseErrors | Where-Object { $_ -match "authority_parse_failed" }).Count -gt 0) {
        $authorityStatus = "AUTHORITY_PRESENT_PARSE_FAILED"
    } elseif (@($authorityRefs).Count -gt 0 -and @($authorityMissingFields).Count -gt 0) {
        $authorityStatus = "AUTHORITY_REQUIRED_FIELD_MISSING"
    } elseif (@($authorityRefs).Count -gt 0) {
        $authorityStatus = "AUTHORITY_PRESENT_UNVALIDATED"
    }

    $capabilityPassportStatus = "CAPABILITY_PASSPORT_MISSING"
    if (-not $requiresPassport) {
        $capabilityPassportStatus = "CAPABILITY_PASSPORT_NOT_REQUIRED_FOR_NON_ORGAN"
    } elseif (@($capabilityPassportRefs).Count -gt 0 -and @($parseErrors | Where-Object { $_ -match "passport_parse_failed" }).Count -gt 0) {
        $capabilityPassportStatus = "CAPABILITY_PASSPORT_PARSE_FAILED"
    } elseif (@($capabilityPassportRefs).Count -gt 0) {
        $capabilityPassportStatus = "CAPABILITY_PASSPORT_PRESENT_UNVALIDATED"
    }

    $validatorStatus = "VALIDATOR_UNKNOWN"
    if ($validatorPresent -and $contractPresent) {
        $validatorStatus = "VALIDATOR_PRESENT_AND_REFERENCED"
    } elseif ($validatorPresent -and -not $contractPresent) {
        $validatorStatus = "VALIDATOR_CLUSTER_FOUND_NO_CONTRACT"
    } elseif (-not $validatorPresent -and $requiresPassport) {
        $validatorStatus = "VALIDATOR_MISSING"
    }

    $proofStatus = "PROOF_UNKNOWN"
    if (@($proofRefs).Count -gt 0) {
        $missingProofRefs = @()
        $parseFailedProofRefs = @()
        foreach ($proofRef in @($proofRefs | Select-Object -Unique)) {
            if ($proofRef -match "\.json$") {
                $parsedProof = Read-JsonMaybe -Path $proofRef
                if (-not $parsedProof.exists) {
                    $missingProofRefs += $proofRef
                } elseif ($parsedProof.parse_status -eq "PARSE_FAILED") {
                    $parseFailedProofRefs += $proofRef
                }
            } elseif (-not (Test-Path -LiteralPath (Resolve-RepoPath -Path $proofRef))) {
                $missingProofRefs += $proofRef
            }
        }
        if (@($missingProofRefs).Count -gt 0) {
            $proofStatus = "PROOF_REF_BROKEN"
        } elseif (@($parseFailedProofRefs).Count -gt 0) {
            $proofStatus = "PROOF_REF_PARSE_FAILED"
        } else {
            $proofStatus = "PROOF_REF_VALID"
        }
    } elseif ($requiresPassport) {
        $proofStatus = "PROOF_REF_MISSING"
    }

    $passportStatus = Get-PassportStatus -RequiresPassport $requiresPassport -PassportRefs $passportRefs -PassportIndexRefs $passportIndexRefs -ContractPresent $contractPresent -MissingFields $missingFields -ParseErrors $parseErrors -ValidatorStatus $validatorStatus -ProofStatus $proofStatus

    $painCandidates = @()
    if ($passportStatus -in @("PASSPORT_MISSING", "CONTRACT_PRESENT_PASSPORT_MISSING")) {
        $painCandidates += "organ_missing_passport"
    }
    if ($passportStatus -eq "PASSPORT_REQUIRED_FIELD_MISSING") {
        $painCandidates += "passport_missing_required_field"
    }
    if ($passportStatus -eq "PASSPORT_PRESENT_PARSE_FAILED") {
        $painCandidates += "passport_parse_failed"
    }
    if ($contractStatus -eq "CONTRACT_MISSING" -and $requiresPassport) {
        $painCandidates += "organ_contract_missing"
    }
    if ($contractStatus -eq "CONTRACT_PRESENT_PARSE_FAILED") {
        $painCandidates += "organ_contract_parse_failed"
    }
    if ($authorityStatus -eq "AUTHORITY_PASSPORT_MISSING" -and $requiresPassport) {
        $painCandidates += "authority_passport_missing"
    }
    if ($capabilityPassportStatus -eq "CAPABILITY_PASSPORT_MISSING" -and $requiresPassport) {
        $painCandidates += "capability_passport_missing"
    }
    if ($validatorStatus -eq "VALIDATOR_MISSING") {
        $painCandidates += "validator_referenced_missing"
    }
    if ($proofStatus -eq "PROOF_REF_BROKEN") {
        $painCandidates += "proof_ref_broken"
    }
    if ($proofStatus -eq "PROOF_REF_MISSING") {
        $painCandidates += "proof_ref_missing"
    }

    $recommended = "monitor_only"
    if ($passportStatus -in @("PASSPORT_MISSING", "CONTRACT_PRESENT_PASSPORT_MISSING")) {
        $recommended = "create_passport_requirement_draft"
    } elseif ($contractStatus -eq "CONTRACT_MISSING" -and $requiresPassport) {
        $recommended = "create_contract_requirement_draft"
    } elseif ($validatorStatus -eq "VALIDATOR_MISSING") {
        $recommended = "create_validator_requirement_draft"
    } elseif ($passportStatus -eq "PASSPORT_REQUIRED_FIELD_MISSING") {
        $recommended = "compare_existing_passport_schema"
    } elseif (-not $requiresPassport) {
        $recommended = "mark_not_organ_candidate"
    }

    $auditRecords += @{
        audit_id = "passport_audit_" + (Sanitize-Id -Value $targetId)
        target_id = $targetId
        target_kind = $target.target_kind
        target_refs = @($refs)
        passport_status = $passportStatus
        contract_status = $contractStatus
        authority_status = $authorityStatus
        capability_passport_status = $capabilityPassportStatus
        validator_status = $validatorStatus
        proof_status = $proofStatus
        required_fields_checked = @($requiredFieldsChecked | Select-Object -Unique)
        missing_fields = @($missingFields | Select-Object -Unique)
        parse_errors = @($parseErrors | Select-Object -Unique)
        evidence_refs = @($target.evidence_refs | Select-Object -Unique)
        pain_candidates = @($painCandidates | Select-Object -Unique)
        recommended_logic_action = $recommended
        forbidden_now = @(
            "claim organ mature",
            "wire organ",
            "mutate body map",
            "auto-create passport without proof",
            "delete candidate"
        )
        source_kinds = @($target.source_kinds | Select-Object -Unique)
        boundary_flags = @{
            passport_presence_claims_maturity = $false
            contract_presence_claims_wiring = $false
            candidate_promoted_to_organ = $false
        }
    }
}

$passportStatusCounts = @{}
$validatorStatusCounts = @{}
$proofStatusCounts = @{}
foreach ($record in @($auditRecords)) {
    foreach ($pair in @(
        @{ table = $passportStatusCounts; value = $record.passport_status },
        @{ table = $validatorStatusCounts; value = $record.validator_status },
        @{ table = $proofStatusCounts; value = $record.proof_status }
    )) {
        $table = $pair.table
        $value = [string]$pair.value
        if (-not $table.ContainsKey($value)) {
            $table[$value] = 0
        }
        $table[$value] = [int]$table[$value] + 1
    }
}

$output = @{
    schema = "body_self_inspection_passport_contract_audit_v1"
    status = "PASS_BODY_SELF_INSPECTION_PASSPORT_CONTRACT_AUDIT_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "C"
    source_refs = @{
        repo_inventory = $inventoryPath
        body_map_read = $bodyMapPath
        capability_map_read = $capabilityMapPath
        organ_candidates = $candidatePath
        organ_similarity_index = $similarityPath
    }
    law_reference_surfaces = @(
        "contracts/accepted_atom_retention_organ/passports/ORGAN_PASSPORT.json",
        "contracts/accepted_atom_retention_organ/passports/PASSPORT_INDEX.json",
        "contracts/accepted_atom_retention_organ/passports/CAPABILITY_PASSPORT.json",
        "operations/autonomous_inner_motor/organ_contract.json",
        "operations/autonomous_inner_motor/execution_authority_passport_v1.json",
        "validators/validate_accepted_atom_retention_passports_v1.ps1",
        "validators/validate_autonomous_inner_motor_organ_contract.ps1"
    )
    audit_records = @($auditRecords)
    aggregates = @{
        target_count = @($auditRecords).Count
        passport_status_counts = $passportStatusCounts
        validator_status_counts = $validatorStatusCounts
        proof_status_counts = $proofStatusCounts
        pain_candidate_count = @($auditRecords | Where-Object { @($_.pain_candidates).Count -gt 0 }).Count
        similarity_record_count_seen = $similarity.aggregates.similarity_record_count
    }
    boundary_statement = @{
        passport_present = "PASSPORT_PRESENT != PASSPORT_VALIDATED"
        passport_validated = "PASSPORT_VALIDATED != ORGAN_MATURE"
        contract_present = "CONTRACT_PRESENT != ORGAN_WIRED"
    }
    boundary_claims = @{
        passport_presence_claims_maturity = $false
        contract_presence_claims_wiring = $false
        candidate_promoted_to_organ = $false
    }
    boundary = New-BodyInspectionBoundary
    errors = @($errors)
}

Write-JsonFile -Path $outputPath -Data $output
Write-Output $outputPath
