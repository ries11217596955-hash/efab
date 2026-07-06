$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/EPHEMERAL_CANDIDATE_TO_ATOM_BATCH_100_TRIAL_V1.json"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath "modules/generate_ephemeral_d2b_candidate_batch_v1.ps1")) {
  Fail "GENERATOR_MISSING"
}
if (-not (Test-Path -LiteralPath "modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1")) {
  Fail "LEGACY_RUNNER_MISSING"
}
if (-not (Test-Path -LiteralPath $ProofPath)) {
  Fail "PROOF_MISSING"
}

$runnerSource = Get-Content -LiteralPath "modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1" -Raw
if ($runnerSource -notmatch "CandidateBatchPath") {
  Fail "RUNNER_CANDIDATE_BATCH_PATH_MISSING"
}
if ($runnerSource -notmatch "Remove-D2BCandidateBatchMaterialOnSuccess") {
  Fail "RUNNER_CANDIDATE_PRUNE_HOOK_MISSING"
}
if ($runnerSource -notmatch "Invoke-D2BPostBatchRetentionHook") {
  Fail "RUNNER_RETENTION_HOOK_MISSING"
}

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json

if ([string]$p.status -ne "PASS") { Fail "PROOF_STATUS_NOT_PASS" }
if (-not [string]::IsNullOrWhiteSpace([string]$p.trial_error)) { Fail "PROOF_CREATED_AFTER_FAILED_RUN" }
if ([int]$p.runner_exit_code -ne 0) { Fail "RUNNER_EXIT_CODE_NOT_ZERO" }
if ([string]$p.runner_final_status -ne "PASS_QUEUE_EMPTY") { Fail "RUNNER_FINAL_STATUS_NOT_PASS_QUEUE_EMPTY" }
if ([bool]$p.direct_candidate_batch_mode -ne $true) { Fail "DIRECT_CANDIDATE_BATCH_MODE_FALSE" }
if ([int]$p.accepted_count -lt 100) { Fail "ACCEPTED_COUNT_LT_100" }
if ([int]$p.receipt_count -ne [int]$p.accepted_count) { Fail "RECEIPT_COUNT_MISMATCH" }
if ([string]$p.retention_status -ne "PASS") { Fail "RETENTION_NOT_PASS" }
if ([bool]$p.retention_gate_invoked -ne $true) { Fail "RETENTION_GATE_NOT_INVOKED" }
if ([bool]$p.heavy_trace_pruned -ne $true) { Fail "HEAVY_TRACE_NOT_PRUNED" }
if ([bool]$p.candidate_material_pruned -ne $true) { Fail "CANDIDATE_MATERIAL_STILL_EXISTS" }
if ([bool]$p.runner_candidate_material_pruned -ne $true) { Fail "RUNNER_DID_NOT_REPORT_CANDIDATE_PRUNED" }
if ([bool]$p.work_current_exists_after_success -ne $false) { Fail "WORK_CURRENT_STILL_EXISTS" }
if ([bool]$p.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([int]$p.unexpected_git_status_count -ne 0) { Fail "UNEXPECTED_GIT_STATUS_AFTER_RESTORE" }
if ([bool]$p.active_state_restored -ne $true) { Fail "ACTIVE_STATE_NOT_RESTORED" }

Write-Host "VALIDATION_PASS=EPHEMERAL_CANDIDATE_TO_ATOM_BATCH_100_TRIAL_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "RUNTIME_READY=false"
exit 0
