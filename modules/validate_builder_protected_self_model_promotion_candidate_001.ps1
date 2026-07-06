param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CandidateRoot = 'reports/self_development/protected_state_update_candidates'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-BuilderCandidate {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$root = (Resolve-Path $RepoRoot).Path
$candidateFull = Join-Path $root $CandidateRoot
$manifestPath = Join-Path $candidateFull 'PHASE161F_PROMOTION_MANIFEST.json'
$riskPath = Join-Path $candidateFull 'PHASE161F_RISK_REVIEW.json'
$dryRunPath = Join-Path $candidateFull 'PHASE161F_DRY_RUN_APPLY_RESULT.json'
$syncPlanPath = Join-Path $candidateFull 'PHASE161F_PROTECTED_STATE_SYNC_PLAN.md'
$rollbackPath = Join-Path $candidateFull 'PHASE161F_ROLLBACK_PLAN.md'
$orchestratorCandidatePath = Join-Path $candidateFull 'orchestrator_run_update_candidate.md'

foreach ($path in @($manifestPath,$riskPath,$dryRunPath,$syncPlanPath,$rollbackPath,$orchestratorCandidatePath)) {
  Assert-BuilderCandidate (Test-Path -LiteralPath $path) "Candidate artifact missing: $path"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$risk = Get-Content -LiteralPath $riskPath -Raw | ConvertFrom-Json
$dryRun = Get-Content -LiteralPath $dryRunPath -Raw | ConvertFrom-Json
$orchestratorText = Get-Content -LiteralPath $orchestratorCandidatePath -Raw

Assert-BuilderCandidate ($manifest.direct_mutation_performed -eq $false) 'Manifest reports direct mutation'
Assert-BuilderCandidate ($manifest.protected_state_mutation_allowed -eq $false) 'Manifest allows protected mutation'
Assert-BuilderCandidate ($manifest.owner_approval_required -eq $true) 'Manifest lacks owner approval gate'
Assert-BuilderCandidate ($manifest.candidate_status -eq 'OWNER_REVIEW_REQUIRED') 'Manifest status is not OWNER_REVIEW_REQUIRED'
Assert-BuilderCandidate (@($manifest.target_protected_files).Count -eq 5) 'Manifest target count mismatch'
Assert-BuilderCandidate ($risk.protected_files_modified_directly -eq $false) 'Risk review reports protected mutation'
Assert-BuilderCandidate ($risk.owner_approval_required -eq $true) 'Risk review lacks owner approval gate'
Assert-BuilderCandidate ($dryRun.dry_run_status -eq 'PASS') 'Dry-run did not pass'
Assert-BuilderCandidate ($dryRun.protected_files_modified_directly -eq $false) 'Dry-run modified protected files'
Assert-BuilderCandidate ($dryRun.original_hashes_preserved -eq $true) 'Dry-run did not preserve hashes'
Assert-BuilderCandidate ($orchestratorText -match 'NO DIRECT ORCHESTRATOR CHANGE') 'Orchestrator candidate does not default to no change'

$jsonCandidateNames = @(
  'GENESIS_STATE_update_candidate.json',
  'CAPABILITY_ROADMAP_update_candidate.json',
  'TASK_QUEUE_update_candidate.json',
  'packs_registry_update_candidate.json'
)
foreach ($name in $jsonCandidateNames) {
  $candidate = Get-Content -LiteralPath (Join-Path $candidateFull $name) -Raw | ConvertFrom-Json
  Assert-BuilderCandidate ($candidate.owner_approval_required -eq $true) "$name lacks owner approval gate"
  Assert-BuilderCandidate ($candidate.direct_apply_allowed -eq $false) "$name allows direct apply"
  Assert-BuilderCandidate (-not [string]::IsNullOrWhiteSpace($candidate.target_file)) "$name target missing"
  Assert-BuilderCandidate (-not [string]::IsNullOrWhiteSpace($candidate.current_file_hash_or_size.sha256)) "$name hash missing"
}

$activeMap = Get-Content -LiteralPath (Join-Path $root 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json') -Raw | ConvertFrom-Json
Assert-BuilderCandidate ($activeMap.protected_state_promotion_candidate_status -eq 'OWNER_REVIEW_REQUIRED') 'Active map candidate status missing'
Assert-BuilderCandidate ($activeMap.protected_state_direct_mutation_performed -eq $false) 'Active map reports direct mutation'

[pscustomobject]@{
  result = 'PASS'
  promotion_id = $manifest.promotion_id
  candidate_status = $manifest.candidate_status
  target_count = @($manifest.target_protected_files).Count
  proposed_changes_count = [int]$risk.proposed_changes_count
  dry_run_status = $dryRun.dry_run_status
  protected_files_modified_directly = $false
}
