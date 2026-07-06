param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CandidateRoot = 'reports/self_development/protected_state_update_candidates'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-Compatibility {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Write-JsonFile {
  param([string]$Path, $Value)
  $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$root = (Resolve-Path $RepoRoot).Path
$candidateFull = Join-Path $root $CandidateRoot
$matrix = Get-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G1_CONSUMER_COMPATIBILITY_MATRIX.json') -Raw | ConvertFrom-Json
$simulation = Get-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G1_SIMULATED_APPLY_RESULT.json') -Raw | ConvertFrom-Json
$genesisCandidate = Get-Content -LiteralPath (Join-Path $candidateFull 'GENESIS_STATE_update_candidate.json') -Raw | ConvertFrom-Json
$roadmapCandidate = Get-Content -LiteralPath (Join-Path $candidateFull 'CAPABILITY_ROADMAP_update_candidate.json') -Raw | ConvertFrom-Json

Assert-Compatibility ($simulation.simulation_status -eq 'PASS') 'Simulation did not pass'
Assert-Compatibility ($simulation.protected_files_modified_directly -eq $false) 'Simulation modified protected files'
Assert-Compatibility ($simulation.current_phase_unchanged -eq $true) 'current_phase changed'
Assert-Compatibility ($simulation.roadmap_existing_entries_unchanged -eq $true) 'Existing roadmap entries changed'
Assert-Compatibility ($simulation.validator_only_not_promoted_to_live -eq $true) 'Validator-only evidence was promoted'
Assert-Compatibility ($genesisCandidate.proposed_fields_or_sections.protected_self_model_memory.evidence_boundary -eq 'DERIVED_MAP_REFERENCE_ONLY') 'Genesis evidence boundary is unsafe'
Assert-Compatibility ($roadmapCandidate.proposed_fields_or_sections.phase161e_self_map_auto_refresh.status -eq 'ACCEPTED_EVIDENCE_REFERENCE_CANDIDATE') 'Roadmap status is not cautious'

$genesisCurrent = @($matrix.consumers | Where-Object { $_.target_file -eq 'GENESIS_STATE.json' -and $_.consumer_scope -eq 'CURRENT_EXECUTABLE_CANDIDATE' })
$roadmapCurrent = @($matrix.consumers | Where-Object { $_.target_file -eq 'CAPABILITY_ROADMAP.json' -and $_.consumer_scope -eq 'CURRENT_EXECUTABLE_CANDIDATE' })
$genesisStrict = @($genesisCurrent | Where-Object { $_.strict_schema_risk -eq 'true' }).Count
$roadmapStrict = @($roadmapCurrent | Where-Object { $_.strict_schema_risk -eq 'true' }).Count

$genesisDecision = $(if ($genesisStrict -eq 0) { 'APPROVE_WITH_LIMITS' } else { 'DELAY' })
$roadmapDecision = $(if ($roadmapStrict -eq 0) { 'APPROVE_WITH_LIMITS' } else { 'DELAY' })

@(
  '# PHASE161G1 GENESIS_STATE Compatibility Review',
  '',
  ('Decision: `{0}`' -f $genesisDecision),
  '',
  'The candidate adds only `protected_self_model_memory` as bounded top-level metadata.',
  '',
  "- Current executable references reviewed: $($genesisCurrent.Count)",
  "- Strict extra-field rejection signals: $genesisStrict",
  "- Simulation parse: $($simulation.genesis_simulation_parse_pass)",
  "- Existing fields unchanged: $($simulation.genesis_existing_fields_unchanged)",
  "- current_phase unchanged: $($simulation.current_phase_unchanged)",
  "- current_capability unchanged: $($simulation.current_capability_unchanged)",
  "- evidence boundary preserved: $($simulation.evidence_boundary_preserved)",
  '',
  'Limit: a future apply may add only the candidate object. It must not change existing readiness, status, phase, capability, or live-evidence claims. Unknown historical/reference consumers remain listed in the matrix and are not treated as current compatibility proof.'
) | Set-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G1_GENESIS_STATE_COMPATIBILITY_REVIEW.md') -Encoding UTF8

@(
  '# PHASE161G1 CAPABILITY_ROADMAP Compatibility Review',
  '',
  ('Decision: `{0}`' -f $roadmapDecision),
  '',
  'The candidate adds only `phase161e_self_map_auto_refresh` as a cautious accepted-evidence reference.',
  '',
  "- Current executable references reviewed: $($roadmapCurrent.Count)",
  "- Strict extra-field rejection signals: $roadmapStrict",
  "- Simulation parse: $($simulation.capability_roadmap_simulation_parse_pass)",
  "- Existing roadmap entries unchanged: $($simulation.roadmap_existing_entries_unchanged)",
  "- Candidate status cautious: $($simulation.capability_candidate_status_cautious)",
  "- Protected promotion status cautious: $($simulation.protected_promotion_status_cautious)",
  "- Validator-only evidence not promoted: $($simulation.validator_only_not_promoted_to_live)",
  '',
  'Limit: a future apply may add only this evidence-reference object. It must not modify existing completion claims, capability status, route state, or evidence classifications.'
) | Set-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G1_CAPABILITY_ROADMAP_COMPATIBILITY_REVIEW.md') -Encoding UTF8

$delayed = [pscustomobject][ordered]@{
  review_id = 'PHASE161G1_DELAYED_OR_BLOCKED_SCOPE_V1'
  items = @(
    [pscustomobject]@{ target_file='TASK_QUEUE.json'; decision='DELAY'; reason='Queue content affects scheduling and active-task behavior.'; future_proof_required='Separate queue-consumer, alias, backlog, and active_task_id preservation proof.' },
    [pscustomobject]@{ target_file='packs/registry.json'; decision='DELAY'; reason='No executable pack exists for this capability; registry admission would create false wiring.'; future_proof_required='Real pack artifact and pack admission compatibility proof.' },
    [pscustomobject]@{ target_file='orchestrator/run.ps1'; decision='REJECT'; reason='No orchestrator flow change is justified by the protected metadata candidate.'; future_proof_required='Separately scoped accepted-change hook, failure behavior, and orchestration regression proof.' }
  )
  owner_approval_required = $true
}
Write-JsonFile -Path (Join-Path $candidateFull 'PHASE161G1_DELAYED_OR_BLOCKED_SCOPE.json') -Value $delayed

$recommendation = [pscustomobject][ordered]@{
  recommendation_id = 'PHASE161G1_LIMITED_APPLY_SCOPE_RECOMMENDATION_V1'
  source_candidate_manifest = "$CandidateRoot/PHASE161F_PROMOTION_MANIFEST.json"
  recommended_future_phase = 'PHASE161G2_APPLY_LIMITED_PROTECTED_SELF_MODEL_REFERENCES'
  apply_allowed_now = $false
  decisions = [ordered]@{
    genesis_state = $genesisDecision
    capability_roadmap = $roadmapDecision
    task_queue = 'DELAY'
    packs_registry = 'DELAY'
    orchestrator_run = 'REJECT'
  }
  future_apply_scope = @(
    [pscustomobject]@{ target_file='GENESIS_STATE.json'; section='protected_self_model_memory'; allowed_only_if_decision='APPROVE_WITH_LIMITS' },
    [pscustomobject]@{ target_file='CAPABILITY_ROADMAP.json'; section='phase161e_self_map_auto_refresh'; allowed_only_if_decision='APPROVE_WITH_LIMITS' }
  )
  delayed_scope = @('TASK_QUEUE.json','packs/registry.json','orchestrator/run.ps1')
  explicit_forbidden_changes = @('current_phase','active_task_id','active route lock','pack registry admission','orchestrator flow','validator-only-to-live promotion','full body map copy into protected state')
  required_pre_apply_hashes = [ordered]@{
    'GENESIS_STATE.json' = (Get-FileHash -LiteralPath (Join-Path $root 'GENESIS_STATE.json') -Algorithm SHA256).Hash
    'CAPABILITY_ROADMAP.json' = (Get-FileHash -LiteralPath (Join-Path $root 'CAPABILITY_ROADMAP.json') -Algorithm SHA256).Hash
  }
  required_post_apply_checks = @('JSON parse','existing field equality','current_phase unchanged','existing roadmap entries unchanged','consumer regression checks','PHASE161E self-map refresh','protected diff review')
  rollback_required = $true
  owner_approval_required = $true
}
Write-JsonFile -Path (Join-Path $candidateFull 'PHASE161G1_LIMITED_APPLY_SCOPE_RECOMMENDATION.json') -Value $recommendation

[pscustomobject]@{
  result = 'PASS'
  genesis_state_decision = $genesisDecision
  capability_roadmap_decision = $roadmapDecision
  task_queue_decision = 'DELAY'
  packs_registry_decision = 'DELAY'
  orchestrator_run_decision = 'REJECT'
  simulation_status = $simulation.simulation_status
}
