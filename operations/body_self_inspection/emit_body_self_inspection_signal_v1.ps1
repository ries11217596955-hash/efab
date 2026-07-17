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
        parent_action_executed = $false
        mind_logic_mutated = $false
        nervous_system_connected = $false
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

function Get-CountFromAggregate {
    param(
        $Object,
        [string[]]$Names
    )

    $aggregate = Get-PropertyValue -Object $Object -Name "aggregate_counts"
    if ($null -eq $aggregate) {
        $aggregate = Get-PropertyValue -Object $Object -Name "aggregates"
    }
    foreach ($name in @($Names)) {
        $value = Get-PropertyValue -Object $aggregate -Name $name
        if ($null -ne $value -and [string]$value -ne "") {
            return [int]$value
        }
    }
    return 0
}

function Invoke-AllowedGit {
    param(
        [string]$Root,
        [string[]]$Arguments
    )

    $output = & git -C $Root @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        return ""
    }
    return (($output | Out-String).Trim())
}

if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
}

$paths = [ordered]@{
    body_pain_register = Join-Path $RuntimeRoot "body_pain_register.json"
    repair_draft_board = Join-Path $RuntimeRoot "repair_draft_board.json"
    next_logic_queue = Join-Path $RuntimeRoot "next_logic_queue.json"
    body_reconciliation = Join-Path $RuntimeRoot "body_reconciliation.json"
    slice_a_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_A_V1_PROOF.json"
    slice_b_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_B_V1_PROOF.json"
    slice_c_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_C_V1_PROOF.json"
    slice_d_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_D_V1_PROOF.json"
    slice_e_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_E_V1_PROOF.json"
}

$painRegister = Read-JsonFile -Path $paths.body_pain_register
$repairDraftBoard = Read-JsonFile -Path $paths.repair_draft_board
$nextLogicQueue = Read-JsonFile -Path $paths.next_logic_queue
$bodyReconciliation = Read-JsonFile -Path $paths.body_reconciliation

$sliceProofs = [ordered]@{
    A = Read-JsonFile -Path $paths.slice_a_tracked_proof
    B = Read-JsonFile -Path $paths.slice_b_tracked_proof
    C = Read-JsonFile -Path $paths.slice_c_tracked_proof
    D = Read-JsonFile -Path $paths.slice_d_tracked_proof
    E = Read-JsonFile -Path $paths.slice_e_tracked_proof
}

$painRecords = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $painRegister -Name "pain_records"))
$repairDrafts = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $repairDraftBoard -Name "repair_drafts"))
$queueItems = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $nextLogicQueue -Name "queue_items"))
$selectedNextItem = Get-PropertyValue -Object $nextLogicQueue -Name "selected_next_item"
$topPriorityItems = @($queueItems | Sort-Object -Property @{ Expression = "priority"; Descending = $true }, @{ Expression = "queue_id"; Descending = $false } | Select-Object -First 5)

$repoHead = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--short", "HEAD")
$branch = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
$generatedAt = (Get-Date).ToUniversalTime().ToString("o")
$signalPath = Join-Path $RuntimeRoot "body_self_inspection_signal.json"
$parentPacketPath = Join-Path $RuntimeRoot "body_self_inspection_parent_packet.json"
$boundary = New-BodyInspectionBoundary

$sourceOutputs = [ordered]@{
    body_reconciliation = $paths.body_reconciliation
    body_pain_register = $paths.body_pain_register
    repair_draft_board = $paths.repair_draft_board
    next_logic_queue = $paths.next_logic_queue
}

$proofRefs = [ordered]@{
    slice_a_tracked_proof = $paths.slice_a_tracked_proof
    slice_b_tracked_proof = $paths.slice_b_tracked_proof
    slice_c_tracked_proof = $paths.slice_c_tracked_proof
    slice_d_tracked_proof = $paths.slice_d_tracked_proof
    slice_e_tracked_proof = $paths.slice_e_tracked_proof
}

$sliceStatuses = [ordered]@{}
foreach ($key in @("A", "B", "C", "D", "E")) {
    $sliceStatuses[$key] = [string](Get-PropertyValue -Object $sliceProofs[$key] -Name "status")
}

$signal = [ordered]@{
    schema = "body_self_inspection_signal_v1"
    status = "PASS_BODY_SELF_INSPECTION_SIGNAL_V1"
    version = "1.0"
    generated_at = $generatedAt
    repo_root = $RepoRoot
    repo_head = $repoHead
    branch = $branch
    source_outputs = $sourceOutputs
    proof_refs = $proofRefs
    body_health_summary = [ordered]@{
        circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
        slice_statuses = $sliceStatuses
        reconciliation_status = [string](Get-PropertyValue -Object $bodyReconciliation -Name "status")
        total_reconciliation_records = Get-CountFromAggregate -Object $bodyReconciliation -Names @("total_reconciliation_records")
        total_discrepancy_records = Get-CountFromAggregate -Object $bodyReconciliation -Names @("total_discrepancy_records")
        evidence_status = "AGGREGATE_SIGNAL_READY_PENDING_PARENT_CONSUMPTION"
    }
    pain_summary = [ordered]@{
        status = [string](Get-PropertyValue -Object $painRegister -Name "status")
        total_pains = @($painRecords).Count
        aggregate_counts = Get-PropertyValue -Object $painRegister -Name "aggregate_counts"
    }
    repair_summary = [ordered]@{
        status = [string](Get-PropertyValue -Object $repairDraftBoard -Name "status")
        total_repair_drafts = @($repairDrafts).Count
        aggregate_counts = Get-PropertyValue -Object $repairDraftBoard -Name "aggregate_counts"
        repair_executed = $false
        execution_allowed = $false
    }
    queue_summary = [ordered]@{
        status = [string](Get-PropertyValue -Object $nextLogicQueue -Name "status")
        total_queue_items = @($queueItems).Count
        selected_next_item = $selectedNextItem
        execution_allowed = $false
        queue_item_is_permission = $false
    }
    top_priority_items = @($topPriorityItems)
    parent_loop_signal = [ordered]@{
        signal_type = "BODY_SELF_INSPECTION_PARENT_LOOP_READY_PACKET_AVAILABLE"
        signal_sink = "PLACEHOLDER_RUNTIME_FILE"
        source_signal_ref = $signalPath
        parent_packet_ref = $parentPacketPath
        recommended_parent_action = "READ_PACKET_AND_DECIDE_FUTURE_SAFE_REASONING_ACTION"
        execution_allowed = $false
        parent_action_executed = $false
        owner_decision_required = $true
    }
    integration_boundary = [ordered]@{
        statement = "signal != nervous system connection; parent packet != executed parent action; queue item != permission; repair draft != patch; aggregate PASS != mature organ acceptance"
        signal_is_not_nervous_system_connection = $true
        parent_packet_is_not_executed_parent_action = $true
        queue_item_is_not_permission = $true
        repair_draft_is_not_patch = $true
        aggregate_pass_is_not_mature_organ_acceptance = $true
        nervous_system_consumed = $false
    }
    boundary = $boundary
}

$parentPacket = [ordered]@{
    schema = "body_self_inspection_parent_packet_v1"
    status = "PASS_BODY_SELF_INSPECTION_PARENT_PACKET_V1"
    version = "1.0"
    generated_at = $generatedAt
    packet_type = "BODY_SELF_INSPECTION_PARENT_LOOP_INTEGRATION_READY_PACKET"
    produced_by = "operations/body_self_inspection/emit_body_self_inspection_signal_v1.ps1"
    source_signal_ref = $signalPath
    recommended_parent_action = "READ_BODY_SELF_INSPECTION_SIGNAL_AND_SELECTED_QUEUE_ITEM_BEFORE_ANY_FUTURE_PARENT_LOOP_DECISION"
    next_safe_operator_action = "Review body_self_inspection_signal.json and body_self_inspection_parent_packet.json; promote a bounded future task only if owner/operator chooses."
    execution_allowed = $false
    owner_decision_required = $true
    proof_required_before_execution = $true
    forbidden_now = @(
        "execute_parent_action",
        "execute_queue_item",
        "execute_repair_draft",
        "patch_from_repair_draft",
        "mutate_mind_logic",
        "mutate_active_memory",
        "mutate_accepted_core",
        "mutate_body_map",
        "mutate_capability_map",
        "mutate_passports",
        "mutate_contracts",
        "claim_nervous_system_connected",
        "claim_mature_organ_accepted",
        "launch_live_runtime",
        "launch_codex",
        "browse_web",
        "cleanup_runtime"
    )
    integration_boundary = [ordered]@{
        statement = "parent packet != executed parent action; signal != nervous system connection; queue item != permission; repair draft != patch; aggregate PASS != mature organ acceptance"
        signal_is_not_nervous_system_connection = $true
        parent_packet_is_not_executed_parent_action = $true
        queue_item_is_not_permission = $true
        repair_draft_is_not_patch = $true
        aggregate_pass_is_not_mature_organ_acceptance = $true
    }
    boundary = $boundary
}

Write-JsonFile -Path $signalPath -Data $signal
Write-JsonFile -Path $parentPacketPath -Data $parentPacket
Write-Output $signalPath
Write-Output $parentPacketPath
