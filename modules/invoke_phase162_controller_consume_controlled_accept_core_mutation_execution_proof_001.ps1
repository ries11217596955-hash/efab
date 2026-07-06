param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,

  [Parameter(Mandatory=$true)]
  [string]$ExecutionProofPath,

  [Parameter(Mandatory=$true)]
  [string]$OutputRoot
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
  param([string]$Path, [object]$Object)
  $Parent = Split-Path -Parent $Path
  if ($Parent) { New-Item -ItemType Directory -Force -Path $Parent | Out-Null }
  $Object | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Resolve-RepoPath {
  param([string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
  return Join-Path $RepoRoot $Path
}

$proofFullPath = Resolve-RepoPath $ExecutionProofPath
$proof = Read-Json $proofFullPath

$executionRoot = Resolve-RepoPath ([string]$proof.output_root)
$executionResultPath = Join-Path $executionRoot "execute_controlled_accept_core_mutation_result.json"
$executionValidationPath = Join-Path $executionRoot "execute_controlled_accept_core_mutation_validation.json"

$execution = Read-Json $executionResultPath
$validation = Read-Json $executionValidationPath

$checks = [ordered]@{
  execution_proof_status_pass = ([string]$proof.status -eq "PASS")
  execution_result_status_pass = ([string]$execution.status -eq "PASS")
  execution_validation_status_pass = ([string]$validation.status -eq "PASS")
  controlled_accept_core_mutation_executed_true = ([bool]$execution.controlled_accept_core_mutation_executed -eq $true)
  post_real_mutation_validation_passed_true = ([bool]$execution.post_real_mutation_validation_passed -eq $true)
  rollback_not_executed = ([bool]$execution.rollback_executed -eq $false)
  staged_atom_count_positive = ([int]$execution.staged_atom_count -gt 0)
  accepted_core_write_executed_true = ([bool]$execution.accepted_core_write_executed -eq $true)
  accepted_memory_mutated_true = ([bool]$execution.accepted_memory_mutated -eq $true)
  accepted_self_model_mutated_true = ([bool]$execution.accepted_self_model_mutated -eq $true)
  registry_mutated_true = ([bool]$execution.registry_mutated -eq $true)
  final_accept_ready_true = ([bool]$execution.final_accept_ready -eq $true)
  execution_next_action_feeds_controller = ([string]$execution.next_machine_action -eq "FEED_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_BACK_INTO_CONTROLLER")
  proof_next_action_feeds_controller = ([string]$proof.next_action -eq "FEED_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_BACK_INTO_CONTROLLER")
  atom_not_claimed_before_controller_finalization = ([bool]$proof.accepted_atom_claimed -eq $false)
  machine_decision_pending_finalization = ([string]$execution.machine_decision -eq "CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTED_PENDING_CONTROLLER_FINALIZATION")
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_PROOF_RESULT_V1"
  status = $status
  created_at = (Get-Date -Format o)
  execution_proof = $ExecutionProofPath
  execution_output_root = [string]$proof.output_root
  controller_finalization_executed = ($status -eq "PASS")
  accepted_atom_claimed = ($status -eq "PASS")
  accepted_core_rewrite_executed = $false
  repeated_mutation_execution = $false
  consumed_execution_commit = [string]$proof.head
  consumed_next_action = [string]$execution.next_machine_action
  checks = $checks
  failed_checks = $failed
  machine_decision = if ($status -eq "PASS") { "CONTROLLED_ACCEPT_CORE_MUTATION_FINALIZED_PENDING_VISIBILITY_TRIAL" } else { "CONTROLLED_ACCEPT_CORE_MUTATION_FINALIZATION_REJECTED_PENDING_REPAIR" }
  next_machine_action = if ($status -eq "PASS") { "VERIFY_ACCEPTED_ATOM_VISIBLE_TO_NEXT_CYCLE" } else { "REPAIR_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_PROOF" }
}

Write-Json -Path (Join-Path $OutputRoot "controller_consume_controlled_accept_core_mutation_execution_proof_result.json") -Object $result

@"
# PHASE162 Controller Consumes Controlled Accept Core Mutation Execution Proof Report

## Result

- status: $($result.status)
- controller_finalization_executed: $($result.controller_finalization_executed)
- accepted_atom_claimed: $($result.accepted_atom_claimed)
- accepted_core_rewrite_executed: $($result.accepted_core_rewrite_executed)
- repeated_mutation_execution: $($result.repeated_mutation_execution)
- machine_decision: $($result.machine_decision)
- next_machine_action: $($result.next_machine_action)

## Meaning

Controller consumed the real accepted-core mutation execution proof.

This step does not run mutation again and does not rewrite accepted core. It finalizes the controller decision and sends the machine to next-cycle visibility verification.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_PROOF_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  controller_finalization_executed = [bool]$result.controller_finalization_executed
  accepted_atom_claimed = [bool]$result.accepted_atom_claimed
  accepted_core_rewrite_executed = [bool]$result.accepted_core_rewrite_executed
  repeated_mutation_execution = [bool]$result.repeated_mutation_execution
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}
