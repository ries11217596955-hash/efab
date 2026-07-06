param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputRoot = 'reports/self_development'
)

$builder = Join-Path $PSScriptRoot 'build_builder_agent_body_map_001.ps1'
& $builder -RepoRoot $RepoRoot -OutputRoot $OutputRoot -Build | Out-Null
Get-Content -LiteralPath (Join-Path (Resolve-Path $RepoRoot).Path (Join-Path $OutputRoot 'self_model_gap_chain.json')) -Raw | ConvertFrom-Json
