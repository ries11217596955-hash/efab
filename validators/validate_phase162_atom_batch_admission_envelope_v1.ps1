param(
  [Parameter(Mandatory=$true)]
  [string]$OutputRoot
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$envelope = Read-Json (Join-Path $OutputRoot "atom_batch_admission_envelope.json")
$request = Read-Json (Join-Path $OutputRoot "controlled_accept_candidate_dry_run_for_atom_batch_request.json")

$records = @($envelope.atom_records)
$eligible = @($records | Where-Object { [bool]$_.eligible_for_controlled_accept_candidate_dry_run -eq $true })
$recordsWithReasons = @($records | Where-Object { @($_.reason_codes).Count -gt 0 })

$checks = [ordered]@{
  status_pass = ([string]$envelope.status -eq "PASS")
  batch_policy_per_atom = ([string]$envelope.batch_policy_mode -eq "PER_ATOM_DECISION_NO_BATCH_BLIND_ACCEPT")
  batch_size_positive = ([int]$envelope.batch_size -gt 0)
  records_match_batch_size = ($records.Count -eq [int]$envelope.batch_size)
  eligible_count_matches = ($eligible.Count -eq [int]$envelope.eligible_atom_count)
  records_have_reasons = ($recordsWithReasons.Count -eq $records.Count)
  final_accept_false = ([bool]$envelope.allow_final_accept -eq $false)
  next_action_batch = ([string]$envelope.next_machine_action -eq "BUILD_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH")
  request_ready = ([string]$request.status -eq "READY_TO_BUILD")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_controlled_accept_candidate_dry_run_for_atom_batch_001.ps1")
  no_accepted_atom_claim = ([bool]$envelope.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$envelope.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$envelope.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$envelope.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_ATOM_BATCH_ADMISSION_ENVELOPE_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  batch_size = [int]$envelope.batch_size
  eligible_atom_count = [int]$envelope.eligible_atom_count
  next_machine_action = [string]$envelope.next_machine_action
}

$validationPath = Join-Path $OutputRoot "atom_batch_admission_envelope_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_ATOM_BATCH_ADMISSION_ENVELOPE_VALIDATION_FAILED"
}

Write-Host "PHASE162_ATOM_BATCH_ADMISSION_ENVELOPE_VALIDATION=PASS"
Write-Host "BATCH_POLICY_MODE=$($envelope.batch_policy_mode)"
Write-Host "BATCH_SIZE=$($envelope.batch_size)"
Write-Host "ELIGIBLE_ATOM_COUNT=$($envelope.eligible_atom_count)"
Write-Host "NEXT_MACHINE_ACTION=$($envelope.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
