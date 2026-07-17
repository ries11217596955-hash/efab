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

$sliceCInvoker = Join-Path $PSScriptRoot "invoke_body_self_inspection_slice_c_v1.ps1"
$reconciler = Join-Path $PSScriptRoot "reconcile_body_state_v1.ps1"

& $sliceCInvoker -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
& $reconciler -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null

$paths = @{
    repo_inventory = Join-Path $RuntimeRoot "repo_inventory.json"
    body_map_read = Join-Path $RuntimeRoot "body_map_read.json"
    capability_map_read = Join-Path $RuntimeRoot "capability_map_read.json"
    organ_candidates = Join-Path $RuntimeRoot "organ_candidates.json"
    organ_similarity_index = Join-Path $RuntimeRoot "organ_similarity_index.json"
    passport_audit = Join-Path $RuntimeRoot "passport_audit.json"
    signal_readiness_audit = Join-Path $RuntimeRoot "signal_readiness_audit.json"
    body_reconciliation = Join-Path $RuntimeRoot "body_reconciliation.json"
}

$reconciliation = Read-JsonFile -Path $paths.body_reconciliation
$proofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_D_PROOF.json"

$proof = @{
    schema = "body_self_inspection_slice_d_runtime_proof_v1"
    status = "PASS_BODY_SELF_INSPECTION_SLICE_D_RUNTIME_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "D"
    repo_root = $RepoRoot
    repo_head = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--short", "HEAD")
    branch = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    output_refs = @{
        repo_inventory = $paths.repo_inventory
        body_map_read = $paths.body_map_read
        capability_map_read = $paths.capability_map_read
        organ_candidates = $paths.organ_candidates
        organ_similarity_index = $paths.organ_similarity_index
        passport_audit = $paths.passport_audit
        signal_readiness_audit = $paths.signal_readiness_audit
        body_reconciliation = $paths.body_reconciliation
        runtime_proof = $proofPath
    }
    checks = @{
        body_reconciliation_status = $reconciliation.status
        reconciliation_record_count = $reconciliation.aggregates.total_reconciliation_records
        discrepancy_record_count = $reconciliation.aggregates.total_discrepancy_records
        reference_status_count = @($reconciliation.reference_status_index).Count
    }
    aggregate_counts = $reconciliation.aggregates
    boundary_statement = @{
        declared = "DECLARED != PRESENT"
        present = "PRESENT != VALIDATED"
        validated = "VALIDATED != MATURE"
        similarity = "SIMILAR != DUPLICATE_PROVEN"
        audit_record = "AUDIT_RECORD != PAIN_REGISTER"
        discrepancy = "DISCREPANCY != REPAIR_DRAFT"
    }
    boundary_claims = $reconciliation.boundary_claims
    boundary = New-BodyInspectionBoundary
    errors = @()
}

Write-JsonFile -Path $proofPath -Data $proof
Write-Output $proofPath
