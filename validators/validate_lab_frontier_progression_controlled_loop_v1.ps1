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
$outputDir = Join-Path $root "reports/lab_frontier_progression_controlled_loop_v1_$timestamp"
$modulePath = Join-Path $root 'modules/invoke_lab_frontier_progression_controlled_loop_v1.ps1'
$loopOutputPath = Join-Path $outputDir 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_RESULT.json'
$proofPath = Join-Path $outputDir 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_VALIDATION_PROOF.json'
$reportPath = Join-Path $outputDir 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_VALIDATION_REPORT.md'

if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
  throw "MISSING_LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_MODULE=$modulePath"
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

$loopJson = & $modulePath -RepoRoot $root -Cycles 3 -ReportRoot $outputDir -EmitJson
$loopResult = $loopJson | ConvertFrom-Json
$writtenLoopResult = Read-Json $loopOutputPath
$checks = @()

$cycleRecords = @($loopResult.cycle_records)
$cyclesWithoutClassification = @($cycleRecords | Where-Object { -not [bool]$_.action_classified })
$cyclesWithoutSafeOrBlock = @($cycleRecords | Where-Object { (-not [bool]$_.safe_action_executed) -and (-not [bool]$_.blocked_action) })
$cyclesClaimingCompletion = @($cycleRecords | Where-Object { [bool]$_.self_completion_claimed })
$validClasses = @(
  'READ_ONLY_PROBE',
  'REPORT_ONLY',
  'SAFE_LOCAL_EVIDENCE_ACTION',
  'PROTECTED_MUTATION_REQUIRED',
  'LIVE_PATCH_REQUIRED',
  'UNKNOWN_UNSAFE'
)
$cyclesWithInvalidClass = @($cycleRecords | Where-Object { $validClasses -notcontains [string]$_.action_class })

Add-Check 'controlled_loop_status_pass' ([string]$loopResult.status -eq 'PASS') "status=$($loopResult.status)"
Add-Check 'cycles_run_at_least_3' ([int]$loopResult.cycles_run -ge 3) "cycles_run=$($loopResult.cycles_run)"
Add-Check 'selector_runnable_all_cycles_true' ([bool]$loopResult.selector_runnable_all_cycles -eq $true) "selector_runnable_all_cycles=$($loopResult.selector_runnable_all_cycles)"
Add-Check 'next_action_captured_all_cycles_true' ([bool]$loopResult.next_action_captured_all_cycles -eq $true) "next_action_captured_all_cycles=$($loopResult.next_action_captured_all_cycles)"
Add-Check 'action_classified_all_cycles_true' ([bool]$loopResult.action_classified_all_cycles -eq $true) "action_classified_all_cycles=$($loopResult.action_classified_all_cycles)"
Add-Check 'all_cycle_classes_valid' ($cyclesWithInvalidClass.Count -eq 0) "invalid_class_count=$($cyclesWithInvalidClass.Count)"
Add-Check 'all_cycles_safe_executed_or_blocked' ($cyclesWithoutSafeOrBlock.Count -eq 0) "unaccounted_cycle_count=$($cyclesWithoutSafeOrBlock.Count)"
Add-Check 'safe_plus_blocked_equals_cycles_run' (([int]$loopResult.safe_action_executed_count + [int]$loopResult.blocked_unsafe_action_count) -eq [int]$loopResult.cycles_run) "safe=$($loopResult.safe_action_executed_count); blocked=$($loopResult.blocked_unsafe_action_count); cycles=$($loopResult.cycles_run)"
Add-Check 'loop_continued_after_action_or_block_true' ([bool]$loopResult.loop_continued_after_action_or_block -eq $true) "loop_continued_after_action_or_block=$($loopResult.loop_continued_after_action_or_block)"
Add-Check 'no_cycle_claims_completion' ($cyclesClaimingCompletion.Count -eq 0) "cycle_completion_claims=$($cyclesClaimingCompletion.Count)"
Add-Check 'self_completion_claimed_false' ([bool]$loopResult.self_completion_claimed -eq $false) "self_completion_claimed=$($loopResult.self_completion_claimed)"
Add-Check 'continue_required_true' ([bool]$loopResult.continue_required -eq $true) "continue_required=$($loopResult.continue_required)"
Add-Check 'protected_mutation_persisted_false' ([bool]$loopResult.protected_mutation_persisted -eq $false) "protected_mutation_persisted=$($loopResult.protected_mutation_persisted)"
Add-Check 'worktree_clean_after_true' ([bool]$loopResult.worktree_clean_after -eq $true) "worktree_clean_after=$($loopResult.worktree_clean_after)"
Add-Check 'codex_used_at_runtime_false' ([bool]$loopResult.codex_used_at_runtime -eq $false) "codex_used_at_runtime=$($loopResult.codex_used_at_runtime)"
Add-Check 'commit_done_false' ([bool]$loopResult.commit_done -eq $false) "commit_done=$($loopResult.commit_done)"
Add-Check 'push_done_false' ([bool]$loopResult.push_done -eq $false) "push_done=$($loopResult.push_done)"
Add-Check 'live_patch_done_false' ([bool]$loopResult.live_patch_done -eq $false) "live_patch_done=$($loopResult.live_patch_done)"
Add-Check 'next_status_ready_for_micro_trial' ([string]$loopResult.next_status -eq 'READY_FOR_CONTROLLED_ACTION_EXECUTION_MICRO_TRIAL') "next_status=$($loopResult.next_status)"
Add-Check 'output_json_written_matches_status' ([string]$writtenLoopResult.status -eq [string]$loopResult.status) "output_path=$loopOutputPath"
Add-Check 'no_missing_classification_records' ($cyclesWithoutClassification.Count -eq 0) "missing_classification_count=$($cyclesWithoutClassification.Count)"

$protectedStatusAfter = @(Get-ProtectedStatusRows -Root $root -Paths $protectedPaths)
$protectedMutationPersisted = ($protectedStatusBefore.Count -gt 0 -or $protectedStatusAfter.Count -gt 0)
Add-Check 'protected_status_clean_after_controlled_loop' (-not $protectedMutationPersisted) 'protected exact-path git status clean before and after controlled loop'

$failed = @($checks | Where-Object { [string]$_.status -eq 'FAIL' })
$status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

$proof = [ordered]@{
  schema = 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_VALIDATION_PROOF_V1'
  status = $status
  created_at = (Get-Date).ToString('o')
  repo_root = $root
  controlled_loop_module = $modulePath
  controlled_loop_output_path = $loopOutputPath
  controlled_loop_result = $loopResult
  checks = $checks
  failed_count = $failed.Count
  protected_paths_checked = $protectedPaths
  protected_status_before = @($protectedStatusBefore)
  protected_status_after = @($protectedStatusAfter)
  protected_mutation_persisted = [bool]$protectedMutationPersisted
  worktree_clean_after = [bool]$loopResult.worktree_clean_after
  self_completion_claimed = $false
  continue_required = $true
  codex_used_at_runtime = $false
  commit_done = $false
  push_done = $false
  live_patch_done = $false
  next_status = [string]$loopResult.next_status
}
Write-Json -Path $proofPath -Object $proof

$reportLines = @(
  '# Lab Frontier Progression Controlled Loop V1 Validation',
  '',
  "Status: $status",
  '',
  '## Loop',
  '',
  "- cycles_run: $($loopResult.cycles_run)",
  "- selector_runnable_all_cycles: $($loopResult.selector_runnable_all_cycles)",
  "- next_action_captured_all_cycles: $($loopResult.next_action_captured_all_cycles)",
  "- action_classified_all_cycles: $($loopResult.action_classified_all_cycles)",
  "- safe_action_executed_count: $($loopResult.safe_action_executed_count)",
  "- blocked_unsafe_action_count: $($loopResult.blocked_unsafe_action_count)",
  "- loop_continued_after_action_or_block: $($loopResult.loop_continued_after_action_or_block)",
  '',
  '## Boundary',
  '',
  '- self_completion_claimed: false',
  '- continue_required: true',
  "- protected_mutation_persisted: $protectedMutationPersisted",
  "- worktree_clean_after: $($loopResult.worktree_clean_after)",
  '- codex_used_at_runtime: false',
  '- commit_done: false',
  '- push_done: false',
  '- live_patch_done: false',
  '',
  '## Outputs',
  '',
  "- controlled_loop_result: $loopOutputPath",
  "- validation_proof: $proofPath"
)
Write-Json -Path (Join-Path $outputDir 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_VALIDATION_SUMMARY.json') -Object ([ordered]@{
  status = $status
  cycles_run = [int]$loopResult.cycles_run
  safe_action_executed_count = [int]$loopResult.safe_action_executed_count
  blocked_unsafe_action_count = [int]$loopResult.blocked_unsafe_action_count
  next_status = [string]$loopResult.next_status
})
[System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_STATUS=$status"
Write-Host "CYCLES_RUN=$($loopResult.cycles_run)"
Write-Host "SELECTOR_RUNNABLE_ALL_CYCLES=$(([bool]$loopResult.selector_runnable_all_cycles).ToString().ToLowerInvariant())"
Write-Host "NEXT_ACTION_CAPTURED_ALL_CYCLES=$(([bool]$loopResult.next_action_captured_all_cycles).ToString().ToLowerInvariant())"
Write-Host "ACTION_CLASSIFIED_ALL_CYCLES=$(([bool]$loopResult.action_classified_all_cycles).ToString().ToLowerInvariant())"
Write-Host "LOOP_CONTINUED_AFTER_ACTION_OR_BLOCK=$(([bool]$loopResult.loop_continued_after_action_or_block).ToString().ToLowerInvariant())"
Write-Host 'SELF_COMPLETION_CLAIMED=false'
Write-Host 'CONTINUE_REQUIRED=true'
Write-Host "PROTECTED_MUTATION_PERSISTED=$(([bool]$protectedMutationPersisted).ToString().ToLowerInvariant())"
Write-Host "WORKTREE_CLEAN_AFTER=$(([bool]$loopResult.worktree_clean_after).ToString().ToLowerInvariant())"
Write-Host 'CODEX_USED_AT_RUNTIME=false'
Write-Host 'COMMIT_DONE=false'
Write-Host 'PUSH_DONE=false'
Write-Host 'LIVE_PATCH_DONE=false'
Write-Host "NEXT_STATUS=$($loopResult.next_status)"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "REPORT_PATH=$reportPath"

if ($status -ne 'PASS') {
  exit 1
}
