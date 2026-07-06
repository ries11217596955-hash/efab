param(
    [ValidateSet("", "Begin", "Commit", "Rollback", "Fail")][string]$Action = "",
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$RuntimeRoot = "",
    [string]$TransactionId = "",
    [string]$ManifestPath = "",
    [string[]]$ProtectedPath = @(
        "packs/registry.json",
        "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
        "reports/self_development/accepted_change_memory_snapshot.json"
    ),
    [string[]]$ExpectedChangedPath = @(),
    [switch]$RequireAnyProtectedChange,
    [string]$SuccessConditionPath = "",
    [string]$SuccessConditionProperty = "status",
    [string]$SuccessConditionValue = "PASS",
    [string]$FailureReason = "CALLER_REPORTED_FAILURE"
)

$ErrorActionPreference = "Stop"

function Get-ProtectedSurfaceUtcNow {
    return (Get-Date).ToUniversalTime().ToString("o")
}

function ConvertTo-ProtectedSurfaceFullPath {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-ProtectedSurfaceRelativePath {
    param(
        [Parameter(Mandatory=$true)][string]$Root,
        [Parameter(Mandatory=$true)][string]$Path
    )

    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        return ($Path -replace "\\", "/")
    }

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $rootUri = [System.Uri]::new($rootFull + [System.IO.Path]::DirectorySeparatorChar)
    $pathUri = [System.Uri]::new($pathFull)
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString())
}

function Get-ProtectedSurfaceFileHash {
    param([Parameter(Mandatory=$true)][string]$Path)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            return "sha256:" + (($sha.ComputeHash($stream) | ForEach-Object { $_.ToString("x2") }) -join "")
        } finally {
            $stream.Dispose()
        }
    } finally {
        $sha.Dispose()
    }
}

function Get-ProtectedSurfaceSafeName {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (($Path -replace "[:\\/]+", "_") -replace "[^A-Za-z0-9_.-]", "_")
}

function Read-ProtectedSurfaceManifest {
    param([Parameter(Mandatory=$true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "PROTECTED_SURFACE_TRANSACTION_MANIFEST_MISSING=$Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ProtectedSurfaceSnapshotEntry {
    param(
        [Parameter(Mandatory=$true)]$Manifest,
        [Parameter(Mandatory=$true)][string]$Path
    )

    $relative = ConvertTo-ProtectedSurfaceRelativePath -Root ([string]$Manifest.repo_root) -Path $Path
    foreach ($entry in @($Manifest.protected_files)) {
        if ([string]$entry.relative_path -eq $relative) {
            return $entry
        }
    }

    return $null
}

function Test-ProtectedSurfaceEntryChanged {
    param(
        [Parameter(Mandatory=$true)]$Manifest,
        [Parameter(Mandatory=$true)]$Entry
    )

    $currentExists = Test-Path -LiteralPath ([string]$Entry.full_path) -PathType Leaf
    if ([bool]$Entry.existed -ne $currentExists) {
        return $true
    }

    if (-not $currentExists) {
        return $false
    }

    $currentHash = Get-ProtectedSurfaceFileHash -Path ([string]$Entry.full_path)
    return ($currentHash -ne [string]$Entry.sha256)
}

function Compare-ProtectedSurfaceToSnapshot {
    param([Parameter(Mandatory=$true)]$Manifest)

    $mismatches = @()
    foreach ($entry in @($Manifest.protected_files)) {
        $existsNow = Test-Path -LiteralPath ([string]$entry.full_path) -PathType Leaf

        if ([bool]$entry.existed -ne $existsNow) {
            $mismatches += [string]$entry.relative_path
            continue
        }

        if ($existsNow) {
            $hashNow = Get-ProtectedSurfaceFileHash -Path ([string]$entry.full_path)
            if ($hashNow -ne [string]$entry.sha256) {
                $mismatches += [string]$entry.relative_path
            }
        }
    }

    return [ordered]@{
        protected_surface_clean_after = ($mismatches.Count -eq 0)
        mismatched_paths = @($mismatches)
    }
}

function Invoke-ProtectedSurfaceTransactionBegin {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$RuntimeRoot,
        [string]$TransactionId = "",
        [string[]]$ProtectedPath = @()
    )

    if ([string]::IsNullOrWhiteSpace($TransactionId)) {
        $TransactionId = "pst_" + (Get-Date -Format "yyyyMMdd_HHmmss_ffff") + "_" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
    }

    $repoFull = [System.IO.Path]::GetFullPath($RepoRoot)
    $runtimeFull = [System.IO.Path]::GetFullPath($RuntimeRoot)
    $transactionRoot = Join-Path $runtimeFull $TransactionId
    $snapshotRoot = Join-Path $transactionRoot "snapshots"

    New-Item -ItemType Directory -Force -Path $transactionRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $snapshotRoot | Out-Null

    $entries = @()
    $index = 0
    foreach ($path in $ProtectedPath) {
        $index += 1
        $fullPath = ConvertTo-ProtectedSurfaceFullPath -Root $repoFull -Path $path
        $relativePath = ConvertTo-ProtectedSurfaceRelativePath -Root $repoFull -Path $fullPath
        $exists = Test-Path -LiteralPath $fullPath -PathType Leaf
        $snapshotPath = ""
        $length = 0
        $sha256 = ""
        $lastWriteUtc = ""
        $attributes = ""

        if ($exists) {
            $safeName = "{0:D3}.bin" -f $index
            $snapshotPath = Join-Path $snapshotRoot $safeName
            $snapshotParent = Split-Path -Parent $snapshotPath
            if ($snapshotParent) {
                [System.IO.Directory]::CreateDirectory($snapshotParent) | Out-Null
            }
            Copy-Item -LiteralPath $fullPath -Destination $snapshotPath -Force
            $length = (Get-Item -LiteralPath $snapshotPath).Length
            $sha256 = Get-ProtectedSurfaceFileHash -Path $fullPath
            $lastWriteUtc = ([System.IO.File]::GetLastWriteTimeUtc($fullPath)).ToString("o")
            $attributes = ([System.IO.File]::GetAttributes($fullPath)).ToString()
        }

        $entries += [ordered]@{
            relative_path = $relativePath
            full_path = $fullPath
            existed = [bool]$exists
            snapshot_path = $snapshotPath
            byte_length = [int64]$length
            sha256 = $sha256
            last_write_time_utc = $lastWriteUtc
            attributes = $attributes
        }
    }

    $manifest = [ordered]@{
        schema = "protected_surface_transaction_manifest_v1"
        transaction_id = $TransactionId
        status = "BEGUN"
        repo_root = $repoFull
        runtime_root = $runtimeFull
        transaction_root = $transactionRoot
        snapshot_root = $snapshotRoot
        begun_utc = Get-ProtectedSurfaceUtcNow
        protected_files = @($entries)
        protected_surface_snapshot_count = @($entries).Count
        runtime_ready = $false
    }

    $manifestPath = Join-Path $transactionRoot "transaction_manifest.json"
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    return [ordered]@{
        schema = "protected_surface_transaction_result_v1"
        action = "Begin"
        status = "PASS"
        transaction_id = $TransactionId
        manifest_path = $manifestPath
        transaction_root = $transactionRoot
        protected_file_count = @($entries).Count
        protected_surface_clean_after = $true
        protected_surface_snapshot_count = @($entries).Count
        protected_surface_restored_count = 0
        protected_surface_deleted_count = 0
        protected_surface_guard_failures = @()
        runtime_ready = $false
    }
}

function Invoke-ProtectedSurfaceTransactionCommit {
    param(
        [Parameter(Mandatory=$true)][string]$ManifestPath,
        [string[]]$ExpectedChangedPath = @(),
        [switch]$RequireAnyProtectedChange,
        [string]$SuccessConditionPath = "",
        [string]$SuccessConditionProperty = "status",
        [string]$SuccessConditionValue = "PASS"
    )

    $manifest = Read-ProtectedSurfaceManifest -Path $ManifestPath
    $failures = @()
    $changedPaths = @()
    $snapshotCount = @($manifest.protected_files).Count

    foreach ($entry in @($manifest.protected_files)) {
        if (Test-ProtectedSurfaceEntryChanged -Manifest $manifest -Entry $entry) {
            $changedPaths += [string]$entry.relative_path
        }
    }

    $hasSuccessCondition = -not [string]::IsNullOrWhiteSpace($SuccessConditionPath)
    if ($hasSuccessCondition) {
        if (-not (Test-Path -LiteralPath $SuccessConditionPath -PathType Leaf)) {
            $failures += "SUCCESS_CONDITION_PATH_MISSING=$SuccessConditionPath"
        } else {
            $condition = Get-Content -LiteralPath $SuccessConditionPath -Raw | ConvertFrom-Json
            $property = $condition.PSObject.Properties[$SuccessConditionProperty]
            if ($null -eq $property) {
                $failures += "SUCCESS_CONDITION_PROPERTY_MISSING=$SuccessConditionProperty"
            } elseif ([string]$property.Value -ne $SuccessConditionValue) {
                $failures += "SUCCESS_CONDITION_VALUE_MISMATCH=$SuccessConditionProperty"
            }
        }
    }

    if ($ExpectedChangedPath.Count -gt 0) {
        foreach ($path in $ExpectedChangedPath) {
            $entry = Get-ProtectedSurfaceSnapshotEntry -Manifest $manifest -Path $path
            if ($null -eq $entry) {
                $failures += "EXPECTED_CHANGED_PATH_NOT_PROTECTED=$path"
            } elseif (-not (Test-ProtectedSurfaceEntryChanged -Manifest $manifest -Entry $entry)) {
                $failures += "EXPECTED_CHANGED_PATH_NOT_CHANGED=$([string]$entry.relative_path)"
            }
        }
    } elseif (-not $hasSuccessCondition -or $RequireAnyProtectedChange) {
        if ($changedPaths.Count -lt 1) {
            $failures += "NO_PROTECTED_SURFACE_CHANGE_DETECTED"
        }
    }

    if ($failures.Count -gt 0) {
        return [ordered]@{
            schema = "protected_surface_transaction_result_v1"
            action = "Commit"
            status = "FAIL"
            transaction_id = [string]$manifest.transaction_id
            manifest_path = $ManifestPath
            failed_checks = @($failures)
            changed_paths = @($changedPaths)
            protected_surface_clean_after = $false
            protected_surface_snapshot_count = $snapshotCount
            protected_surface_restored_count = 0
            protected_surface_deleted_count = 0
            protected_surface_guard_failures = @($failures)
            runtime_ready = $false
        }
    }

    $receiptPath = Join-Path ([string]$manifest.transaction_root) "transaction_receipt.json"
    $receipt = [ordered]@{
        schema = "protected_surface_transaction_receipt_v1"
        status = "PASS"
        action = "Commit"
        transaction_id = [string]$manifest.transaction_id
        committed_utc = Get-ProtectedSurfaceUtcNow
        manifest_path = $ManifestPath
        changed_paths = @($changedPaths)
        expected_changed_paths = @($ExpectedChangedPath)
        success_condition_path = $SuccessConditionPath
        protected_surface_clean_after = $true
        protected_surface_snapshot_count = $snapshotCount
        protected_surface_restored_count = 0
        protected_surface_deleted_count = 0
        protected_surface_guard_failures = @()
        runtime_ready = $false
    }
    $receipt | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $receiptPath -Encoding UTF8

    return [ordered]@{
        schema = "protected_surface_transaction_result_v1"
        action = "Commit"
        status = "PASS"
        transaction_id = [string]$manifest.transaction_id
        manifest_path = $ManifestPath
        receipt_path = $receiptPath
        changed_paths = @($changedPaths)
        protected_surface_clean_after = $true
        protected_surface_snapshot_count = $snapshotCount
        protected_surface_restored_count = 0
        protected_surface_deleted_count = 0
        protected_surface_guard_failures = @()
        runtime_ready = $false
    }
}

function Invoke-ProtectedSurfaceTransactionRollback {
    param(
        [Parameter(Mandatory=$true)][string]$ManifestPath,
        [string]$Reason = "ROLLBACK_REQUESTED"
    )

    $manifest = Read-ProtectedSurfaceManifest -Path $ManifestPath
    $failedPaths = @()
    $restoredPaths = @()
    $deletedPaths = @()
    $snapshotCount = @($manifest.protected_files).Count

    foreach ($entry in @($manifest.protected_files)) {
        $path = [string]$entry.full_path
        try {
            if ([bool]$entry.existed) {
                $snapshotPath = [string]$entry.snapshot_path
                if ([string]::IsNullOrWhiteSpace($snapshotPath) -or -not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
                    throw "SNAPSHOT_BYTES_MISSING=$snapshotPath"
                }

                $parent = Split-Path -Parent $path
                if ($parent) {
                    New-Item -ItemType Directory -Force -Path $parent | Out-Null
                }
                if (Test-Path -LiteralPath $path -PathType Leaf) {
                    [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
                }

                $bytes = [System.IO.File]::ReadAllBytes($snapshotPath)
                [System.IO.File]::WriteAllBytes($path, $bytes)
                [System.IO.File]::SetLastWriteTimeUtc($path, [datetime]::Parse([string]$entry.last_write_time_utc).ToUniversalTime())
                [System.IO.File]::SetAttributes($path, [System.Enum]::Parse([System.IO.FileAttributes], [string]$entry.attributes))
                $restoredPaths += [string]$entry.relative_path
            } else {
                if (Test-Path -LiteralPath $path -PathType Leaf) {
                    [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
                    Remove-Item -LiteralPath $path -Force -ErrorAction Stop
                    $deletedPaths += [string]$entry.relative_path
                }
            }
        } catch {
            $failedPaths += [ordered]@{
                path = [string]$entry.relative_path
                full_path = $path
                error = $_.Exception.Message
            }
        }
    }

    $cleanCheck = Compare-ProtectedSurfaceToSnapshot -Manifest $manifest
    $status = if ($failedPaths.Count -eq 0 -and [bool]$cleanCheck.protected_surface_clean_after) { "PASS" } else { "FAIL" }
    $guardFailures = @($failedPaths | ForEach-Object { [string]$_.path })

    $receiptPath = Join-Path ([string]$manifest.transaction_root) "transaction_rollback_receipt.json"
    $receipt = [ordered]@{
        schema = "protected_surface_transaction_rollback_receipt_v1"
        status = $status
        action = "Rollback"
        transaction_id = [string]$manifest.transaction_id
        rollback_utc = Get-ProtectedSurfaceUtcNow
        reason = $Reason
        restored_paths = @($restoredPaths)
        deleted_paths = @($deletedPaths)
        failed_paths = @($failedPaths)
        protected_surface_clean_after = [bool]$cleanCheck.protected_surface_clean_after
        protected_surface_snapshot_count = $snapshotCount
        protected_surface_restored_count = @($restoredPaths).Count
        protected_surface_deleted_count = @($deletedPaths).Count
        protected_surface_guard_failures = @($guardFailures)
        mismatched_paths = @($cleanCheck.mismatched_paths)
        runtime_ready = $false
    }
    $receipt | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $receiptPath -Encoding UTF8

    return [ordered]@{
        schema = "protected_surface_transaction_result_v1"
        action = "Rollback"
        status = $status
        transaction_id = [string]$manifest.transaction_id
        manifest_path = $ManifestPath
        receipt_path = $receiptPath
        restored_paths = @($restoredPaths)
        deleted_paths = @($deletedPaths)
        failed_paths = @($failedPaths)
        protected_surface_clean_after = [bool]$cleanCheck.protected_surface_clean_after
        protected_surface_snapshot_count = $snapshotCount
        protected_surface_restored_count = @($restoredPaths).Count
        protected_surface_deleted_count = @($deletedPaths).Count
        protected_surface_guard_failures = @($guardFailures)
        runtime_ready = $false
    }
}

function Invoke-ProtectedSurfaceTransactionFail {
    param(
        [Parameter(Mandatory=$true)][string]$ManifestPath,
        [string]$FailureReason = "CALLER_REPORTED_FAILURE"
    )

    $rollback = Invoke-ProtectedSurfaceTransactionRollback -ManifestPath $ManifestPath -Reason $FailureReason
    $rollback["action"] = "Fail"
    return $rollback
}

if (-not [string]::IsNullOrWhiteSpace($Action)) {
    switch ($Action) {
        "Begin" {
            if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) { throw "RUNTIME_ROOT_REQUIRED_FOR_BEGIN" }
            $result = Invoke-ProtectedSurfaceTransactionBegin -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot -TransactionId $TransactionId -ProtectedPath $ProtectedPath
        }
        "Commit" {
            if ([string]::IsNullOrWhiteSpace($ManifestPath)) { throw "MANIFEST_PATH_REQUIRED_FOR_COMMIT" }
            $result = Invoke-ProtectedSurfaceTransactionCommit -ManifestPath $ManifestPath -ExpectedChangedPath $ExpectedChangedPath -RequireAnyProtectedChange:$RequireAnyProtectedChange -SuccessConditionPath $SuccessConditionPath -SuccessConditionProperty $SuccessConditionProperty -SuccessConditionValue $SuccessConditionValue
        }
        "Rollback" {
            if ([string]::IsNullOrWhiteSpace($ManifestPath)) { throw "MANIFEST_PATH_REQUIRED_FOR_ROLLBACK" }
            $result = Invoke-ProtectedSurfaceTransactionRollback -ManifestPath $ManifestPath -Reason "ROLLBACK_REQUESTED"
        }
        "Fail" {
            if ([string]::IsNullOrWhiteSpace($ManifestPath)) { throw "MANIFEST_PATH_REQUIRED_FOR_FAIL" }
            $result = Invoke-ProtectedSurfaceTransactionFail -ManifestPath $ManifestPath -FailureReason $FailureReason
        }
    }

    $result | ConvertTo-Json -Depth 20
}
