param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$AcceptedHead = '777326e87a797b9b90e6411aff7da0a4379455c4'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-Phase161F {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Test-Phase161FParser {
  param([string]$Path)
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors) | Out-Null
  if ($errors -and $errors.Count -gt 0) {
    throw ("Parser failed for {0}: {1}" -f $Path, (($errors | ForEach-Object { $_.Message }) -join '; '))
  }
}

function Write-Phase161FJson {
  param([string]$Path, $Value, [int]$Depth = 30)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

try {
  $root = (Resolve-Path $RepoRoot).Path
  $protected = @('TASK_QUEUE.json','GENESIS_STATE.json','CAPABILITY_ROADMAP.json','packs/registry.json','orchestrator/run.ps1')
  foreach ($path in $protected) {
    Assert-Phase161F (Test-Path -LiteralPath (Join-Path $root $path)) "Root guard missing $path"
  }

  $branchBefore = (git -C $root branch --show-current).Trim()
  $headBefore = (git -C $root rev-parse HEAD).Trim()
  Assert-Phase161F ($headBefore -eq $AcceptedHead) "HEAD does not match accepted baseline $AcceptedHead"
  Assert-Phase161F (Test-Path -LiteralPath (Join-Path $root 'reports/self_development/PHASE161F_EXECUTION_PLAN.md')) 'Execution plan missing'

  $hashesBefore = @{}
  foreach ($path in $protected) {
    $hashesBefore[$path] = (Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash
  }

  $parserFiles = @(
    'modules/build_builder_protected_self_model_promotion_candidate_001.ps1',
    'modules/inspect_builder_protected_self_model_sync_targets_001.ps1',
    'modules/validate_builder_protected_self_model_promotion_candidate_001.ps1',
    'modules/write_builder_protected_self_model_promotion_risk_review_001.ps1',
    'modules/simulate_builder_protected_state_candidate_apply_001.ps1',
    'validators/validate_phase161f_protected_self_model_promotion_candidate_v1.ps1'
  )
  foreach ($path in $parserFiles) {
    Test-Phase161FParser -Path (Join-Path $root $path)
  }

  $builder = Join-Path $root 'modules/build_builder_protected_self_model_promotion_candidate_001.ps1'
  $manifest = & $builder -RepoRoot $root -SourceBaselineHead $AcceptedHead -SourcePhase 'PHASE161E_SELF_MAP_AUTO_REFRESH_AFTER_ACCEPTED_CHANGE'
  Assert-Phase161F ($manifest.candidate_status -eq 'OWNER_REVIEW_REQUIRED') 'Builder did not create owner-review candidate'

  $simulator = Join-Path $root 'modules/simulate_builder_protected_state_candidate_apply_001.ps1'
  $dryRun = & $simulator -RepoRoot $root
  Assert-Phase161F ($dryRun.dry_run_status -eq 'PASS') 'Dry-run apply simulation failed'

  $contractValidator = Join-Path $root 'modules/validate_builder_protected_self_model_promotion_candidate_001.ps1'
  $contract = & $contractValidator -RepoRoot $root
  Assert-Phase161F ($contract.result -eq 'PASS') 'Promotion candidate contract failed'

  $candidateRoot = Join-Path $root 'reports/self_development/protected_state_update_candidates'
  $requiredCandidateFiles = @(
    'PHASE161F_PROMOTION_MANIFEST.json',
    'PHASE161F_PROTECTED_STATE_SYNC_PLAN.md',
    'GENESIS_STATE_update_candidate.json',
    'CAPABILITY_ROADMAP_update_candidate.json',
    'TASK_QUEUE_update_candidate.json',
    'packs_registry_update_candidate.json',
    'orchestrator_run_update_candidate.md',
    'PHASE161F_RISK_REVIEW.json',
    'PHASE161F_ROLLBACK_PLAN.md',
    'PHASE161F_DRY_RUN_APPLY_RESULT.json'
  )
  foreach ($name in $requiredCandidateFiles) {
    Assert-Phase161F (Test-Path -LiteralPath (Join-Path $candidateRoot $name)) "Candidate output missing: $name"
  }

  foreach ($name in @(
    'PHASE161F_PROMOTION_MANIFEST.json',
    'GENESIS_STATE_update_candidate.json',
    'CAPABILITY_ROADMAP_update_candidate.json',
    'TASK_QUEUE_update_candidate.json',
    'packs_registry_update_candidate.json',
    'PHASE161F_RISK_REVIEW.json',
    'PHASE161F_DRY_RUN_APPLY_RESULT.json'
  )) {
    Get-Content -LiteralPath (Join-Path $candidateRoot $name) -Raw | ConvertFrom-Json | Out-Null
  }

  $hashesAfter = @{}
  foreach ($path in $protected) {
    $hashesAfter[$path] = (Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash
    Assert-Phase161F ($hashesAfter[$path] -eq $hashesBefore[$path]) "Protected file changed: $path"
  }

  $protectedGitStatus = @(git -C $root status --short -- TASK_QUEUE.json GENESIS_STATE.json CAPABILITY_ROADMAP.json packs/registry.json orchestrator/run.ps1)
  $runtimeStatus = @(git -C $root status --short -- runtime_sessions)
  $branchAfter = (git -C $root branch --show-current).Trim()
  $headAfter = (git -C $root rev-parse HEAD).Trim()
  Assert-Phase161F ($protectedGitStatus.Count -eq 0) 'Protected state has git changes'
  Assert-Phase161F ($runtimeStatus.Count -eq 0) 'runtime_sessions changed or staged'
  Assert-Phase161F ($branchAfter -eq $branchBefore) 'Branch switched during validator'
  Assert-Phase161F ($headAfter -eq $headBefore) 'Commit occurred during validator'

  $risk = Get-Content -LiteralPath (Join-Path $candidateRoot 'PHASE161F_RISK_REVIEW.json') -Raw | ConvertFrom-Json
  $activeMap = Get-Content -LiteralPath (Join-Path $root 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json') -Raw | ConvertFrom-Json
  Assert-Phase161F ($activeMap.map_refresh_status -eq 'SELF_KNOWLEDGE_READY') 'PHASE161E self-map readiness was broken'
  Assert-Phase161F ($activeMap.protected_state_promotion_candidate_status -eq 'OWNER_REVIEW_REQUIRED') 'Active map promotion link missing'
  Assert-Phase161F ($activeMap.protected_state_direct_mutation_performed -eq $false) 'Active map reports protected mutation'

  $proofPath = Join-Path $root 'proofs/self_development/PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_PROOF.json'
  $reportPath = Join-Path $root 'reports/self_development/PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_REPORT.md'
  $routePath = Join-Path $root 'route_change_requests/PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_REQUEST.md'
  $deliveryPath = Join-Path $root 'reports/self_development/PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_CODEX_DELIVERY.md'

  $proof = [pscustomobject][ordered]@{
    phase = 'PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_V1'
    validate_result = 'PASS'
    source_baseline_head = $AcceptedHead
    promotion_id = $manifest.promotion_id
    candidate_status = $manifest.candidate_status
    target_protected_files = @($manifest.target_protected_files)
    candidate_file_count = $requiredCandidateFiles.Count
    proposed_changes_count = [int]$risk.proposed_changes_count
    dry_run_status = $dryRun.dry_run_status
    protected_files_modified_directly = $false
    protected_hashes_before = $hashesBefore
    protected_hashes_after = $hashesAfter
    runtime_outputs_staged = $false
    no_commit_performed = $true
    no_push_performed = $true
    no_branch_switch = $true
    phase161e_self_knowledge_ready_preserved = $true
    created_at = (Get-Date).ToUniversalTime().ToString('o')
  }
  Write-Phase161FJson -Path $proofPath -Value $proof

  @(
    '# PHASE161F Protected Self-Model Promotion Candidate Report',
    '',
    'Validation result: `PASS`',
    '',
    "Source baseline: $AcceptedHead",
    'Candidate status: `OWNER_REVIEW_REQUIRED`',
    'Protected files modified directly: `False`',
    "Proposed protected changes: $($risk.proposed_changes_count)",
    'Dry-run status: `PASS`',
    '',
    'The package proposes bounded self-model memory references only. It rejects direct orchestrator, pack admission, active task, current phase, and live-evidence promotion changes.'
  ) | Set-Content -LiteralPath $reportPath -Encoding UTF8

  @(
    '# PHASE161F Protected Self-Model Promotion Candidate Request',
    '',
    'Request owner review of the candidate package under `reports/self_development/protected_state_update_candidates/`.',
    '',
    'No protected apply is requested or performed in PHASE161F.'
  ) | Set-Content -LiteralPath $routePath -Encoding UTF8

  @(
    '# PHASE161F Protected Self-Model Promotion Candidate Codex Delivery',
    '',
    'Root guard: `PASS`',
    'Validator: `PASS`',
    "Source baseline: $AcceptedHead",
    'Candidate status: `OWNER_REVIEW_REQUIRED`',
    'Promotion manifest: `reports/self_development/protected_state_update_candidates/PHASE161F_PROMOTION_MANIFEST.json`',
    'Dry-run result: `reports/self_development/protected_state_update_candidates/PHASE161F_DRY_RUN_APPLY_RESULT.json`',
    'Protected state mutated: `False`',
    'Runtime outputs staged: `False`',
    'No commit performed by validator: `True`',
    'No push performed by validator: `True`',
    'Final recommendation: `READY_FOR_OWNER_REVIEW`'
  ) | Set-Content -LiteralPath $deliveryPath -Encoding UTF8

  Write-Host 'PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_VALIDATE_RESULT=PASS'
  Write-Host 'EXECUTION_PLAN_CREATED=True'
  Write-Host 'PROMOTION_MANIFEST_CREATED=True'
  Write-Host 'PROTECTED_STATE_SYNC_PLAN_CREATED=True'
  Write-Host 'ALL_TARGET_CANDIDATES_CREATED=True'
  Write-Host 'RISK_REVIEW_CREATED=True'
  Write-Host 'ROLLBACK_PLAN_CREATED=True'
  Write-Host 'DRY_RUN_APPLY_PASS=True'
  Write-Host 'OWNER_APPROVAL_REQUIRED=True'
  Write-Host 'CANDIDATE_STATUS=OWNER_REVIEW_REQUIRED'
  Write-Host 'PHASE161E_SELF_KNOWLEDGE_READY_PRESERVED=True'
  Write-Host 'NO_PROTECTED_STATE_MUTATION=True'
  Write-Host 'RUNTIME_OUTPUTS_STAGED=False'
  Write-Host 'NO_COMMIT_PERFORMED=True'
  Write-Host 'NO_PUSH_PERFORMED=True'
  Write-Host 'NO_BRANCH_SWITCH=True'
  Write-Host 'CODEX_DELIVERY_FILE_CREATED=True'
} catch {
  Write-Host 'PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_VALIDATE_RESULT=FAIL'
  Write-Host ("FAIL_REASON={0}" -f $_.Exception.Message)
  exit 1
}
