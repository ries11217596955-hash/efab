param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$TaskKind = '',
  [string]$RequestedCapability = '',
  [string]$ContextHint = '',
  [string]$OutputPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-Json {
  param([string]$Path, [object]$Object)
  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 50) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path $RepoRoot).Path
$selectorModule = Join-Path $root 'modules/resolve_startup_selector_proof_energy_schema_validator_v1.ps1'
if (-not (Test-Path -LiteralPath $selectorModule -PathType Leaf)) {
  throw "MISSING_SELECTOR_MODULE=$selectorModule"
}

$selectorJson = & $selectorModule `
  -RepoRoot $root `
  -TaskKind $TaskKind `
  -RequestedCapability $RequestedCapability `
  -ContextHint $ContextHint

$selector = $selectorJson | ConvertFrom-Json
$selectorMatched = ([string]$selector.status -eq 'SELECTOR_MATCH')

$result = [ordered]@{
  status = if ($selectorMatched) { 'SHADOW_ROUTE_SELECTOR_PASS' } else { 'SHADOW_ROUTE_SELECTOR_NO_MATCH' }
  selector_status = [string]$selector.status
  selected_atom_id = [string]$selector.selected_atom_id
  selected_schema_path = [string]$selector.selected_schema_path
  selected_validator_path = [string]$selector.selected_validator_path
  route_layer = 'lab_shadow'
  protected_mutation_done = $false
  live_patch_done = $false
  codex_used_at_runtime = $false
  next_recommendation = if ($selectorMatched) {
    'Use selected_validator_path for local proof-energy record validation in lab shadow only.'
  } else {
    'No selector match; keep startup route unchanged and do not patch live flow.'
  }
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $OutputPath))
  }
  Write-Json -Path $outputFullPath -Object $result
}

$result | ConvertTo-Json -Depth 50
