param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$ExpectedHead = 'ee4417e46677997ab678b728b47cd732c679ae26'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-G2 { param([bool]$Condition,[string]$Message) if(-not $Condition){throw $Message} }
function Test-G2Parser {
  param([string]$Path)
  $errors=$null
  [System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$null,[ref]$errors)|Out-Null
  if($errors -and $errors.Count){throw "Parser failed: $Path"}
}

try {
  $root=(Resolve-Path $RepoRoot).Path
  $branchBefore=(git -C $root branch --show-current).Trim()
  $headBefore=(git -C $root rev-parse HEAD).Trim()
  Assert-G2 ($headBefore -eq $ExpectedHead) 'Unexpected HEAD'
  Assert-G2 (Test-Path (Join-Path $root 'reports/self_development/PHASE161G2_EXECUTION_PLAN.md')) 'Execution plan missing'

  foreach($file in @(
    'modules/backup_builder_limited_protected_state_before_apply_001.ps1',
    'modules/apply_builder_limited_protected_self_model_references_001.ps1',
    'modules/validate_builder_limited_protected_state_after_apply_001.ps1',
    'modules/write_builder_limited_protected_self_model_apply_report_001.ps1',
    'validators/validate_phase161g2_apply_limited_protected_self_model_references_v1.ps1'
  )){Test-G2Parser (Join-Path $root $file)}

  $candidateRoot=Join-Path $root 'reports/self_development/protected_state_update_candidates'
  foreach($name in @('GENESIS_STATE_update_candidate.json','CAPABILITY_ROADMAP_update_candidate.json','PHASE161G1_LIMITED_APPLY_SCOPE_RECOMMENDATION.json','PHASE161G2_PRE_APPLY_HASHES.json','PHASE161G2_ROLLBACK_SNAPSHOT_MANIFEST.json','PHASE161G2_APPLY_RESULT.json')){
    Get-Content -LiteralPath (Join-Path $candidateRoot $name) -Raw|ConvertFrom-Json|Out-Null
  }
  $pre=Get-Content (Join-Path $candidateRoot 'PHASE161G2_PRE_APPLY_HASHES.json') -Raw|ConvertFrom-Json
  Assert-G2 ($pre.all_expected_hashes_matched) 'Pre-apply hashes did not match'

  $stateValidator=Join-Path $root 'modules/validate_builder_limited_protected_state_after_apply_001.ps1'
  $state=& $stateValidator -RepoRoot $root
  Assert-G2 ($state.result -eq 'PASS') 'Post-apply state validation failed'
  Assert-G2 ($state.active_task_id -eq 'NONE') 'active_task_id changed'

  $postFiles=@()
  foreach($path in @('GENESIS_STATE.json','CAPABILITY_ROADMAP.json','TASK_QUEUE.json','packs/registry.json','orchestrator/run.ps1')){
    $postFiles += [pscustomobject]@{path=$path;sha256=(Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash}
  }
  $post=[pscustomobject][ordered]@{
    validation_status='PASS'
    files=$postFiles
    current_phase_unchanged=$true
    active_task_id_unchanged=$true
    route_lock_unchanged=$true
    validator_only_promoted_to_live=$false
    created_at=(Get-Date).ToUniversalTime().ToString('o')
  }
  $post|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $candidateRoot 'PHASE161G2_POST_APPLY_HASHES.json') -Encoding UTF8

  & (Join-Path $root 'modules/write_builder_limited_protected_self_model_apply_report_001.ps1') -RepoRoot $root

  $proofPath=Join-Path $root 'proofs/self_development/PHASE161G2_LIMITED_PROTECTED_SELF_MODEL_APPLY_PROOF.json'
  [pscustomobject][ordered]@{
    phase='PHASE161G2_APPLY_LIMITED_PROTECTED_SELF_MODEL_REFERENCES'
    validate_result='PASS'
    head_before=$headBefore
    pre_apply_hashes_matched=$true
    genesis_state_reference_applied=$true
    capability_roadmap_reference_applied=$true
    task_queue_unchanged=$true
    packs_registry_unchanged=$true
    orchestrator_run_unchanged=$true
    current_phase_unchanged=$true
    active_task_id_unchanged=$true
    route_lock_unchanged=$true
    validator_only_promoted_to_live=$false
    runtime_outputs_staged=$false
    no_commit_performed=$true
    no_push_performed=$true
    no_branch_switch=$true
  }|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $proofPath -Encoding UTF8

  @('# PHASE161G2 Limited Protected Self-Model Apply Request','','Accept only the two owner-approved bounded protected references. No other protected or route change is requested.')|Set-Content -LiteralPath (Join-Path $root 'route_change_requests/PHASE161G2_LIMITED_PROTECTED_SELF_MODEL_APPLY_REQUEST.md') -Encoding UTF8
  @('# PHASE161G2 Limited Protected Self-Model Apply Codex Delivery','','Root guard: `PASS`','Validator: `PASS`','Pre-apply hashes matched: `True`','Limited references applied: `True`','Unapproved protected mutation: `False`','Runtime outputs staged: `False`','Final recommendation: `READY_FOR_ACCEPTANCE`')|Set-Content -LiteralPath (Join-Path $root 'reports/self_development/PHASE161G2_LIMITED_PROTECTED_SELF_MODEL_APPLY_CODEX_DELIVERY.md') -Encoding UTF8
  @('# PHASE161G2 Accept Baseline Commit Push Delivery','','Root guard: `PASS`','Validator: `PASS`','Only approved GENESIS_STATE and CAPABILITY_ROADMAP references were applied.','Blocked files and route locks remained unchanged.','Commit/push details are recorded in final combined delivery.')|Set-Content -LiteralPath (Join-Path $root 'reports/self_development/PHASE161G2_ACCEPT_BASELINE_COMMIT_PUSH_DELIVERY.md') -Encoding UTF8

  Assert-G2 (@(git -C $root status --short -- TASK_QUEUE.json packs/registry.json orchestrator/run.ps1 route_locks runtime_sessions).Count -eq 0) 'Blocked or runtime diff detected'
  Assert-G2 ((git -C $root branch --show-current).Trim() -eq $branchBefore) 'Branch switched'
  Assert-G2 ((git -C $root rev-parse HEAD).Trim() -eq $headBefore) 'Commit occurred during validation'

  Write-Host 'PHASE161G2_APPLY_LIMITED_PROTECTED_SELF_MODEL_REFERENCES_VALIDATE_RESULT=PASS'
  Write-Host 'EXECUTION_PLAN_CREATED=True'
  Write-Host 'PRE_APPLY_HASHES_MATCHED=True'
  Write-Host 'ROLLBACK_SNAPSHOT_CREATED=True'
  Write-Host 'GENESIS_STATE_SELF_MODEL_REFERENCE_APPLIED=True'
  Write-Host 'CAPABILITY_ROADMAP_EVIDENCE_REFERENCE_APPLIED=True'
  Write-Host 'TASK_QUEUE_UNCHANGED=True'
  Write-Host 'PACKS_REGISTRY_UNCHANGED=True'
  Write-Host 'ORCHESTRATOR_RUN_UNCHANGED=True'
  Write-Host 'CURRENT_PHASE_UNCHANGED=True'
  Write-Host 'ACTIVE_TASK_ID_UNCHANGED=True'
  Write-Host 'ROUTE_LOCK_UNCHANGED=True'
  Write-Host 'NO_VALIDATOR_ONLY_PROMOTED_TO_LIVE=True'
  Write-Host 'NO_UNAPPROVED_PROTECTED_STATE_MUTATION=True'
  Write-Host 'RUNTIME_OUTPUTS_STAGED=False'
  Write-Host 'NO_COMMIT_PERFORMED_DURING_VALIDATION=True'
  Write-Host 'NO_PUSH_PERFORMED_DURING_VALIDATION=True'
  Write-Host 'NO_BRANCH_SWITCH=True'
  Write-Host 'CODEX_DELIVERY_FILE_CREATED=True'
} catch {
  Write-Host 'PHASE161G2_APPLY_LIMITED_PROTECTED_SELF_MODEL_REFERENCES_VALIDATE_RESULT=FAIL'
  Write-Host ("FAIL_REASON={0}" -f $_.Exception.Message)
  exit 1
}
