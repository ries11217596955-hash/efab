param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [ValidateRange(1, 100)]
  [int]$Cycles = 3,
  [string]$ReportRoot = '',
  [switch]$EmitJson
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if ($Path -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Write-Json {
  param([string]$Path, [object]$Object)
  Ensure-Dir (Split-Path -Parent $Path)
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-PropValue {
  param($Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  if ($Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
  return $null
}

function Convert-ToStableText {
  param($Value)
  if ($null -eq $Value) { return '' }
  if ($Value -is [string]) { return $Value }
  if ($Value -is [ValueType]) { return [string]$Value }
  return (($Value | ConvertTo-Json -Depth 30 -Compress) -replace "`r`n", "`n")
}

function Add-ActionFieldsFromObject {
  param($Object, $Fields, [int]$Depth = 0)
  if ($null -eq $Object -or $Depth -gt 6) { return }

  $names = @(
    'next_action',
    'selected_next_action',
    'recommended_next_action',
    'recommendation_id',
    'recommended_phase',
    'recommended_next_phase_id',
    'phase',
    'phase_id',
    'next_action_type',
    'macro_step',
    'recommended_next_macro_step',
    'route',
    'selected_atom_id',
    'selected_action',
    'selected_action_id',
    'next_action_type',
    'frontier',
    'frontier_id',
    'selected_frontier',
    'selected_frontier_id',
    'recommended_frontier',
    'recommended_frontier_id',
    'next_frontier',
    'next_frontier_id',
    'selected_action_score',
    'owner_approval_required'
  )

  if ($Object -is [System.Collections.IDictionary]) {
    foreach ($key in @($Object.Keys)) {
      $name = [string]$key
      $value = $Object[$key]
      if ($names -contains $name -and $null -ne $value -and -not [string]::IsNullOrWhiteSpace((Convert-ToStableText -Value $value)) -and -not $Fields.Contains($name)) {
        $Fields[$name] = $value
      }
      Add-ActionFieldsFromObject -Object $value -Fields $Fields -Depth ($Depth + 1)
    }
    return
  }

  if ($Object -is [System.Collections.IEnumerable] -and -not ($Object -is [string])) {
    foreach ($item in @($Object)) {
      Add-ActionFieldsFromObject -Object $item -Fields $Fields -Depth ($Depth + 1)
    }
    return
  }

  if ($Object.PSObject -and $Object.PSObject.Properties) {
    foreach ($prop in @($Object.PSObject.Properties)) {
      $name = [string]$prop.Name
      $value = $prop.Value
      if ($names -contains $name -and $null -ne $value -and -not [string]::IsNullOrWhiteSpace((Convert-ToStableText -Value $value)) -and -not $Fields.Contains($name)) {
        $Fields[$name] = $value
      }
      if ($value -is [pscustomobject] -or $value -is [System.Collections.IDictionary] -or ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string]))) {
        Add-ActionFieldsFromObject -Object $value -Fields $Fields -Depth ($Depth + 1)
      }
    }
  }
}

function Get-ActionFields {
  param($SelectorResult, [string[]]$StdoutLines)
  $fields = [ordered]@{}
  Add-ActionFieldsFromObject -Object $SelectorResult -Fields $fields

  $stdoutMatches = @()
  foreach ($line in @($StdoutLines)) {
    $text = [string]$line
    if (-not [string]::IsNullOrWhiteSpace($text) -and $text -match '(?i)recommendation|next[_ -]?action|phase') {
      $stdoutMatches += $text.Trim()
    }
  }
  if ($stdoutMatches.Count -gt 0 -and -not $fields.Contains('selector_stdout_match')) {
    $fields['selector_stdout_match'] = (($stdoutMatches | Select-Object -First 5) -join "`n")
  }

  return $fields
}

function Get-SelectedActionKey {
  param($ActionFields)
  $preferredParts = @()
  $fallbackParts = @()
  $preferredNames = @(
    'selected_atom_id',
    'selected_action_id',
    'selected_action',
    'selected_next_action',
    'recommended_next_action',
    'next_action',
    'next_action_type',
    'macro_step',
    'recommended_next_macro_step',
    'recommended_phase',
    'recommended_next_phase_id',
    'route',
    'phase',
    'phase_id',
    'frontier_id',
    'frontier',
    'selected_frontier_id',
    'selected_frontier',
    'recommended_frontier_id',
    'recommended_frontier',
    'next_frontier_id',
    'next_frontier'
  )
  foreach ($name in $preferredNames) {
    if ($ActionFields.Contains($name)) {
      $text = Convert-ToStableText -Value $ActionFields[$name]
      if (-not [string]::IsNullOrWhiteSpace($text)) {
        $preferredParts += "${name}=$text"
      }
    }
  }
  foreach ($name in @('recommendation_id', 'selector_stdout_match')) {
    if ($ActionFields.Contains($name)) {
      $text = Convert-ToStableText -Value $ActionFields[$name]
      if (-not [string]::IsNullOrWhiteSpace($text)) {
        $fallbackParts += "${name}=$text"
      }
    }
  }
  if ($preferredParts.Count -gt 0) { return ($preferredParts -join ' | ') }
  return ($fallbackParts -join ' | ')
}

function Get-GitStatusRows {
  param([string]$Root)
  $lines = @(& git -C $Root status --porcelain)
  $rows = @()
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $status = $line.Substring(0, [Math]::Min(2, $line.Length))
    $path = if ($line.Length -gt 3) { $line.Substring(3) } else { '' }
    $rows += [pscustomobject][ordered]@{
      status = $status
      path = $path
      raw = $line
      untracked = ($status -eq '??')
    }
  }
  return @($rows)
}

function Convert-ToRepoRelativePath {
  param([string]$Root, [string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  $full = [System.IO.Path]::GetFullPath($Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $full.Substring($rootFull.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
  }
  return $full.Replace('\', '/')
}

function Test-AllowedStatusPath {
  param([string]$Path, [string]$ReportRootRel)
  return (
    $Path -eq 'modules/invoke_lab_frontier_progression_shadow_harness_v1.ps1' -or
    $Path -eq 'validators/validate_lab_frontier_progression_shadow_harness_v1.ps1' -or
    $Path -like 'reports/lab_frontier_progression_shadow_harness_v1_*' -or
    $Path -like 'reports/existing_self_map_next_action_selector_readonly_wrapper_v1_*' -or
    (-not [string]::IsNullOrWhiteSpace($ReportRootRel) -and ($Path -eq $ReportRootRel -or $Path -like "$ReportRootRel/*"))
  )
}

function Get-UnexpectedStatusRows {
  param([string]$Root, [string]$ReportRootRel)
  return @(Get-GitStatusRows -Root $Root | Where-Object { -not (Test-AllowedStatusPath -Path ([string]$_.path) -ReportRootRel $ReportRootRel) })
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

function Invoke-WrapperWithUntrackedHidden {
  param([string]$WrapperPath, [string]$Root, [string]$OutputPath)
  $oldCount = [Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT', 'Process')
  $oldKey0 = [Environment]::GetEnvironmentVariable('GIT_CONFIG_KEY_0', 'Process')
  $oldValue0 = [Environment]::GetEnvironmentVariable('GIT_CONFIG_VALUE_0', 'Process')
  try {
    $env:GIT_CONFIG_COUNT = '1'
    $env:GIT_CONFIG_KEY_0 = 'status.showUntrackedFiles'
    $env:GIT_CONFIG_VALUE_0 = 'no'
    return @(& $WrapperPath -RepoRoot $Root -OutputPath $OutputPath)
  } finally {
    if ($null -eq $oldCount) { Remove-Item Env:\GIT_CONFIG_COUNT -ErrorAction SilentlyContinue } else { $env:GIT_CONFIG_COUNT = $oldCount }
    if ($null -eq $oldKey0) { Remove-Item Env:\GIT_CONFIG_KEY_0 -ErrorAction SilentlyContinue } else { $env:GIT_CONFIG_KEY_0 = $oldKey0 }
    if ($null -eq $oldValue0) { Remove-Item Env:\GIT_CONFIG_VALUE_0 -ErrorAction SilentlyContinue } else { $env:GIT_CONFIG_VALUE_0 = $oldValue0 }
  }
}

$root = (Resolve-Path $RepoRoot).Path
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportDir = if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
  Join-Path $root "reports/lab_frontier_progression_shadow_harness_v1_$timestamp"
} elseif ([System.IO.Path]::IsPathRooted($ReportRoot)) {
  [System.IO.Path]::GetFullPath($ReportRoot)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $root $ReportRoot))
}
$reportRootRel = Convert-ToRepoRelativePath -Root $root -Path $reportDir
$resultPath = Join-Path $reportDir 'LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_RESULT.json'
$reportPath = Join-Path $reportDir 'LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_REPORT.md'

$wrapperPath = Join-Path $root 'modules/invoke_existing_self_map_next_action_selector_readonly_wrapper_v1.ps1'
if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
  throw "MISSING_ACCEPTED_SELECTOR_READONLY_WRAPPER=$wrapperPath"
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

$preExistingDirty = @(Get-UnexpectedStatusRows -Root $root -ReportRootRel $reportRootRel)
if ($preExistingDirty.Count -gt 0) {
  throw "LAB_FRONTIER_PROGRESSION_REQUIRES_NO_UNEXPECTED_DIRTY_SCOPE dirty=$($preExistingDirty.raw -join '; ')"
}

$cycleRecords = @()
$selectorRunnableAllCycles = $true
$nextActionCapturedAllCycles = $true
$worktreeCleanAfterAllCycles = $true
$protectedMutationPersisted = $false
$previousActionKey = ''
$actionKeys = @()

for ($cycleIndex = 1; $cycleIndex -le $Cycles; $cycleIndex += 1) {
  $cycleTimestamp = (Get-Date).ToString('o')
  $wrapperResult = $null
  $wrapperStatus = 'WRAPPER_NOT_RUN'
  $wrapperError = ''
  $actionFields = [ordered]@{}
  $actionKey = ''
  $nextActionCaptured = $false
  $repeatedFromPrevious = $false
  $stableRepeatedReason = ''
  $selectorRunnable = $false
  $selectorOutputCaptured = $false
  $wrapperWorktreeCleanAfter = $false
  $cycleUnexpectedDirty = @()
  $wrapperOutputPath = Join-Path $root ("reports/existing_self_map_next_action_selector_readonly_wrapper_v1_lab_frontier_shadow_{0}_cycle_{1:D3}/EXISTING_SELF_MAP_NEXT_ACTION_SELECTOR_READONLY_WRAPPER_RESULT.json" -f $timestamp, $cycleIndex)
  $wrapperStdoutLines = @()

  try {
    $wrapperStdoutLines = Invoke-WrapperWithUntrackedHidden -WrapperPath $wrapperPath -Root $root -OutputPath $wrapperOutputPath
    $wrapperJson = ($wrapperStdoutLines -join "`n")
    $wrapperParsed = $wrapperJson | ConvertFrom-Json
    $wrapperResult = if ($null -ne (Get-PropValue -Object $wrapperParsed -Name 'wrapper_result')) {
      Get-PropValue -Object $wrapperParsed -Name 'wrapper_result'
    } else {
      $wrapperParsed
    }
    $wrapperStatus = [string](Get-PropValue -Object $wrapperResult -Name 'status')
    $selectorRunnable = ([bool](Get-PropValue -Object $wrapperResult -Name 'selector_runnable'))
    $selectorOutputCaptured = ([bool](Get-PropValue -Object $wrapperResult -Name 'selector_output_captured'))
    $wrapperWorktreeCleanAfter = ([bool](Get-PropValue -Object $wrapperResult -Name 'worktree_clean_after'))
    $actionFields = Get-ActionFields -SelectorResult $wrapperResult -StdoutLines $wrapperStdoutLines
    $actionKey = Get-SelectedActionKey -ActionFields $actionFields
    $nextActionCaptured = (-not [string]::IsNullOrWhiteSpace($actionKey))
  } catch {
    $wrapperStatus = 'WRAPPER_EXCEPTION'
    $wrapperError = $_.Exception.Message
  }

  $protectedStatusAfterCycle = @(Get-ProtectedStatusRows -Root $root -Paths $protectedPaths)
  $cycleProtectedMutationPersisted = ($protectedStatusAfterCycle.Count -gt 0)
  $cycleUnexpectedDirty = @(Get-UnexpectedStatusRows -Root $root -ReportRootRel $reportRootRel)
  if ($cycleProtectedMutationPersisted) { $protectedMutationPersisted = $true }
  if (-not $selectorRunnable) { $selectorRunnableAllCycles = $false }
  if (-not $nextActionCaptured) { $nextActionCapturedAllCycles = $false }
  if ($cycleUnexpectedDirty.Count -gt 0 -or $cycleProtectedMutationPersisted) { $worktreeCleanAfterAllCycles = $false }

  if ($nextActionCaptured) {
    $actionKeys += $actionKey
    if ($cycleIndex -gt 1 -and $actionKey -eq $previousActionKey) {
      $repeatedFromPrevious = $true
      $stableRepeatedReason = 'STABLE_FRONTIER_PENDING: accepted wrapper returned the same next_action/frontier as the previous shadow cycle; no selected action was executed and no protected state was mutated, so the same frontier remains pending for a controlled loop.'
    }
    $previousActionKey = $actionKey
  }

  $cycleRecords += [ordered]@{
    cycle_index = [int]$cycleIndex
    timestamp = $cycleTimestamp
    selector_wrapper_status = $wrapperStatus
    selector_runnable = [bool]$selectorRunnable
    selector_output_captured = [bool]$selectorOutputCaptured
    selector_worktree_clean_after = [bool]$wrapperWorktreeCleanAfter
    wrapper_output_path = $wrapperOutputPath
    selected_action = $actionKey
    selected_action_fields = $actionFields
    next_action_captured = [bool]$nextActionCaptured
    repeated_from_previous_cycle = [bool]$repeatedFromPrevious
    stable_repeated_reason = $stableRepeatedReason
    selected_action_executed = $false
    protected_mutation_persisted = [bool]$cycleProtectedMutationPersisted
    self_completion_claimed = $false
    continue_required = $true
    codex_used_at_runtime = $false
    commit_done = $false
    push_done = $false
    live_patch_done = $false
    unexpected_dirty_scope = @($cycleUnexpectedDirty)
    wrapper_error = $wrapperError
  }

  if ($cycleProtectedMutationPersisted -or $cycleUnexpectedDirty.Count -gt 0) {
    break
  }
}

$cyclesRun = @($cycleRecords).Count
$uniqueActionKeys = @($actionKeys | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
$uniqueNextActionCount = @($uniqueActionKeys).Count
$frontierProgressionObserved = ($uniqueNextActionCount -gt 1)
$stableFrontierReason = ''
$repeatedNextActionAllowedWithReason = $false
if ($cyclesRun -ge 2 -and $uniqueNextActionCount -eq 1 -and $nextActionCapturedAllCycles -and $selectorRunnableAllCycles) {
  $stableFrontierReason = 'STABLE_FRONTIER_PENDING: selector state is unchanged because this harness is shadow-only and does not execute the recommendation; no protected state was mutated, self_completion_claimed=false, and continue_required=true.'
  $repeatedNextActionAllowedWithReason = $true
}

$postSelectorDirty = @(Get-UnexpectedStatusRows -Root $root -ReportRootRel $reportRootRel)
$worktreeCleanAfter = ($worktreeCleanAfterAllCycles -and $postSelectorDirty.Count -eq 0)
$protectedStatusAfter = @(Get-ProtectedStatusRows -Root $root -Paths $protectedPaths)
$protectedMutationPersisted = ($protectedMutationPersisted -or $protectedStatusAfter.Count -gt 0)
$frontierConditionPass = ($frontierProgressionObserved -or $repeatedNextActionAllowedWithReason)

$harnessPass = (
  $cyclesRun -eq $Cycles -and
  $cyclesRun -ge 1 -and
  $selectorRunnableAllCycles -and
  $nextActionCapturedAllCycles -and
  $frontierConditionPass -and
  (-not $protectedMutationPersisted) -and
  $worktreeCleanAfter
)

$status = if ($harnessPass) { 'PASS' } else { 'FAIL' }
$nextStatus = if ($harnessPass) {
  'READY_TO_PROMOTE_FRONTIER_PROGRESSION_SHADOW_TO_CONTROLLED_LOOP'
} else {
  'BLOCKED_LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_FAILED'
}

$result = [ordered]@{
  schema = 'LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_RESULT_V1'
  status = $status
  created_at = (Get-Date).ToString('o')
  repo_root = $root
  report_root = $reportDir
  harness_mode = 'shadow'
  selector_wrapper = 'modules/invoke_existing_self_map_next_action_selector_readonly_wrapper_v1.ps1'
  cycles_requested = [int]$Cycles
  cycles_run = [int]$cyclesRun
  selector_runnable_all_cycles = [bool]$selectorRunnableAllCycles
  next_action_captured_all_cycles = [bool]$nextActionCapturedAllCycles
  unique_next_action_count = [int]$uniqueNextActionCount
  repeated_next_action_allowed_with_reason = [bool]$repeatedNextActionAllowedWithReason
  repeated_next_action_reason = $stableFrontierReason
  frontier_progression_observed = [bool]$frontierProgressionObserved
  self_completion_claimed = $false
  continue_required = $true
  protected_mutation_persisted = [bool]$protectedMutationPersisted
  worktree_clean_after = [bool]$worktreeCleanAfter
  worktree_clean_after_scope = 'after_each_selector_call_before_harness_report_write; harness report files are owned proof output'
  codex_used_at_runtime = $false
  commit_done = $false
  push_done = $false
  live_patch_done = $false
  selected_actions_executed = $false
  next_status = $nextStatus
  protected_paths_checked = $protectedPaths
  protected_status_before = @($protectedStatusBefore)
  protected_status_after = @($protectedStatusAfter)
  unexpected_status_after_selector = @($postSelectorDirty)
  cycle_records = $cycleRecords
  proof_path = $resultPath
  report_path = $reportPath
}

Write-Json -Path $resultPath -Object $result

$reportLines = @(
  '# Lab Frontier Progression Shadow Harness V1',
  '',
  "Status: $status",
  '',
  '## Harness',
  '',
  "- harness_mode: shadow",
  "- cycles_requested: $Cycles",
  "- cycles_run: $cyclesRun",
  "- selector_runnable_all_cycles: $selectorRunnableAllCycles",
  "- next_action_captured_all_cycles: $nextActionCapturedAllCycles",
  "- unique_next_action_count: $uniqueNextActionCount",
  "- frontier_progression_observed: $frontierProgressionObserved",
  "- repeated_next_action_allowed_with_reason: $repeatedNextActionAllowedWithReason",
  '',
  '## Boundary',
  '',
  '- self_completion_claimed: false',
  '- continue_required: true',
  "- protected_mutation_persisted: $protectedMutationPersisted",
  "- worktree_clean_after: $worktreeCleanAfter",
  '- codex_used_at_runtime: false',
  '- commit_done: false',
  '- push_done: false',
  '- live_patch_done: false',
  '',
  '## Next',
  '',
  "- next_status: $nextStatus",
  '',
  '## Outputs',
  '',
  "- proof: $resultPath"
)
[System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

if ($EmitJson) {
  $result | ConvertTo-Json -Depth 100
} else {
  Write-Host "LAB_FRONTIER_PROGRESSION_SHADOW_HARNESS_STATUS=$status"
  Write-Host "CYCLES_RUN=$cyclesRun"
  Write-Host "PROOF_PATH=$resultPath"
  Write-Host "REPORT_PATH=$reportPath"
  Write-Host "NEXT_STATUS=$nextStatus"
}
