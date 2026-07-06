$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/CONTROLLED_RUNTIME_30000_STRESS_PROOF_V1.json"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath $ProofPath)) { Fail "PROOF_MISSING" }

try {
  $proof = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
} catch {
  Fail "PROOF_JSON_PARSE_FAILED"
}

if ([string]$proof.status -ne "PASS") { Fail "STATUS_NOT_PASS" }
if ([string]$proof.design_mode -ne "RuntimeDeltaOnly") { Fail "DESIGN_MODE_NOT_RUNTIME_DELTA_ONLY" }
if ([int]$proof.completed_cycles -ne 300) { Fail "COMPLETED_CYCLES_NOT_300" }
if ([int]$proof.total_accepted -ne 30000) { Fail "TOTAL_ACCEPTED_NOT_30000" }
if ([int]$proof.total_receipts -ne 30000) { Fail "TOTAL_RECEIPTS_NOT_30000" }
if ($null -ne $proof.failed_cycle -and -not [string]::IsNullOrWhiteSpace([string]$proof.failed_cycle)) { Fail "FAILED_CYCLE_NOT_EMPTY" }
if ($null -ne $proof.failure_reason -and -not [string]::IsNullOrWhiteSpace([string]$proof.failure_reason)) { Fail "FAILURE_REASON_NOT_EMPTY" }
if ([bool]$proof.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([bool]$proof.heartbeat_exists -ne $true) { Fail "HEARTBEAT_EXISTS_FALSE" }
if ([bool]$proof.summary_exists -ne $true) { Fail "SUMMARY_EXISTS_FALSE" }
if ([bool]$proof.tracked_git_status_clean_after_run -ne $true) { Fail "TRACKED_GIT_STATUS_NOT_CLEAN" }
if ([bool]$proof.tracked_core_memory_growth_blocked -ne $true) { Fail "TRACKED_CORE_MEMORY_GROWTH_NOT_BLOCKED" }
if ([bool]$proof.stderr_tail_empty -ne $true) { Fail "STDERR_TAIL_NOT_EMPTY" }
if ([string]::IsNullOrWhiteSpace([string]$proof.next_required)) { Fail "NEXT_REQUIRED_MISSING" }

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_30000_STRESS_PROOF_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "TOTAL_ACCEPTED=$($proof.total_accepted)"
Write-Host "TOTAL_RECEIPTS=$($proof.total_receipts)"
Write-Host "DESIGN_MODE=$($proof.design_mode)"
Write-Host "RUNTIME_READY=false"
exit 0
