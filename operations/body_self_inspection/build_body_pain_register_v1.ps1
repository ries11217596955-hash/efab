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
    return [ordered]@{
        repo_mutated = $false
        active_memory_mutated = $false
        accepted_core_mutated = $false
        body_map_mutated = $false
        capability_map_mutated = $false
        passports_mutated = $false
        contracts_mutated = $false
        repair_executed = $false
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
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
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

function Merge-UniqueItems {
    param(
        $First,
        $Second
    )

    $seen = @{}
    $items = @()
    foreach ($item in @((ConvertTo-ItemArray -Value $First) + (ConvertTo-ItemArray -Value $Second))) {
        $key = [string]$item
        if ($key.Trim() -eq "") {
            continue
        }
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $items += $item
        }
    }
    return @($items)
}

function Get-StableId {
    param(
        [string]$Prefix,
        [object[]]$Parts
    )

    $material = (($Parts | ForEach-Object { if ($null -eq $_) { "" } else { [string]$_ } }) -join "|").ToLowerInvariant()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($material)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }
    $hex = -join ($hash[0..7] | ForEach-Object { $_.ToString("x2") })
    return ($Prefix + "_" + $hex)
}

function ConvertTo-PainType {
    param([string]$DiscrepancyType)

    switch ($DiscrepancyType) {
        "CANDIDATE_WITHOUT_PASSPORT" { return "MISSING_PASSPORT_PAIN" }
        "CANDIDATE_WITHOUT_CONTRACT" { return "MISSING_CONTRACT_PAIN" }
        "PASSPORT_WITHOUT_CONTRACT" { return "MISSING_CONTRACT_PAIN" }
        "CONTRACT_WITHOUT_PASSPORT" { return "MISSING_CONTRACT_PAIN" }
        "CANDIDATE_WITHOUT_VALIDATOR" { return "MISSING_VALIDATOR_PAIN" }
        "SIGNAL_CONTRACT_WITHOUT_VALIDATOR" { return "MISSING_VALIDATOR_PAIN" }
        "SIGNAL_VALIDATOR_WITHOUT_CONTRACT" { return "MISSING_VALIDATOR_PAIN" }
        "CANDIDATE_WITHOUT_PROOF" { return "MISSING_PROOF_PAIN" }
        "CANDIDATE_WITHOUT_SIGNAL" { return "MISSING_SIGNAL_PAIN" }
        "POSSIBLE_DUPLICATE_NEEDS_REVIEW" { return "POSSIBLE_DUPLICATE_PAIN" }
        "FUNCTIONAL_OVERLAP_NEEDS_REVIEW" { return "FUNCTIONAL_OVERLAP_PAIN" }
        "BROKEN_REFERENCE" { return "BROKEN_REFERENCE_PAIN" }
        "STALE_REFERENCE" { return "BROKEN_REFERENCE_PAIN" }
        "DECLARED_NOT_FOUND_IN_REPO" { return "MAP_AMBIGUITY_PAIN" }
        "PRESENT_NOT_DECLARED" { return "MAP_AMBIGUITY_PAIN" }
        "MAP_DECLARATION_AMBIGUOUS" { return "MAP_AMBIGUITY_PAIN" }
        default { return "UNKNOWN_BODY_PAIN" }
    }
}

function ConvertTo-RepairClass {
    param([string]$PainType)

    switch ($PainType) {
        "MISSING_PASSPORT_PAIN" { return "CREATE_OR_REPAIR_PASSPORT_DRAFT" }
        "MISSING_CONTRACT_PAIN" { return "CREATE_OR_REPAIR_CONTRACT_DRAFT" }
        "MISSING_VALIDATOR_PAIN" { return "ADD_OR_REPAIR_VALIDATOR_DRAFT" }
        "MISSING_PROOF_PAIN" { return "ADD_OR_REPAIR_PROOF_DRAFT" }
        "MISSING_SIGNAL_PAIN" { return "ADD_SIGNAL_CONTRACT_DRAFT" }
        "POSSIBLE_DUPLICATE_PAIN" { return "REVIEW_DUPLICATE_DRAFT" }
        "FUNCTIONAL_OVERLAP_PAIN" { return "REVIEW_FUNCTIONAL_OVERLAP_DRAFT" }
        "BROKEN_REFERENCE_PAIN" { return "REPAIR_BROKEN_REFERENCE_DRAFT" }
        "MAP_AMBIGUITY_PAIN" { return "MAP_REFRESH_REVIEW_DRAFT" }
        default { return "HUMAN_REVIEW_DRAFT" }
    }
}

function Add-Count {
    param(
        [hashtable]$Table,
        [string]$Key
    )

    if (-not $Key -or $Key.Trim() -eq "") {
        $Key = "UNKNOWN"
    }
    if (-not $Table.ContainsKey($Key)) {
        $Table[$Key] = 0
    }
    $Table[$Key] += 1
}

if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
}

$inputPath = Join-Path $RuntimeRoot "body_reconciliation.json"
$outputPath = Join-Path $RuntimeRoot "body_pain_register.json"
$reconciliation = Read-JsonFile -Path $inputPath

$standardForbidden = @(
    "execute_repair",
    "mutate_maps",
    "mutate_passports",
    "mutate_contracts",
    "mutate_active_memory",
    "mutate_accepted_core",
    "launch_live_runtime",
    "launch_codex",
    "browse_web",
    "cleanup_runtime"
)

$painRecords = @()
$seenPainIds = @{}
$painTypeCounts = @{}
$severityCounts = @{}

foreach ($discrepancy in @(Get-PropertyValue -Object $reconciliation -Name "discrepancy_records")) {
    $discrepancyId = [string](Get-PropertyValue -Object $discrepancy -Name "discrepancy_id")
    $subjectId = [string](Get-PropertyValue -Object $discrepancy -Name "subject_id")
    $discrepancyType = [string](Get-PropertyValue -Object $discrepancy -Name "discrepancy_type")
    $painType = ConvertTo-PainType -DiscrepancyType $discrepancyType
    $repairClass = ConvertTo-RepairClass -PainType $painType
    $painId = Get-StableId -Prefix "pain" -Parts @($painType, $subjectId, $discrepancyType, $discrepancyId)

    if ($seenPainIds.ContainsKey($painId)) {
        continue
    }
    $seenPainIds[$painId] = $true

    $severity = [string](Get-PropertyValue -Object $discrepancy -Name "severity")
    if (-not $severity -or $severity.Trim() -eq "") {
        $severity = "UNKNOWN"
    }

    $evidenceRefs = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $discrepancy -Name "evidence_refs"))
    $sourceRefs = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $discrepancy -Name "source_refs"))
    $forbiddenNow = @(Merge-UniqueItems -First (Get-PropertyValue -Object $discrepancy -Name "forbidden_now") -Second $standardForbidden)
    $explanation = [string](Get-PropertyValue -Object $discrepancy -Name "explanation")
    if (-not $explanation -or $explanation.Trim() -eq "") {
        $explanation = "Slice D reported a body reconciliation discrepancy for this subject."
    }

    Add-Count -Table $painTypeCounts -Key $painType
    Add-Count -Table $severityCounts -Key $severity

    $painRecords += [ordered]@{
        pain_id = $painId
        source_discrepancy_id = $discrepancyId
        subject_id = $subjectId
        pain_type = $painType
        severity = $severity
        evidence_refs = $evidenceRefs
        source_refs = $sourceRefs
        why_it_matters = ($explanation + " It matters because Slice E may only route this as a candidate pain, not as an accepted defect or repair permission.")
        blocked_capability = $(if ($subjectId) { $subjectId } else { "UNKNOWN_SUBJECT" })
        recommended_repair_class = $repairClass
        next_cell = "REPAIR_DRAFT_BOARD"
        acceptance_boundary = "pain record != repair; pain record != accepted defect; pain record != permission to mutate"
        forbidden_now = $forbiddenNow
    }
}

$output = [ordered]@{
    schema = "body_pain_register_v1"
    status = "PASS_BODY_PAIN_REGISTER_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "E"
    source_reconciliation_ref = $inputPath
    pain_records = @($painRecords)
    aggregate_counts = [ordered]@{
        total_pain_records = @($painRecords).Count
        source_discrepancy_records = @((Get-PropertyValue -Object $reconciliation -Name "discrepancy_records")).Count
        pain_type_counts = $painTypeCounts
        severity_counts = $severityCounts
    }
    boundary_statement = "PAIN_RECORD != REPAIR; PAIN_RECORD != ACCEPTED_DEFECT; PAIN_RECORD != PERMISSION_TO_MUTATE"
    boundary = New-BodyInspectionBoundary
    errors = @()
}

Write-JsonFile -Path $outputPath -Data $output
Write-Output $outputPath
