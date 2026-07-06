$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ModulePath = "modules/invoke_protected_surface_transaction_v1.ps1"
$TrialPath = "tests/protected_surface_transaction/run_protected_surface_transaction_micro_trial_v1.ps1"
$ProofPath = "tests/protected_surface_transaction/PROTECTED_SURFACE_TRANSACTION_MICRO_TRIAL_V1.json"

if (-not (Test-Path -LiteralPath $ModulePath)) {
    Write-Host "FAIL=MODULE_MISSING"
    exit 1
}

if (-not (Test-Path -LiteralPath $TrialPath)) {
    Write-Host "FAIL=MICRO_TRIAL_MISSING"
    exit 1
}

& $TrialPath

if (-not (Test-Path -LiteralPath $ProofPath)) {
    Write-Host "FAIL=PROOF_MISSING"
    exit 1
}

$proof = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json

if ($proof.status -ne "PASS") { Write-Host "FAIL=PROOF_STATUS"; exit 1 }
if ([bool]$proof.runtime_ready -ne $false) { Write-Host "FAIL=RUNTIME_READY_NOT_FALSE"; exit 1 }
if ([bool]$proof.protected_surface_clean_after -ne $true) { Write-Host "FAIL=SURFACE_NOT_CLEAN_AFTER"; exit 1 }
if ([int]$proof.protected_surface_snapshot_count -lt 3) { Write-Host "FAIL=SNAPSHOT_COUNT"; exit 1 }
if (@($proof.protected_surface_guard_failures).Count -ne 0) { Write-Host "FAIL=GUARD_FAILURES"; exit 1 }
if ([bool]$proof.existing_file_restored_exactly -ne $true) { Write-Host "FAIL=EXISTING_FILE_NOT_RESTORED_EXACTLY"; exit 1 }
if ([bool]$proof.newly_created_file_deleted_on_rollback -ne $true) { Write-Host "FAIL=CREATED_FILE_NOT_DELETED"; exit 1 }
if ([string]$proof.rollback_status -ne "PASS") { Write-Host "FAIL=ROLLBACK_STATUS"; exit 1 }
if ([int]$proof.protected_surface_restored_count -lt 1) { Write-Host "FAIL=RESTORED_COUNT"; exit 1 }
if ([int]$proof.protected_surface_deleted_count -lt 1) { Write-Host "FAIL=DELETED_COUNT"; exit 1 }
if ([bool]$proof.commit_receipt_written -ne $true) { Write-Host "FAIL=COMMIT_RECEIPT_MISSING"; exit 1 }
if ([string]$proof.failed_restore_status -ne "FAIL") { Write-Host "FAIL=FAILED_RESTORE_STATUS"; exit 1 }
if ([bool]$proof.failed_restore_path_surfaced -ne $true) { Write-Host "FAIL=FAILED_PATH_NOT_SURFACED"; exit 1 }

Write-Host "VALIDATION_PASS=PROTECTED_SURFACE_TRANSACTION_V1"
Write-Host "RUNTIME_READY=false"
exit 0
