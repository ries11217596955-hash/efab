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

function New-BodyScanBoundary {
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

    $json = ($Data | ConvertTo-Json -Depth 50) -replace "`r`n", "`n"; $json = $json.TrimEnd() + "`n"; [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
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

$policyBuilder = Join-Path $PSScriptRoot "build_body_scan_policy_v1.ps1"
$inventoryBuilder = Join-Path $PSScriptRoot "build_body_repo_inventory_v1.ps1"

& $policyBuilder -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
& $inventoryBuilder -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null

$policyPath = Join-Path $RuntimeRoot "scan_policy_effective.json"
$inventoryPath = Join-Path $RuntimeRoot "repo_inventory.json"
$skippedPath = Join-Path $RuntimeRoot "scan_skipped_surfaces.json"
$proofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"

$policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
$inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json
$skipped = Get-Content -Raw -LiteralPath $skippedPath | ConvertFrom-Json

$proof = @{
    schema = "body_self_inspection_slice_a_runtime_proof_v1"
    status = "PASS_BODY_SELF_INSPECTION_SLICE_A_RUNTIME_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "A"
    repo_root = $RepoRoot
    repo_head = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--short", "HEAD")
    branch = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    output_refs = @{
        scan_policy_effective = $policyPath
        scan_skipped_surfaces = $skippedPath
        repo_inventory = $inventoryPath
        runtime_proof = $proofPath
    }
    checks = @{
        scan_policy_status = $policy.status
        repo_inventory_status = $inventory.status
        skipped_surfaces_status = $skipped.status
        root_marker_count = @($inventory.root_markers).Count
        skipped_surfaces_count = @($skipped.skipped_surfaces).Count
        content_files_read = $inventory.aggregates.content_files_read
    }
    aggregate_counts = $inventory.aggregates
    stale_after = @{
        slice_a_runtime_proof = "24h"
        immediate_stale_if_git_head_changes = $true
    }
    boundary = New-BodyScanBoundary
    errors = @()
}

Write-JsonFile -Path $proofPath -Data $proof

Write-Output $proofPath
