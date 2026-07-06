param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$candidateRoot = Join-Path $root 'reports/self_development/protected_state_update_candidates'
$result = Get-Content -LiteralPath (Join-Path $candidateRoot 'PHASE161G2_APPLY_RESULT.json') -Raw | ConvertFrom-Json
$post = Get-Content -LiteralPath (Join-Path $candidateRoot 'PHASE161G2_POST_APPLY_HASHES.json') -Raw | ConvertFrom-Json

@(
  '# PHASE161G2 Limited Protected Self-Model Apply Report',
  '',
  ('Apply status: `{0}`' -f $result.apply_status),
  '',
  'Applied only:',
  '',
  '- `GENESIS_STATE.json.protected_self_model_memory`',
  '- `CAPABILITY_ROADMAP.json.phase161e_self_map_auto_refresh`',
  '',
  'Blocked files, route locks, current phase, current capability, and active task remained unchanged.',
  '',
  ('Post-apply protected checks: `{0}`' -f $post.validation_status),
  '',
  'Validator-only evidence was not promoted to live evidence.'
) | Set-Content -LiteralPath (Join-Path $root 'reports/self_development/PHASE161G2_LIMITED_PROTECTED_SELF_MODEL_APPLY_REPORT.md') -Encoding UTF8
