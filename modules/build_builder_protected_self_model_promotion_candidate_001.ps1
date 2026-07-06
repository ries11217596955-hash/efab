param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$SourceBaselineHead = '777326e87a797b9b90e6411aff7da0a4379455c4',
  [string]$SourcePhase = 'PHASE161E_SELF_MAP_AUTO_REFRESH_AFTER_ACCEPTED_CHANGE'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-BuilderJson {
  param([string]$Path, $Value, [int]$Depth = 30)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Set-BuilderProperty {
  param($Object, [string]$Name, $Value)
  if ($Object.PSObject.Properties.Name -contains $Name) {
    $Object.$Name = $Value
  } else {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  }
}

$root = (Resolve-Path $RepoRoot).Path
$candidateRelative = 'reports/self_development/protected_state_update_candidates'
$candidateRoot = Join-Path $root $candidateRelative
if (-not (Test-Path -LiteralPath $candidateRoot)) {
  New-Item -ItemType Directory -Path $candidateRoot | Out-Null
}

$sourcePaths = @(
  'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  'reports/self_development/self_map_memory_report.md',
  'reports/self_development/self_map_refresh_after_acceptance_result.json',
  'reports/self_development/accepted_change_memory_snapshot.json',
  'reports/self_development/live_evidence_separation_index.json',
  'reports/self_development/self_model_gap_chain.json',
  'reports/self_development/agent_body_map.json',
  'proofs/self_development/PHASE161E_SELF_MAP_AUTO_REFRESH_PROOF.json',
  'route_locks/ACTIVE_ROUTE_LOCK.json'
)
foreach ($path in $sourcePaths) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $path))) { throw "Promotion source missing: $path" }
}

$activeMap = Get-Content -LiteralPath (Join-Path $root 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json') -Raw | ConvertFrom-Json
$refresh = Get-Content -LiteralPath (Join-Path $root 'reports/self_development/self_map_refresh_after_acceptance_result.json') -Raw | ConvertFrom-Json
if ($activeMap.map_refresh_status -ne 'SELF_KNOWLEDGE_READY' -or -not $activeMap.self_knowledge_ready) {
  throw 'Source self-map is not ready for promotion candidate generation.'
}

$inspector = Join-Path $PSScriptRoot 'inspect_builder_protected_self_model_sync_targets_001.ps1'
$inspection = & $inspector -RepoRoot $root
$targetByPath = @{}
foreach ($target in $inspection.targets) { $targetByPath[$target.target_file] = $target }

$promotionId = 'PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_V1'
$commonValidation = @(
  'Parse target JSON after proposed apply.',
  'Run target-specific validators and downstream consumer compatibility checks.',
  'Confirm protected target pre-apply SHA-256 matches candidate identity.',
  'Run PHASE161E self-map refresh after approved apply.',
  'Confirm no validator-only evidence is promoted to live evidence.'
)

$candidates = @(
  [pscustomobject][ordered]@{
    file_name = 'GENESIS_STATE_update_candidate.json'
    target_file = 'GENESIS_STATE.json'
    proposed_update_type = 'ADD_NAMESPACED_SELF_MODEL_MEMORY_REFERENCE'
    proposed_fields_or_sections = [ordered]@{
      protected_self_model_memory = [ordered]@{
        promotion_id = $promotionId
        source_baseline_head = $SourceBaselineHead
        source_phase = $SourcePhase
        map_refresh_status = $refresh.map_refresh_status
        self_knowledge_ready = [bool]$refresh.self_knowledge_ready
        map_is_ready_for_next_decision = [bool]$refresh.map_is_ready_for_next_decision
        active_route_lock = $refresh.active_route_lock
        self_model_active_map_path = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
        memory_report_path = 'reports/self_development/self_map_memory_report.md'
        evidence_boundary = 'DERIVED_MAP_REFERENCE_ONLY'
      }
    }
    reason = 'GENESIS_STATE is the closest protected memory surface, but the proposal is a bounded reference rather than copying the full derived map or changing readiness/product claims.'
    risk_level = 'MEDIUM'
  },
  [pscustomobject][ordered]@{
    file_name = 'CAPABILITY_ROADMAP_update_candidate.json'
    target_file = 'CAPABILITY_ROADMAP.json'
    proposed_update_type = 'ADD_PHASE161E_CAPABILITY_EVIDENCE_REFERENCE'
    proposed_fields_or_sections = [ordered]@{
      phase161e_self_map_auto_refresh = [ordered]@{
        status = 'ACCEPTED_EVIDENCE_REFERENCE_CANDIDATE'
        accepted_head = $SourceBaselineHead
        proof_path = 'proofs/self_development/PHASE161E_SELF_MAP_AUTO_REFRESH_PROOF.json'
        active_map_path = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
        protected_promotion_status = 'OWNER_REVIEW_REQUIRED'
      }
    }
    reason = 'The roadmap can reference the accepted self-map refresh capability without rewriting existing capability entries or claiming protected promotion is complete.'
    risk_level = 'MEDIUM'
  },
  [pscustomobject][ordered]@{
    file_name = 'TASK_QUEUE_update_candidate.json'
    target_file = 'TASK_QUEUE.json'
    proposed_update_type = 'ADD_NON_ACTIVE_OWNER_REVIEW_TASK'
    proposed_fields_or_sections = [ordered]@{
      proposed_task = [ordered]@{
        task_id = 'PHASE161F_OWNER_REVIEW_PROTECTED_SELF_MODEL_PROMOTION'
        line = 'AGENT_BUILDER_SELF_DEVELOPMENT'
        status = 'OWNER_REVIEW_REQUIRED'
        active_task_change_allowed = $false
        candidate_manifest = "$candidateRelative/PHASE161F_PROMOTION_MANIFEST.json"
        goal = 'Review and approve, reject, or revise the protected self-model promotion candidate.'
      }
    }
    reason = 'A later approved queue update can expose the owner decision without replacing active_task_id or changing current execution.'
    risk_level = 'MEDIUM'
  },
  [pscustomobject][ordered]@{
    file_name = 'packs_registry_update_candidate.json'
    target_file = 'packs/registry.json'
    proposed_update_type = 'NO_CHANGE_RECOMMENDED'
    proposed_fields_or_sections = [ordered]@{
      recommendation = 'Do not add PHASE161E/PHASE161F as a pack entry.'
      reason = 'The accepted self-map refresh is implemented through modules, validators, and derived reports; no admitted executable pack was created.'
    }
    reason = 'Adding a registry entry without a real pack would create false capability wiring.'
    risk_level = 'LOW'
  }
)

foreach ($candidate in $candidates) {
  $identity = $targetByPath[$candidate.target_file]
  $document = [pscustomobject][ordered]@{
    target_file = $candidate.target_file
    current_file_hash_or_size = [ordered]@{
      sha256 = $identity.current_sha256
      size_bytes = $identity.current_size_bytes
    }
    source_self_map_head = $SourceBaselineHead
    proposed_update_type = $candidate.proposed_update_type
    proposed_fields_or_sections = $candidate.proposed_fields_or_sections
    reason = $candidate.reason
    risk_level = $candidate.risk_level
    owner_approval_required = $true
    direct_apply_allowed = $false
    rollback_note = 'Restore exact pre-apply bytes identified by the recorded SHA-256 if a future approved apply fails validation.'
    validation_required = $commonValidation
  }
  Write-BuilderJson -Path (Join-Path $candidateRoot $candidate.file_name) -Value $document
}

$orchestratorIdentity = $targetByPath['orchestrator/run.ps1']
$orchestratorLines = @(
  '# Orchestrator Run Update Candidate',
  '',
  'Target: `orchestrator/run.ps1`',
  '',
  ('Current SHA-256: `{0}`' -f $orchestratorIdentity.current_sha256),
  '',
  ('Current size: `{0}` bytes' -f $orchestratorIdentity.current_size_bytes),
  '',
  'Recommendation: **NO DIRECT ORCHESTRATOR CHANGE**.',
  '',
  'Reason: PHASE161E refresh is a reusable acceptance workflow module. Current evidence does not justify changing orchestrator flow or adding a new runtime mode. A future integration should first prove the exact accepted-change hook, invocation ownership, failure behavior, and rollback contract.',
  '',
  'Owner approval required: `true`',
  '',
  'Direct apply allowed: `false`'
)
$orchestratorLines | Set-Content -LiteralPath (Join-Path $candidateRoot 'orchestrator_run_update_candidate.md') -Encoding UTF8

$manifest = [pscustomobject][ordered]@{
  promotion_id = $promotionId
  source_baseline_head = $SourceBaselineHead
  source_phase = $SourcePhase
  source_self_model_active_map = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
  source_memory_report = 'reports/self_development/self_map_memory_report.md'
  source_refresh_result = 'reports/self_development/self_map_refresh_after_acceptance_result.json'
  target_protected_files = @('TASK_QUEUE.json','GENESIS_STATE.json','CAPABILITY_ROADMAP.json','packs/registry.json','orchestrator/run.ps1')
  direct_mutation_performed = $false
  owner_approval_required = $true
  candidate_status = 'OWNER_REVIEW_REQUIRED'
  proposed_sync_summary = 'Propose bounded protected references to accepted PHASE161E self-map memory and an owner-review task. Do not alter current execution claims, pack admission, route, or orchestrator flow.'
  protected_state_mutation_allowed = $false
  candidate_files = @(
    "$candidateRelative/GENESIS_STATE_update_candidate.json",
    "$candidateRelative/CAPABILITY_ROADMAP_update_candidate.json",
    "$candidateRelative/TASK_QUEUE_update_candidate.json",
    "$candidateRelative/packs_registry_update_candidate.json",
    "$candidateRelative/orchestrator_run_update_candidate.md"
  )
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
Write-BuilderJson -Path (Join-Path $candidateRoot 'PHASE161F_PROMOTION_MANIFEST.json') -Value $manifest

$syncPlan = @(
  '# PHASE161F Protected State Sync Plan',
  '',
  'This package proposes synchronization references only. It does not modify protected source-of-truth files.',
  '',
  '## Proposed Synchronization',
  '',
  '- `GENESIS_STATE.json`: add a bounded `protected_self_model_memory` reference to accepted PHASE161E readiness and evidence paths.',
  '- `CAPABILITY_ROADMAP.json`: add a PHASE161E accepted evidence reference without changing existing completion claims.',
  '- `TASK_QUEUE.json`: add a non-active owner review task without changing `active_task_id`.',
  '- `packs/registry.json`: no change recommended because no pack was created.',
  '- `orchestrator/run.ps1`: no change recommended without a separately proven acceptance workflow hook.',
  '',
  '## Do Not Synchronize',
  '',
  '- Full `agent_body_map.json` payloads.',
  '- Validator-only evidence as live evidence.',
  '- Historical or superseded artifacts as active organs.',
  '- Current phase, current task, readiness, route, pack, or orchestrator behavior changes.',
  '',
  '## Later Approved Validation',
  '',
  'Verify exact pre-apply hashes, apply one target at a time, parse JSON, run target consumers and validators, confirm route/task invariants, run PHASE161E refresh, and compare post-apply map evidence.',
  '',
  '## Why Candidate Only',
  '',
  'Protected state owns execution truth. Promotion requires explicit owner approval and a separate apply phase with rollback evidence.'
)
$syncPlan | Set-Content -LiteralPath (Join-Path $candidateRoot 'PHASE161F_PROTECTED_STATE_SYNC_PLAN.md') -Encoding UTF8

$rollbackPlan = @(
  '# PHASE161F Rollback Plan',
  '',
  'PHASE161F performs no protected mutation, so no protected rollback is required now.',
  '',
  'For a future owner-approved apply:',
  '',
  '1. Verify every protected target matches the SHA-256 recorded in its candidate.',
  '2. Save exact byte-for-byte pre-apply copies outside runtime execution paths.',
  '3. Apply one target at a time.',
  '4. Parse and validate immediately after each target.',
  '5. Restore the exact pre-apply copy on any failure.',
  '6. Re-run protected consumers, PHASE161E refresh, and repository safety checks.',
  '7. Do not continue to another target until the current target passes.'
)
$rollbackPlan | Set-Content -LiteralPath (Join-Path $candidateRoot 'PHASE161F_ROLLBACK_PLAN.md') -Encoding UTF8

$riskWriter = Join-Path $PSScriptRoot 'write_builder_protected_self_model_promotion_risk_review_001.ps1'
& $riskWriter -RepoRoot $root -CandidateRoot $candidateRelative | Out-Null

Set-BuilderProperty -Object $activeMap -Name 'protected_state_promotion_candidate_id' -Value $promotionId
Set-BuilderProperty -Object $activeMap -Name 'protected_state_promotion_candidate_status' -Value 'OWNER_REVIEW_REQUIRED'
Set-BuilderProperty -Object $activeMap -Name 'protected_state_direct_mutation_performed' -Value $false
Set-BuilderProperty -Object $activeMap -Name 'protected_state_candidate_manifest_path' -Value "$candidateRelative/PHASE161F_PROMOTION_MANIFEST.json"
Write-BuilderJson -Path (Join-Path $root 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json') -Value $activeMap

$manifest
