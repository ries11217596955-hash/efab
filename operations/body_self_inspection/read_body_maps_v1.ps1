param(
    [string]$RepoRoot,
    [string]$RuntimeRoot,
    [string]$InventoryPath
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

function Get-PropertyValue {
    param(
        $Object,
        [string]$Name
    )

    if (Test-HasProperty -Object $Object -Name $Name) {
        return $Object.$Name
    }
    return $null
}

function Get-NormalizedId {
    param([string]$Text)

    if (-not $Text) {
        return ""
    }

    $value = $Text.ToLowerInvariant()
    $value = $value -replace "\\", "/"
    $value = $value -replace "\.[a-z0-9]+$", ""
    $value = $value -replace "[^a-z0-9]+", "_"
    $value = $value.Trim("_")
    while ($value.Contains("__")) {
        $value = $value.Replace("__", "_")
    }
    return $value
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

function Add-UniqueObjectById {
    param(
        [ref]$List,
        $Object,
        [string]$IdField
    )

    if ($null -eq $Object) {
        return
    }

    $id = [string](Get-PropertyValue -Object $Object -Name $IdField)
    foreach ($existing in @($List.Value)) {
        $existingId = [string](Get-PropertyValue -Object $existing -Name $IdField)
        if ($existingId -eq $id) {
            return
        }
    }
    $List.Value += $Object
}

function Get-AllStringValues {
    param($Node)

    $values = @()
    if ($null -eq $Node) {
        return $values
    }

    if ($Node -is [string]) {
        return @($Node)
    }

    if ($Node -is [System.ValueType]) {
        return @([string]$Node)
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in @($Node)) {
            $values += @(Get-AllStringValues -Node $item)
        }
        return $values
    }

    foreach ($property in @($Node.PSObject.Properties)) {
        $values += @([string]$property.Name)
        $values += @(Get-AllStringValues -Node $property.Value)
    }

    return $values
}

function Get-StringsMatching {
    param(
        $Node,
        [string]$Pattern
    )

    $matches = @()
    foreach ($value in @(Get-AllStringValues -Node $Node)) {
        if ($value -match $Pattern) {
            Add-UniqueString -List ([ref]$matches) -Value $value
        }
    }
    return $matches
}

function Get-FirstPresentProperty {
    param(
        $Object,
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $value = Get-PropertyValue -Object $Object -Name $name
        if ($null -ne $value -and ([string]$value).Trim() -ne "") {
            return [string]$value
        }
    }
    return $null
}

function Get-MapType {
    param(
        [string]$Path,
        [string]$RoleGuess
    )

    $lower = $Path.ToLowerInvariant()
    if ($lower -eq "capability_roadmap.json" -or $lower -like "*capability*map*" -or $RoleGuess -eq "CAPABILITY_MAP_FILE") {
        return "CAPABILITY_MAP"
    }
    if ($lower -eq "genesis_state.json" -or $lower -like "*body*map*" -or $lower -like "*self*model*map*" -or $lower -like "*composition*map*") {
        return "BODY_MAP"
    }
    if ($lower -eq "packs/registry.json" -or $lower -like "*organ*registry*" -or $RoleGuess -eq "ORGAN_REGISTRY_FILE") {
        return "ORGAN_REGISTRY"
    }
    if ($lower -like "*invocation*map*" -or $lower -eq "task_queue.json") {
        return "INVOCATION_MAP"
    }
    if ($lower -eq "orchestrator/run.ps1" -or $lower -like "*launch*map*") {
        return "LAUNCH_MAP"
    }
    if ($lower -like "*passport*index*") {
        return "PASSPORT_INDEX"
    }
    if ($lower -like "*validator*index*") {
        return "VALIDATOR_INDEX"
    }
    if ($lower -like "*proof*index*") {
        return "PROOF_INDEX"
    }
    if ($lower -like "*signal*index*" -or $lower -like "*signal*map*") {
        return "SIGNAL_INDEX"
    }
    if ($lower -like "*handoff*") {
        return "HANDOFF_STATUS_POINTER"
    }
    return "UNKNOWN_MAP_LIKE"
}

function Test-IsMapLikePath {
    param(
        [string]$Path,
        [string]$RoleGuess
    )

    $lower = $Path.ToLowerInvariant()
    $rootMarkers = @(
        "capability_roadmap.json",
        "genesis_state.json",
        "task_queue.json",
        "packs/registry.json",
        "orchestrator/run.ps1",
        "operations/gpt_handoff/next_chat_handoff_20260716_mind_logic_status.json",
        "operations/gpt_handoff/next_chat_handoff_20260716_mind_logic.md"
    )

    if ($rootMarkers -contains $lower) {
        return $true
    }

    if (@("MAP_FILE", "CAPABILITY_MAP_FILE", "ORGAN_REGISTRY_FILE", "REPAIR_DRAFT_BOARD", "BODY_PAIN_REGISTER", "HANDOFF_POINTER") -contains $RoleGuess) {
        return $true
    }

    $mapNamePatterns = @(
        "body*map",
        "capability*map",
        "composition*map",
        "organ*registry",
        "invocation*map",
        "launch*map",
        "passport*index",
        "validator*index",
        "proof*index",
        "signal*index",
        "draft*board",
        "pain*register"
    )

    $leaf = Split-Path -Leaf $lower
    foreach ($pattern in $mapNamePatterns) {
        if ($leaf -like $pattern -or $lower -like ("*" + $pattern + "*")) {
            return $true
        }
    }

    return $false
}

function New-DeclaredOrgan {
    param(
        [string]$Id,
        [string]$Name,
        [string]$SourceMapRef,
        [string[]]$ImplementationRefs,
        [string[]]$ContractRefs,
        [string[]]$PassportRefs,
        [string[]]$ValidatorRefs,
        [string[]]$ProofRefs,
        [string[]]$Capabilities,
        [string[]]$InvocationPaths,
        [string[]]$SignalRefs
    )

    $declaredId = Get-NormalizedId -Text $Id
    if (-not $declaredId) {
        $declaredId = Get-NormalizedId -Text $Name
    }

    return @{
        declared_organ_id = $declaredId
        name = $Name
        source_map_ref = $SourceMapRef
        implementation_refs = @($ImplementationRefs)
        contract_refs = @($ContractRefs)
        passport_refs = @($PassportRefs)
        validator_refs = @($ValidatorRefs)
        proof_refs = @($ProofRefs)
        capabilities = @($Capabilities)
        invocation_paths = @($InvocationPaths)
        state_touched = @()
        authority_refs = @()
        signal_refs = @($SignalRefs)
        lifecycle_status = "DECLARED_ONLY_UNPROVEN"
        evidence_status = "MAP_DECLARATION_NOT_PROOF"
    }
}

function New-DeclaredCapability {
    param(
        [string]$Id,
        [string]$Name,
        [string]$SourceMapRef,
        [string[]]$OwningOrganRefs,
        [string[]]$InvocationRefs,
        [string[]]$ValidatorRefs,
        [string[]]$ProofRefs
    )

    $capabilityId = Get-NormalizedId -Text $Id
    if (-not $capabilityId) {
        $capabilityId = Get-NormalizedId -Text $Name
    }

    return @{
        capability_id = $capabilityId
        name = $Name
        source_map_ref = $SourceMapRef
        owning_organ_refs = @($OwningOrganRefs)
        invocation_refs = @($InvocationRefs)
        validator_refs = @($ValidatorRefs)
        proof_refs = @($ProofRefs)
        input_contract = $null
        output_contract = $null
        state_touched = @()
        maturity_status = "DECLARED_ONLY_NOT_USABLE"
        evidence_status = "MAP_DECLARATION_NOT_PROOF"
    }
}

function New-MapRecord {
    param(
        [string]$Path,
        [string]$MapType,
        [string]$ParseStatus,
        [string]$Schema,
        [string]$Status,
        [array]$DeclaredOrgans,
        [array]$DeclaredCapabilities,
        [array]$DeclaredInvocationPaths,
        [array]$DeclaredValidators,
        [array]$DeclaredProofRefs,
        [array]$DeclaredPassportRefs,
        [array]$DeclaredSignalRefs,
        [string]$LastUpdatedIfPresent,
        [string]$EvidenceStatus,
        [array]$Errors
    )

    return @{
        path = $Path
        map_type = $MapType
        parse_status = $ParseStatus
        schema = $Schema
        status = $Status
        declared_organs = @($DeclaredOrgans)
        declared_capabilities = @($DeclaredCapabilities)
        declared_invocation_paths = @($DeclaredInvocationPaths)
        declared_validators = @($DeclaredValidators)
        declared_proof_refs = @($DeclaredProofRefs)
        declared_passport_refs = @($DeclaredPassportRefs)
        declared_signal_refs = @($DeclaredSignalRefs)
        stale_after = "24h"
        last_updated_if_present = $LastUpdatedIfPresent
        evidence_status = $EvidenceStatus
        errors = @($Errors)
    }
}

function Read-MapSurface {
    param(
        [string]$Path,
        $InventoryRecord,
        [bool]$Exists
    )

    $roleGuess = ""
    if ($InventoryRecord) {
        $roleGuess = [string]$InventoryRecord.role_guess
    }

    $mapType = Get-MapType -Path $Path -RoleGuess $roleGuess
    if (-not $Exists) {
        return (New-MapRecord -Path $Path -MapType $mapType -ParseStatus "MISSING" -Schema $null -Status "MISSING" -DeclaredOrgans @() -DeclaredCapabilities @() -DeclaredInvocationPaths @() -DeclaredValidators @() -DeclaredProofRefs @() -DeclaredPassportRefs @() -DeclaredSignalRefs @() -LastUpdatedIfPresent $null -EvidenceStatus "MISSING_NOT_PROOF" -Errors @("map-like surface missing"))
    }

    $fullPath = Join-Path $RepoRoot ($Path -replace "/", "\")
    $errors = @()
    $schema = $null
    $status = $null
    $lastUpdated = $null
    $parseStatus = "READ_TEXT"
    $declaredOrgans = @()
    $declaredCapabilities = @()
    $invocationRefs = @()
    $validatorRefs = @()
    $proofRefs = @()
    $passportRefs = @()
    $signalRefs = @()
    $implementationRefs = @()

    try {
        $item = Get-Item -LiteralPath $fullPath
        if ($item.Length -gt 262144) {
            return (New-MapRecord -Path $Path -MapType $mapType -ParseStatus "METADATA_ONLY_SIZE_LIMIT" -Schema $null -Status "CONTENT_NOT_READ" -DeclaredOrgans @() -DeclaredCapabilities @() -DeclaredInvocationPaths @() -DeclaredValidators @() -DeclaredProofRefs @() -DeclaredPassportRefs @() -DeclaredSignalRefs @() -LastUpdatedIfPresent $item.LastWriteTimeUtc.ToString("o") -EvidenceStatus "MAP_SURFACE_METADATA_ONLY_NOT_PROOF" -Errors @("content above map reader size limit"))
        }

        $text = Get-Content -Raw -LiteralPath $fullPath
        $lastUpdated = $item.LastWriteTimeUtc.ToString("o")

        if ($Path.ToLowerInvariant().EndsWith(".json")) {
            try {
                $json = $text | ConvertFrom-Json
                $parseStatus = "PARSED_JSON"
                $schema = Get-FirstPresentProperty -Object $json -Names @("schema", "schema_version", "version")
                $status = Get-FirstPresentProperty -Object $json -Names @("status", "state", "lifecycle_status")
                $lastUpdatedJson = Get-FirstPresentProperty -Object $json -Names @("last_updated", "updated_at", "generated_at", "created_at")
                if ($lastUpdatedJson) {
                    $lastUpdated = $lastUpdatedJson
                }

                $invocationRefs = @(Get-StringsMatching -Node $json -Pattern "(?i)(^|/|\\)(operations|modules|orchestrator)(/|\\).*\.(ps1|py|js|ts)$|\.ps1$")
                $validatorRefs = @(Get-StringsMatching -Node $json -Pattern "(?i)(^|/|\\)validators(/|\\).*validate_.*\.ps1$")
                $proofRefs = @(Get-StringsMatching -Node $json -Pattern "(?i)proof.*\.json$|_proof\.json$")
                $passportRefs = @(Get-StringsMatching -Node $json -Pattern "(?i)passport.*\.(json|md)$")
                $signalRefs = @(Get-StringsMatching -Node $json -Pattern "(?i)signal")
                $implementationRefs = @(Get-StringsMatching -Node $json -Pattern "(?i)(^|/|\\)(operations|modules|orchestrator)(/|\\).*\.(ps1|py|js|ts)$")

                $organStrings = @(Get-StringsMatching -Node $json -Pattern "(?i)(^|[_\-/ ])organ([_\-/ ]|$)|organ_id|organ_ref|organ_name")
                foreach ($organText in @($organStrings | Select-Object -First 80)) {
                    $organId = Get-NormalizedId -Text $organText
                    if ($organId -and $organId -ne "organ" -and $organId.Length -gt 4) {
                        $organ = New-DeclaredOrgan -Id $organId -Name $organText -SourceMapRef $Path -ImplementationRefs $implementationRefs -ContractRefs @() -PassportRefs $passportRefs -ValidatorRefs $validatorRefs -ProofRefs $proofRefs -Capabilities @() -InvocationPaths $invocationRefs -SignalRefs $signalRefs
                        Add-UniqueObjectById -List ([ref]$declaredOrgans) -Object $organ -IdField "declared_organ_id"
                    }
                }

                $capabilityStrings = @(Get-StringsMatching -Node $json -Pattern "(?i)(^|[_\-/ ])capability([_\-/ ]|$)|capability_id|capabilities|capability_ref")
                foreach ($capabilityText in @($capabilityStrings | Select-Object -First 120)) {
                    $capabilityId = Get-NormalizedId -Text $capabilityText
                    if ($capabilityId -and $capabilityId -ne "capability" -and $capabilityId.Length -gt 5) {
                        $capability = New-DeclaredCapability -Id $capabilityId -Name $capabilityText -SourceMapRef $Path -OwningOrganRefs @() -InvocationRefs $invocationRefs -ValidatorRefs $validatorRefs -ProofRefs $proofRefs
                        Add-UniqueObjectById -List ([ref]$declaredCapabilities) -Object $capability -IdField "capability_id"
                    }
                }
            } catch {
                $parseStatus = "PARSE_FAILED"
                $status = "PARSE_FAILED"
                $errors += $_.Exception.Message
            }
        } else {
            $parseStatus = "READ_TEXT"
            $status = "TEXT_SURFACE_READ"
            foreach ($match in [regex]::Matches($text, "(?i)(operations|modules|orchestrator)[/\\][A-Za-z0-9_\-./\\]+\.ps1")) {
                Add-UniqueString -List ([ref]$invocationRefs) -Value ($match.Value -replace "\\", "/")
            }
            foreach ($match in [regex]::Matches($text, "(?i)validators[/\\][A-Za-z0-9_\-./\\]+\.ps1")) {
                Add-UniqueString -List ([ref]$validatorRefs) -Value ($match.Value -replace "\\", "/")
            }
            foreach ($match in [regex]::Matches($text, "(?i)[A-Za-z0-9_\-./\\]*proof[A-Za-z0-9_\-./\\]*\.json")) {
                Add-UniqueString -List ([ref]$proofRefs) -Value ($match.Value -replace "\\", "/")
            }
            foreach ($match in [regex]::Matches($text, "(?i)[A-Za-z0-9_\-./\\]*passport[A-Za-z0-9_\-./\\]*\.(json|md)")) {
                Add-UniqueString -List ([ref]$passportRefs) -Value ($match.Value -replace "\\", "/")
            }
            foreach ($match in [regex]::Matches($text, "(?i)signal[A-Za-z0-9_\-./\\]*")) {
                Add-UniqueString -List ([ref]$signalRefs) -Value $match.Value
            }
        }
    } catch {
        $parseStatus = "READ_FAILED"
        $status = "READ_FAILED"
        $errors += $_.Exception.Message
    }

    if (-not $schema) {
        $schema = "UNKNOWN_OR_TEXT"
    }
    if (-not $status) {
        $status = "DECLARED_SURFACE_READ"
    }

    return (New-MapRecord -Path $Path -MapType $mapType -ParseStatus $parseStatus -Schema $schema -Status $status -DeclaredOrgans $declaredOrgans -DeclaredCapabilities $declaredCapabilities -DeclaredInvocationPaths $invocationRefs -DeclaredValidators $validatorRefs -DeclaredProofRefs $proofRefs -DeclaredPassportRefs $passportRefs -DeclaredSignalRefs $signalRefs -LastUpdatedIfPresent $lastUpdated -EvidenceStatus "DECLARATION_ONLY_NOT_PROOF" -Errors $errors)
}

if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
}

$inventory = Read-JsonFile -Path $InventoryPath
$generatedAt = (Get-Date).ToUniversalTime().ToString("o")

$requiredMapPaths = @(
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1",
    "operations/gpt_handoff/NEXT_CHAT_HANDOFF_20260716_MIND_LOGIC_STATUS.json",
    "operations/gpt_handoff/NEXT_CHAT_HANDOFF_20260716_MIND_LOGIC.md"
)

$recordByPath = @{}
foreach ($record in @($inventory.records)) {
    $path = [string]$record.normalized_path
    if ($path -and -not $recordByPath.ContainsKey($path.ToLowerInvariant())) {
        $recordByPath[$path.ToLowerInvariant()] = $record
    }
}

$mapPaths = @()
foreach ($path in $requiredMapPaths) {
    Add-UniqueString -List ([ref]$mapPaths) -Value ($path -replace "\\", "/")
}

foreach ($record in @($inventory.records)) {
    if ([string]$record.kind -ne "file") {
        continue
    }
    $path = [string]$record.normalized_path
    $roleGuess = [string]$record.role_guess
    if (Test-IsMapLikePath -Path $path -RoleGuess $roleGuess) {
        Add-UniqueString -List ([ref]$mapPaths) -Value $path
    }
}

$mapRecords = @()
foreach ($path in @($mapPaths | Sort-Object)) {
    $key = $path.ToLowerInvariant()
    $inventoryRecord = $null
    if ($recordByPath.ContainsKey($key)) {
        $inventoryRecord = $recordByPath[$key]
    }
    $exists = Test-Path -LiteralPath (Join-Path $RepoRoot ($path -replace "/", "\"))
    $mapRecords += (Read-MapSurface -Path $path -InventoryRecord $inventoryRecord -Exists $exists)
}

$bodyRecords = @()
$capabilityRecords = @()
foreach ($record in @($mapRecords)) {
    $bodyRecords += $record
    if ([string]$record.map_type -eq "CAPABILITY_MAP" -or @($record.declared_capabilities).Count -gt 0) {
        $capabilityRecords += $record
    }
}

if ($capabilityRecords.Count -eq 0) {
    foreach ($record in @($mapRecords)) {
        if ([string]$record.path -eq "CAPABILITY_ROADMAP.json") {
            $capabilityRecords += $record
        }
    }
}

function New-MapAggregates {
    param([array]$Records)

    $declaredOrgans = @()
    $declaredCapabilities = @()
    $validators = @()
    $invocations = @()
    $proofRefs = @()
    $missingRootMarkers = @()
    $mapsParsed = 0
    $mapsFailed = 0
    $staleMaps = 0

    foreach ($record in @($Records)) {
        foreach ($organ in @($record.declared_organs)) {
            Add-UniqueObjectById -List ([ref]$declaredOrgans) -Object $organ -IdField "declared_organ_id"
        }
        foreach ($capability in @($record.declared_capabilities)) {
            Add-UniqueObjectById -List ([ref]$declaredCapabilities) -Object $capability -IdField "capability_id"
        }
        foreach ($validator in @($record.declared_validators)) {
            Add-UniqueString -List ([ref]$validators) -Value $validator
        }
        foreach ($invocation in @($record.declared_invocation_paths)) {
            Add-UniqueString -List ([ref]$invocations) -Value $invocation
        }
        foreach ($proofRef in @($record.declared_proof_refs)) {
            Add-UniqueString -List ([ref]$proofRefs) -Value $proofRef
        }
        if ([string]$record.parse_status -eq "PARSED_JSON" -or [string]$record.parse_status -eq "READ_TEXT") {
            $mapsParsed++
        }
        if ([string]$record.parse_status -eq "PARSE_FAILED" -or [string]$record.parse_status -eq "READ_FAILED") {
            $mapsFailed++
        }
        if ([string]$record.parse_status -eq "MISSING") {
            $missingRootMarkers += $record.path
        }
        if ([string]$record.evidence_status -eq "STALE_BY_TIME" -or [string]$record.evidence_status -eq "STALE_BY_HEAD_CHANGE") {
            $staleMaps++
        }
    }

    return @{
        maps_seen = @($Records).Count
        maps_parsed = $mapsParsed
        maps_failed = $mapsFailed
        declared_organs_count = @($declaredOrgans).Count
        declared_capabilities_count = @($declaredCapabilities).Count
        declared_validators_count = @($validators).Count
        declared_invocation_paths_count = @($invocations).Count
        declared_proof_refs_count = @($proofRefs).Count
        stale_maps_count = $staleMaps
        conflict_count = 0
        missing_root_markers = @($missingRootMarkers)
    }
}

function Get-AggregatedOrgans {
    param([array]$Records)

    $items = @()
    foreach ($record in @($Records)) {
        foreach ($organ in @($record.declared_organs)) {
            Add-UniqueObjectById -List ([ref]$items) -Object $organ -IdField "declared_organ_id"
        }
    }
    return $items
}

function Get-AggregatedCapabilities {
    param([array]$Records)

    $items = @()
    foreach ($record in @($Records)) {
        foreach ($capability in @($record.declared_capabilities)) {
            Add-UniqueObjectById -List ([ref]$items) -Object $capability -IdField "capability_id"
        }
    }
    return $items
}

$bodyMapRead = @{
    schema = "body_map_read_v1"
    status = "PASS_BODY_MAP_READ_V1"
    generated_at = $generatedAt
    source_inventory_ref = $InventoryPath
    map_records = @($bodyRecords)
    declared_organs = @(Get-AggregatedOrgans -Records $bodyRecords)
    declared_capabilities = @(Get-AggregatedCapabilities -Records $bodyRecords)
    aggregates = New-MapAggregates -Records $bodyRecords
    boundary_note = @{
        declared_organ_boundary = "DECLARED_ORGAN != PRESENT_ORGAN != VALID_ORGAN != MATURE_ORGAN"
        declared_capability_boundary = "DECLARED_CAPABILITY != USABLE_CAPABILITY"
    }
    stale_after = "24h"
    boundary = New-BodyInspectionBoundary
    errors = @()
}

$capabilityMapRead = @{
    schema = "capability_map_read_v1"
    status = "PASS_CAPABILITY_MAP_READ_V1"
    generated_at = $generatedAt
    source_inventory_ref = $InventoryPath
    map_records = @($capabilityRecords)
    declared_organs = @(Get-AggregatedOrgans -Records $capabilityRecords)
    declared_capabilities = @(Get-AggregatedCapabilities -Records $capabilityRecords)
    aggregates = New-MapAggregates -Records $capabilityRecords
    boundary_note = @{
        declared_capability_boundary = "DECLARED_CAPABILITY != USABLE_CAPABILITY"
        map_declaration_boundary = "map declaration is not proof"
    }
    stale_after = "24h"
    boundary = New-BodyInspectionBoundary
    errors = @()
}

$bodyMapPath = Join-Path $RuntimeRoot "body_map_read.json"
$capabilityMapPath = Join-Path $RuntimeRoot "capability_map_read.json"

Write-JsonFile -Path $bodyMapPath -Data $bodyMapRead
Write-JsonFile -Path $capabilityMapPath -Data $capabilityMapRead

Write-Output $bodyMapPath
Write-Output $capabilityMapPath
