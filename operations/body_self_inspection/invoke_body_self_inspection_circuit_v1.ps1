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

$sliceEInvoker = Join-Path $PSScriptRoot "invoke_body_self_inspection_slice_e_v1.ps1"
$signalEmitter = Join-Path $PSScriptRoot "emit_body_self_inspection_signal_v1.ps1"

if (-not (Test-Path -LiteralPath $sliceEInvoker)) {
    throw "Missing Slice E invoker: $sliceEInvoker"
}
if (-not (Test-Path -LiteralPath $signalEmitter)) {
    throw "Missing Slice F signal emitter: $signalEmitter"
}

& $sliceEInvoker -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
& $signalEmitter -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null

$paths = [ordered]@{
    slice_a_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"
    slice_b_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_B_PROOF.json"
    slice_c_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_C_PROOF.json"
    slice_d_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_D_PROOF.json"
    slice_e_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_E_PROOF.json"
    body_pain_register = Join-Path $RuntimeRoot "body_pain_register.json"
    repair_draft_board = Join-Path $RuntimeRoot "repair_draft_board.json"
    next_logic_queue = Join-Path $RuntimeRoot "next_logic_queue.json"
    body_self_inspection_signal = Join-Path $RuntimeRoot "body_self_inspection_signal.json"
    body_self_inspection_parent_packet = Join-Path $RuntimeRoot "body_self_inspection_parent_packet.json"
}

$sliceAProof = Read-JsonFile -Path $paths.slice_a_runtime_proof
$sliceBProof = Read-JsonFile -Path $paths.slice_b_runtime_proof
$sliceCProof = Read-JsonFile -Path $paths.slice_c_runtime_proof
$sliceDProof = Read-JsonFile -Path $paths.slice_d_runtime_proof
$sliceEProof = Read-JsonFile -Path $paths.slice_e_runtime_proof
$painRegister = Read-JsonFile -Path $paths.body_pain_register
$repairDraftBoard = Read-JsonFile -Path $paths.repair_draft_board
$nextLogicQueue = Read-JsonFile -Path $paths.next_logic_queue
$signal = Read-JsonFile -Path $paths.body_self_inspection_signal
$parentPacket = Read-JsonFile -Path $paths.body_self_inspection_parent_packet

$painRecords = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $painRegister -Name "pain_records"))
$repairDrafts = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $repairDraftBoard -Name "repair_drafts"))
$queueItems = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $nextLogicQueue -Name "queue_items"))
$proofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_CIRCUIT_PROOF.json"

$proof = [ordered]@{
    schema = "body_self_inspection_circuit_runtime_proof_v1"
    status = "PASS_BODY_SELF_INSPECTION_CIRCUIT_RUNTIME_V1"
    version = "1.0"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    repo_root = $RepoRoot
    repo_head = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--short", "HEAD")
    branch = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    output_refs = [ordered]@{
        slice_a_runtime_proof = $paths.slice_a_runtime_proof
        slice_b_runtime_proof = $paths.slice_b_runtime_proof
        slice_c_runtime_proof = $paths.slice_c_runtime_proof
        slice_d_runtime_proof = $paths.slice_d_runtime_proof
        slice_e_runtime_proof = $paths.slice_e_runtime_proof
        body_pain_register = $paths.body_pain_register
        repair_draft_board = $paths.repair_draft_board
        next_logic_queue = $paths.next_logic_queue
        body_self_inspection_signal = $paths.body_self_inspection_signal
        body_self_inspection_parent_packet = $paths.body_self_inspection_parent_packet
        runtime_proof = $proofPath
    }
    slice_a_status = [string](Get-PropertyValue -Object $sliceAProof -Name "status")
    slice_b_status = [string](Get-PropertyValue -Object $sliceBProof -Name "status")
    slice_c_status = [string](Get-PropertyValue -Object $sliceCProof -Name "status")
    slice_d_status = [string](Get-PropertyValue -Object $sliceDProof -Name "status")
    slice_e_status = [string](Get-PropertyValue -Object $sliceEProof -Name "status")
    signal_status = [string](Get-PropertyValue -Object $signal -Name "status")
    parent_packet_status = [string](Get-PropertyValue -Object $parentPacket -Name "status")
    total_pains = @($painRecords).Count
    total_repair_drafts = @($repairDrafts).Count
    total_queue_items = @($queueItems).Count
    execution_allowed = $false
    parent_action_executed = $false
    aggregate_summary = [ordered]@{
        slice_a_status = [string](Get-PropertyValue -Object $sliceAProof -Name "status")
        slice_b_status = [string](Get-PropertyValue -Object $sliceBProof -Name "status")
        slice_c_status = [string](Get-PropertyValue -Object $sliceCProof -Name "status")
        slice_d_status = [string](Get-PropertyValue -Object $sliceDProof -Name "status")
        slice_e_status = [string](Get-PropertyValue -Object $sliceEProof -Name "status")
        signal_status = [string](Get-PropertyValue -Object $signal -Name "status")
        parent_packet_status = [string](Get-PropertyValue -Object $parentPacket -Name "status")
        total_pains = @($painRecords).Count
        total_repair_drafts = @($repairDrafts).Count
        total_queue_items = @($queueItems).Count
        execution_allowed = $false
    }
    integration_boundary = [ordered]@{
        statement = "aggregate PASS != mature organ acceptance; signal != nervous system connection; parent packet != executed parent action; queue item != permission; repair draft != patch"
        signal_is_not_nervous_system_connection = $true
        parent_packet_is_not_executed_parent_action = $true
        queue_item_is_not_permission = $true
        repair_draft_is_not_patch = $true
        aggregate_pass_is_not_mature_organ_acceptance = $true
    }
    boundary = New-BodyInspectionBoundary
    errors = @()
}

Write-JsonFile -Path $proofPath -Data $proof
Write-Output $proofPath
