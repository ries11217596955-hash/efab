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

function ConvertTo-QueueType {
    param([string]$RepairClass)

    switch ($RepairClass) {
        "CREATE_OR_REPAIR_PASSPORT_DRAFT" { return "PASSPORT_REPAIR_CANDIDATE" }
        "CREATE_OR_REPAIR_CONTRACT_DRAFT" { return "CODEX_TASK_CANDIDATE" }
        "ADD_OR_REPAIR_VALIDATOR_DRAFT" { return "VALIDATOR_REPAIR_CANDIDATE" }
        "ADD_OR_REPAIR_PROOF_DRAFT" { return "VALIDATOR_REPAIR_CANDIDATE" }
        "ADD_SIGNAL_CONTRACT_DRAFT" { return "SIGNAL_REPAIR_CANDIDATE" }
        "REVIEW_DUPLICATE_DRAFT" { return "DUPLICATE_REVIEW_CANDIDATE" }
        "REVIEW_FUNCTIONAL_OVERLAP_DRAFT" { return "HUMAN_DECISION_REQUIRED" }
        "REPAIR_BROKEN_REFERENCE_DRAFT" { return "MAP_REVIEW_CANDIDATE" }
        "MAP_REFRESH_REVIEW_DRAFT" { return "MAP_REVIEW_CANDIDATE" }
        default { return "OPERATOR_REVIEW" }
    }
}

function ConvertTo-Priority {
    param([string]$Risk)

    switch ($Risk) {
        "HIGH_REVIEW_RISK" { return 90 }
        "MEDIUM_REVIEW_RISK" { return 60 }
        "LOW_REVIEW_RISK" { return 30 }
        default { return 10 }
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

$draftPath = Join-Path $RuntimeRoot "repair_draft_board.json"
$painPath = Join-Path $RuntimeRoot "body_pain_register.json"
$outputPath = Join-Path $RuntimeRoot "next_logic_queue.json"
$draftBoard = Read-JsonFile -Path $draftPath
$painRegister = Read-JsonFile -Path $painPath

$painById = @{}
foreach ($pain in @(Get-PropertyValue -Object $painRegister -Name "pain_records")) {
    $painId = [string](Get-PropertyValue -Object $pain -Name "pain_id")
    if ($painId) {
        $painById[$painId] = $pain
    }
}

$queueItems = @()
$queueTypeCounts = @{}
$standardForbidden = @(
    "execute_queue_item",
    "execute_repair",
    "mutate_repo",
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

foreach ($draft in @(Get-PropertyValue -Object $draftBoard -Name "repair_drafts")) {
    $draftId = [string](Get-PropertyValue -Object $draft -Name "draft_id")
    $painId = [string](Get-PropertyValue -Object $draft -Name "source_pain_id")
    $subjectId = [string](Get-PropertyValue -Object $draft -Name "subject_id")
    $repairClass = [string](Get-PropertyValue -Object $draft -Name "repair_class")
    $queueType = ConvertTo-QueueType -RepairClass $repairClass
    $risk = [string](Get-PropertyValue -Object $draft -Name "risk")
    $priority = ConvertTo-Priority -Risk $risk
    $queueId = Get-StableId -Prefix "queue" -Parts @($draftId, $painId, $subjectId, $queueType)
    $ownerDecisionRequired = ($queueType -in @("HUMAN_DECISION_REQUIRED", "DUPLICATE_REVIEW_CANDIDATE"))
    $forbiddenNow = @(Merge-UniqueItems -First (Get-PropertyValue -Object $draft -Name "forbidden_now") -Second $standardForbidden)

    Add-Count -Table $queueTypeCounts -Key $queueType

    $queueItems += [ordered]@{
        queue_id = $queueId
        source_draft_id = $draftId
        subject_id = $subjectId
        priority = $priority
        queue_type = $queueType
        reason = "Review draft " + $draftId + " from pain " + $painId + "; this queue item selects reasoning only and cannot execute a repair."
        proposed_next_slice = "FUTURE_OPERATOR_REVIEW_SLICE"
        dependencies = @(Merge-UniqueItems -First @($painId, $draftId) -Second (Get-PropertyValue -Object $draft -Name "files_in_scope"))
        validators_required = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $draft -Name "validators_required"))
        proof_required = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $draft -Name "proof_required"))
        execution_allowed = $false
        owner_decision_required = $ownerDecisionRequired
        recommended_operator = [string](Get-PropertyValue -Object $draft -Name "recommended_operator")
        forbidden_now = $forbiddenNow
    }
}

$selectedNextItem = $null
if (@($queueItems).Count -gt 0) {
    $selectedNextItem = @($queueItems | Sort-Object -Property @{ Expression = "priority"; Descending = $true }, @{ Expression = "queue_id"; Descending = $false } | Select-Object -First 1)[0]
}

$output = [ordered]@{
    schema = "next_logic_queue_v1"
    status = "PASS_NEXT_LOGIC_QUEUE_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "E"
    source_repair_draft_board_ref = $draftPath
    source_pain_register_ref = $painPath
    queue_items = @($queueItems)
    selected_next_item = $selectedNextItem
    selection_reason = $(if ($selectedNextItem) { "Highest priority candidate selected for future operator reasoning only." } else { "No repair drafts available for queue selection." })
    aggregate_counts = [ordered]@{
        total_queue_items = @($queueItems).Count
        source_repair_drafts = @((Get-PropertyValue -Object $draftBoard -Name "repair_drafts")).Count
        source_pain_records = @((Get-PropertyValue -Object $painRegister -Name "pain_records")).Count
        queue_type_counts = $queueTypeCounts
    }
    boundary_statement = "QUEUE_ITEM != EXECUTION; QUEUE_ITEM != OWNER_APPROVAL; QUEUE_ITEM != ACCEPTED_TASK"
    boundary = New-BodyInspectionBoundary
    errors = @()
}

Write-JsonFile -Path $outputPath -Data $output
Write-Output $outputPath
