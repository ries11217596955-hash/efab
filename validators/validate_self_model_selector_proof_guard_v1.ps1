$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $RepoRoot "modules/invoke_self_model_first_runtime_entrypoint.ps1")

function Write-JsonFixture {
  param([string]$Path, $Value)
  $Dir = Split-Path $Path -Parent
  if ($Dir -and -not (Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
  $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("efab_selector_guard_" + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null
  Write-JsonFixture (Join-Path $TempRoot "TASK_QUEUE.json") ([ordered]@{ active_task_id = "NONE" })
  Write-JsonFixture (Join-Path $TempRoot "self_model/BUILDER_SELF_MODEL.json") ([ordered]@{ status = "PASS"; current_detected_need = "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR" })
  Write-JsonFixture (Join-Path $TempRoot "self_control/AUTONOMOUS_LOOP_CONTROLLER.json") ([ordered]@{ status = "PASS" })

  $MissingProofResult = Invoke-SelfModelFirstRuntimeEntrypoint -RepoRoot $TempRoot -RunId "missing-proofs" -OutputRoot (Join-Path $TempRoot "out-missing")
  if ($MissingProofResult.status -ne "BLOCKED") { throw "EXPECTED_BLOCKED_WITH_MISSING_PROOFS" }
  if ($MissingProofResult.decision_id -ne "ENTRY_BLOCKED_SELECTOR_PROOFS_MISSING_V1") { throw "UNEXPECTED_MISSING_PROOF_DECISION:$($MissingProofResult.decision_id)" }

  Write-JsonFixture (Join-Path $TempRoot "proofs/self_development/PHASE131_RUN_CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL_V1.json") ([ordered]@{ status = "PASS" })
  Write-JsonFixture (Join-Path $TempRoot "proofs/self_development/PHASE132_BUILD_OPERATION_TRIAL_AWARE_SELF_MODEL_ADVANCE_V1.json") ([ordered]@{ status = "PASS" })

  $ProofPassResult = Invoke-SelfModelFirstRuntimeEntrypoint -RepoRoot $TempRoot -RunId "proofs-pass" -OutputRoot (Join-Path $TempRoot "out-pass")
  if ($ProofPassResult.status -ne "PASS") { throw "EXPECTED_PASS_WITH_REQUIRED_PROOFS" }
  if ($ProofPassResult.decision_id -ne "ENTRYPOINT_USE_SELF_MODEL_CAPABILITY_SELECTOR_NEED_V1") { throw "UNEXPECTED_PROOF_PASS_DECISION:$($ProofPassResult.decision_id)" }

  $RouteRoot = Join-Path ([IO.Path]::GetTempPath()) ("efab_active_route_" + [guid]::NewGuid().ToString("N"))
  try {
    New-Item -ItemType Directory -Force -Path $RouteRoot | Out-Null
    Push-Location $RouteRoot
    try {
      & git init -q
      & git config user.email "validator@example.invalid"
      & git config user.name "EFAB Validator"
      Set-Content -LiteralPath (Join-Path $RouteRoot "seed.txt") -Value "seed" -Encoding UTF8
      & git add seed.txt
      & git commit -q -m "seed"
      $RouteHead = (& git rev-parse HEAD).Trim()
    } finally { Pop-Location }
    Write-JsonFixture (Join-Path $RouteRoot "TASK_QUEUE.json") ([ordered]@{ active_task_id = "NONE" })
    Write-JsonFixture (Join-Path $RouteRoot "self_model/BUILDER_SELF_MODEL.json") ([ordered]@{ status = "PASS"; current_detected_need = "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR" })
    Write-JsonFixture (Join-Path $RouteRoot "self_control/AUTONOMOUS_LOOP_CONTROLLER.json") ([ordered]@{ status = "PASS" })
    Write-JsonFixture (Join-Path $RouteRoot "self_control/CURRENT_AGENT_BUILDER_STATE.json") ([ordered]@{ status = "PASS"; branch = "wrong-branch"; accepted_head = "deadbeef"; next_allowed_step = "OLD_PHASE"; last_accepted_proof = "proofs/missing-old.json"; pending_current_proof = "proofs/missing-old2.json" })
    Write-JsonFixture (Join-Path $RouteRoot "self_control/NEXT_ACTION.json") ([ordered]@{ status = "PASS"; next_allowed_step = "OLD_PHASE" })
    Write-JsonFixture (Join-Path $RouteRoot "self_control/LAST_ACCEPTED_PROOF_POINTER.json") ([ordered]@{ status = "PASS"; next_allowed_step = "OLD_PHASE"; last_accepted_proof = "proofs/missing-old.json"; pending_current_proof = "proofs/missing-old2.json" })
    New-Item -ItemType Directory -Force -Path (Join-Path $RouteRoot "route_locks") | Out-Null
    Set-Content -LiteralPath (Join-Path $RouteRoot "route_locks/ACTIVE.md") -Value "# ACTIVE ROUTE" -Encoding UTF8
    Write-JsonFixture (Join-Path $RouteRoot "route_locks/ACTIVE_ROUTE_LOCK.json") ([ordered]@{ active_route_lock_status = "ACTIVE_ROUTE_LOCK"; active_route_lock_file = "route_locks/ACTIVE.md"; route_baseline_head = $RouteHead; next_target_phase = "PASSPORT_REPEATABILITY_SECOND_SAMPLE_V1" })
    $RouteResult = Invoke-SelfModelFirstRuntimeEntrypoint -RepoRoot $RouteRoot -RunId "active-route" -OutputRoot (Join-Path $RouteRoot "out-route")
    if ($RouteResult.status -ne "BLOCKED") { throw "EXPECTED_BLOCKED_FOR_UNWIRED_ACTIVE_ROUTE" }
    if ($RouteResult.decision_id -ne "ENTRY_BLOCKED_ACTIVE_ROUTE_NOT_WIRED_V1") { throw "UNEXPECTED_ACTIVE_ROUTE_DECISION:$($RouteResult.decision_id)" }
    if ($RouteResult.proposed_next_step -ne "PASSPORT_REPEATABILITY_SECOND_SAMPLE_V1") { throw "ACTIVE_ROUTE_TARGET_NOT_PROPAGATED" }
  } finally {
    if (Test-Path $RouteRoot) { Remove-Item -LiteralPath $RouteRoot -Recurse -Force }
  }

  $StaleRoot = Join-Path ([IO.Path]::GetTempPath()) ("efab_stale_capsule_" + [guid]::NewGuid().ToString("N"))
  try {
    New-Item -ItemType Directory -Force -Path $StaleRoot | Out-Null
    Push-Location $StaleRoot
    try {
      & git init -q
      & git config user.email "validator@example.invalid"
      & git config user.name "EFAB Validator"
      Set-Content -LiteralPath (Join-Path $StaleRoot "seed.txt") -Value "seed" -Encoding UTF8
      & git add seed.txt
      & git commit -q -m "seed"
    } finally { Pop-Location }
    Write-JsonFixture (Join-Path $StaleRoot "TASK_QUEUE.json") ([ordered]@{ active_task_id = "NONE" })
    Write-JsonFixture (Join-Path $StaleRoot "self_model/BUILDER_SELF_MODEL.json") ([ordered]@{ status = "PASS"; current_detected_need = "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR" })
    Write-JsonFixture (Join-Path $StaleRoot "self_control/AUTONOMOUS_LOOP_CONTROLLER.json") ([ordered]@{ status = "PASS" })
    Write-JsonFixture (Join-Path $StaleRoot "self_control/CURRENT_AGENT_BUILDER_STATE.json") ([ordered]@{ status = "PASS"; branch = "wrong-branch"; accepted_head = "deadbeef"; next_allowed_step = "PHASE142"; last_accepted_proof = "proofs/missing140.json"; pending_current_proof = "proofs/missing141.json" })
    Write-JsonFixture (Join-Path $StaleRoot "self_control/NEXT_ACTION.json") ([ordered]@{ status = "PASS"; next_allowed_step = "PHASE142" })
    Write-JsonFixture (Join-Path $StaleRoot "self_control/LAST_ACCEPTED_PROOF_POINTER.json") ([ordered]@{ status = "PASS"; next_allowed_step = "PHASE142"; last_accepted_proof = "proofs/missing140.json"; pending_current_proof = "proofs/missing141.json" })
    $StaleResult = Invoke-SelfModelFirstRuntimeEntrypoint -RepoRoot $StaleRoot -RunId "stale-capsule" -OutputRoot (Join-Path $StaleRoot "out-stale")
    if ($StaleResult.status -ne "BLOCKED") { throw "EXPECTED_BLOCKED_WITH_STALE_CAPSULE" }
    if ($StaleResult.decision_id -ne "ENTRY_BLOCKED_STALE_STATE_CAPSULE_V1") { throw "UNEXPECTED_STALE_CAPSULE_DECISION:$($StaleResult.decision_id)" }
  } finally {
    if (Test-Path $StaleRoot) { Remove-Item -LiteralPath $StaleRoot -Recurse -Force }
  }

  Write-Host "VALIDATION_PASS=SELF_MODEL_SELECTOR_PROOF_GUARD_V1"
  exit 0
} finally {
  if (Test-Path $TempRoot) { Remove-Item -LiteralPath $TempRoot -Recurse -Force }
}