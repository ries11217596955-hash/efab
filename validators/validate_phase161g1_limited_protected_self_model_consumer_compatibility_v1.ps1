param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$AcceptedHead = 'f6ddd77543a143bdd191c1dba1a3759574c844bd'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-Phase161G1 {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Test-Phase161G1Parser {
  param([string]$Path)
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors) | Out-Null
  if ($errors -and $errors.Count -gt 0) {
    throw ("Parser failed for {0}: {1}" -f $Path, (($errors | ForEach-Object { $_.Message }) -join '; '))
  }
}

function Write-Phase161G1Json {
  param([string]$Path, $Value)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

try {
  $root = (Resolve-Path $RepoRoot).Path
  $protected = @('GENESIS_STATE.json','CAPABILITY_ROADMAP.json','TASK_QUEUE.json','packs/registry.json','orchestrator/run.ps1')
  foreach ($path in $protected) {
    Assert-Phase161G1 (Test-Path -LiteralPath (Join-Path $root $path)) "Root guard missing $path"
  }

  $branchBefore = (git -C $root branch --show-current).Trim()
  $headBefore = (git -C $root rev-parse HEAD).Trim()
  Assert-Phase161G1 ($headBefore -eq $AcceptedHead) "HEAD does not match accepted baseline $AcceptedHead"
  Assert-Phase161G1 (Test-Path -LiteralPath (Join-Path $root 'reports/self_development/PHASE161G1_EXECUTION_PLAN.md')) 'Execution plan missing'

  $hashesBefore = @{}
  foreach ($path in $protected) {
    $hashesBefore[$path] = (Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash
  }

  $candidateRoot = Join-Path $root 'reports/self_development/protected_state_update_candidates'
  $sourceCandidates = @(
    'GENESIS_STATE_update_candidate.json',
    'CAPABILITY_ROADMAP_update_candidate.json',
    'TASK_QUEUE_update_candidate.json',
    'PHASE161F_PROMOTION_MANIFEST.json',
    'PHASE161F_RISK_REVIEW.json'
  )
  foreach ($name in $sourceCandidates) {
    $path = Join-Path $candidateRoot $name
    Assert-Phase161G1 (Test-Path -LiteralPath $path) "Source candidate missing: $name"
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
  }
  Assert-Phase161G1 (Test-Path -LiteralPath (Join-Path $candidateRoot 'PHASE161F_PROTECTED_STATE_SYNC_PLAN.md')) 'PHASE161F sync plan missing'

  $parserFiles = @(
    'modules/inspect_builder_protected_state_consumers_001.ps1',
    'modules/simulate_builder_limited_protected_self_model_metadata_apply_001.ps1',
    'modules/validate_builder_limited_protected_self_model_compatibility_001.ps1',
    'validators/validate_phase161g1_limited_protected_self_model_consumer_compatibility_v1.ps1'
  )
  foreach ($path in $parserFiles) { Test-Phase161G1Parser -Path (Join-Path $root $path) }

  $inspector = Join-Path $root 'modules/inspect_builder_protected_state_consumers_001.ps1'
  $matrix = & $inspector -RepoRoot $root
  Assert-Phase161G1 (@($matrix.consumers).Count -gt 0) 'Consumer compatibility matrix is empty'

  $simulator = Join-Path $root 'modules/simulate_builder_limited_protected_self_model_metadata_apply_001.ps1'
  $simulation = & $simulator -RepoRoot $root
  Assert-Phase161G1 ($simulation.simulation_status -eq 'PASS') 'Limited simulation failed'

  $contractModule = Join-Path $root 'modules/validate_builder_limited_protected_self_model_compatibility_001.ps1'
  $contract = & $contractModule -RepoRoot $root
  Assert-Phase161G1 ($contract.result -eq 'PASS') 'Limited compatibility contract failed'
  Assert-Phase161G1 ($contract.genesis_state_decision -in @('APPROVE_WITH_LIMITS','DELAY')) 'Invalid GENESIS_STATE decision'
  Assert-Phase161G1 ($contract.capability_roadmap_decision -in @('APPROVE_WITH_LIMITS','DELAY')) 'Invalid CAPABILITY_ROADMAP decision'
  Assert-Phase161G1 ($contract.task_queue_decision -eq 'DELAY') 'TASK_QUEUE was not delayed'
  Assert-Phase161G1 ($contract.packs_registry_decision -in @('DELAY','REJECT')) 'packs/registry was approved'
  Assert-Phase161G1 ($contract.orchestrator_run_decision -in @('DELAY','REJECT')) 'orchestrator/run.ps1 was approved'

  $requiredOutputs = @(
    'PHASE161G1_CONSUMER_COMPATIBILITY_MATRIX.json',
    'PHASE161G1_GENESIS_STATE_COMPATIBILITY_REVIEW.md',
    'PHASE161G1_CAPABILITY_ROADMAP_COMPATIBILITY_REVIEW.md',
    'PHASE161G1_LIMITED_APPLY_SCOPE_RECOMMENDATION.json',
    'PHASE161G1_DELAYED_OR_BLOCKED_SCOPE.json',
    'PHASE161G1_SIMULATED_APPLY_RESULT.json'
  )
  foreach ($name in $requiredOutputs) {
    Assert-Phase161G1 (Test-Path -LiteralPath (Join-Path $candidateRoot $name)) "Required output missing: $name"
  }
  foreach ($name in @('PHASE161G1_CONSUMER_COMPATIBILITY_MATRIX.json','PHASE161G1_LIMITED_APPLY_SCOPE_RECOMMENDATION.json','PHASE161G1_DELAYED_OR_BLOCKED_SCOPE.json','PHASE161G1_SIMULATED_APPLY_RESULT.json')) {
    Get-Content -LiteralPath (Join-Path $candidateRoot $name) -Raw | ConvertFrom-Json | Out-Null
  }

  $delayed = Get-Content -LiteralPath (Join-Path $candidateRoot 'PHASE161G1_DELAYED_OR_BLOCKED_SCOPE.json') -Raw | ConvertFrom-Json
  $taskDecision = @($delayed.items | Where-Object { $_.target_file -eq 'TASK_QUEUE.json' })[0].decision
  $packDecision = @($delayed.items | Where-Object { $_.target_file -eq 'packs/registry.json' })[0].decision
  $orchestratorDecision = @($delayed.items | Where-Object { $_.target_file -eq 'orchestrator/run.ps1' })[0].decision
  Assert-Phase161G1 ($taskDecision -eq 'DELAY') 'TASK_QUEUE delayed scope missing'
  Assert-Phase161G1 ($packDecision -in @('DELAY','REJECT')) 'packs registry blocked scope missing'
  Assert-Phase161G1 ($orchestratorDecision -in @('DELAY','REJECT')) 'orchestrator blocked scope missing'

  $hashesAfter = @{}
  foreach ($path in $protected) {
    $hashesAfter[$path] = (Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash
    Assert-Phase161G1 ($hashesAfter[$path] -eq $hashesBefore[$path]) "Protected file changed: $path"
  }
  $protectedStatus = @(git -C $root status --short -- GENESIS_STATE.json CAPABILITY_ROADMAP.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1)
  $runtimeStatus = @(git -C $root status --short -- runtime_sessions)
  $branchAfter = (git -C $root branch --show-current).Trim()
  $headAfter = (git -C $root rev-parse HEAD).Trim()
  Assert-Phase161G1 ($protectedStatus.Count -eq 0) 'Protected files have git diff'
  Assert-Phase161G1 ($runtimeStatus.Count -eq 0) 'runtime_sessions changed or staged'
  Assert-Phase161G1 ($branchAfter -eq $branchBefore) 'Branch switched during validator'
  Assert-Phase161G1 ($headAfter -eq $headBefore) 'Commit occurred during validator'

  $proofPath = Join-Path $root 'proofs/self_development/PHASE161G1_LIMITED_PROTECTED_SELF_MODEL_COMPATIBILITY_PROOF.json'
  $reportPath = Join-Path $root 'reports/self_development/PHASE161G1_LIMITED_PROTECTED_SELF_MODEL_COMPATIBILITY_REPORT.md'
  $routePath = Join-Path $root 'route_change_requests/PHASE161G1_LIMITED_PROTECTED_SELF_MODEL_COMPATIBILITY_REQUEST.md'
  $deliveryPath = Join-Path $root 'reports/self_development/PHASE161G1_LIMITED_PROTECTED_SELF_MODEL_COMPATIBILITY_CODEX_DELIVERY.md'

  $proof = [pscustomobject][ordered]@{
    phase = 'PHASE161G1_LIMITED_PROTECTED_SELF_MODEL_CONSUMER_COMPATIBILITY_V1'
    validate_result = 'PASS'
    accepted_head = $AcceptedHead
    genesis_state_decision = $contract.genesis_state_decision
    capability_roadmap_decision = $contract.capability_roadmap_decision
    task_queue_decision = $taskDecision
    packs_registry_decision = $packDecision
    orchestrator_run_decision = $orchestratorDecision
    simulation_status = $simulation.simulation_status
    protected_files_modified_directly = $false
    protected_hashes_before = $hashesBefore
    protected_hashes_after = $hashesAfter
    consumer_record_count = @($matrix.consumers).Count
    runtime_outputs_staged = $false
    no_commit_performed = $true
    no_push_performed = $true
    no_branch_switch = $true
    created_at = (Get-Date).ToUniversalTime().ToString('o')
  }
  Write-Phase161G1Json -Path $proofPath -Value $proof

  @(
    '# PHASE161G1 Limited Protected Self-Model Compatibility Report',
    '',
    'Validation result: `PASS`',
    '',
    "GENESIS_STATE decision: $($contract.genesis_state_decision)",
    "CAPABILITY_ROADMAP decision: $($contract.capability_roadmap_decision)",
    "TASK_QUEUE decision: $taskDecision",
    "packs/registry decision: $packDecision",
    "orchestrator/run.ps1 decision: $orchestratorDecision",
    "Consumer records: $(@($matrix.consumers).Count)",
    'Simulation: `PASS`',
    'Protected state modified: `False`',
    '',
    'Only bounded GENESIS_STATE and CAPABILITY_ROADMAP metadata references may proceed to a separately approved PHASE161G2. Queue, pack registry, route, and orchestrator behavior remain outside scope.'
  ) | Set-Content -LiteralPath $reportPath -Encoding UTF8

  @(
    '# PHASE161G1 Limited Protected Self-Model Compatibility Request',
    '',
    'Request acceptance of the compatibility proof only.',
    '',
    'No protected apply is requested. Any future limited apply requires explicit owner approval and PHASE161G2.'
  ) | Set-Content -LiteralPath $routePath -Encoding UTF8

  @(
    '# PHASE161G1 Limited Protected Self-Model Compatibility Codex Delivery',
    '',
    'Root guard: `PASS`',
    'Validator: `PASS`',
    "GENESIS_STATE decision: $($contract.genesis_state_decision)",
    "CAPABILITY_ROADMAP decision: $($contract.capability_roadmap_decision)",
    'TASK_QUEUE decision: `DELAY`',
    "packs/registry decision: $packDecision",
    "orchestrator/run.ps1 decision: $orchestratorDecision",
    'Simulation: `PASS`',
    'Protected state mutated: `False`',
    'Runtime outputs staged: `False`',
    'No commit performed by validator: `True`',
    'No push performed by validator: `True`',
    'Final recommendation: `READY_FOR_ACCEPTANCE`'
  ) | Set-Content -LiteralPath $deliveryPath -Encoding UTF8

  Write-Host 'PHASE161G1_LIMITED_PROTECTED_SELF_MODEL_CONSUMER_COMPATIBILITY_VALIDATE_RESULT=PASS'
  Write-Host 'EXECUTION_PLAN_CREATED=True'
  Write-Host 'CONSUMER_COMPATIBILITY_MATRIX_CREATED=True'
  Write-Host 'GENESIS_STATE_COMPATIBILITY_REVIEW_CREATED=True'
  Write-Host 'CAPABILITY_ROADMAP_COMPATIBILITY_REVIEW_CREATED=True'
  Write-Host 'SIMULATED_APPLY_PASS=True'
  Write-Host 'GENESIS_STATE_APPROVE_WITH_LIMITS_OR_DELAY=True'
  Write-Host 'CAPABILITY_ROADMAP_APPROVE_WITH_LIMITS_OR_DELAY=True'
  Write-Host 'TASK_QUEUE_DELAYED=True'
  Write-Host 'PACKS_REGISTRY_BLOCKED_OR_DELAYED=True'
  Write-Host 'ORCHESTRATOR_RUN_BLOCKED_OR_DELAYED=True'
  Write-Host 'LIMITED_APPLY_SCOPE_RECOMMENDATION_CREATED=True'
  Write-Host 'NO_PROTECTED_STATE_MUTATION=True'
  Write-Host 'RUNTIME_OUTPUTS_STAGED=False'
  Write-Host 'NO_COMMIT_PERFORMED=True'
  Write-Host 'NO_PUSH_PERFORMED=True'
  Write-Host 'NO_BRANCH_SWITCH=True'
  Write-Host 'CODEX_DELIVERY_FILE_CREATED=True'
} catch {
  Write-Host 'PHASE161G1_LIMITED_PROTECTED_SELF_MODEL_CONSUMER_COMPATIBILITY_VALIDATE_RESULT=FAIL'
  Write-Host ("FAIL_REASON={0}" -f $_.Exception.Message)
  exit 1
}
