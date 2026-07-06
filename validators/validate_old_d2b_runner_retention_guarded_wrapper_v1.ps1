$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/OLD_D2B_RUNNER_RETENTION_GUARDED_WRAPPER_DRY_TRIAL_V1.json"

if (-not (Test-Path "modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_retention_guarded_001.ps1")) {
  Write-Host "FAIL=GUARDED_RUNNER_MISSING"
  exit 1
}

if (-not (Test-Path $ProofPath)) {
  Write-Host "FAIL=PROOF_MISSING"
  exit 1
}

$p = Get-Content $ProofPath -Raw | ConvertFrom-Json

if ($p.status -ne "PASS") { Write-Host "FAIL=PROOF_STATUS"; exit 1 }
if ($p.blocked_full_trace.status -ne "BLOCKED_RETENTION_MODE_REQUIRED") { Write-Host "FAIL=FULL_TRACE_NOT_BLOCKED"; exit 1 }
if ([bool]$p.blocked_full_trace.legacy_runner_invoked -ne $false) { Write-Host "FAIL=LEGACY_INVOKED_ON_BLOCKED_MODE"; exit 1 }

if ($p.success_case.status -ne "PASS") { Write-Host "FAIL=SUCCESS_STATUS"; exit 1 }
if ([int]$p.success_case.accepted_count -ne 11) { Write-Host "FAIL=SUCCESS_ACCEPTED_COUNT"; exit 1 }
if ([int]$p.success_case.receipt_count -ne 11) { Write-Host "FAIL=SUCCESS_RECEIPT_COUNT"; exit 1 }
if ([bool]$p.success_case.heavy_trace_pruned -ne $true) { Write-Host "FAIL=SUCCESS_NOT_PRUNED"; exit 1 }
if ([bool]$p.success_case.work_exists_after -ne $false) { Write-Host "FAIL=SUCCESS_WORK_STILL_EXISTS"; exit 1 }
if ([bool]$p.success_case.legacy_runner_invoked -ne $false) { Write-Host "FAIL=LEGACY_INVOKED_IN_DRY_TRIAL"; exit 1 }

if ($p.failure_case.status -ne "QUARANTINE_TRACE_REQUIRED") { Write-Host "FAIL=FAILURE_STATUS"; exit 1 }
if ([bool]$p.failure_case.heavy_trace_pruned -ne $false) { Write-Host "FAIL=FAILURE_PRUNED"; exit 1 }
if ([bool]$p.failure_case.work_exists_after -ne $true) { Write-Host "FAIL=FAILURE_WORK_NOT_PRESERVED"; exit 1 }
if ([bool]$p.failure_case.legacy_runner_invoked -ne $false) { Write-Host "FAIL=LEGACY_INVOKED_IN_FAILURE_DRY_TRIAL"; exit 1 }

if ($p.live_without_owner_approval.status -ne "BLOCKED_OWNER_APPROVAL_REQUIRED_FOR_LIVE_ONE_BATCH") { Write-Host "FAIL=LIVE_NOT_BLOCKED"; exit 1 }
if ([bool]$p.live_without_owner_approval.legacy_runner_invoked -ne $false) { Write-Host "FAIL=LEGACY_INVOKED_WITHOUT_OWNER_APPROVAL"; exit 1 }

if ([int64]$p.repo_growth_bytes -gt 300000) { Write-Host "FAIL=REPO_GROWTH_TOO_HIGH"; exit 1 }

Write-Host "VALIDATION_PASS=OLD_D2B_RUNNER_RETENTION_GUARDED_WRAPPER_DRY_TRIAL_V1"
Write-Host "RUNTIME_READY=false"
exit 0
