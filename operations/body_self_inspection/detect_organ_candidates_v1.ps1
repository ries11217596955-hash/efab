param(
    [string]$RepoRoot,
    [string]$RuntimeRoot,
    [string]$InventoryPath,
    [string]$BodyMapPath,
    [string]$CapabilityMapPath
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

if (-not $InventoryPath -or $InventoryPath.Trim() -eq "") {
    $InventoryPath = Join-Path $RuntimeRoot "repo_inventory.json"
}
if (-not $BodyMapPath -or $BodyMapPath.Trim() -eq "") {
    $BodyMapPath = Join-Path $RuntimeRoot "body_map_read.json"
}
if (-not $CapabilityMapPath -or $CapabilityMapPath.Trim() -eq "") {
    $CapabilityMapPath = Join-Path $RuntimeRoot "capability_map_read.json"
}

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

function Add-UniqueString {
    param(
        [ref]$List,
        [string]$Value
    )

    if (-not $Value -or $Value.Trim() -eq "") {
        return
    }

    $text = $Value.Trim()
    foreach ($existing in @($List.Value)) {
        if ([string]$existing -eq $text) {
            return
        }
    }
    $List.Value += $text
}

function Get-NormalizedStem {
    param([string]$Text)

    if (-not $Text) {
        return "unknown"
    }

    $stem = $Text.ToLowerInvariant()
    $stem = $stem -replace "\\", "/"
    $stem = Split-Path -Leaf $stem
    $stem = $stem -replace "\.(ps1|json|md|py|js|ts)$", ""
    $stem = $stem -replace "^(invoke|validate|run|build|detect|read|update|emit|audit|select|reconcile|generate|create)_", ""
    $stem = $stem -replace "_(runtime|validator|validation|proof|policy|index|contract)$", ""
    $stem = $stem -replace "_v[0-9]+(_[0-9]+)?$", ""
    $stem = $stem -replace "_slice_[a-z]$", ""
    $stem = $stem -replace "[^a-z0-9]+", "_"
    $stem = $stem.Trim("_")
    while ($stem.Contains("__")) {
        $stem = $stem.Replace("__", "_")
    }
    if (-not $stem) {
        return "unknown"
    }
    return $stem
}

function Get-FamilyKey {
    param([string]$Path)

    $lower = $Path.ToLowerInvariant() -replace "\\", "/"
    if ($lower -match "^operations/([^/]+)/") {
        return $Matches[1]
    }
    if ($lower -match "^contracts/([^/]+)/") {
        return $Matches[1]
    }
    if ($lower -match "^modules/invoke_(.+)\.ps1$") {
        return (Get-NormalizedStem -Text $Matches[1])
    }
    if ($lower -match "^validators/validate_(.+)\.ps1$") {
        return (Get-NormalizedStem -Text $Matches[1])
    }
    if ($lower -match "^tests/self_development/(.+)_proof\.json$") {
        return (Get-NormalizedStem -Text $Matches[1])
    }
    if ($lower -match "^orchestrator/") {
        return "orchestrator"
    }
    if ($lower -match "^packs/") {
        return "packs_registry"
    }
    return (Get-NormalizedStem -Text $Path)
}

function Get-CandidateType {
    param(
        [array]$Paths,
        [array]$RoleGuesses,
        [string]$FamilyKey
    )

    $joined = (($Paths + $RoleGuesses + @($FamilyKey)) -join " ").ToLowerInvariant()
    if ($joined -match "organ_contract|organ_contract_file") {
        return "ORGAN_CONTRACT_CANDIDATE"
    }
    if ($joined -match "authority.*passport|authority_passport_file") {
        return "AUTHORITY_PASSPORT_CANDIDATE"
    }
    if ($joined -match "capability.*passport|organ_passport_file|passport") {
        return "CAPABILITY_PASSPORT_CANDIDATE"
    }
    if ($joined -match "validator|validate_") {
        return "VALIDATOR_CLUSTER_CANDIDATE"
    }
    if ($joined -match "proof") {
        return "PROOF_PRODUCER_CANDIDATE"
    }
    if ($joined -match "map|registry|index|roadmap") {
        return "MAP_TOOL_CANDIDATE"
    }
    if ($joined -match "memory|retention|compact") {
        return "MEMORY_TOOL_CANDIDATE"
    }
    if ($joined -match "runtime|school|inner_motor|orchestrator") {
        return "RUNTIME_TOOL_CANDIDATE"
    }
    if ($joined -match "signal") {
        return "SIGNAL_TOOL_CANDIDATE"
    }
    if ($joined -match "\.ps1") {
        return "ORGAN_SCRIPT_CANDIDATE"
    }
    if ($joined -match "^operations/") {
        return "ORGAN_FOLDER_CANDIDATE"
    }
    return "UNKNOWN_BODY_SURFACE_CANDIDATE"
}

function Get-StateTouchedGuess {
    param([array]$Paths)

    $joined = ($Paths -join " ").ToLowerInvariant()
    $states = @()
    if ($joined -match "active_compact|active_memory|accepted_atom_retention|memory") {
        $states += "memory_surface_guess"
    }
    if ($joined -match "runtime|\.runtime|runner|school") {
        $states += "runtime_surface_guess"
    }
    if ($joined -match "map|roadmap|registry|queue") {
        $states += "map_surface_guess"
    }
    if ($joined -match "accepted-core|accepted_core") {
        $states += "accepted_core_surface_guess"
    }
    if ($states.Count -eq 0) {
        $states += "unknown_state_touch"
    }
    return $states
}

function Test-IsCandidateSource {
    param($Record)

    if ([string]$Record.kind -ne "file") {
        return $false
    }

    $path = ([string]$Record.normalized_path).ToLowerInvariant()
    $role = [string]$Record.role_guess
    if (@("ORGAN_CANDIDATE_SCRIPT", "ORGAN_CONTRACT_FILE", "ORGAN_PASSPORT_FILE", "AUTHORITY_PASSPORT_FILE", "VALIDATOR_FILE", "PROOF_JSON", "MAP_FILE", "CAPABILITY_MAP_FILE", "ORGAN_REGISTRY_FILE") -contains $role) {
        return $true
    }
    if ($path -like "modules/invoke_*.ps1" -or $path -like "orchestrator/*.ps1") {
        return $true
    }
    if ($path -like "operations/*/*.ps1" -or $path -like "operations/*/organ_contract.json" -or $path -like "operations/*/*passport*.json") {
        return $true
    }
    if ($path -like "validators/validate_*_organ*.ps1" -or $path -like "validators/validate_*_wiring*.ps1") {
        return $true
    }
    if ($path -like "contracts/*/organ_passport.json" -or $path -like "contracts/*/capability_passport.json") {
        return $true
    }
    if ($path -like "*_proof.json" -or $path -like "*proof*.json") {
        return $true
    }
    return $false
}

function Get-MapDeclarationStrings {
    param(
        $BodyMap,
        $CapabilityMap
    )

    $strings = @()
    foreach ($source in @($BodyMap, $CapabilityMap)) {
        foreach ($record in @($source.map_records)) {
            Add-UniqueString -List ([ref]$strings) -Value ([string]$record.path)
            foreach ($value in @($record.declared_invocation_paths + $record.declared_validators + $record.declared_proof_refs + $record.declared_passport_refs + $record.declared_signal_refs)) {
                Add-UniqueString -List ([ref]$strings) -Value ([string]$value)
            }
            foreach ($organ in @($record.declared_organs)) {
                Add-UniqueString -List ([ref]$strings) -Value ([string]$organ.declared_organ_id)
                Add-UniqueString -List ([ref]$strings) -Value ([string]$organ.name)
            }
            foreach ($capability in @($record.declared_capabilities)) {
                Add-UniqueString -List ([ref]$strings) -Value ([string]$capability.capability_id)
                Add-UniqueString -List ([ref]$strings) -Value ([string]$capability.name)
            }
        }
    }
    return $strings
}

if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
}

$inventory = Read-JsonFile -Path $InventoryPath
$bodyMap = Read-JsonFile -Path $BodyMapPath
$capabilityMap = Read-JsonFile -Path $CapabilityMapPath
$generatedAt = (Get-Date).ToUniversalTime().ToString("o")
$mapDeclarationStrings = @(Get-MapDeclarationStrings -BodyMap $bodyMap -CapabilityMap $capabilityMap)
$mapDeclarationJoined = ($mapDeclarationStrings -join " ").ToLowerInvariant()

$families = @{}
foreach ($record in @($inventory.records)) {
    if (-not (Test-IsCandidateSource -Record $record)) {
        continue
    }

    $path = [string]$record.normalized_path
    $familyKey = Get-FamilyKey -Path $path
    if (-not $families.ContainsKey($familyKey)) {
        $families[$familyKey] = @{
            family_key = $familyKey
            paths = @()
            role_guesses = @()
            discovered_from = @("repo_inventory")
        }
    }

    if (-not (@($families[$familyKey].paths) -contains $path)) {
        $families[$familyKey].paths = @($families[$familyKey].paths) + $path
    }
    $roleGuess = [string]$record.role_guess
    if ($roleGuess -and -not (@($families[$familyKey].role_guesses) -contains $roleGuess)) {
        $families[$familyKey].role_guesses = @($families[$familyKey].role_guesses) + $roleGuess
    }
}

$candidates = @()
$candidateFamilies = @()
foreach ($key in @($families.Keys | Sort-Object)) {
    $family = $families[$key]
    $paths = @($family.paths | Sort-Object)
    if ($paths.Count -eq 0) {
        continue
    }

    $primaryPath = $paths[0]
    foreach ($path in $paths) {
        if ($path -like "operations/*/*.ps1" -or $path -like "modules/invoke_*.ps1" -or $path -like "orchestrator/*.ps1") {
            $primaryPath = $path
            break
        }
    }

    $candidateType = Get-CandidateType -Paths $paths -RoleGuesses $family.role_guesses -FamilyKey $key
    $nameGuess = Get-NormalizedStem -Text $key
    $capabilityGuess = ($nameGuess -replace "_", " ")
    $joined = ($paths -join " ").ToLowerInvariant()
    $declaredInMaps = $false
    if ($mapDeclarationJoined.Contains($nameGuess.ToLowerInvariant()) -or $mapDeclarationJoined.Contains($primaryPath.ToLowerInvariant())) {
        $declaredInMaps = $true
    }

    $hasContractRef = ($joined -match "contract")
    $hasPassportRef = ($joined -match "passport")
    $hasValidatorRef = ($joined -match "validators/validate_|validate_")
    $hasProofRef = ($joined -match "proof")
    $hasInvocationRef = ($joined -match "\.ps1")
    $hasSignalRef = ($joined -match "signal")

    $confidence = "LOW_NAME_PATTERN_ONLY"
    if ($hasContractRef) {
        $confidence = "HIGH_CONTRACT_BACKED"
    } elseif ($hasValidatorRef) {
        $confidence = "MEDIUM_VALIDATOR_BACKED"
    } elseif ($declaredInMaps) {
        $confidence = "MEDIUM_MAP_DECLARED"
    } elseif ($candidateType -eq "ORGAN_FOLDER_CANDIDATE") {
        $confidence = "LOW_DIRECTORY_PATTERN_ONLY"
    } elseif ($candidateType -eq "UNKNOWN_BODY_SURFACE_CANDIDATE") {
        $confidence = "UNKNOWN"
    }

    $warnings = @(
        "ORGAN_CANDIDATE != ORGAN",
        "SCRIPT != ORGAN",
        "VALIDATOR != ORGAN",
        "PASSPORT != ORGAN",
        "PROOF_PRODUCER != ORGAN"
    )
    if (-not $hasContractRef) {
        $warnings += "missing_contract_ref_or_not_detected"
    }
    if (-not $hasPassportRef) {
        $warnings += "missing_passport_ref_or_not_detected"
    }

    $candidateId = "candidate_" + (Get-NormalizedStem -Text ($candidateType + "_" + $key))
    $candidate = @{
        candidate_id = $candidateId
        candidate_type = $candidateType
        primary_path = $primaryPath
        related_paths = @($paths)
        family_root = $key
        name_guess = $nameGuess
        capability_guess = $capabilityGuess
        role_guess = ($family.role_guesses -join ";")
        evidence_refs = @($paths)
        confidence = $confidence
        discovered_from = @($family.discovered_from)
        declared_in_maps = $declaredInMaps
        has_contract_ref = $hasContractRef
        has_passport_ref = $hasPassportRef
        has_validator_ref = $hasValidatorRef
        has_proof_ref = $hasProofRef
        has_invocation_ref = $hasInvocationRef
        has_signal_ref = $hasSignalRef
        state_touched_guess = @(Get-StateTouchedGuess -Paths $paths)
        authority_guess = $(if ($joined -match "authority") { "AUTHORITY_REF_PRESENT" } else { "NO_AUTHORITY_PROOF" })
        maturity_guess = "CANDIDATE_ONLY_NOT_ORGAN"
        warnings = @($warnings)
    }

    $candidates += $candidate
    $candidateFamilies += @{
        family_id = "family_" + (Get-NormalizedStem -Text $key)
        family_root = $key
        candidate_ids = @($candidateId)
        related_paths = @($paths)
        grouping_evidence = @("normalized_name_stem", "directory_or_role_cluster")
        has_multiple_paths = ($paths.Count -gt 1)
    }
}

$typeCounts = @{}
$confidenceCounts = @{}
$multiPathFamilies = 0
foreach ($candidate in @($candidates)) {
    $type = [string]$candidate.candidate_type
    if (-not $typeCounts.ContainsKey($type)) {
        $typeCounts[$type] = 0
    }
    $typeCounts[$type] = $typeCounts[$type] + 1

    $confidence = [string]$candidate.confidence
    if (-not $confidenceCounts.ContainsKey($confidence)) {
        $confidenceCounts[$confidence] = 0
    }
    $confidenceCounts[$confidence] = $confidenceCounts[$confidence] + 1
}
foreach ($family in @($candidateFamilies)) {
    if ($family.has_multiple_paths) {
        $multiPathFamilies++
    }
}

$output = @{
    schema = "organ_candidates_v1"
    status = "PASS_ORGAN_CANDIDATE_DETECTION_V1"
    generated_at = $generatedAt
    source_refs = @{
        repo_inventory = $InventoryPath
        body_map_read = $BodyMapPath
        capability_map_read = $CapabilityMapPath
    }
    candidates = @($candidates)
    candidate_families = @($candidateFamilies)
    aggregates = @{
        candidate_count = @($candidates).Count
        candidate_family_count = @($candidateFamilies).Count
        multi_path_family_count = $multiPathFamilies
        candidate_type_counts = $typeCounts
        confidence_counts = $confidenceCounts
        declared_in_maps_count = @($candidates | Where-Object { $_.declared_in_maps -eq $true }).Count
    }
    boundary_note = @{
        candidate_boundary = "ORGAN_CANDIDATE != ORGAN"
        script_boundary = "SCRIPT != ORGAN"
        validator_boundary = "VALIDATOR != ORGAN"
        passport_boundary = "PASSPORT != ORGAN"
        proof_boundary = "PROOF_PRODUCER != ORGAN"
    }
    stale_after = "24h"
    boundary = New-BodyInspectionBoundary
    errors = @()
}

$outputPath = Join-Path $RuntimeRoot "organ_candidates.json"
Write-JsonFile -Path $outputPath -Data $output
Write-Output $outputPath
