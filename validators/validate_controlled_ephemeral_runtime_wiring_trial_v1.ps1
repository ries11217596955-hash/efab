$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/CONTROLLED_EPHEMERAL_RUNTIME_WIRING_TRIAL_V1.json"
$Entrypoint = "modules/run_ephemeral_candidate_controlled_runtime_v1.ps1"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath $Entrypoint)) { Fail "CONTROLLED_RUNTIME_ENTRYPOINT_MISSING" }
if (-not (Test-Path -LiteralPath "tests/accepted_atom_retention/run_controlled_ephemeral_runtime_wiring_trial_v1.ps1")) {
  Fail "CONTROLLED_RUNTIME_TRIAL_RUNNER_MISSING"
}
if (-not (Test-Path -LiteralPath $ProofPath)) { Fail "PROOF_MISSING" }

$entrypointSource = Get-Content -LiteralPath $Entrypoint -Raw
if ($entrypointSource -notmatch "MaxCycles") { Fail "ENTRYPOINT_MAXCYCLES_MISSING" }
if ($entrypointSource -notmatch "StopFile") { Fail "ENTRYPOINT_STOPFILE_MISSING" }
if ($entrypointSource -notmatch "HeartbeatPath") { Fail "ENTRYPOINT_HEARTBEAT_MISSING" }
if ($entrypointSource -notmatch "SummaryPath") { Fail "ENTRYPOINT_SUMMARY_MISSING" }
if ($entrypointSource -notmatch "CompactAccepted") { Fail "ENTRYPOINT_COMPACT_ACCEPTED_MISSING" }

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
if ([string]$p.status -ne "PASS") { Fail "PROOF_STATUS_NOT_PASS" }
if (-not [string]::IsNullOrWhiteSpace([string]$p.trial_error)) { Fail "PROOF_TRIAL_ERROR_PRESENT" }
if ([bool]$p.runtime_ready -ne $false) { Fail "PROOF_RUNTIME_READY_TRUE" }
if ([int]$p.unexpected_git_status_count -ne 0) { Fail "UNEXPECTED_GIT_STATUS" }

$normal = $p.normal_case
if ([string]$normal.status -ne "PASS") { Fail "NORMAL_STATUS_NOT_PASS" }
if ([int]$normal.max_cycles -ne 10) { Fail "NORMAL_MAXCYCLES_NOT_10" }
if ([int]$normal.batch_size -ne 100) { Fail "NORMAL_BATCHSIZE_NOT_100" }
if ([int]$normal.total_accepted -lt 1000) { Fail "NORMAL_TOTAL_ACCEPTED_LT_1000" }
if ([int]$normal.total_receipts -ne [int]$normal.total_accepted) { Fail "NORMAL_RECEIPTS_MISMATCH" }
if ([int]$normal.failed_cycles -ne 0) { Fail "NORMAL_FAILED_CYCLES_NOT_ZERO" }
if ([bool]$normal.retention_pass_all -ne $true) { Fail "NORMAL_RETENTION_NOT_ALL_PASS" }
if ([bool]$normal.material_pruned_all -ne $true) { Fail "NORMAL_CANDIDATE_MATERIAL_LEFT" }
if ([bool]$normal.work_pruned_all -ne $true) { Fail "NORMAL_WORK_CURRENT_LEFT" }
if ([bool]$normal.heartbeat_written -ne $true) { Fail "NORMAL_HEARTBEAT_MISSING" }
if ([bool]$normal.summary_written -ne $true) { Fail "NORMAL_SUMMARY_MISSING" }
if ([bool]$normal.cycle_invariants_pass -ne $true) { Fail "NORMAL_CYCLE_INVARIANTS_FAILED" }
if ([bool]$normal.runtime_ready -ne $false) { Fail "NORMAL_RUNTIME_READY_TRUE" }

$stop = $p.stop_file_case
if ([bool]$stop.stopped_safely -ne $true) { Fail "STOP_CASE_NOT_SAFE" }
if ([string]$stop.status -notin @("STOPPED_BY_SIGNAL","STOPPED_BY_STOP_FILE")) { Fail "STOP_STATUS_UNEXPECTED" }
if ([bool]$stop.false_success_claim -ne $false) { Fail "STOP_FALSE_SUCCESS_CLAIM" }
if ([int]$stop.completed_cycles -ne 0) { Fail "STOP_COMPLETED_CYCLES_NOT_ZERO" }
if ([int]$stop.total_accepted -ne 0) { Fail "STOP_ACCEPTED_NOT_ZERO" }
if ([int]$stop.total_receipts -ne 0) { Fail "STOP_RECEIPTS_NOT_ZERO" }
if ([bool]$stop.summary_written -ne $true) { Fail "STOP_SUMMARY_MISSING" }
if ([bool]$stop.runtime_ready -ne $false) { Fail "STOP_RUNTIME_READY_TRUE" }

Write-Host "VALIDATION_PASS=CONTROLLED_EPHEMERAL_RUNTIME_WIRING_TRIAL_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "RUNTIME_READY=false"
exit 0
