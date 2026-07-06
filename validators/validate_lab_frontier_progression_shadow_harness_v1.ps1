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

function Get-ProtectedStatusRows {
  param([string]$Root, [string[]]$Paths)
  $lines = @(& git -C $Root status --porcelain -- $Paths)
  $rows = @()
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $status = $line.Substring(0, [Math]::Min(2, $line.Length))
    $path = if ($line.Length -gt 3) { $line.Substring(3) } else { '' }
    $rows += [pscustomobject][ordered]@{
      status = $status
      path = $path
      raw = $line
    }
  }
  return @($rows)
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
$outputDir = Join-Path $root "reports/lab_frontier_progression_shadow_harness_v1_$timestamp"

$modulePath = Join-Path $root 'modules/invoke_lab_frontier_progression_shadow_harness_v1.ps1'
$harnessOutputPath = Join-Path $outputDir 'LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_RESULT.json'
$proofPath = Join-Path $outputDir 'LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_VALIDATION_PROOF.json'
$reportPath = Join-Path $outputDir 'LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_VALIDATION_REPORT.md'

if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
  throw "MISSING_LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_MODULE=$modulePath"
}

$protectedPaths = @(
  'packs/registry.json',
  'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  'reports/self_development/accepted_change_memory_snapshot.json',
  'TASK_QUEUE.json',
  'CAPABILITY_ROADMAP.json',
  'GENESIS_STATE.json',
  'orchestrator/run.ps1'
)
$protectedStatusBefore = @(Get-ProtectedStatusRows -Root $root -Paths $protectedPaths)

$harnessJson = & $modulePath -RepoRoot $root -Cycles 3 -ReportRoot $outputDir -EmitJson
$harnessResult = $harnessJson | ConvertFrom-Json
$writtenHarnessResult = Read-Json $harnessOutputPath
$checks = @()

$stableReason = [string]$harnessResult.repeated_next_action_reason
$stableReasonProvesPendingFrontier = (
  [bool]$harnessResult.repeated_next_action_allowed_with_reason -and
  $stableReason -match 'STABLE_FRONTIER_PENDING' -and
  $stableReason -match 'selector state is unchanged' -and
  $stableReason -match 'shadow-only' -and
  $stableReason -match 'does not execute the recommendation' -and
  [bool]$harnessResult.self_completion_claimed -eq $false -and
  [bool]$harnessResult.continue_required -eq $true
)
$frontierConditionPass = ([int]$harnessResult.unique_next_action_count -gt 1 -or $stableReasonProvesPendingFrontier)

Add-Check 'harness_status_pass' ([string]$harnessResult.status -eq 'PASS') "status=$($harnessResult.status)"
Add-Check 'cycles_run_at_least_3' ([int]$harnessResult.cycles_run -ge 3) "cycles_run=$($harnessResult.cycles_run)"
Add-Check 'selector_runnable_all_cycles_true' ([bool]$harnessResult.selector_runnable_all_cycles -eq $true) "selector_runnable_all_cycles=$($harnessResult.selector_runnable_all_cycles)"
Add-Check 'next_action_captured_all_cycles_true' ([bool]$harnessResult.next_action_captured_all_cycles -eq $true) "next_action_captured_all_cycles=$($harnessResult.next_action_captured_all_cycles)"
Add-Check 'protected_mutation_persisted_false' ([bool]$harnessResult.protected_mutation_persisted -eq $false) "protected_mutation_persisted=$($harnessResult.protected_mutation_persisted)"
Add-Check 'worktree_clean_after_true' ([bool]$harnessResult.worktree_clean_after -eq $true) "worktree_clean_after=$($harnessResult.worktree_clean_after)"
Add-Check 'self_completion_claimed_false' ([bool]$harnessResult.self_completion_claimed -eq $false) "self_completion_claimed=$($harnessResult.self_completion_claimed)"
Add-Check 'continue_required_true' ([bool]$harnessResult.continue_required -eq $true) "continue_required=$($harnessResult.continue_required)"
Add-Check 'codex_used_at_runtime_false' ([bool]$harnessResult.codex_used_at_runtime -eq $false) "codex_used_at_runtime=$($harnessResult.codex_used_at_runtime)"
Add-Check 'commit_done_false' ([bool]$harnessResult.commit_done -eq $false) "commit_done=$($harnessResult.commit_done)"
Add-Check 'push_done_false' ([bool]$harnessResult.push_done -eq $false) "push_done=$($harnessResult.push_done)"
Add-Check 'live_patch_done_false' ([bool]$harnessResult.live_patch_done -eq $false) "live_patch_done=$($harnessResult.live_patch_done)"
Add-Check 'frontier_progression_or_stable_pending_frontier' $frontierConditionPass "unique_next_action_count=$($harnessResult.unique_next_action_count); repeated_next_action_allowed_with_reason=$($harnessResult.repeated_next_action_allowed_with_reason)"
Add-Check 'no_selected_actions_executed' ([bool]$harnessResult.selected_actions_executed -eq $false) "selected_actions_executed=$($harnessResult.selected_actions_executed)"
Add-Check 'next_status_ready_to_promote' ([string]$harnessResult.next_status -eq 'READY_TO_PROMOTE_FRONTIER_PROGRESSION_SHADOW_TO_CONTROLLED_LOOP') "next_status=$($harnessResult.next_status)"
Add-Check 'output_json_written_matches_status' ([string]$writtenHarnessResult.status -eq [string]$harnessResult.status) "output_path=$harnessOutputPath"

$protectedStatusAfter = @(Get-ProtectedStatusRows -Root $root -Paths $protectedPaths)
$protectedMutationPersisted = ($protectedStatusBefore.Count -gt 0 -or $protectedStatusAfter.Count -gt 0)
Add-Check 'protected_status_clean_after_harness' (-not $protectedMutationPersisted) 'protected exact-path git status clean before and after shadow harness'

$failed = @($checks | Where-Object { [string]$_.status -eq 'FAIL' })
$status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

$proof = [ordered]@{
  schema = 'LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_VALIDATION_PROOF_V1'
  status = $status
  created_at = (Get-Date).ToString('o')
  repo_root = $root
  harness_module = $modulePath
  harness_output_path = $harnessOutputPath
  harness_result = $harnessResult
  checks = $checks
  failed_count = $failed.Count
  protected_paths_checked = $protectedPaths
  protected_status_before = @($protectedStatusBefore)
  protected_status_after = @($protectedStatusAfter)
  protected_mutation_persisted = [bool]$protectedMutationPersisted
  worktree_clean_after = [bool]$harnessResult.worktree_clean_after
  self_completion_claimed = $false
  continue_required = $true
  codex_used_at_runtime = $false
  commit_done = $false
  push_done = $false
  live_patch_done = $false
  next_status = [string]$harnessResult.next_status
}
Write-Json -Path $proofPath -Object $proof

$reportLines = @(
  '# Lab Frontier Progression Shadow Harness V1 Validation',
  '',
  "Status: $status",
  '',
  '## Harness',
  '',
  "- cycles_run: $($harnessResult.cycles_run)",
  "- selector_runnable_all_cycles: $($harnessResult.selector_runnable_all_cycles)",
  "- next_action_captured_all_cycles: $($harnessResult.next_action_captured_all_cycles)",
  "- unique_next_action_count: $($harnessResult.unique_next_action_count)",
  "- frontier_progression_observed: $($harnessResult.frontier_progression_observed)",
  "- repeated_next_action_allowed_with_reason: $($harnessResult.repeated_next_action_allowed_with_reason)",
  '',
  '## Boundary',
  '',
  '- self_completion_claimed: false',
  '- continue_required: true',
  "- protected_mutation_persisted: $protectedMutationPersisted",
  "- worktree_clean_after: $($harnessResult.worktree_clean_after)",
  '- codex_used_at_runtime: false',
  '- commit_done: false',
  '- push_done: false',
  '- live_patch_done: false',
  '',
  '## Outputs',
  '',
  "- harness_result: $harnessOutputPath",
  "- validation_proof: $proofPath"
)
Write-Json -Path (Join-Path $outputDir 'LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_VALIDATION_SUMMARY.json') -Object ([ordered]@{
  status = $status
  cycles_run = [int]$harnessResult.cycles_run
  frontier_progression_observed = [bool]$harnessResult.frontier_progression_observed
  repeated_next_action_allowed_with_reason = [bool]$harnessResult.repeated_next_action_allowed_with_reason
  next_status = [string]$harnessResult.next_status
})
[System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_STATUS=$status"
Write-Host "CYCLES_RUN=$($harnessResult.cycles_run)"
Write-Host "SELECTOR_RUNNABLE_ALL_CYCLES=$(([bool]$harnessResult.selector_runnable_all_cycles).ToString().ToLowerInvariant())"
Write-Host "NEXT_ACTION_CAPTURED_ALL_CYCLES=$(([bool]$harnessResult.next_action_captured_all_cycles).ToString().ToLowerInvariant())"
Write-Host "FRONTIER_PROGRESSION_OBSERVED=$(([bool]$harnessResult.frontier_progression_observed).ToString().ToLowerInvariant())"
Write-Host "REPEATED_NEXT_ACTION_ALLOWED_WITH_REASON=$(([bool]$harnessResult.repeated_next_action_allowed_with_reason).ToString().ToLowerInvariant())"
Write-Host 'SELF_COMPLETION_CLAIMED=false'
Write-Host 'CONTINUE_REQUIRED=true'
Write-Host "PROTECTED_MUTATION_PERSISTED=$(([bool]$protectedMutationPersisted).ToString().ToLowerInvariant())"
Write-Host "WORKTREE_CLEAN_AFTER=$(([bool]$harnessResult.worktree_clean_after).ToString().ToLowerInvariant())"
Write-Host 'CODEX_USED_AT_RUNTIME=false'
Write-Host 'COMMIT_DONE=false'
Write-Host 'PUSH_DONE=false'
Write-Host 'LIVE_PATCH_DONE=false'
Write-Host "NEXT_STATUS=$($harnessResult.next_status)"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "REPORT_PATH=$reportPath"

if ($status -ne 'PASS') {
  exit 1
}
