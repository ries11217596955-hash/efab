$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/LEGACY_D2B_STATE_WRITE_ATOMICITY_REPAIR_TRIAL_V1.json"
$RunnerPath = "modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath $ProofPath)) { Fail "PROOF_MISSING" }
if (-not (Test-Path -LiteralPath $RunnerPath)) { Fail "LEGACY_RUNNER_MISSING" }

$source = Get-Content -LiteralPath $RunnerPath -Raw
if ($source -notmatch "\[guid\]::NewGuid") { Fail "UNIQUE_TEMP_GUID_MISSING" }
if ($source -notmatch "D2B_JSON_STATE_WRITE_FAILED") { Fail "STRUCTURED_WRITE_FAILURE_MISSING" }
if ($source -notmatch "UnauthorizedAccessException") { Fail "UNAUTHORIZED_RETRY_MISSING" }
if ($source -notmatch "System\.IO\.IOException") { Fail "IO_RETRY_MISSING" }

try {
  $p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
} catch {
  Fail "PROOF_JSON_PARSE_FAILED"
}

if ([string]$p.status -ne "PASS") { Fail "PROOF_STATUS_NOT_PASS" }
if (-not [string]::IsNullOrWhiteSpace([string]$p.trial_error)) { Fail "PROOF_TRIAL_ERROR_PRESENT" }
if ([int]$p.completed_cycles -ne 1) { Fail "COMPLETED_CYCLES_NOT_1" }
if ([int]$p.total_accepted -ne 100) { Fail "TOTAL_ACCEPTED_NOT_100" }
if ([int]$p.total_receipts -ne 100) { Fail "TOTAL_RECEIPTS_NOT_100" }
if ([bool]$p.stderr_contains_unauthorized_access_exception -ne $false) { Fail "STDERR_UNAUTHORIZED_ACCESS_EXCEPTION" }
if ([string]$p.stderr_tail -match "UnauthorizedAccessException") { Fail "STDERR_TAIL_UNAUTHORIZED_ACCESS_EXCEPTION" }
if ([bool]$p.queue_state_write_repaired -ne $true) { Fail "QUEUE_STATE_WRITE_REPAIRED_FALSE" }
if ([bool]$p.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([bool]$p.material_pruned -ne $true) { Fail "MATERIAL_NOT_PRUNED" }
if ([bool]$p.work_current_pruned -ne $true) { Fail "WORK_CURRENT_NOT_PRUNED" }
if ([bool]$p.summary_written -ne $true) { Fail "SUMMARY_NOT_WRITTEN" }
if ([int]$p.unexpected_git_status_count -ne 0) { Fail "UNEXPECTED_GIT_STATUS" }

Write-Host "VALIDATION_PASS=LEGACY_D2B_STATE_WRITE_ATOMICITY_REPAIR_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "RUNTIME_READY=false"
exit 0
