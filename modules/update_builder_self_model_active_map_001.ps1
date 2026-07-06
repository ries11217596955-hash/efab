param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputRoot = 'reports/self_development'
)

$builder = Join-Path $PSScriptRoot 'build_builder_agent_body_map_001.ps1'
. $builder
Invoke-BuilderAgentBodyMap001 -RepoRoot $RepoRoot -OutputRoot $OutputRoot -ActiveMapOnly | Out-Null
Get-Content -LiteralPath (Join-Path (Resolve-Path $RepoRoot).Path (Join-Path $OutputRoot 'SELF_MODEL_ACTIVE_MAP.json')) -Raw | ConvertFrom-Json
