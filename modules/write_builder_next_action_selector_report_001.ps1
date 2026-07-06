param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputRoot = 'reports/self_development',
  [string]$OutputPath = 'reports/self_development/PHASE161J_NEXT_ACTION_SELECTOR_REPORT.md'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$recommendation = Get-Content (Join-Path $root (Join-Path $OutputRoot 'self_map_next_action_recommendation.json')) -Raw | ConvertFrom-Json
$health = Get-Content (Join-Path $root (Join-Path $OutputRoot 'organism_health_state.json')) -Raw | ConvertFrom-Json
$full = Join-Path $root $OutputPath

@(
  '# PHASE161J Next Action Selector Report',
  '',
  ('Organism health: `{0}` ({1})' -f $health.health_state, $health.health_score),
  '',
  '## Selected Action',
  '',
  $recommendation.recommended_next_macro_step,
  '',
  ('Recommended phase: `{0}`' -f $recommendation.recommended_next_phase_id),
  ('Priority: `{0}`' -f $recommendation.priority_class),
  ('Action type: `{0}`' -f $recommendation.next_action_type),
  ('Score: `{0}`' -f $recommendation.selected_action_score),
  '',
  '## Why',
  '',
  $recommendation.why_this_step,
  '',
  'The completed PHASE161F/G1/G2 protected-state sequence is suppressed as a stale top recommendation. Delayed queue/registry scopes remain delayed, and the rejected orchestrator change remains rejected.'
) | Set-Content -LiteralPath $full -Encoding UTF8

$full
