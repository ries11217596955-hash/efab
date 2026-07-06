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
  $json = ($Object | ConvertTo-Json -Depth 80) -replace "`r`n", "`n"
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
$outputDir = Join-Path $root "reports/controlled_self_build_loop_gate_v1_$timestamp"
Ensure-Dir $outputDir

$modulePath = Join-Path $root 'modules/invoke_controlled_self_build_loop_gate_v1.ps1'
$gateOutputPath = Join-Path $outputDir 'CONTROLLED_SELF_BUILD_LOOP_GATE_RESULT.json'
$proofPath = Join-Path $outputDir 'CONTROLLED_SELF_BUILD_LOOP_GATE_PROOF.json'
$reportPath = Join-Path $outputDir 'CONTROLLED_SELF_BUILD_LOOP_GATE_REPORT.md'

$protectedPaths = @(
  'packs/registry.json',
  'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  'reports/self_development/accepted_change_memory_snapshot.json',
  'orchestrator/run.ps1'
)
$protectedBefore = Get-HashSnapshot -Root $root -Paths $protectedPaths

$gateJson = & $modulePath -RepoRoot $root -MaxCycles 2 -OutputPath $gateOutputPath
$gateResult = $gateJson | ConvertFrom-Json
$writtenGateResult = Read-Json $gateOutputPath

$schemaFullPath = Join-Path $root ([string]$gateResult.selected_schema_path)
$validatorFullPath = Join-Path $root ([string]$gateResult.selected_validator_path)
$checks = @()

Add-Check 'gate_status_pass' ([string]$gateResult.status -eq 'CONTROLLED_SELF_BUILD_LOOP_GATE_PASS') "status=$($gateResult.status)"
Add-Check 'cycles_executed_at_least_2' ([int]$gateResult.cycles_executed -ge 2) "cycles_executed=$($gateResult.cycles_executed)"
Add-Check 'checkpoints_created_at_least_2' ([int]$gateResult.checkpoints_created -ge 2) "checkpoints_created=$($gateResult.checkpoints_created)"
Add-Check 'selector_route_status_pass' ([string]$gateResult.selector_route_status -eq 'SHADOW_ROUTE_SELECTOR_PASS') "selector_route_status=$($gateResult.selector_route_status)"
Add-Check 'selected_schema_path_exists' (Test-Path -LiteralPath $schemaFullPath -PathType Leaf) ([string]$gateResult.selected_schema_path)
Add-Check 'selected_validator_path_exists' (Test-Path -LiteralPath $validatorFullPath -PathType Leaf) ([string]$gateResult.selected_validator_path)
Add-Check 'next_action_selected_not_empty' (-not [string]::IsNullOrWhiteSpace([string]$gateResult.next_action_selected)) "next_action_selected=$($gateResult.next_action_selected)"
Add-Check 'self_completion_claimed_false' ([bool]$gateResult.self_completion_claimed -eq $false) "self_completion_claimed=$($gateResult.self_completion_claimed)"
Add-Check 'continue_required_true' ([bool]$gateResult.continue_required -eq $true) "continue_required=$($gateResult.continue_required)"
Add-Check 'protected_mutation_done_false' ([bool]$gateResult.protected_mutation_done -eq $false) "protected_mutation_done=$($gateResult.protected_mutation_done)"
Add-Check 'live_patch_done_false' ([bool]$gateResult.live_patch_done -eq $false) "live_patch_done=$($gateResult.live_patch_done)"
Add-Check 'codex_used_at_runtime_false' ([bool]$gateResult.codex_used_at_runtime -eq $false) "codex_used_at_runtime=$($gateResult.codex_used_at_runtime)"
Add-Check 'commit_done_false' ([bool]$gateResult.commit_done -eq $false) "commit_done=$($gateResult.commit_done)"
Add-Check 'push_done_false' ([bool]$gateResult.push_done -eq $false) "push_done=$($gateResult.push_done)"
Add-Check 'output_json_written_matches_status' ([string]$writtenGateResult.status -eq [string]$gateResult.status) "output_path=$gateOutputPath"

$protectedAfter = Get-HashSnapshot -Root $root -Paths $protectedPaths
$protectedMutationDone = -not (Test-SnapshotUnchanged -Before $protectedBefore -After $protectedAfter -Paths $protectedPaths)
Add-Check 'protected_files_unchanged' (-not $protectedMutationDone) 'registry, self-map, accepted-memory, and orchestrator hashes unchanged'

$failed = @($checks | Where-Object { [string]$_.status -eq 'FAIL' })
$status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

$proof = [ordered]@{
  schema = 'CONTROLLED_SELF_BUILD_LOOP_GATE_PROOF_V1'
  status = $status
  created_at = (Get-Date).ToString('o')
  repo_root = $root
  loop_gate_module = $modulePath
  loop_gate_output_path = $gateOutputPath
  loop_gate_result = $gateResult
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
  '# Controlled Self-Build Loop Gate V1',
  '',
  "Status: $status",
  '',
  '## Loop Gate',
  '',
  "- loop_mode: $($gateResult.loop_mode)",
  "- cycles_requested: $($gateResult.cycles_requested)",
  "- cycles_executed: $($gateResult.cycles_executed)",
  "- checkpoints_created: $($gateResult.checkpoints_created)",
  "- selector_route_status: $($gateResult.selector_route_status)",
  "- selected_atom_id: $($gateResult.selected_atom_id)",
  "- selected_schema_path: $($gateResult.selected_schema_path)",
  "- selected_validator_path: $($gateResult.selected_validator_path)",
  "- next_action_selected: $($gateResult.next_action_selected)",
  '',
  '## Boundary',
  '',
  '- self_completion_claimed: false',
  '- continue_required: true',
  '- protected_mutation_done: false',
  '- live_patch_done: false',
  '- codex_used_at_runtime: false',
  '- commit_done: false',
  '- push_done: false',
  '',
  '## Outputs',
  '',
  "- proof: $proofPath",
  "- loop_gate_result: $gateOutputPath"
)
[System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "CONTROLLED_SELF_BUILD_LOOP_GATE_STATUS=$status"
Write-Host 'SELF_COMPLETION_CLAIMED=false'
Write-Host 'CONTINUE_REQUIRED=true'
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
