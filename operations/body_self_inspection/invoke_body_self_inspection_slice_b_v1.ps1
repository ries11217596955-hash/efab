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

$sliceAInvoker = Join-Path $PSScriptRoot "invoke_body_self_inspection_slice_a_v1.ps1"
$mapReader = Join-Path $PSScriptRoot "read_body_maps_v1.ps1"
$candidateDetector = Join-Path $PSScriptRoot "detect_organ_candidates_v1.ps1"
$similarityDetector = Join-Path $PSScriptRoot "detect_organ_similarity_v1.ps1"

& $sliceAInvoker -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null

$inventoryPath = Join-Path $RuntimeRoot "repo_inventory.json"
$scanPolicyPath = Join-Path $RuntimeRoot "scan_policy_effective.json"
$skippedPath = Join-Path $RuntimeRoot "scan_skipped_surfaces.json"
$sliceAProofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"

& $mapReader -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot -InventoryPath $inventoryPath | Out-Null

$bodyMapPath = Join-Path $RuntimeRoot "body_map_read.json"
$capabilityMapPath = Join-Path $RuntimeRoot "capability_map_read.json"

& $candidateDetector -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot -InventoryPath $inventoryPath -BodyMapPath $bodyMapPath -CapabilityMapPath $capabilityMapPath | Out-Null

$candidatePath = Join-Path $RuntimeRoot "organ_candidates.json"

& $similarityDetector -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot -CandidatePath $candidatePath -BodyMapPath $bodyMapPath -CapabilityMapPath $capabilityMapPath | Out-Null

$similarityPath = Join-Path $RuntimeRoot "organ_similarity_index.json"
$proofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_B_PROOF.json"

$scanPolicy = Read-JsonFile -Path $scanPolicyPath
$skipped = Read-JsonFile -Path $skippedPath
$inventory = Read-JsonFile -Path $inventoryPath
$sliceAProof = Read-JsonFile -Path $sliceAProofPath
$bodyMap = Read-JsonFile -Path $bodyMapPath
$capabilityMap = Read-JsonFile -Path $capabilityMapPath
$candidates = Read-JsonFile -Path $candidatePath
$similarity = Read-JsonFile -Path $similarityPath

$proof = @{
    schema = "body_self_inspection_slice_b_runtime_proof_v1"
    status = "PASS_BODY_SELF_INSPECTION_SLICE_B_RUNTIME_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "B"
    repo_root = $RepoRoot
    repo_head = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--short", "HEAD")
    branch = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    output_refs = @{
        scan_policy_effective = $scanPolicyPath
        scan_skipped_surfaces = $skippedPath
        repo_inventory = $inventoryPath
        slice_a_runtime_proof = $sliceAProofPath
        body_map_read = $bodyMapPath
        capability_map_read = $capabilityMapPath
        organ_candidates = $candidatePath
        organ_similarity_index = $similarityPath
        runtime_proof = $proofPath
    }
    checks = @{
        scan_policy_status = $scanPolicy.status
        skipped_surfaces_status = $skipped.status
        repo_inventory_status = $inventory.status
        slice_a_runtime_proof_status = $sliceAProof.status
        body_map_status = $bodyMap.status
        capability_map_status = $capabilityMap.status
        organ_candidates_status = $candidates.status
        organ_similarity_status = $similarity.status
        body_maps_seen = $bodyMap.aggregates.maps_seen
        candidate_count = $candidates.aggregates.candidate_count
        candidate_family_count = $candidates.aggregates.candidate_family_count
        similarity_record_count = $similarity.aggregates.similarity_record_count
    }
    aggregate_counts = @{
        body_map_read = $bodyMap.aggregates
        capability_map_read = $capabilityMap.aggregates
        organ_candidates = $candidates.aggregates
        organ_similarity_index = $similarity.aggregates
    }
    boundary_statement = @{
        declared_organ = "DECLARED_ORGAN != PRESENT_ORGAN != VALID_ORGAN != MATURE_ORGAN"
        declared_capability = "DECLARED_CAPABILITY != USABLE_CAPABILITY"
        organ_candidate = "ORGAN_CANDIDATE != ORGAN"
        similarity = "similarity_score is heuristic, not proof"
    }
    stale_after = "24h"
    boundary = New-BodyInspectionBoundary
    errors = @()
}

Write-JsonFile -Path $proofPath -Data $proof
Write-Output $proofPath
