$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/ACCEPTED_ATOM_RETENTION_GATE_REAL_SHAPE_MICRO_TRIAL_V1.json"

if (-not (Test-Path "modules/invoke_accepted_atom_retention_gate_v1.ps1")) {
    Write-Host "FAIL=GATE_MODULE_MISSING"
    exit 1
}

if (-not (Test-Path $ProofPath)) {
    Write-Host "FAIL=PROOF_MISSING"
    exit 1
}

$p = Get-Content $ProofPath -Raw | ConvertFrom-Json

if ($p.status -ne "PASS") { Write-Host "FAIL=PROOF_STATUS"; exit 1 }
if ($p.success_case.status -ne "PASS") { Write-Host "FAIL=SUCCESS_STATUS"; exit 1 }
if ([int]$p.success_case.accepted_count -ne 5) { Write-Host "FAIL=SUCCESS_ACCEPTED_COUNT"; exit 1 }
if ([int]$p.success_case.receipt_count -ne 5) { Write-Host "FAIL=SUCCESS_RECEIPT_COUNT"; exit 1 }
if ([bool]$p.success_case.heavy_trace_pruned -ne $true) { Write-Host "FAIL=SUCCESS_NOT_PRUNED"; exit 1 }
if ([bool]$p.success_case.work_current_preserved -ne $false) { Write-Host "FAIL=SUCCESS_WORK_STILL_PRESENT"; exit 1 }

if ($p.failure_case.status -ne "QUARANTINE_TRACE_REQUIRED") { Write-Host "FAIL=FAILURE_STATUS_NOT_QUARANTINE"; exit 1 }
if ([bool]$p.failure_case.heavy_trace_pruned -ne $false) { Write-Host "FAIL=FAILURE_WAS_PRUNED"; exit 1 }
if ([bool]$p.failure_case.work_current_preserved -ne $true) { Write-Host "FAIL=FAILURE_WORK_NOT_PRESERVED"; exit 1 }

if ([int64]$p.repo_growth_bytes -gt 300000) { Write-Host "FAIL=REPO_GROWTH_TOO_HIGH"; exit 1 }

Write-Host "VALIDATION_PASS=ACCEPTED_ATOM_RETENTION_GATE_REAL_SHAPE_MICRO_TRIAL_V1"
Write-Host "RUNTIME_READY=false"
exit 0
