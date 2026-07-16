param(
    [string]$RepoRoot,
    [string]$RuntimeRoot,
    [string]$PolicyPath
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

if (-not $PolicyPath -or $PolicyPath.Trim() -eq "") {
    $PolicyPath = Join-Path $RuntimeRoot "scan_policy_effective.json"
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

    $json = ($Data | ConvertTo-Json -Depth 60) -replace "`r`n", "`n"; $json = $json.TrimEnd() + "`n"; [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
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

function Convert-ToNormalizedRepoPath {
    param(
        [string]$Root,
        [string]$FullPath
    )

    $rootPath = (Resolve-Path -LiteralPath $Root).Path
    while ($rootPath.EndsWith("\") -or $rootPath.EndsWith("/")) {
        $rootPath = $rootPath.Substring(0, $rootPath.Length - 1)
    }

    $resolved = (Resolve-Path -LiteralPath $FullPath).Path
    if ($resolved -eq $rootPath) {
        return "."
    }

    $relative = $resolved.Substring($rootPath.Length)
    while ($relative.StartsWith("\") -or $relative.StartsWith("/")) {
        $relative = $relative.Substring(1)
    }
    return ($relative -replace "\\", "/")
}

function Get-RepoPathDepth {
    param([string]$NormalizedPath)

    if (-not $NormalizedPath -or $NormalizedPath -eq ".") {
        return 0
    }
    return (($NormalizedPath -split "/").Count)
}

function Get-RepoParentDir {
    param([string]$NormalizedPath)

    if (-not $NormalizedPath -or $NormalizedPath -eq ".") {
        return "."
    }

    $parent = Split-Path -Path $NormalizedPath -Parent
    if (-not $parent -or $parent -eq "") {
        return "."
    }

    return ($parent -replace "\\", "/")
}

function Test-DeniedDirName {
    param(
        [string]$Name,
        $Policy
    )

    $lowerName = $Name.ToLowerInvariant()
    foreach ($dir in $Policy.denied_dirs) {
        $dirText = [string]$dir
        if ($dirText.ToLowerInvariant() -eq $lowerName) {
            return $dirText
        }
    }
    return $null
}

function Test-DeniedFilePattern {
    param(
        [string]$Name,
        [string]$NormalizedPath,
        $Policy
    )

    foreach ($pattern in $Policy.denied_file_patterns) {
        $patternText = [string]$pattern
        if ($Name -like $patternText -or $NormalizedPath -like $patternText) {
            return $patternText
        }
    }
    return $null
}

function Get-RoleGuess {
    param(
        [string]$NormalizedPath,
        [string]$Kind,
        [string]$Extension
    )

    $lower = $NormalizedPath.ToLowerInvariant()
    $role = "UNKNOWN"
    $confidence = 0.1
    $evidence = @()
    $riskFlags = @()

    if ($lower -eq ".git" -or $lower.StartsWith(".git/")) {
        $role = "PROTECTED_SURFACE"
        $confidence = 1.0
        $evidence += ".git metadata"
        $riskFlags += "GIT_METADATA"
    } elseif ($lower -eq ".runtime" -or $lower.StartsWith(".runtime/")) {
        $role = "TRANSIENT_RUNTIME"
        $confidence = 0.95
        $evidence += "runtime subtree"
        $riskFlags += "RUNTIME_SURFACE"
    } elseif ($lower -eq "raw_shards" -or $lower.StartsWith("raw_shards/") -or $lower -eq "proofs" -or $lower.StartsWith("proofs/")) {
        $role = "PROTECTED_SURFACE"
        $confidence = 0.9
        $evidence += "protected evidence/raw subtree"
        $riskFlags += "PROTECTED_EVIDENCE_SURFACE"
    } elseif ($Kind -eq "directory") {
        if ($lower -like "operations/*") {
            $role = "UNKNOWN"
            $confidence = 0.25
            $evidence += "operations subtree"
        }
    } else {
        if ($lower -eq "capability_roadmap.json" -or $lower -like "*capability*map*.json") {
            $role = "CAPABILITY_MAP_FILE"
            $confidence = 0.9
            $evidence += "capability map naming"
        } elseif ($lower -eq "packs/registry.json" -or $lower -like "*organ*registry*.json") {
            $role = "ORGAN_REGISTRY_FILE"
            $confidence = 0.85
            $evidence += "registry naming"
        } elseif ($lower -like "*authority*passport*.json") {
            $role = "AUTHORITY_PASSPORT_FILE"
            $confidence = 0.9
            $evidence += "authority passport naming"
        } elseif ($lower -like "*passport*.json") {
            $role = "ORGAN_PASSPORT_FILE"
            $confidence = 0.75
            $evidence += "passport naming"
        } elseif ($lower -like "*organ*contract*.json" -or $lower -like "contracts/*/organ_contract.json") {
            $role = "ORGAN_CONTRACT_FILE"
            $confidence = 0.85
            $evidence += "organ contract naming"
        } elseif ($lower -like "validators/validate_*.ps1") {
            $role = "VALIDATOR_FILE"
            $confidence = 0.9
            $evidence += "validator script naming"
        } elseif ($lower -like "*proof*.json") {
            $role = "PROOF_JSON"
            $confidence = 0.8
            $evidence += "proof json naming"
        } elseif ($lower -like "*runtime*summary*.json" -or $lower -like "*latest*summary*.json") {
            $role = "RUNTIME_SUMMARY"
            $confidence = 0.7
            $evidence += "runtime summary naming"
        } elseif ($lower -like "*repair*draft*board*") {
            $role = "REPAIR_DRAFT_BOARD"
            $confidence = 0.8
            $evidence += "repair draft board naming"
        } elseif ($lower -like "*pain*register*") {
            $role = "BODY_PAIN_REGISTER"
            $confidence = 0.8
            $evidence += "pain register naming"
        } elseif ($lower -like "*handoff*") {
            $role = "HANDOFF_POINTER"
            $confidence = 0.7
            $evidence += "handoff naming"
        } elseif ($lower -like "*plan*.md" -or $lower -eq "operations/body_self_inspection/body_self_inspection_circuit_v1_plan.md") {
            $role = "PLAN_FILE"
            $confidence = 0.7
            $evidence += "plan markdown naming"
        } elseif ($lower -like "modules/invoke_*.ps1" -or $lower -like "orchestrator/*.ps1" -or $lower -like "operations/*/*.ps1") {
            $role = "ORGAN_CANDIDATE_SCRIPT"
            $confidence = 0.45
            $evidence += "weak organ candidate script path"
        } elseif ($lower -like "*map*.json") {
            $role = "MAP_FILE"
            $confidence = 0.55
            $evidence += "map json naming"
        }
    }

    return @{
        role_guess = $role
        confidence = $confidence
        evidence = $evidence
        risk_flags = $riskFlags
    }
}

function New-InventoryRecord {
    param(
        $Item,
        [string]$NormalizedPath,
        [string]$Kind,
        [string]$ScanStatus,
        [string]$SkippedReason,
        [string]$ContentReadStatus,
        [string]$RoleOverride
    )

    $extension = ""
    $sizeBytes = $null
    if ($Kind -eq "file") {
        $extension = $Item.Extension
        $sizeBytes = $Item.Length
    }

    $roleData = Get-RoleGuess -NormalizedPath $NormalizedPath -Kind $Kind -Extension $extension
    if ($RoleOverride -and $RoleOverride.Trim() -ne "") {
        $roleData.role_guess = $RoleOverride
        if ($RoleOverride -eq "HEAVY_SKIPPED_SURFACE") {
            $roleData.confidence = 1.0
            $roleData.evidence += "file exceeded max_content_read_bytes"
            $roleData.risk_flags += "HEAVY_SKIPPED"
        }
        if ($RoleOverride -eq "PROTECTED_SURFACE") {
            $roleData.confidence = 1.0
            $roleData.evidence += "protected surface policy"
            $roleData.risk_flags += "PROTECTED_SURFACE"
        }
    }

    return @{
        path = $NormalizedPath
        normalized_path = $NormalizedPath
        kind = $Kind
        extension = $extension
        size_bytes = $sizeBytes
        mtime_utc = $Item.LastWriteTimeUtc.ToString("o")
        depth = Get-RepoPathDepth -NormalizedPath $NormalizedPath
        parent_dir = Get-RepoParentDir -NormalizedPath $NormalizedPath
        scan_status = $ScanStatus
        skipped_reason = $SkippedReason
        role_guess = $roleData.role_guess
        confidence = $roleData.confidence
        evidence = $roleData.evidence
        content_read_status = $ContentReadStatus
        content_summary_ref = $null
        risk_flags = $roleData.risk_flags
    }
}

function New-SkippedSurface {
    param(
        [string]$Path,
        [string]$Reason,
        [string]$PolicyRule,
        $Item,
        [string]$SummaryRef
    )

    $metadata = @{
        exists = $false
        kind = "unknown"
        size_bytes = $null
        mtime_utc = $null
    }

    if ($Item) {
        $metadata.exists = $true
        if ($Item.PSIsContainer) {
            $metadata.kind = "directory"
        } else {
            $metadata.kind = "file"
            $metadata.size_bytes = $Item.Length
        }
        $metadata.mtime_utc = $Item.LastWriteTimeUtc.ToString("o")
    }

    return @{
        path = $Path
        reason = $Reason
        policy_rule = $PolicyRule
        metadata_seen = $metadata
        summary_ref_if_any = $SummaryRef
    }
}

if (-not (Test-Path -LiteralPath $PolicyPath)) {
    throw "Missing scan policy: $PolicyPath"
}

if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
}

$policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
$scanStartedAt = (Get-Date).ToUniversalTime().ToString("o")
$repoHead = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--short", "HEAD")
$branch = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")

$records = @()
$skippedSurfaces = @()
$recordPaths = @{}
$skippedPaths = @{}
$errors = @()

function Add-Record {
    param($Record)
    $key = $Record.normalized_path.ToLowerInvariant()
    if (-not $recordPaths.ContainsKey($key)) {
        $script:records += $Record
        $script:recordPaths[$key] = $true
    }
}

function Add-Skipped {
    param($Skipped)
    $key = $Skipped.path.ToLowerInvariant()
    if (-not $skippedPaths.ContainsKey($key)) {
        $script:skippedSurfaces += $Skipped
        $script:skippedPaths[$key] = $true
    }
}

$stack = @($RepoRoot)

while ($stack.Count -gt 0) {
    $current = $stack[$stack.Count - 1]
    if ($stack.Count -gt 1) {
        $stack = $stack[0..($stack.Count - 2)]
    } else {
        $stack = @()
    }

    try {
        $children = @(Get-ChildItem -Force -LiteralPath $current -ErrorAction Stop)
    } catch {
        $normalizedCurrent = Convert-ToNormalizedRepoPath -Root $RepoRoot -FullPath $current
        $errors += @{
            path = $normalizedCurrent
            status = "READ_FAILED"
            error_class = "DIRECTORY_ENUMERATION_FAILED"
            message = $_.Exception.Message
        }
        continue
    }

    foreach ($child in $children) {
        $normalized = Convert-ToNormalizedRepoPath -Root $RepoRoot -FullPath $child.FullName
        if ($child.PSIsContainer) {
            $kind = "directory"
            $deniedRule = Test-DeniedDirName -Name $child.Name -Policy $policy
            if ($deniedRule) {
                $roleOverride = $null
                $skipReason = "DENIED_DIR"
                if ($child.Name -eq ".git") {
                    $roleOverride = "PROTECTED_SURFACE"
                    $skipReason = "PROTECTED_SURFACE_POLICY_DENIED"
                } elseif ($child.Name -eq ".runtime") {
                    $roleOverride = "PROTECTED_SURFACE"
                    $skipReason = "RUNTIME_BULK_POLICY_DENIED"
                }

                Add-Record -Record (New-InventoryRecord -Item $child -NormalizedPath $normalized -Kind $kind -ScanStatus "SKIPPED" -SkippedReason $skipReason -ContentReadStatus "NOT_READ_POLICY_SKIPPED" -RoleOverride $roleOverride)
                Add-Skipped -Skipped (New-SkippedSurface -Path $normalized -Reason $skipReason -PolicyRule "denied_dirs:$deniedRule" -Item $child -SummaryRef $null)
                continue
            }

            Add-Record -Record (New-InventoryRecord -Item $child -NormalizedPath $normalized -Kind $kind -ScanStatus "METADATA_ONLY" -SkippedReason $null -ContentReadStatus "NOT_APPLICABLE" -RoleOverride $null)
            $stack += $child.FullName
        } else {
            $kind = "file"
            $deniedPattern = Test-DeniedFilePattern -Name $child.Name -NormalizedPath $normalized -Policy $policy
            if ($deniedPattern) {
                Add-Record -Record (New-InventoryRecord -Item $child -NormalizedPath $normalized -Kind $kind -ScanStatus "SKIPPED" -SkippedReason "DENIED_FILE_PATTERN" -ContentReadStatus "NOT_READ_POLICY_SKIPPED" -RoleOverride $null)
                Add-Skipped -Skipped (New-SkippedSurface -Path $normalized -Reason "DENIED_FILE_PATTERN" -PolicyRule "denied_file_patterns:$deniedPattern" -Item $child -SummaryRef $null)
                continue
            }

            if ($child.Length -gt [int64]$policy.max_content_read_bytes) {
                Add-Record -Record (New-InventoryRecord -Item $child -NormalizedPath $normalized -Kind $kind -ScanStatus "METADATA_ONLY" -SkippedReason "CONTENT_HEAVY_METADATA_ONLY" -ContentReadStatus "METADATA_ONLY_SIZE_LIMIT" -RoleOverride "HEAVY_SKIPPED_SURFACE")
                Add-Skipped -Skipped (New-SkippedSurface -Path $normalized -Reason "CONTENT_HEAVY_METADATA_ONLY" -PolicyRule "max_content_read_bytes:$($policy.max_content_read_bytes)" -Item $child -SummaryRef $null)
                continue
            }

            Add-Record -Record (New-InventoryRecord -Item $child -NormalizedPath $normalized -Kind $kind -ScanStatus "METADATA_ONLY" -SkippedReason $null -ContentReadStatus "METADATA_ONLY" -RoleOverride $null)
        }
    }
}

$explicitProtected = @(
    ".git",
    ".runtime",
    ".runtime/active_compact_semantic_memory_v1",
    "accepted-core",
    "raw_shards",
    "proofs",
    "runtime_sessions",
    "zz_MUSORKA_DO_NOT_READ_BY_CODEX"
)

foreach ($protectedPath in $explicitProtected) {
    $full = Join-Path $RepoRoot ($protectedPath -replace "/", "\")
    if (Test-Path -LiteralPath $full) {
        $item = Get-Item -Force -LiteralPath $full
        $kind = "file"
        if ($item.PSIsContainer) {
            $kind = "directory"
        }
        $reason = "PROTECTED_SURFACE_POLICY_DENIED"
        if ($protectedPath -eq ".runtime" -or $protectedPath.StartsWith(".runtime/")) {
            $reason = "RUNTIME_BULK_POLICY_DENIED"
        }
        Add-Record -Record (New-InventoryRecord -Item $item -NormalizedPath $protectedPath -Kind $kind -ScanStatus "SKIPPED" -SkippedReason $reason -ContentReadStatus "NOT_READ_POLICY_SKIPPED" -RoleOverride "PROTECTED_SURFACE")
        Add-Skipped -Skipped (New-SkippedSurface -Path $protectedPath -Reason $reason -PolicyRule "protected_surfaces/runtime_read_policy" -Item $item -SummaryRef $null)
    }
}

$requiredRootMarkers = @(
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
)

$rootMarkers = @()
foreach ($marker in $requiredRootMarkers) {
    $full = Join-Path $RepoRoot ($marker -replace "/", "\")
    $exists = Test-Path -LiteralPath $full
    $markerRecord = @{
        path = $marker
        exists = $exists
        kind = "missing"
        size_bytes = $null
        mtime_utc = $null
        status = "ROOT_MARKER_MISSING"
    }

    if ($exists) {
        $item = Get-Item -Force -LiteralPath $full
        if ($item.PSIsContainer) {
            $markerRecord.kind = "directory"
        } else {
            $markerRecord.kind = "file"
            $markerRecord.size_bytes = $item.Length
        }
        $markerRecord.mtime_utc = $item.LastWriteTimeUtc.ToString("o")
        $markerRecord.status = "ROOT_MARKER_PRESENT"
    }

    $rootMarkers += $markerRecord
}

$allowedRoles = @(
    "UNKNOWN",
    "MAP_FILE",
    "CAPABILITY_MAP_FILE",
    "ORGAN_REGISTRY_FILE",
    "ORGAN_CANDIDATE_SCRIPT",
    "ORGAN_CONTRACT_FILE",
    "ORGAN_PASSPORT_FILE",
    "AUTHORITY_PASSPORT_FILE",
    "VALIDATOR_FILE",
    "PROOF_JSON",
    "RUNTIME_SUMMARY",
    "REPAIR_DRAFT_BOARD",
    "BODY_PAIN_REGISTER",
    "HANDOFF_POINTER",
    "PLAN_FILE",
    "TRANSIENT_RUNTIME",
    "PROTECTED_SURFACE",
    "HEAVY_SKIPPED_SURFACE"
)

$roleCounts = @{}
foreach ($role in $allowedRoles) {
    $roleCounts[$role] = 0
}

foreach ($record in $records) {
    $role = [string]$record.role_guess
    if (-not $roleCounts.ContainsKey($role)) {
        $roleCounts[$role] = 0
    }
    $roleCounts[$role] = $roleCounts[$role] + 1
}

$filesSeen = @($records | Where-Object { $_.kind -eq "file" })
$dirsSeen = @($records | Where-Object { $_.kind -eq "directory" })
$filesSkipped = @($records | Where-Object { $_.kind -eq "file" -and $_.scan_status -eq "SKIPPED" })
$dirsSkipped = @($records | Where-Object { $_.kind -eq "directory" -and $_.scan_status -eq "SKIPPED" })
$contentMetadataOnly = @($records | Where-Object { $_.kind -eq "file" -and ($_.content_read_status -eq "METADATA_ONLY" -or $_.content_read_status -eq "METADATA_ONLY_SIZE_LIMIT") })

$aggregates = @{
    total_files_seen = $filesSeen.Count
    total_dirs_seen = $dirsSeen.Count
    files_skipped = $filesSkipped.Count
    dirs_skipped = $dirsSkipped.Count
    content_files_read = 0
    content_files_metadata_only = $contentMetadataOnly.Count
    role_counts = $roleCounts
    organ_candidate_count = $roleCounts["ORGAN_CANDIDATE_SCRIPT"]
    passport_file_count = ($roleCounts["ORGAN_PASSPORT_FILE"] + $roleCounts["AUTHORITY_PASSPORT_FILE"])
    contract_file_count = $roleCounts["ORGAN_CONTRACT_FILE"]
    validator_file_count = $roleCounts["VALIDATOR_FILE"]
    proof_json_count = $roleCounts["PROOF_JSON"]
    runtime_summary_count = $roleCounts["RUNTIME_SUMMARY"]
    heavy_skipped_count = $roleCounts["HEAVY_SKIPPED_SURFACE"]
    protected_skipped_count = $roleCounts["PROTECTED_SURFACE"]
}

$skipReasonCounts = @{}
foreach ($skipped in $skippedSurfaces) {
    $reason = [string]$skipped.reason
    if (-not $skipReasonCounts.ContainsKey($reason)) {
        $skipReasonCounts[$reason] = 0
    }
    $skipReasonCounts[$reason] = $skipReasonCounts[$reason] + 1
}

$scanFinishedAt = (Get-Date).ToUniversalTime().ToString("o")

$inventory = @{
    schema = "body_repo_inventory_v1"
    status = "PASS_BODY_REPO_INVENTORY_V1"
    scan_started_at = $scanStartedAt
    scan_finished_at = $scanFinishedAt
    repo_root = $RepoRoot
    repo_head = $repoHead
    branch = $branch
    scan_policy_ref = $PolicyPath
    root_markers = $rootMarkers
    records = $records
    aggregates = $aggregates
    stale_after = @{
        body_reality = "24h"
        active_runtime_references = "1h"
        immediate_stale_if_git_head_changes = $true
    }
    boundary = New-BodyScanBoundary
    errors = $errors
}

$skippedOutput = @{
    schema = "body_scan_skipped_surfaces_v1"
    status = "PASS_BODY_SCAN_SKIPPED_SURFACES_V1"
    generated_at = $scanFinishedAt
    skipped_surfaces = $skippedSurfaces
    aggregates = @{
        total_skipped_surfaces = $skippedSurfaces.Count
        skipped_by_reason = $skipReasonCounts
        metadata_seen_count = @($skippedSurfaces | Where-Object { $_.metadata_seen.exists -eq $true }).Count
    }
    boundary = New-BodyScanBoundary
}

$inventoryPath = Join-Path $RuntimeRoot "repo_inventory.json"
$skippedPath = Join-Path $RuntimeRoot "scan_skipped_surfaces.json"

Write-JsonFile -Path $inventoryPath -Data $inventory
Write-JsonFile -Path $skippedPath -Data $skippedOutput

Write-Output $inventoryPath
Write-Output $skippedPath
