param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [Parameter(Mandatory=$true)]$PipelineResult,
  [string]$OutputPath = 'reports/self_development/acceptance_pipeline_self_map_refresh_last_run.json'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$full = Join-Path $root $OutputPath
$dir = Split-Path -Parent $full
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
  New-Item -ItemType Directory -Path $dir | Out-Null
}
$PipelineResult | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $full -Encoding UTF8
$PipelineResult
