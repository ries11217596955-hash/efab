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

$sliceDInvoker = Join-Path $PSScriptRoot "invoke_body_self_inspection_slice_d_v1.ps1"
$painBuilder = Join-Path $PSScriptRoot "build_body_pain_register_v1.ps1"
$draftBuilder = Join-Path $PSScriptRoot "build_repair_draft_board_v1.ps1"
$queueBuilder = Join-Path $PSScriptRoot "build_next_logic_queue_v1.ps1"

& $sliceDInvoker -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
& $painBuilder -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
& $draftBuilder -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
& $queueBuilder -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null

$paths = [ordered]@{
    body_reconciliation = Join-Path $RuntimeRoot "body_reconciliation.json"
    slice_d_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_D_PROOF.json"
    body_pain_register = Join-Path $RuntimeRoot "body_pain_register.json"
    repair_draft_board = Join-Path $RuntimeRoot "repair_draft_board.json"
    next_logic_queue = Join-Path $RuntimeRoot "next_logic_queue.json"
}

$reconciliation = Read-JsonFile -Path $paths.body_reconciliation
$painRegister = Read-JsonFile -Path $paths.body_pain_register
$draftBoard = Read-JsonFile -Path $paths.repair_draft_board
$queue = Read-JsonFile -Path $paths.next_logic_queue
$proofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_E_PROOF.json"

$proof = [ordered]@{
    schema = "body_self_inspection_slice_e_runtime_proof_v1"
    status = "PASS_BODY_SELF_INSPECTION_SLICE_E_RUNTIME_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "E"
    repo_root = $RepoRoot
    repo_head = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--short", "HEAD")
    branch = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    output_refs = [ordered]@{
        body_reconciliation = $paths.body_reconciliation
        slice_d_runtime_proof = $paths.slice_d_runtime_proof
        body_pain_register = $paths.body_pain_register
        repair_draft_board = $paths.repair_draft_board
        next_logic_queue = $paths.next_logic_queue
        runtime_proof = $proofPath
    }
    checks = [ordered]@{
        reconciliation_discrepancy_count = @($reconciliation.discrepancy_records).Count
        pain_record_count = @($painRegister.pain_records).Count
        repair_draft_count = @($draftBoard.repair_drafts).Count
        next_logic_queue_count = @($queue.queue_items).Count
    }
    boundary_statement = [ordered]@{
        pain_record = "PAIN_RECORD != REPAIR"
        repair_draft = "DRAFT != PATCH"
        queue_item = "QUEUE_ITEM != EXECUTION"
    }
    boundary = New-BodyInspectionBoundary
    errors = @()
}

Write-JsonFile -Path $proofPath -Data $proof
Write-Output $proofPath
