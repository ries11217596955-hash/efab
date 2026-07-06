$ErrorActionPreference = "Stop"

$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Repo

$ModulePath = "modules/invoke_protected_surface_transaction_v1.ps1"
$ProofPath = "tests/protected_surface_transaction/PROTECTED_SURFACE_TRANSACTION_MICRO_TRIAL_V1.json"

if (-not (Test-Path -LiteralPath $ModulePath)) {
    Write-Host "FAIL=MODULE_MISSING"
    exit 1
}

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            return "sha256:" + (($sha.ComputeHash($stream) | ForEach-Object { $_.ToString("x2") }) -join "")
        } finally {
            $stream.Dispose()
        }
    } finally {
        $sha.Dispose()
    }
}

function Invoke-TransactionJson {
    param([Parameter(Mandatory=$true)][scriptblock]$Command)
    $json = & $Command
    return $json | ConvertFrom-Json
}

$Stamp = Get-Date -Format "yyyyMMdd_HHmmss_ffff"
$Sandbox = Join-Path $env:TEMP "efab_protected_surface_transaction_$Stamp"
$FixtureRepo = Join-Path $Sandbox "fixture_repo"
$RuntimeRoot = Join-Path $Sandbox "runtime"

New-Item -ItemType Directory -Force -Path (Join-Path $FixtureRepo "packs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $FixtureRepo "reports/self_development") | Out-Null
New-Item -ItemType Directory -Force -Path $RuntimeRoot | Out-Null

$RegistryPath = Join-Path $FixtureRepo "packs/registry.json"
$MapPath = Join-Path $FixtureRepo "reports/self_development/SELF_MODEL_ACTIVE_MAP.json"
$CreatedDuringTransactionPath = Join-Path $FixtureRepo "reports/self_development/accepted_change_memory_snapshot.json"

@{ fixture = "registry"; version = 1 } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $RegistryPath -Encoding UTF8
@{ fixture = "active_map"; version = 1 } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $MapPath -Encoding UTF8

$OriginalRegistryHash = Get-FileSha256 -Path $RegistryPath
$OriginalRegistryLastWrite = [datetime]"2024-01-02T03:04:05Z"
[System.IO.File]::SetLastWriteTimeUtc($RegistryPath, $OriginalRegistryLastWrite)
[System.IO.File]::SetAttributes($RegistryPath, [System.IO.FileAttributes]::ReadOnly)
$OriginalRegistryAttributes = [System.IO.File]::GetAttributes($RegistryPath).ToString()

$beginRollback = Invoke-TransactionJson { & $ModulePath -Action Begin -RepoRoot $FixtureRepo -RuntimeRoot $RuntimeRoot -TransactionId "rollback_case" }

[System.IO.File]::SetAttributes($RegistryPath, [System.IO.FileAttributes]::Normal)
@{ fixture = "registry"; version = 2; mutated = $true } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $RegistryPath -Encoding UTF8
@{ fixture = "created_during_transaction" } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $CreatedDuringTransactionPath -Encoding UTF8

$rollback = Invoke-TransactionJson { & $ModulePath -Action Rollback -ManifestPath ([string]$beginRollback.manifest_path) }

$RestoredRegistryHash = Get-FileSha256 -Path $RegistryPath
$RestoredRegistryLastWrite = [System.IO.File]::GetLastWriteTimeUtc($RegistryPath)
$RestoredRegistryAttributes = [System.IO.File]::GetAttributes($RegistryPath).ToString()
$ExistingFileRestoredExactly = (
    $RestoredRegistryHash -eq $OriginalRegistryHash -and
    $RestoredRegistryLastWrite.ToString("o") -eq $OriginalRegistryLastWrite.ToUniversalTime().ToString("o") -and
    $RestoredRegistryAttributes -eq $OriginalRegistryAttributes
)
$CreatedFileDeleted = -not (Test-Path -LiteralPath $CreatedDuringTransactionPath)

[System.IO.File]::SetAttributes($RegistryPath, [System.IO.FileAttributes]::Normal)
$beginCommit = Invoke-TransactionJson { & $ModulePath -Action Begin -RepoRoot $FixtureRepo -RuntimeRoot $RuntimeRoot -TransactionId "commit_case" }
@{ fixture = "registry"; version = 3; committed = $true } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $RegistryPath -Encoding UTF8
$commit = Invoke-TransactionJson { & $ModulePath -Action Commit -ManifestPath ([string]$beginCommit.manifest_path) -ExpectedChangedPath "packs/registry.json" }
$ReceiptWritten = (
    [string]$commit.status -eq "PASS" -and
    -not [string]::IsNullOrWhiteSpace([string]$commit.receipt_path) -and
    (Test-Path -LiteralPath ([string]$commit.receipt_path))
)

$beginFail = Invoke-TransactionJson { & $ModulePath -Action Begin -RepoRoot $FixtureRepo -RuntimeRoot $RuntimeRoot -TransactionId "failed_restore_case" }
$manifest = Get-Content -LiteralPath ([string]$beginFail.manifest_path) -Raw | ConvertFrom-Json
$manifest.protected_files[0].snapshot_path = Join-Path $Sandbox "missing_snapshot_bytes.bin"
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath ([string]$beginFail.manifest_path) -Encoding UTF8
@{ fixture = "registry"; version = 4; should_fail_restore = $true } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $RegistryPath -Encoding UTF8
$failedRestore = Invoke-TransactionJson { & $ModulePath -Action Fail -ManifestPath ([string]$beginFail.manifest_path) -FailureReason "SYNTHETIC_CALLER_FAILURE" }
$FailedPathSurfaced = (
    [string]$failedRestore.status -eq "FAIL" -and
    [string]$failedRestore.action -eq "Fail" -and
    @($failedRestore.failed_paths).Count -ge 1 -and
    [string]$failedRestore.failed_paths[0].path -eq "packs/registry.json"
)

$allPass = (
    [string]$rollback.status -eq "PASS" -and
    [bool]$rollback.protected_surface_clean_after -eq $true -and
    [int]$rollback.protected_surface_snapshot_count -ge 3 -and
    [int]$rollback.protected_surface_restored_count -ge 1 -and
    [int]$rollback.protected_surface_deleted_count -ge 1 -and
    @($rollback.protected_surface_guard_failures).Count -eq 0 -and
    $ExistingFileRestoredExactly -and
    $CreatedFileDeleted -and
    $ReceiptWritten -and
    $FailedPathSurfaced
)

$proof = [ordered]@{
    schema = "protected_surface_transaction_micro_trial_v1"
    status = if ($allPass) { "PASS" } else { "FAIL" }
    existing_file_restored_exactly = [bool]$ExistingFileRestoredExactly
    newly_created_file_deleted_on_rollback = [bool]$CreatedFileDeleted
    rollback_status = [string]$rollback.status
    protected_surface_clean_after = [bool]$rollback.protected_surface_clean_after
    protected_surface_snapshot_count = [int]$rollback.protected_surface_snapshot_count
    protected_surface_restored_count = [int]$rollback.protected_surface_restored_count
    protected_surface_deleted_count = [int]$rollback.protected_surface_deleted_count
    protected_surface_guard_failures = @($rollback.protected_surface_guard_failures)
    commit_receipt_written = [bool]$ReceiptWritten
    failed_restore_status = [string]$failedRestore.status
    failed_restore_path_surfaced = [bool]$FailedPathSurfaced
    runtime_ready = $false
}

$proof | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ProofPath -Encoding UTF8

if ($allPass) {
    Write-Host "MICRO_TRIAL_STATUS=PASS"
    Write-Host "PROOF_PATH=$ProofPath"
    Write-Host "RUNTIME_READY=false"
    exit 0
}

Write-Host "MICRO_TRIAL_STATUS=FAIL"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "RUNTIME_READY=false"
exit 1
