param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if ($Path -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
  param([string]$Path, [object]$Object)
  Ensure-Dir (Split-Path -Parent $Path)
  $json = ($Object | ConvertTo-Json -Depth 60) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-HashSnapshot {
  param([string]$Root, [string[]]$Paths)
  $snapshot = [ordered]@{}
  foreach ($rel in $Paths) {
    $full = Join-Path $Root $rel
    if (Test-Path -LiteralPath $full -PathType Leaf) {
      $snapshot[$rel] = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    } else {
      $snapshot[$rel] = 'ABSENT'
    }
  }
  return $snapshot
}

function Test-SnapshotUnchanged {
  param($Before, $After, [string[]]$Paths)
  foreach ($rel in $Paths) {
    if ([string]$Before[$rel] -ne [string]$After[$rel]) { return $false }
  }
  return $true
}

function Add-Check {
  param([string]$Name, [bool]$Pass, [string]$Detail)
  $script:checks += [ordered]@{
    name = $Name
    status = if ($Pass) { 'PASS' } else { 'FAIL' }
    detail = $Detail
  }
}

$root = (Resolve-Path $RepoRoot).Path
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outputDir = Join-Path $root "reports/startup_selector_shadow_route_v1_$timestamp"
Ensure-Dir $outputDir

$modulePath = Join-Path $root 'modules/invoke_startup_selector_shadow_route_v1.ps1'
$routeOutputPath = Join-Path $outputDir 'STARTUP_SELECTOR_SHADOW_ROUTE_RESULT.json'
$proofPath = Join-Path $outputDir 'STARTUP_SELECTOR_SHADOW_ROUTE_PROOF.json'
$reportPath = Join-Path $outputDir 'STARTUP_SELECTOR_SHADOW_ROUTE_REPORT.md'

$protectedPaths = @(
  'packs/registry.json',
  'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  'reports/self_development/accepted_change_memory_snapshot.json'
)
$protectedBefore = Get-HashSnapshot -Root $root -Paths $protectedPaths

$routeJson = & $modulePath `
  -RepoRoot $root `
  -TaskKind 'proof_energy_record_validation' `
  -RequestedCapability 'validate_law_kernel_matrix_cell_proof_energy_record' `
  -ContextHint 'law_kernel_matrix_cell' `
  -OutputPath $routeOutputPath

$routeResult = $routeJson | ConvertFrom-Json
$writtenRouteResult = Read-Json $routeOutputPath

$schemaFullPath = Join-Path $root ([string]$routeResult.selected_schema_path)
$validatorFullPath = Join-Path $root ([string]$routeResult.selected_validator_path)
$checks = @()

Add-Check 'shadow_route_status_pass' ([string]$routeResult.status -eq 'SHADOW_ROUTE_SELECTOR_PASS') "status=$($routeResult.status)"
Add-Check 'selector_status_match' ([string]$routeResult.selector_status -eq 'SELECTOR_MATCH') "selector_status=$($routeResult.selector_status)"
Add-Check 'schema_path_exists' (Test-Path -LiteralPath $schemaFullPath -PathType Leaf) ([string]$routeResult.selected_schema_path)
Add-Check 'validator_path_exists' (Test-Path -LiteralPath $validatorFullPath -PathType Leaf) ([string]$routeResult.selected_validator_path)
Add-Check 'protected_mutation_done_false' ([bool]$routeResult.protected_mutation_done -eq $false) "protected_mutation_done=$($routeResult.protected_mutation_done)"
Add-Check 'live_patch_done_false' ([bool]$routeResult.live_patch_done -eq $false) "live_patch_done=$($routeResult.live_patch_done)"
Add-Check 'codex_used_at_runtime_false' ([bool]$routeResult.codex_used_at_runtime -eq $false) "codex_used_at_runtime=$($routeResult.codex_used_at_runtime)"
Add-Check 'route_layer_lab_shadow' ([string]$routeResult.route_layer -eq 'lab_shadow') "route_layer=$($routeResult.route_layer)"
Add-Check 'output_json_written_matches_status' ([string]$writtenRouteResult.status -eq [string]$routeResult.status) "output_path=$routeOutputPath"

$protectedAfter = Get-HashSnapshot -Root $root -Paths $protectedPaths
$protectedMutationDone = -not (Test-SnapshotUnchanged -Before $protectedBefore -After $protectedAfter -Paths $protectedPaths)
Add-Check 'protected_files_unchanged' (-not $protectedMutationDone) 'registry, self-map, and accepted-memory hashes unchanged'

$failed = @($checks | Where-Object { [string]$_.status -eq 'FAIL' })
$status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

$proof = [ordered]@{
  schema = 'STARTUP_SELECTOR_SHADOW_ROUTE_PROOF_V1'
  status = $status
  created_at = (Get-Date).ToString('o')
  repo_root = $root
  shadow_route_module = $modulePath
  shadow_route_output_path = $routeOutputPath
  shadow_route_result = $routeResult
  checks = $checks
  failed_count = $failed.Count
  protected_paths_checked = $protectedPaths
  protected_hashes_before = $protectedBefore
  protected_hashes_after = $protectedAfter
  protected_mutation_done = [bool]$protectedMutationDone
  live_patch_done = $false
  codex_used_at_runtime = $false
  commit_done = $false
  push_done = $false
}
Write-Json -Path $proofPath -Object $proof

$reportLines = @(
  '# Startup Selector Shadow Route Smoke',
  '',
  "Status: $status",
  '',
  '## Shadow Route',
  '',
  "- route_layer: $($routeResult.route_layer)",
  "- route_status: $($routeResult.status)",
  "- selector_status: $($routeResult.selector_status)",
  "- selected_atom_id: $($routeResult.selected_atom_id)",
  "- selected_schema_path: $($routeResult.selected_schema_path)",
  "- selected_validator_path: $($routeResult.selected_validator_path)",
  '',
  '## Boundary',
  '',
  '- protected_mutation_done: false',
  '- live_patch_done: false',
  '- codex_used_at_runtime: false',
  '- commit_done: false',
  '- push_done: false',
  '',
  '## Outputs',
  '',
  "- proof: $proofPath",
  "- shadow_route_result: $routeOutputPath"
)
[System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "STARTUP_SELECTOR_SHADOW_ROUTE_STATUS=$status"
Write-Host "PROTECTED_MUTATION_DONE=$(([bool]$protectedMutationDone).ToString().ToLowerInvariant())"
Write-Host 'LIVE_PATCH_DONE=false'
Write-Host 'CODEX_USED_AT_RUNTIME=false'
Write-Host 'COMMIT_DONE=false'
Write-Host 'PUSH_DONE=false'
Write-Host "PROOF_PATH=$proofPath"
Write-Host "REPORT_PATH=$reportPath"

if ($status -ne 'PASS') {
  exit 1
}
