param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

$RuntimeRoot = Join-Path $RepoRoot ".runtime\body_self_inspection_v1"
$InvokerPath = Join-Path $RepoRoot "operations\body_self_inspection\invoke_body_self_inspection_slice_a_v1.ps1"
$TrackedProofPath = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_A_V1_PROOF.json"

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

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Add-Failure {
    param([string]$Message)
    $script:Failures += $Message
}

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message
    )

    $script:Checks += @{
        name = $Name
        passed = $Passed
        message = $Message
    }

    if (-not $Passed) {
        Add-Failure -Message $Message
    }
}

function Test-HasProperty {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $false
    }
    return (@($Object.PSObject.Properties.Name) -contains $Name)
}

function Test-BoundaryFalse {
    param(
        $Object,
        [string]$Flag
    )

    if (-not (Test-HasProperty -Object $Object -Name "boundary")) {
        return $false
    }
    if (-not (Test-HasProperty -Object $Object.boundary -Name $Flag)) {
        return $false
    }
    return ($Object.boundary.$Flag -eq $false)
}

$Failures = @()
$Checks = @()
$Blocked = $false
$OutputRefs = @{
    scan_policy_effective = Join-Path $RuntimeRoot "scan_policy_effective.json"
    scan_skipped_surfaces = Join-Path $RuntimeRoot "scan_skipped_surfaces.json"
    repo_inventory = Join-Path $RuntimeRoot "repo_inventory.json"
    runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"
}

try {
    if (-not (Test-Path -LiteralPath $InvokerPath)) {
        $Blocked = $true
        throw "Missing invoker: $InvokerPath"
    }

    & $InvokerPath -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
} catch {
    $Blocked = $true
    Add-Failure -Message ("Invoker failed: " + $_.Exception.Message)
}

$policy = $null
$skipped = $null
$inventory = $null
$runtimeProof = $null

try {
    $policy = Read-JsonFile -Path $OutputRefs.scan_policy_effective
    Add-Check -Name "scan_policy_parses" -Passed $true -Message "scan_policy_effective.json parses"
} catch {
    Add-Check -Name "scan_policy_parses" -Passed $false -Message $_.Exception.Message
}

try {
    $skipped = Read-JsonFile -Path $OutputRefs.scan_skipped_surfaces
    Add-Check -Name "skipped_surfaces_parses" -Passed $true -Message "scan_skipped_surfaces.json parses"
} catch {
    Add-Check -Name "skipped_surfaces_parses" -Passed $false -Message $_.Exception.Message
}

try {
    $inventory = Read-JsonFile -Path $OutputRefs.repo_inventory
    Add-Check -Name "repo_inventory_parses" -Passed $true -Message "repo_inventory.json parses"
} catch {
    Add-Check -Name "repo_inventory_parses" -Passed $false -Message $_.Exception.Message
}

try {
    $runtimeProof = Read-JsonFile -Path $OutputRefs.runtime_proof
    Add-Check -Name "runtime_proof_parses" -Passed $true -Message "BODY_SELF_INSPECTION_SLICE_A_PROOF.json parses"
} catch {
    Add-Check -Name "runtime_proof_parses" -Passed $false -Message $_.Exception.Message
}

if ($policy) {
    Add-Check -Name "policy_status_pass" -Passed ($policy.status -eq "PASS_BODY_SCAN_POLICY_V1") -Message "scan policy status must be PASS_BODY_SCAN_POLICY_V1"
    Add-Check -Name "policy_stale_after_exists" -Passed (Test-HasProperty -Object $policy -Name "stale_after") -Message "scan policy stale_after exists"

    $requiredDeniedDirs = @(
        ".git",
        "node_modules",
        ".venv",
        "env",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache",
        "dist",
        "build",
        "cache",
        "tmp",
        "temp",
        "large archives",
        "generated streaming chunks",
        "old raw school run bodies",
        "stale raw runtime chunks"
    )

    foreach ($dir in $requiredDeniedDirs) {
        Add-Check -Name ("policy_denied_dir_" + $dir) -Passed (@($policy.denied_dirs) -contains $dir) -Message ("policy denied_dirs includes " + $dir)
    }

    $requiredGitDeny = @("git add", "git commit", "git push", "git clean", "git checkout", "git reset")
    foreach ($cmd in $requiredGitDeny) {
        Add-Check -Name ("policy_git_deny_" + $cmd) -Passed (@($policy.git_command_denylist) -contains $cmd) -Message ("git denylist includes " + $cmd)
    }

    $requiredGitAllow = @("git status", "git rev-parse", "git rev-list", "git log")
    foreach ($cmd in $requiredGitAllow) {
        Add-Check -Name ("policy_git_allow_" + $cmd) -Passed (@($policy.git_command_allowlist) -contains $cmd) -Message ("git allowlist includes " + $cmd)
    }

    Add-Check -Name "policy_max_content_read_bytes" -Passed ($policy.max_content_read_bytes -eq 262144) -Message "max_content_read_bytes is 262144"
}

if ($inventory) {
    Add-Check -Name "inventory_status_pass" -Passed ($inventory.status -eq "PASS_BODY_REPO_INVENTORY_V1") -Message "repo inventory status must be PASS_BODY_REPO_INVENTORY_V1"
    Add-Check -Name "inventory_boundary_exists" -Passed (Test-HasProperty -Object $inventory -Name "boundary") -Message "repo inventory includes boundary proof"
    Add-Check -Name "inventory_stale_after_exists" -Passed (Test-HasProperty -Object $inventory -Name "stale_after") -Message "repo inventory stale_after exists"
    Add-Check -Name "inventory_root_markers_exists" -Passed (Test-HasProperty -Object $inventory -Name "root_markers") -Message "repo inventory includes root marker checks"

    $requiredMarkers = @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")
    $markerPaths = @()
    foreach ($marker in @($inventory.root_markers)) {
        $markerPaths += $marker.path
    }
    foreach ($markerPath in $requiredMarkers) {
        Add-Check -Name ("root_marker_checked_" + $markerPath) -Passed ($markerPaths -contains $markerPath) -Message ("root marker checked: " + $markerPath)
    }

    $requiredAggregateFields = @(
        "total_files_seen",
        "total_dirs_seen",
        "files_skipped",
        "dirs_skipped",
        "content_files_read",
        "content_files_metadata_only",
        "role_counts",
        "organ_candidate_count",
        "passport_file_count",
        "contract_file_count",
        "validator_file_count",
        "proof_json_count",
        "runtime_summary_count",
        "heavy_skipped_count",
        "protected_skipped_count"
    )
    foreach ($field in $requiredAggregateFields) {
        Add-Check -Name ("aggregate_field_" + $field) -Passed (Test-HasProperty -Object $inventory.aggregates -Name $field) -Message ("aggregate field exists: " + $field)
    }

    Add-Check -Name "role_counts_exists" -Passed (Test-HasProperty -Object $inventory.aggregates -Name "role_counts") -Message "role_counts exists"
    Add-Check -Name "no_content_files_read" -Passed ($inventory.aggregates.content_files_read -eq 0) -Message "Slice A inventory must not bulk-read file content"

    $requiredRecordFields = @(
        "path",
        "normalized_path",
        "kind",
        "extension",
        "size_bytes",
        "mtime_utc",
        "depth",
        "parent_dir",
        "scan_status",
        "skipped_reason",
        "role_guess",
        "confidence",
        "evidence",
        "content_read_status",
        "content_summary_ref",
        "risk_flags"
    )

    $recordsHaveFields = $true
    foreach ($record in @($inventory.records)) {
        foreach ($field in $requiredRecordFields) {
            if (-not (Test-HasProperty -Object $record -Name $field)) {
                $recordsHaveFields = $false
            }
        }
    }
    Add-Check -Name "records_required_fields" -Passed $recordsHaveFields -Message "all inventory records include required fields"

    $runtimeBulkRead = $false
    foreach ($record in @($inventory.records)) {
        $path = [string]$record.normalized_path
        if (($path -eq ".runtime" -or $path.StartsWith(".runtime/")) -and $record.scan_status -ne "SKIPPED") {
            $runtimeBulkRead = $true
        }
        if (($path -eq ".runtime" -or $path.StartsWith(".runtime/")) -and $record.content_read_status -notlike "NOT_READ*") {
            $runtimeBulkRead = $true
        }
    }
    Add-Check -Name "runtime_raw_chunks_not_bulk_read" -Passed (-not $runtimeBulkRead) -Message "runtime bulk surfaces are skipped or policy-denied"
}

if ($skipped) {
    Add-Check -Name "skipped_status_pass" -Passed ($skipped.status -eq "PASS_BODY_SCAN_SKIPPED_SURFACES_V1") -Message "skipped surfaces status is PASS"
    Add-Check -Name "skipped_surfaces_present" -Passed (@($skipped.skipped_surfaces).Count -gt 0) -Message "skipped surfaces output is populated"

    $skippedPaths = @()
    foreach ($surface in @($skipped.skipped_surfaces)) {
        $skippedPaths += $surface.path
    }

    Add-Check -Name "git_surface_skipped" -Passed ($skippedPaths -contains ".git") -Message ".git surface is skipped or policy-denied"
    Add-Check -Name "runtime_surface_skipped" -Passed ($skippedPaths -contains ".runtime") -Message ".runtime surface is skipped or policy-denied"
    if (Test-Path -LiteralPath (Join-Path $RepoRoot ".runtime\active_compact_semantic_memory_v1")) {
        Add-Check -Name "active_memory_surface_skipped" -Passed ($skippedPaths -contains ".runtime/active_compact_semantic_memory_v1") -Message "active compact memory surface is skipped or policy-denied"
    }
}

if ($runtimeProof) {
    Add-Check -Name "runtime_proof_status_pass" -Passed ($runtimeProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_A_RUNTIME_V1") -Message "runtime proof status must be PASS"
    Add-Check -Name "runtime_proof_stale_after_exists" -Passed (Test-HasProperty -Object $runtimeProof -Name "stale_after") -Message "runtime proof stale_after exists"
}

$objectsWithBoundaries = @(
    @{ name = "policy"; value = $policy },
    @{ name = "skipped"; value = $skipped },
    @{ name = "inventory"; value = $inventory },
    @{ name = "runtime_proof"; value = $runtimeProof }
)

$boundaryFlags = @(
    "repo_mutated",
    "active_memory_mutated",
    "accepted_core_mutated",
    "body_map_mutated",
    "capability_map_mutated",
    "live_process_touched",
    "codex_launched",
    "web_launched",
    "cleanup_performed"
)

foreach ($entry in $objectsWithBoundaries) {
    foreach ($flag in $boundaryFlags) {
        $checkName = "boundary_" + $entry.name + "_" + $flag
        Add-Check -Name $checkName -Passed (Test-BoundaryFalse -Object $entry.value -Flag $flag) -Message ($entry.name + " boundary flag is false: " + $flag)
    }
}

$status = "PASS_BODY_SELF_INSPECTION_SLICE_A_V1"
if ($Failures.Count -gt 0) {
    $status = "FAIL_BODY_SELF_INSPECTION_SLICE_A_V1"
}
if ($Blocked) {
    $status = "BLOCKED_BODY_SELF_INSPECTION_SLICE_A_V1"
}

$proof = @{
    schema = "body_self_inspection_slice_a_validator_proof_v1"
    status = $status
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    validator_ref = "validators/validate_body_self_inspection_slice_a_v1.ps1"
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "A"
    output_refs = $OutputRefs
    validator_checks = $Checks
    aggregate_counts = @{
        repo_inventory = $(if ($inventory) { $inventory.aggregates } else { $null })
        skipped_surfaces = $(if ($skipped) { $skipped.aggregates } else { $null })
    }
    boundary = New-BodyScanBoundary
    errors = $Failures
}

Write-JsonFile -Path $TrackedProofPath -Data $proof

if ($Failures.Count -gt 0) {
    Write-Output ("STATUS=" + $status)
    foreach ($failure in $Failures) {
        Write-Output ("FAIL=" + $failure)
    }
    exit 1
}

Write-Output ("STATUS=" + $status)
Write-Output ("PROOF=" + $TrackedProofPath)
exit 0
