param(
  [Parameter(Mandatory=$true)]
  [string]$CandidateRoot,

  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
  param([string]$Path, [object]$Object)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  ConvertTo-Json -InputObject $Object -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Get-Prop {
  param([object]$Obj, [string]$Name)
  $p = $Obj.PSObject.Properties[$Name]
  if ($null -eq $p) { return $null }
  return $p.Value
}

function Compare-Fingerprint {
  param([object]$A, [object]$B)
  if ($null -eq $A -or $null -eq $B) { return $false }
  return (
    ([bool]$A.exists -eq [bool]$B.exists) -and
    ([int64]$A.length -eq [int64]$B.length) -and
    ([string]$A.sha256 -eq [string]$B.sha256)
  )
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $CandidateRoot) "PHASE162_VALIDATED_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$result = Read-Json (Join-Path $CandidateRoot "controlled_accept_core_mutation_candidate_result.json")
$upstreamValidation = Read-Json (Join-Path $CandidateRoot "controlled_accept_core_mutation_candidate_validation.json")
$mutationSet = Read-Json (Join-Path $CandidateRoot "controlled_accept_core_mutation_set.json")
$writePlan = Read-Json (Join-Path $CandidateRoot "atomic_accept_write_plan.json")
$rollbackPlan = Read-Json (Join-Path $CandidateRoot "controlled_accept_core_mutation_rollback_plan.json")
$postBinding = Read-Json (Join-Path $CandidateRoot "post_mutation_validation_binding.json")
$pre = Read-Json (Join-Path $CandidateRoot "pre_accept_fingerprints.json")
$after = Read-Json (Join-Path $CandidateRoot "after_candidate_fingerprints.json")

$targetFiles = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)

$memoryOps = @($mutationSet.accepted_memory_operations)
$selfModelOps = @($mutationSet.accepted_self_model_operations)
$registryOps = @($mutationSet.registry_operations)
$allOps = @($memoryOps + $selfModelOps + $registryOps)

$staged = [int]$result.staged_atom_count

$fingerprintTargetsPresent = $true
$preAfterFingerprintsMatch = $true

foreach ($t in $targetFiles) {
  $preFp = Get-Prop -Obj $pre -Name $t
  $afterFp = Get-Prop -Obj $after -Name $t

  if ($null -eq $preFp -or $null -eq $afterFp) {
    $fingerprintTargetsPresent = $false
    $preAfterFingerprintsMatch = $false
  } elseif (-not (Compare-Fingerprint -A $preFp -B $afterFp)) {
    $preAfterFingerprintsMatch = $false
  }
}

$operationIds = @($allOps | ForEach-Object { [string]$_.operation_id })
$operationIdsUnique = ($operationIds.Count -eq @($operationIds | Sort-Object -Unique).Count)

$memoryAtomIds = @($memoryOps | ForEach-Object { [string]$_.atom_id } | Sort-Object)
$selfModelAtomIds = @($selfModelOps | ForEach-Object { [string]$_.atom_id } | Sort-Object)
$registryAtomIds = @($registryOps | ForEach-Object { [string]$_.atom_id } | Sort-Object)

$atomIdsAligned = (
  -not (Compare-Object $memoryAtomIds $selfModelAtomIds) -and
  -not (Compare-Object $memoryAtomIds $registryAtomIds)
)

$targetsAllowed = (
  @($allOps | Where-Object { $targetFiles -notcontains [string]$_.target }).Count -eq 0
)

$noWriteModes = (
  ([string]$mutationSet.mode -eq "CANDIDATE_ONLY_NO_ACCEPTED_CORE_WRITES") -and
  ([string]$writePlan.mode -eq "PLAN_ONLY_NO_WRITE") -and
  ([string]$rollbackPlan.mode -eq "PLAN_ONLY_NO_WRITE") -and
  ([string]$postBinding.mode -eq "BINDING_ONLY_NO_WRITE")
)

$finalWriteDeniedEverywhere = (
  ([bool]$mutationSet.final_write_allowed_now -eq $false) -and
  ([bool]$writePlan.final_write_allowed_now -eq $false) -and
  ([bool]$rollbackPlan.final_write_allowed_now -eq $false) -and
  ([bool]$postBinding.final_write_allowed_now -eq $false)
)

$writePlanValid = (
  ([string]$writePlan.status -eq "PASS") -and
  (@($writePlan.order).Count -ge 6) -and
  (@($writePlan.target_files).Count -eq 3) -and
  ([string]$writePlan.atomicity_rule -eq "all_operations_pass_or_rollback")
)

$rollbackPlanValid = (
  ([string]$rollbackPlan.status -eq "PASS") -and
  (@($rollbackPlan.rollback_actions).Count -ge 5) -and
  ($null -ne $rollbackPlan.pre_accept_fingerprints)
)

$postBindingValid = (
  ([string]$postBinding.status -eq "PASS") -and
  ([int]$postBinding.expected_atom_count -eq $staged) -and
  ([string]$postBinding.bound_to_mutation_set -eq "controlled_accept_core_mutation_set.json") -and
  ([string]$postBinding.bound_to_atomic_write_plan -eq "atomic_accept_write_plan.json") -and
  (@($postBinding.must_run_after_future_write).Count -ge 6)
)

$opsCountsValid = (
  ($staged -gt 0) -and
  ($memoryOps.Count -eq $staged) -and
  ($selfModelOps.Count -eq $staged) -and
  ($registryOps.Count -eq $staged)
)

$upstreamOk = (
  ([string]$upstreamValidation.status -eq "PASS") -and
  ([string]$result.status -eq "PASS") -and
  ([bool]$result.controlled_accept_core_mutation_candidate_prepared -eq $true)
)

$acceptedCoreSafe = (
  ([bool]$result.accepted_state_mutated -eq $false) -and
  ([bool]$result.accepted_memory_mutated -eq $false) -and
  ([bool]$result.accepted_self_model_mutated -eq $false) -and
  ([bool]$result.protected_targets_unchanged -eq $true)
)

$candidateDeepValidationPassed = (
  $upstreamOk -and
  $opsCountsValid -and
  $operationIdsUnique -and
  $atomIdsAligned -and
  $targetsAllowed -and
  $noWriteModes -and
  $finalWriteDeniedEverywhere -and
  $writePlanValid -and
  $rollbackPlanValid -and
  $postBindingValid -and
  $fingerprintTargetsPresent -and
  $preAfterFingerprintsMatch -and
  $acceptedCoreSafe
)

$checks = [ordered]@{
  upstream_ok = [bool]$upstreamOk
  ops_counts_valid = [bool]$opsCountsValid
  operation_ids_unique = [bool]$operationIdsUnique
  atom_ids_aligned = [bool]$atomIdsAligned
  targets_allowed = [bool]$targetsAllowed
  no_write_modes = [bool]$noWriteModes
  final_write_denied_everywhere = [bool]$finalWriteDeniedEverywhere
  write_plan_valid = [bool]$writePlanValid
  rollback_plan_valid = [bool]$rollbackPlanValid
  post_mutation_validation_binding_valid = [bool]$postBindingValid
  fingerprint_targets_present = [bool]$fingerprintTargetsPresent
  pre_after_fingerprints_match = [bool]$preAfterFingerprintsMatch
  accepted_core_safe = [bool]$acceptedCoreSafe
}

$deepResult = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_DEEP_VALIDATION_FOR_ATOM_BATCH_RESULT_V1"
  status = if ($candidateDeepValidationPassed) { "PASS" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  candidate_root = $CandidateRoot
  staged_atom_count = $staged
  controlled_accept_core_mutation_candidate_deep_validated = [bool]$candidateDeepValidationPassed
  checks = $checks
  final_accept_ready = $false
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = "FEED_VALIDATED_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_BACK_INTO_CONTROLLER"
  why_final_accept_denied = @(
    "future_write_authorization_not_issued",
    "accepted_core_write_not_authorized_in_deep_validation_step",
    "controlled_accept_dry_run_not_executed"
  )
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_deep_validation_result.json") -Object $deepResult
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_deep_validation_checks.json") -Object $checks

@"
# PHASE162 Controlled Accept Core Mutation Candidate Deep Validation Report

## Result

- status: $($deepResult.status)
- controlled_accept_core_mutation_candidate_deep_validated: $($deepResult.controlled_accept_core_mutation_candidate_deep_validated)
- staged_atom_count: $($deepResult.staged_atom_count)
- final_accept_ready: false
- next_machine_action: $($deepResult.next_machine_action)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The candidate was checked for operation counts, atom alignment, allowed targets, no-write mode, atomic write plan, rollback plan, post-mutation validation binding, and fingerprint consistency.

No accepted-core file was mutated.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_DEEP_VALIDATION_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $deepResult.status
  output_root = $OutputRoot
  candidate_deep_validated = [bool]$deepResult.controlled_accept_core_mutation_candidate_deep_validated
  staged_atom_count = [int]$deepResult.staged_atom_count
  next_machine_action = [string]$deepResult.next_machine_action
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
