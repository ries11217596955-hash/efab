param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CandidateRoot = 'reports/self_development/protected_state_update_candidates'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$candidateFull = Join-Path $root $CandidateRoot
if (-not (Test-Path -LiteralPath $candidateFull)) {
  New-Item -ItemType Directory -Path $candidateFull | Out-Null
}

$candidateNames = @(
  'GENESIS_STATE_update_candidate.json',
  'CAPABILITY_ROADMAP_update_candidate.json',
  'TASK_QUEUE_update_candidate.json',
  'packs_registry_update_candidate.json'
)
$parsed = @()
foreach ($name in $candidateNames) {
  $path = Join-Path $candidateFull $name
  if (-not (Test-Path -LiteralPath $path)) { throw "Candidate missing: $name" }
  $parsed += Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

$review = [pscustomobject][ordered]@{
  risk_id = 'PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_RISK_REVIEW_V1'
  protected_files_read = @(
    'TASK_QUEUE.json',
    'GENESIS_STATE.json',
    'CAPABILITY_ROADMAP.json',
    'packs/registry.json',
    'orchestrator/run.ps1'
  )
  protected_files_modified_directly = $false
  proposed_changes_count = @($parsed | Where-Object { $_.proposed_update_type -ne 'NO_CHANGE_RECOMMENDED' }).Count
  high_risk_items = @(
    [pscustomobject]@{
      item = 'Directly changing current phase, active task, readiness claims, pack admissions, or orchestrator flow'
      disposition = 'REJECTED_IN_PHASE161F'
      why = 'These fields control execution and require owner approval plus target-specific compatibility validation.'
    }
  )
  medium_risk_items = @(
    [pscustomobject]@{
      item = 'Adding a new protected self-model metadata section'
      mitigation = 'Use a namespaced bounded object and validate all existing consumers before apply.'
    },
    [pscustomobject]@{
      item = 'Adding a queue review item'
      mitigation = 'Do not change active_task_id; apply only after queue schema and alias compatibility validation.'
    }
  )
  low_risk_items = @(
    [pscustomobject]@{
      item = 'Keeping owner-review candidate files under reports/self_development/protected_state_update_candidates'
      mitigation = 'Candidates are inert and do not affect runtime flow.'
    }
  )
  rejected_changes = @(
    'No direct orchestrator change.',
    'No automatic pack registry entry.',
    'No current_phase or current_capability overwrite.',
    'No active_task_id overwrite.',
    'No promotion of validator-only evidence to live evidence.',
    'No bulk copy of agent_body_map.json into protected state.'
  )
  safety_recommendation = 'OWNER_REVIEW_REQUIRED. If approved later, apply one protected target at a time with exact pre-apply hashes, schema/consumer checks, rollback copies, and post-apply self-map refresh.'
  owner_approval_required = $true
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}

$path = Join-Path $candidateFull 'PHASE161F_RISK_REVIEW.json'
$review | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding UTF8
$review
