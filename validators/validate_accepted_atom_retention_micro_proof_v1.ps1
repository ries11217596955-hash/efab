$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/ACCEPTED_ATOM_RETENTION_MICRO_PROOF_V1.json"

if (-not (Test-Path "modules/invoke_accepted_atom_retention_compactor_v1.ps1")) {
    Write-Host "FAIL=MODULE_MISSING"
    exit 1
}

if (-not (Test-Path $ProofPath)) {
    Write-Host "FAIL=PROOF_MISSING"
    exit 1
}

$p = Get-Content $ProofPath -Raw | ConvertFrom-Json

if ($p.status -ne "PASS") { Write-Host "FAIL=PROOF_STATUS"; exit 1 }
if ([int]$p.accepted_count -ne 10) { Write-Host "FAIL=ACCEPTED_COUNT"; exit 1 }
if ([int]$p.failed_count -ne 0) { Write-Host "FAIL=FAILED_COUNT"; exit 1 }
if ([int]$p.quarantined_count -ne 0) { Write-Host "FAIL=QUARANTINED_COUNT"; exit 1 }
if ([int]$p.receipt_count -ne 10) { Write-Host "FAIL=RECEIPT_COUNT"; exit 1 }
if ([bool]$p.heavy_trace_pruned -ne $true) { Write-Host "FAIL=HEAVY_TRACE_NOT_PRUNED"; exit 1 }
if ([bool]$p.manifest_heavy_trace_pruned -ne $true) { Write-Host "FAIL=MANIFEST_PRUNE_FALSE"; exit 1 }
if ([int64]$p.repo_growth_bytes -gt 200000) { Write-Host "FAIL=REPO_GROWTH_TOO_HIGH"; exit 1 }

Write-Host "VALIDATION_PASS=ACCEPTED_ATOM_RETENTION_MICRO_PROOF_V1"
Write-Host "RUNTIME_READY=false"
exit 0
