param(
  [string]$FailureInputPath = "self_build_programs/quarantine/fixtures/FAILED_DYNAMIC_SELF_BUILD_PROGRAM_FIXTURE_V1.json",
  [string]$OutputPath = "self_build_programs/quarantine/failed_programs/FAILED_DYNAMIC_SELF_BUILD_PROGRAM_FIXTURE_V1_QUARANTINE.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $FailureInputPath)) {
  throw "Missing failure input: $FailureInputPath"
}

$Failure = Get-Content $FailureInputPath -Raw | ConvertFrom-Json

$ProgramId = [string]$Failure.program_id
$LineageId = [string]$Failure.lineage_id
$FailureReason = [string]$Failure.failure_reason

if ([string]::IsNullOrWhiteSpace($ProgramId)) { throw "program_id is empty" }
if ([string]::IsNullOrWhiteSpace($LineageId)) { throw "lineage_id is empty" }
if ([string]$Failure.status -ne "FAIL") { throw "failure input status must be FAIL" }
if ([string]::IsNullOrWhiteSpace($FailureReason)) { throw "failure_reason is empty" }
if ([bool]$Failure.not_atom -ne $true) { throw "not_atom must be true" }
if ([bool]$Failure.lineage_required -ne $true) { throw "lineage_required must be true" }

$Record = [pscustomobject]@{
  schema_version = "failed_self_build_program_quarantine_record_v1"
  phase = "PHASE165J_ADD_FAILED_SELF_BUILD_QUARANTINE_PATH"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  quarantine_id = "${ProgramId}_QUARANTINE"
  program_id = $ProgramId
  lineage_id = $LineageId
  status = "QUARANTINED"
  quarantine_decision = "QUARANTINE"
  quarantine_reason = $FailureReason
  failure_stage = [string]$Failure.failure_stage
  accepted = $false
  promoted = $false
  silently_retried = $false
  rollback_required = $false
  owner_review_required = $true
  memory_update_allowed = $false
  required_path = "PHASE87->PHASE88->PHASE89->PHASE90"
  not_atom = $true
  lineage_required = $true
  safety = [pscustomobject]@{
    no_execution = $true
    no_external_agent_production = $true
    no_external_fetch_or_install = $true
    no_protected_state_mutation = $true
    no_route_lock_mutation = $true
  }
}

$Record | ConvertTo-Json -Depth 40 | Set-Content -Encoding UTF8 -Path $OutputPath
$Record | ConvertTo-Json -Depth 40
