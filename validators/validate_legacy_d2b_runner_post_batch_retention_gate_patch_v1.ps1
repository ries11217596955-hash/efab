$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/LEGACY_D2B_RUNNER_POST_BATCH_RETENTION_GATE_PATCH_DRY_TRIAL_V1.json"
$LegacyRunnerPath = "modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath $LegacyRunnerPath)) {
  Fail "LEGACY_RUNNER_MISSING"
}

if (-not (Test-Path -LiteralPath "modules/invoke_real_runner_retention_gate_adapter_v1.ps1")) {
  Fail "RETENTION_ADAPTER_MISSING"
}

if (-not (Test-Path -LiteralPath $ProofPath)) {
  Fail "PROOF_MISSING"
}

$runnerSource = Get-Content -LiteralPath $LegacyRunnerPath -Raw
if ($runnerSource -notmatch "Invoke-D2BPostBatchRetentionHook") {
  Fail "LEGACY_RUNNER_RETENTION_HOOK_MISSING"
}
if ($runnerSource -notmatch "invoke_real_runner_retention_gate_adapter_v1\.ps1") {
  Fail "LEGACY_RUNNER_ADAPTER_CALL_PATH_MISSING"
}
if ($runnerSource -notmatch "ValidateSet\('CompactAccepted','FullTrace','Disabled'\)") {
  Fail "RETENTION_MODE_VALIDATE_SET_MISSING"
}

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json

if ([string]$p.status -ne "PASS") { Fail "PROOF_STATUS" }
if ([bool]$p.runtime_ready -ne $false) { Fail "PROOF_RUNTIME_READY_NOT_FALSE" }
if ([bool]$p.legacy_runner_invoked -ne $true) { Fail "LEGACY_RUNNER_NOT_INVOKED" }
if ([string]$p.legacy_runner_path -ne $LegacyRunnerPath) { Fail "LEGACY_RUNNER_PATH_MISMATCH" }

$success = $p.success_case
if ([bool]$success.legacy_runner_invoked -ne $true) { Fail "SUCCESS_LEGACY_RUNNER_NOT_INVOKED" }
if ([bool]$success.retention_hook_reachable -ne $true) { Fail "SUCCESS_HOOK_NOT_REACHABLE" }
if ([string]$success.runner_status -ne "PASS_QUEUE_EMPTY") { Fail "SUCCESS_RUNNER_STATUS" }
if ([string]$success.retention_status -ne "PASS") { Fail "SUCCESS_RETENTION_STATUS" }
if ([bool]$success.retention_gate_invoked -ne $true) { Fail "SUCCESS_GATE_NOT_INVOKED" }
if ([int]$success.accepted_count -le 0) { Fail "SUCCESS_ACCEPTED_COUNT_ZERO" }
if ([int]$success.receipt_count -ne [int]$success.accepted_count) { Fail "SUCCESS_RECEIPT_COUNT_MISMATCH" }
if ([bool]$success.heavy_trace_pruned -ne $true) { Fail "SUCCESS_HEAVY_TRACE_NOT_PRUNED" }
if ([bool]$success.work_exists_after -ne $false) { Fail "SUCCESS_WORK_CURRENT_STILL_EXISTS" }
if ([bool]$success.runtime_ready -ne $false) { Fail "SUCCESS_RUNTIME_READY_NOT_FALSE" }

$quarantine = $p.failure_quarantine_case
if ([bool]$quarantine.legacy_runner_invoked -ne $true) { Fail "QUARANTINE_LEGACY_RUNNER_NOT_INVOKED" }
if ([bool]$quarantine.retention_hook_reachable -ne $true) { Fail "QUARANTINE_HOOK_NOT_REACHABLE" }
if ([int]$quarantine.accepted_count -le 0) { Fail "QUARANTINE_ACCEPTED_COUNT_ZERO" }
if ([int]$quarantine.quarantine_count -le 0) { Fail "QUARANTINE_COUNT_ZERO" }
if ([string]$quarantine.retention_status -ne "QUARANTINE_TRACE_REQUIRED") { Fail "QUARANTINE_RETENTION_STATUS" }
if ([bool]$quarantine.retention_gate_invoked -ne $true) { Fail "QUARANTINE_GATE_NOT_INVOKED" }
if ([bool]$quarantine.heavy_trace_pruned -ne $false) { Fail "QUARANTINE_TRACE_PRUNED" }
if ([bool]$quarantine.work_current_preserved -ne $true) { Fail "QUARANTINE_WORK_NOT_PRESERVED" }
if ([bool]$quarantine.work_exists_after -ne $true) { Fail "QUARANTINE_WORK_MISSING_AFTER" }
if ([bool]$quarantine.runtime_ready -ne $false) { Fail "QUARANTINE_RUNTIME_READY_NOT_FALSE" }

$noAccepted = $p.no_accepted_atoms_case
if ([bool]$noAccepted.legacy_runner_invoked -ne $true) { Fail "NO_ACCEPTED_LEGACY_RUNNER_NOT_INVOKED" }
if ([bool]$noAccepted.retention_hook_reachable -ne $true) { Fail "NO_ACCEPTED_HOOK_NOT_REACHABLE" }
if ([int]$noAccepted.accepted_count -ne 0) { Fail "NO_ACCEPTED_COUNT_NOT_ZERO" }
if ([string]$noAccepted.retention_status -ne "NO_ACCEPTED_ATOMS") { Fail "NO_ACCEPTED_STATUS" }
if ([bool]$noAccepted.retention_gate_invoked -ne $false) { Fail "NO_ACCEPTED_GATE_INVOKED" }
if ([bool]$noAccepted.runtime_ready -ne $false) { Fail "NO_ACCEPTED_RUNTIME_READY_NOT_FALSE" }

$fullTrace = $p.full_trace_mode_case
if ([string]$fullTrace.retention_mode -ne "FullTrace") { Fail "FULL_TRACE_MODE_NOT_RECORDED" }
if ([string]$fullTrace.retention_status -ne "FULL_TRACE_UNSAFE_RETAINED") { Fail "FULL_TRACE_NOT_MARKED_UNSAFE" }
if ([bool]$fullTrace.retention_gate_invoked -ne $false) { Fail "FULL_TRACE_GATE_INVOKED" }
if ([bool]$fullTrace.heavy_trace_pruned -ne $false) { Fail "FULL_TRACE_PRUNED" }
if ([bool]$fullTrace.work_exists_after -ne $true) { Fail "FULL_TRACE_WORK_NOT_RETAINED" }
if ([bool]$fullTrace.runtime_ready -ne $false) { Fail "FULL_TRACE_RUNTIME_READY_NOT_FALSE" }

$disabled = $p.disabled_mode_case
if ([string]$disabled.retention_mode -ne "Disabled") { Fail "DISABLED_MODE_NOT_RECORDED" }
if ([string]$disabled.retention_status -ne "RETENTION_DISABLED_UNSAFE_FULL_TRACE_RETAINED") { Fail "DISABLED_NOT_MARKED_UNSAFE" }
if ([bool]$disabled.retention_gate_invoked -ne $false) { Fail "DISABLED_GATE_INVOKED" }
if ([bool]$disabled.heavy_trace_pruned -ne $false) { Fail "DISABLED_PRUNED" }
if ([bool]$disabled.work_exists_after -ne $true) { Fail "DISABLED_WORK_NOT_RETAINED" }
if ([bool]$disabled.runtime_ready -ne $false) { Fail "DISABLED_RUNTIME_READY_NOT_FALSE" }

if ([int64]$p.repo_growth_bytes -gt 500000) {
  Fail "REPO_GROWTH_TOO_HIGH"
}

Write-Host "VALIDATION_PASS=LEGACY_D2B_RUNNER_POST_BATCH_RETENTION_GATE_PATCH_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "RUNTIME_READY=false"
exit 0
