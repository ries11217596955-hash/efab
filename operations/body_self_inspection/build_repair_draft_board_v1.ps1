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

function Normalize-RepairClass {
    param([string]$RepairClass)

    $allowed = @(
        "CREATE_OR_REPAIR_PASSPORT_DRAFT",
        "CREATE_OR_REPAIR_CONTRACT_DRAFT",
        "ADD_OR_REPAIR_VALIDATOR_DRAFT",
        "ADD_OR_REPAIR_PROOF_DRAFT",
        "ADD_SIGNAL_CONTRACT_DRAFT",
        "REVIEW_DUPLICATE_DRAFT",
        "REVIEW_FUNCTIONAL_OVERLAP_DRAFT",
        "REPAIR_BROKEN_REFERENCE_DRAFT",
        "MAP_REFRESH_REVIEW_DRAFT",
        "HUMAN_REVIEW_DRAFT"
    )
    if ($allowed -contains $RepairClass) {
        return $RepairClass
    }
    return "HUMAN_REVIEW_DRAFT"
}

function Get-RiskLabel {
    param([string]$Severity)

    switch ($Severity) {
        "BLOCKER_CANDIDATE" { return "HIGH_REVIEW_RISK" }
        "HIGH" { return "HIGH_REVIEW_RISK" }
        "MEDIUM" { return "MEDIUM_REVIEW_RISK" }
        "LOW" { return "LOW_REVIEW_RISK" }
        "INFO" { return "LOW_REVIEW_RISK" }
        default { return "UNKNOWN_REVIEW_RISK" }
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

$painPath = Join-Path $RuntimeRoot "body_pain_register.json"
$reconciliationPath = Join-Path $RuntimeRoot "body_reconciliation.json"
$outputPath = Join-Path $RuntimeRoot "repair_draft_board.json"
$painRegister = Read-JsonFile -Path $painPath
$reconciliation = Read-JsonFile -Path $reconciliationPath

$filesForbidden = @(
    ".runtime/active_compact_semantic_memory_v1",
    "accepted-core",
    "body maps",
    "capability maps",
    "organ passports",
    "contracts",
    "authority passports",
    "operations/autonomous_inner_motor",
    "operations/reasoning",
    "live runtime launch scripts",
    "school runtime scripts",
    "credentials",
    "git metadata"
)

$standardForbidden = @(
    "execute_repair",
    "apply_patch_from_draft",
    "mutate_maps",
    "mutate_passports",
    "mutate_contracts",
    "mutate_active_memory",
    "mutate_accepted_core",
    "promote_candidate_to_organ",
    "launch_live_runtime",
    "launch_codex",
    "browse_web",
    "cleanup_runtime"
)

$draftRecords = @()
$repairClassCounts = @{}

foreach ($pain in @(Get-PropertyValue -Object $painRegister -Name "pain_records")) {
    $painId = [string](Get-PropertyValue -Object $pain -Name "pain_id")
    $subjectId = [string](Get-PropertyValue -Object $pain -Name "subject_id")
    $repairClass = Normalize-RepairClass -RepairClass ([string](Get-PropertyValue -Object $pain -Name "recommended_repair_class"))
    $draftId = Get-StableId -Prefix "draft" -Parts @($painId, $subjectId, $repairClass)
    $risk = Get-RiskLabel -Severity ([string](Get-PropertyValue -Object $pain -Name "severity"))
    $sourceRefs = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $pain -Name "source_refs"))
    $evidenceRefs = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $pain -Name "evidence_refs"))
    $filesInScope = @(Merge-UniqueItems -First $sourceRefs -Second $evidenceRefs)
    $forbiddenNow = @(Merge-UniqueItems -First (Get-PropertyValue -Object $pain -Name "forbidden_now") -Second $standardForbidden)

    Add-Count -Table $repairClassCounts -Key $repairClass

    $draftRecords += [ordered]@{
        draft_id = $draftId
        source_pain_id = $painId
        subject_id = $subjectId
        repair_class = $repairClass
        proposed_scope = "Runtime-only repair hypothesis for " + $subjectId + "; operator must promote to a bounded task before any tracked file change."
        files_in_scope = $filesInScope
        files_forbidden = $filesForbidden
        validators_required = @("A future promoted repair task must name a validator before execution.")
        proof_required = @("Fresh proof must show the pain is resolved before any acceptance claim.")
        risk = $risk
        authority_required = "GPT_OPERATOR_PROMOTION_REQUIRED"
        estimated_slice = "FUTURE_PROMOTED_REPAIR_SLICE"
        execution_allowed = $false
        recommended_operator = "GPT_OPERATOR_REVIEW_THEN_CODEX_ONLY_IF_PROMOTED"
        acceptance_boundary = "draft != patch; draft != accepted repair; draft != Codex task unless later promoted by operator"
        forbidden_now = $forbiddenNow
    }
}

$output = [ordered]@{
    schema = "repair_draft_board_v1"
    status = "PASS_REPAIR_DRAFT_BOARD_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "E"
    source_pain_register_ref = $painPath
    source_reconciliation_ref = $reconciliationPath
    repair_drafts = @($draftRecords)
    aggregate_counts = [ordered]@{
        total_repair_drafts = @($draftRecords).Count
        source_pain_records = @((Get-PropertyValue -Object $painRegister -Name "pain_records")).Count
        source_discrepancy_records = @((Get-PropertyValue -Object $reconciliation -Name "discrepancy_records")).Count
        repair_class_counts = $repairClassCounts
    }
    boundary_statement = "DRAFT != PATCH; DRAFT != ACCEPTED_REPAIR; DRAFT != CODEX_TASK_UNLESS_PROMOTED"
    boundary = New-BodyInspectionBoundary
    errors = @()
}

Write-JsonFile -Path $outputPath -Data $output
Write-Output $outputPath
