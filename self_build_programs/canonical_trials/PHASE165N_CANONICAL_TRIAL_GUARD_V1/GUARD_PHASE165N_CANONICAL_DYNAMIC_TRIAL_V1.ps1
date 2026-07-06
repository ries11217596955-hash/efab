param(
  [string]$OutputPath = "proofs/self_development/PHASE165N_CANONICAL_TRIAL_GUARD_BLOCKED_BY_FIXED_BOOTSTRAP_ASSUMPTIONS_V1.json"
)

$ErrorActionPreference = "Stop"

function Has-Text([string]$Path, [string]$Pattern) {
  if (-not (Test-Path $Path)) { return $false }
  return [bool](Select-String -Path $Path -Pattern $Pattern -SimpleMatch -Quiet)
}

function Read-JsonRequired([string]$Path) {
  if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
  return Get-Content $Path -Raw | ConvertFrom-Json
}

$MProofPath = "proofs/self_development/PHASE165M_RUN_FIRST_DYNAMIC_OWNER_MATERIAL_SELF_BUILD_DRY_RUN_V1.json"
$MProof = Read-JsonRequired $MProofPath

$TaskGenerator = "tasks/TASK_SELF_BUILD_PROGRAM_GENERATOR_V1_001.json"
$TaskAdmission = "tasks/TASK_GENERATED_PROGRAM_ADMISSION_V1_001.json"
$TaskExecution = "tasks/TASK_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001.json"

$Pack89 = "packs/PHASE89_GENERATED_PROGRAM_ADMISSION_V1/APPLY.ps1"
$Pack90 = "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/APPLY.ps1"

$FixedSignals = [pscustomobject]@{
  task_phase88_mentions_fixed_program = (Has-Text $TaskGenerator "SELF_BUILD_PROGRAM_001")
  task_phase89_mentions_fixed_program = (Has-Text $TaskAdmission "SELF_BUILD_PROGRAM_001")
  task_phase90_mentions_fixed_program = (Has-Text $TaskExecution "SELF_BUILD_PROGRAM_001")
  pack_phase89_reads_fixed_program = (Has-Text $Pack89 'Read-JsonRequired "self_build_programs/generated/SELF_BUILD_PROGRAM_001.json"')
  pack_phase90_reads_fixed_program = (Has-Text $Pack90 'Read-JsonRequired "self_build_programs/generated/SELF_BUILD_PROGRAM_001.json"')
  pack_phase90_reads_fixed_admission = (Has-Text $Pack90 'Read-JsonRequired "self_build_programs/admission/SELF_BUILD_PROGRAM_001_ADMISSION.json"')
}

$DynamicDryRunReady = (
  [bool]$MProof.validation_passed -eq $true -and
  [bool]$MProof.dynamic_program_generated -eq $true -and
  [bool]$MProof.dynamic_admission_performed -eq $true -and
  [bool]$MProof.dynamic_execution_performed -eq $true -and
  [bool]$MProof.completed_loop -eq $true -and
  [string]$MProof.absorption_decision -eq "KEEP" -and
  [bool]$MProof.canonical_orchestrator_used -eq $false
)

$FixedAssumptionsPresent = $false
foreach ($Prop in $FixedSignals.PSObject.Properties) {
  if ([bool]$Prop.Value -eq $true) { $FixedAssumptionsPresent = $true }
}

$CanonicalTrialReady = ($DynamicDryRunReady -and -not $FixedAssumptionsPresent)
$CanonicalTrialExecuted = $false

$BlockedReason = if ($FixedAssumptionsPresent) {
  "Canonical trial blocked: task descriptors and/or PHASE89/PHASE90 pack body still contain fixed SELF_BUILD_PROGRAM_001 assumptions."
} elseif (-not $DynamicDryRunReady) {
  "Canonical trial blocked: PHASE165M dry-run proof is not ready."
} else {
  "Canonical trial ready, but this guard does not execute orchestrator."
}

$Proof = [pscustomobject]@{
  phase = "PHASE165N_RUN_FIRST_DYNAMIC_OWNER_MATERIAL_SELF_BUILD_CANONICAL_TRIAL"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  mode = "GUARDED_CANONICAL_TRIAL_PREFLIGHT_NO_ORCHESTRATOR_RUN"

  status = if ($CanonicalTrialReady) { "READY_NOT_EXECUTED_BY_PREFLIGHT" } else { "BLOCKED_SAFE_STOP" }
  guard_validation_passed = $true
  canonical_trial_ready = [bool]$CanonicalTrialReady
  canonical_trial_executed = [bool]$CanonicalTrialExecuted
  blocked_reason = $BlockedReason

  program_id = [string]$MProof.program_id
  lineage_id = [string]$MProof.lineage_id
  selected_material_id = [string]$MProof.selected_material_id

  phase165m_dry_run_ready = [bool]$DynamicDryRunReady
  phase165m_validation_passed = [bool]$MProof.validation_passed
  dry_run_completed_loop = [bool]$MProof.completed_loop
  dry_run_absorption_decision = [string]$MProof.absorption_decision

  fixed_bootstrap_assumptions_present = [bool]$FixedAssumptionsPresent
  fixed_signals = $FixedSignals

  task_queue_mutated = $false
  protected_state_mutated = $false
  route_lock_mutated = $false
  genesis_state_mutated = $false
  capability_roadmap_mutated = $false
  self_model_mutated = $false
  external_agent_production = $false
  external_fetch_or_install = $false
  codex_used = $false

  conclusion = "PHASE165N canonical trial is safely blocked before orchestrator execution because canonical descriptors/pack bodies still carry fixed SELF_BUILD_PROGRAM_001 assumptions. Next action is dynamic canonical contract repair inside PHASE165N before any canonical run."
  next_required_action = "PHASE165N_ROUTE_REPAIR_DYNAMIC_CANONICAL_TASK_DESCRIPTOR_AND_ENTRYPOINT_CONTRACT"
}

$Proof | ConvertTo-Json -Depth 80 | Set-Content -Encoding UTF8 -Path $OutputPath
$Proof | ConvertTo-Json -Depth 80
