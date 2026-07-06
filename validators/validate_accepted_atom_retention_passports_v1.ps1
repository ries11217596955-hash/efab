$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$PassportDir = "contracts/accepted_atom_retention_organ/passports"
$Required = @(
    "ORGAN_PASSPORT.json",
    "CAPABILITY_PASSPORT.json",
    "SANITIZER_PASSPORT.json",
    "LIFECYCLE_PASSPORT.json",
    "PROOF_PASSPORT.json",
    "INTEGRATION_PASSPORT.json",
    "PASSPORT_INDEX.json"
)

foreach ($f in $Required) {
    $p = Join-Path $PassportDir $f
    if (-not (Test-Path $p)) {
        Write-Host "FAIL=MISSING_$f"
        exit 1
    }
    Get-Content $p -Raw | ConvertFrom-Json | Out-Null
}

$organ = Get-Content "$PassportDir/ORGAN_PASSPORT.json" -Raw | ConvertFrom-Json
$cap = Get-Content "$PassportDir/CAPABILITY_PASSPORT.json" -Raw | ConvertFrom-Json
$san = Get-Content "$PassportDir/SANITIZER_PASSPORT.json" -Raw | ConvertFrom-Json
$proof = Get-Content "$PassportDir/PROOF_PASSPORT.json" -Raw | ConvertFrom-Json
$int = Get-Content "$PassportDir/INTEGRATION_PASSPORT.json" -Raw | ConvertFrom-Json

if ($organ.status -ne "CANDIDATE_WITH_MICRO_PROOF_NOT_PROMOTED") { Write-Host "FAIL=ORGAN_STATUS_OVERCLAIM"; exit 1 }
if ([bool]$organ.runtime_ready -ne $false) { Write-Host "FAIL=ORGAN_RUNTIME_READY_OVERCLAIM"; exit 1 }
if ([bool]$int.integrated_with_real_acceptance_runner -ne $false) { Write-Host "FAIL=INTEGRATION_OVERCLAIM"; exit 1 }
if ([int]$proof.proof_summary.accepted_count -ne 10) { Write-Host "FAIL=PROOF_ACCEPTED_COUNT"; exit 1 }
if ([bool]$proof.proof_summary.heavy_trace_pruned -ne $true) { Write-Host "FAIL=PROOF_PRUNE_FALSE"; exit 1 }

$hasNotImplemented = $false
foreach ($c in $cap.capabilities) {
    if ($c.status -match "NOT_IMPLEMENTED|CONTRACT_ONLY") { $hasNotImplemented = $true }
}
if (-not $hasNotImplemented) { Write-Host "FAIL=CAPABILITY_PASSPORT_OVERCLAIMS_COMPLETE"; exit 1 }

if ([bool]$san.live_runtime_deletion_enabled -ne $false) { Write-Host "FAIL=SANITIZER_LIVE_DELETE_ENABLED_TOO_EARLY"; exit 1 }


# REAL_SHAPE_PROOF_REQUIRED_CHECK
$proof2 = Get-Content "$PassportDir/PROOF_PASSPORT.json" -Raw | ConvertFrom-Json
if ($proof2.status -match "REAL_SHAPE") {
    if (-not ($proof2.PSObject.Properties.Name -contains "real_shape_micro_trial")) {
        Write-Host "FAIL=REAL_SHAPE_PROOF_MISSING_FROM_PROOF_PASSPORT"
        exit 1
    }
    if ([int]$proof2.real_shape_micro_trial.success_accepted_count -ne 5) {
        Write-Host "FAIL=REAL_SHAPE_SUCCESS_ACCEPTED_COUNT"
        exit 1
    }
    if ([bool]$proof2.real_shape_micro_trial.success_pruned -ne $true) {
        Write-Host "FAIL=REAL_SHAPE_SUCCESS_NOT_PRUNED"
        exit 1
    }
    if ($proof2.real_shape_micro_trial.failure_status -ne "QUARANTINE_TRACE_REQUIRED") {
        Write-Host "FAIL=REAL_SHAPE_FAILURE_STATUS"
        exit 1
    }
    if ([bool]$proof2.real_shape_micro_trial.failure_preserved -ne $true) {
        Write-Host "FAIL=REAL_SHAPE_FAILURE_NOT_PRESERVED"
        exit 1
    }
}
Write-Host "VALIDATION_PASS=ACCEPTED_ATOM_RETENTION_PASSPORTS_V1"
Write-Host "ORGAN_STATUS=CANDIDATE_WITH_PASSPORTS_NOT_RUNTIME_READY"
exit 0
