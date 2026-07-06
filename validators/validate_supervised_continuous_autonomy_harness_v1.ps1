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
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
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
$outputDir = Join-Path $root "reports/supervised_continuous_autonomy_harness_v1_$timestamp"
Ensure-Dir $outputDir

$modulePath = Join-Path $root 'modules/invoke_supervised_continuous_autonomy_harness_v1.ps1'
$harnessOutputPath = Join-Path $outputDir 'SUPERVISED_CONTINUOUS_AUTONOMY_HARNESS_RESULT.json'
$proofPath = Join-Path $outputDir 'SUPERVISED_CONTINUOUS_AUTONOMY_HARNESS_PROOF.json'
$reportPath = Join-Path $outputDir 'SUPERVISED_CONTINUOUS_AUTONOMY_HARNESS_REPORT.md'

$protectedPaths = @(
  'packs/registry.json',
  'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  'reports/self_development/accepted_change_memory_snapshot.json',
  'orchestrator/run.ps1'
)
$protectedBefore = Get-HashSnapshot -Root $root -Paths $protectedPaths

$harnessJson = & $modulePath -RepoRoot $root -MaxOuterCycles 3 -InnerMaxCycles 2 -OutputPath $harnessOutputPath
$harnessResult = $harnessJson | ConvertFrom-Json
$writtenHarnessResult = Read-Json $harnessOutputPath
$checks = @()

$cycleRecords = @($harnessResult.cycle_records)
$recordsWithNoNextAction = @($cycleRecords | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.next_action_selected) })
$recordsClaimingCompletion = @($cycleRecords | Where-Object { [bool]$_.self_completion_claimed })

Add-Check 'harness_status_pass' ([string]$harnessResult.status -eq 'SUPERVISED_CONTINUOUS_AUTONOMY_HARNESS_PASS') "status=$($harnessResult.status)"
Add-Check 'outer_cycles_executed_3' ([int]$harnessResult.outer_cycles_executed -eq 3) "outer_cycles_executed=$($harnessResult.outer_cycles_executed)"
Add-Check 'total_inner_cycles_observed_at_least_6' ([int]$harnessResult.total_inner_cycles_observed -ge 6) "total_inner_cycles_observed=$($harnessResult.total_inner_cycles_observed)"
Add-Check 'leash_limit_reached_true' ([bool]$harnessResult.leash_limit_reached -eq $true) "leash_limit_reached=$($harnessResult.leash_limit_reached)"
Add-Check 'normal_stop_reason_leash_limit_reached' ([string]$harnessResult.normal_stop_reason -eq 'LEASH_LIMIT_REACHED') "normal_stop_reason=$($harnessResult.normal_stop_reason)"
Add-Check 'self_completion_claimed_false' ([bool]$harnessResult.self_completion_claimed -eq $false) "self_completion_claimed=$($harnessResult.self_completion_claimed)"
Add-Check 'continue_required_true' ([bool]$harnessResult.continue_required -eq $true) "continue_required=$($harnessResult.continue_required)"
Add-Check 'protected_mutation_done_false' ([bool]$harnessResult.protected_mutation_done -eq $false) "protected_mutation_done=$($harnessResult.protected_mutation_done)"
Add-Check 'live_patch_done_false' ([bool]$harnessResult.live_patch_done -eq $false) "live_patch_done=$($harnessResult.live_patch_done)"
Add-Check 'codex_used_at_runtime_false' ([bool]$harnessResult.codex_used_at_runtime -eq $false) "codex_used_at_runtime=$($harnessResult.codex_used_at_runtime)"
Add-Check 'every_cycle_record_has_next_action' ($recordsWithNoNextAction.Count -eq 0) "missing_next_action_count=$($recordsWithNoNextAction.Count)"
Add-Check 'no_cycle_record_claims_completion' ($recordsClaimingCompletion.Count -eq 0) "completion_claim_count=$($recordsClaimingCompletion.Count)"
Add-Check 'commit_done_false' ([bool]$harnessResult.commit_done -eq $false) "commit_done=$($harnessResult.commit_done)"
Add-Check 'push_done_false' ([bool]$harnessResult.push_done -eq $false) "push_done=$($harnessResult.push_done)"
Add-Check 'output_json_written_matches_status' ([string]$writtenHarnessResult.status -eq [string]$harnessResult.status) "output_path=$harnessOutputPath"

$protectedAfter = Get-HashSnapshot -Root $root -Paths $protectedPaths
$protectedMutationDone = -not (Test-SnapshotUnchanged -Before $protectedBefore -After $protectedAfter -Paths $protectedPaths)
Add-Check 'protected_files_unchanged' (-not $protectedMutationDone) 'registry, self-map, accepted-memory, and orchestrator hashes unchanged'

$failed = @($checks | Where-Object { [string]$_.status -eq 'FAIL' })
$status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

$proof = [ordered]@{
  schema = 'SUPERVISED_CONTINUOUS_AUTONOMY_HARNESS_PROOF_V1'
  status = $status
  created_at = (Get-Date).ToString('o')
  repo_root = $root
  harness_module = $modulePath
  harness_output_path = $harnessOutputPath
  harness_result = $harnessResult
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
  '# Supervised Continuous Autonomy Harness V1',
  '',
  "Status: $status",
  '',
  '## Harness',
  '',
  "- harness_mode: $($harnessResult.harness_mode)",
  "- outer_cycles_executed: $($harnessResult.outer_cycles_executed)",
  "- inner_max_cycles: $($harnessResult.inner_max_cycles)",
  "- total_inner_cycles_observed: $($harnessResult.total_inner_cycles_observed)",
  "- leash_limit_reached: $($harnessResult.leash_limit_reached)",
  "- normal_stop_reason: $($harnessResult.normal_stop_reason)",
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
  "- harness_result: $harnessOutputPath"
)
[System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "SUPERVISED_CONTINUOUS_AUTONOMY_HARNESS_STATUS=$status"
Write-Host "OUTER_CYCLES_EXECUTED=$($harnessResult.outer_cycles_executed)"
Write-Host "TOTAL_INNER_CYCLES_OBSERVED>=$($harnessResult.total_inner_cycles_observed)"
Write-Host "LEASH_LIMIT_REACHED=$(([bool]$harnessResult.leash_limit_reached).ToString().ToLowerInvariant())"
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
