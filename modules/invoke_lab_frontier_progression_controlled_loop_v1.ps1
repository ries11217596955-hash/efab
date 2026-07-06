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
    foreach ($subLine in ([string]$line -split "`r?`n")) {
      $text = [string]$subLine
      if (-not [string]::IsNullOrWhiteSpace($text) -and $text -match '(?i)recommendation|next[_ -]?action|phase') {
        $stdoutMatches += $text.Trim()
      }
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
  foreach ($name in @(
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
  )) {
    if ($ActionFields.Contains($name)) {
      $text = Convert-ToStableText -Value $ActionFields[$name]
      if (-not [string]::IsNullOrWhiteSpace($text)) {
        $preferredParts += "${name}=$text"
      }
    }
  }
  if ($preferredParts.Count -gt 0) { return ($preferredParts -join ' | ') }

  $fallbackParts = @()
  foreach ($name in @('recommendation_id', 'selector_stdout_match')) {
    if ($ActionFields.Contains($name)) {
      $text = Convert-ToStableText -Value $ActionFields[$name]
      if (-not [string]::IsNullOrWhiteSpace($text)) {
        $fallbackParts += "${name}=$text"
      }
    }
  }
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
    $Path -eq 'modules/invoke_lab_frontier_progression_controlled_loop_v1.ps1' -or
    $Path -eq 'validators/validate_lab_frontier_progression_controlled_loop_v1.ps1' -or
    $Path -eq 'modules/invoke_lab_frontier_progression_shadow_harness_v1.ps1' -or
    $Path -eq 'validators/validate_lab_frontier_progression_shadow_harness_v1.ps1' -or
    $Path -like 'reports/lab_frontier_progression_controlled_loop_v1_*' -or
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

function Get-FieldText {
  param($Fields, [string]$Name)
  if ($Fields.Contains($Name)) { return Convert-ToStableText -Value $Fields[$Name] }
  return ''
}

function Classify-ActionSafety {
  param($ActionFields, [string]$SelectedAction)
  $actionOnlyFields = [ordered]@{}
  foreach ($name in @($ActionFields.Keys)) {
    if ([string]$name -ne 'selector_stdout_match') {
      $actionOnlyFields[$name] = $ActionFields[$name]
    }
  }
  $fieldJson = Convert-ToStableText -Value $actionOnlyFields
  $combined = (($SelectedAction + "`n" + $fieldJson).ToLowerInvariant())
  $actionType = (Get-FieldText -Fields $ActionFields -Name 'next_action_type').ToUpperInvariant()

  if ($actionType -eq 'MAP_SIGNAL') {
    return [ordered]@{
      action_class = 'READ_ONLY_PROBE'
      safe_to_execute = $true
      reason = 'MAP_SIGNAL is treated as a selector signal; controlled execution is limited to read-only proof/status probes and report-dir ledger output.'
    }
  }
  $protectedPattern = 'packs/registry\.json|self_model_active_map\.json|accepted_change_memory_snapshot\.json|task_queue\.json|capability_roadmap\.json|genesis_state\.json|orchestrator/run\.ps1'
  if ($combined -match $protectedPattern) {
    return [ordered]@{
      action_class = 'PROTECTED_MUTATION_REQUIRED'
      safe_to_execute = $false
      reason = 'Action text references protected state or control files; controlled loop must block instead of mutating protected state.'
    }
  }
  if ($combined -match '\b(push|commit|merge|rebase)\b' -or $combined -match 'live[_ -]?patch|apply[_ -]?patch|patch live|modify module|write module|edit module') {
    return [ordered]@{
      action_class = 'LIVE_PATCH_REQUIRED'
      safe_to_execute = $false
      reason = 'Action appears to require live patch, source mutation, commit, push, or branch operation; controlled loop blocks it.'
    }
  }
  if ($combined -match '\b(report|ledger|record)\b') {
    return [ordered]@{
      action_class = 'REPORT_ONLY'
      safe_to_execute = $true
      reason = 'Action is report/ledger oriented and is bounded to this controlled-loop report directory.'
    }
  }
  if ($combined -match '\b(read|inspect|status|proof|probe|existence|validate)\b') {
    return [ordered]@{
      action_class = 'SAFE_LOCAL_EVIDENCE_ACTION'
      safe_to_execute = $true
      reason = 'Action can be reduced to local read-only evidence/status inspection plus report-dir ledger output.'
    }
  }
  return [ordered]@{
    action_class = 'UNKNOWN_UNSAFE'
    safe_to_execute = $false
    reason = 'Action did not match the bounded safe classes, so it is blocked by the controlled loop.'
  }
}

function Invoke-SafeBoundedAction {
  param(
    [string]$Root,
    [string]$ReportDir,
    [int]$CycleIndex,
    [string]$ActionClass,
    [string]$SelectedAction,
    [string[]]$ProtectedPaths
  )
  $probePaths = @(
    'modules/invoke_existing_self_map_next_action_selector_readonly_wrapper_v1.ps1',
    'modules/invoke_lab_frontier_progression_shadow_harness_v1.ps1',
    'validators/validate_lab_frontier_progression_shadow_harness_v1.ps1',
    'route_locks/ACTIVE_ROUTE_LOCK.json',
    'reports/self_development/self_map_next_action_recommendation.json'
  )
  $probeResults = @()
  foreach ($rel in $probePaths) {
    $full = Join-Path $Root $rel
    $probeResults += [ordered]@{
      path = $rel
      exists = [bool](Test-Path -LiteralPath $full)
      path_type = if (Test-Path -LiteralPath $full -PathType Leaf) { 'Leaf' } elseif (Test-Path -LiteralPath $full -PathType Container) { 'Container' } else { 'Missing' }
    }
  }
  $protectedStatus = @(Get-ProtectedStatusRows -Root $Root -Paths $ProtectedPaths)
  $entry = [ordered]@{
    cycle_index = [int]$CycleIndex
    timestamp = (Get-Date).ToString('o')
    execution_type = 'BOUNDED_READ_ONLY_OR_REPORT_DIR_LEDGER'
    action_class = $ActionClass
    selected_action = $SelectedAction
    read_only_probe_paths = $probeResults
    protected_status_rows = @($protectedStatus)
    wrote_only_report_dir = $true
  }
  $cycleLedgerPath = Join-Path $ReportDir ("ACTION_LEDGER_CYCLE_{0:D3}.json" -f $CycleIndex)
  Write-Json -Path $cycleLedgerPath -Object $entry
  return [ordered]@{
    executed = $true
    execution_result = 'SAFE_BOUNDED_ACTION_RECORDED'
    ledger_path = $cycleLedgerPath
    probe_count = [int]$probeResults.Count
    protected_status_clean = [bool]($protectedStatus.Count -eq 0)
  }
}

$root = (Resolve-Path $RepoRoot).Path
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportDir = if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
  Join-Path $root "reports/lab_frontier_progression_controlled_loop_v1_$timestamp"
} elseif ([System.IO.Path]::IsPathRooted($ReportRoot)) {
  [System.IO.Path]::GetFullPath($ReportRoot)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $root $ReportRoot))
}
$reportRootRel = Convert-ToRepoRelativePath -Root $root -Path $reportDir
$resultPath = Join-Path $reportDir 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_RESULT.json'
$reportPath = Join-Path $reportDir 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_REPORT.md'
$actionLedgerPath = Join-Path $reportDir 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_ACTION_LEDGER.json'

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
$preExistingUnexpected = @(Get-UnexpectedStatusRows -Root $root -ReportRootRel $reportRootRel)
if ($preExistingUnexpected.Count -gt 0) {
  throw "LAB_FRONTIER_CONTROLLED_LOOP_REQUIRES_NO_UNEXPECTED_DIRTY_SCOPE dirty=$($preExistingUnexpected.raw -join '; ')"
}

$cycleRecords = @()
$actionLedger = @()
$selectorRunnableAllCycles = $true
$nextActionCapturedAllCycles = $true
$actionClassifiedAllCycles = $true
$loopContinuedAfterActionOrBlock = $true
$protectedMutationPersisted = $false
$worktreeCleanAfterAllCycles = $true
$safeActionExecutedCount = 0
$blockedUnsafeActionCount = 0
$safetyFailure = $false

for ($cycleIndex = 1; $cycleIndex -le $Cycles; $cycleIndex += 1) {
  $wrapperOutputPath = Join-Path $reportDir ("SELECTOR_WRAPPER_RESULT_CYCLE_{0:D3}.json" -f $cycleIndex)
  $wrapperStdoutLines = @()
  $wrapperResult = $null
  $wrapperStatus = 'WRAPPER_NOT_RUN'
  $wrapperError = ''
  $selectorRunnable = $false
  $selectorOutputCaptured = $false
  $actionFields = [ordered]@{}
  $selectedAction = ''
  $nextActionCaptured = $false
  $classification = [ordered]@{
    action_class = 'UNKNOWN_UNSAFE'
    safe_to_execute = $false
    reason = 'Classification not reached.'
  }
  $execution = [ordered]@{
    executed = $false
    execution_result = 'NOT_EXECUTED'
    ledger_path = ''
  }
  $blockedAction = $false

  try {
    $wrapperStdoutLines = Invoke-WrapperWithUntrackedHidden -WrapperPath $wrapperPath -Root $root -OutputPath $wrapperOutputPath
    $wrapperParsed = ($wrapperStdoutLines -join "`n") | ConvertFrom-Json
    $wrapperResult = if ($null -ne (Get-PropValue -Object $wrapperParsed -Name 'wrapper_result')) {
      Get-PropValue -Object $wrapperParsed -Name 'wrapper_result'
    } else {
      $wrapperParsed
    }
    $wrapperStatus = [string](Get-PropValue -Object $wrapperResult -Name 'status')
    $selectorRunnable = ([bool](Get-PropValue -Object $wrapperResult -Name 'selector_runnable'))
    $selectorOutputCaptured = ([bool](Get-PropValue -Object $wrapperResult -Name 'selector_output_captured'))
    $actionFields = Get-ActionFields -SelectorResult $wrapperResult -StdoutLines $wrapperStdoutLines
    $selectedAction = Get-SelectedActionKey -ActionFields $actionFields
    $nextActionCaptured = (-not [string]::IsNullOrWhiteSpace($selectedAction))
    if ($nextActionCaptured) {
      $classification = Classify-ActionSafety -ActionFields $actionFields -SelectedAction $selectedAction
    }
  } catch {
    $wrapperStatus = 'WRAPPER_EXCEPTION'
    $wrapperError = $_.Exception.Message
  }

  if (-not $selectorRunnable) { $selectorRunnableAllCycles = $false }
  if (-not $nextActionCaptured) { $nextActionCapturedAllCycles = $false }
  if ([string]$classification.action_class -eq 'UNKNOWN_UNSAFE' -and -not $nextActionCaptured) { $actionClassifiedAllCycles = $false }

  if ([bool]$classification.safe_to_execute) {
    $execution = Invoke-SafeBoundedAction -Root $root -ReportDir $reportDir -CycleIndex $cycleIndex -ActionClass ([string]$classification.action_class) -SelectedAction $selectedAction -ProtectedPaths $protectedPaths
    $safeActionExecutedCount += 1
  } else {
    $blockedAction = $true
    $blockedUnsafeActionCount += 1
    $execution = [ordered]@{
      executed = $false
      execution_result = 'BLOCKED_UNSAFE_ACTION'
      ledger_path = ''
      block_reason = [string]$classification.reason
    }
  }

  $protectedStatusAfterCycle = @(Get-ProtectedStatusRows -Root $root -Paths $protectedPaths)
  $unexpectedAfterCycle = @(Get-UnexpectedStatusRows -Root $root -ReportRootRel $reportRootRel)
  $cycleProtectedMutationPersisted = ($protectedStatusAfterCycle.Count -gt 0)
  if ($cycleProtectedMutationPersisted) { $protectedMutationPersisted = $true }
  if ($unexpectedAfterCycle.Count -gt 0 -or $cycleProtectedMutationPersisted) {
    $worktreeCleanAfterAllCycles = $false
    $safetyFailure = $true
  }

  $cycleRecord = [ordered]@{
    cycle_index = [int]$cycleIndex
    timestamp = (Get-Date).ToString('o')
    selector_wrapper_status = $wrapperStatus
    selector_runnable = [bool]$selectorRunnable
    selector_output_captured = [bool]$selectorOutputCaptured
    wrapper_output_path = $wrapperOutputPath
    selected_action = $selectedAction
    selected_action_fields = $actionFields
    next_action_captured = [bool]$nextActionCaptured
    action_class = [string]$classification.action_class
    action_classification_reason = [string]$classification.reason
    action_classified = [bool](-not [string]::IsNullOrWhiteSpace([string]$classification.action_class))
    safe_to_execute = [bool]$classification.safe_to_execute
    safe_action_executed = [bool]$execution.executed
    blocked_action = [bool]$blockedAction
    execution = $execution
    continued_after_action_or_block = [bool]($cycleIndex -lt $Cycles -and -not $safetyFailure)
    protected_mutation_persisted = [bool]$cycleProtectedMutationPersisted
    unexpected_dirty_scope = @($unexpectedAfterCycle)
    self_completion_claimed = $false
    continue_required = $true
    codex_used_at_runtime = $false
    commit_done = $false
    push_done = $false
    live_patch_done = $false
    wrapper_error = $wrapperError
  }
  $cycleRecords += $cycleRecord
  $actionLedger += [ordered]@{
    cycle_index = [int]$cycleIndex
    action_class = [string]$classification.action_class
    safe_action_executed = [bool]$execution.executed
    blocked_action = [bool]$blockedAction
    selected_action = $selectedAction
    execution_result = [string]$execution.execution_result
  }
  Write-Json -Path $actionLedgerPath -Object $actionLedger

  if ($safetyFailure) {
    $loopContinuedAfterActionOrBlock = $false
    break
  }
}

$cyclesRun = @($cycleRecords).Count
$protectedStatusAfter = @(Get-ProtectedStatusRows -Root $root -Paths $protectedPaths)
$protectedMutationPersisted = ($protectedMutationPersisted -or $protectedStatusAfter.Count -gt 0)
$unexpectedAfter = @(Get-UnexpectedStatusRows -Root $root -ReportRootRel $reportRootRel)
$worktreeCleanAfter = ($worktreeCleanAfterAllCycles -and $unexpectedAfter.Count -eq 0 -and -not $protectedMutationPersisted)
$actionClassifiedAllCycles = ($actionClassifiedAllCycles -and @($cycleRecords | Where-Object { -not [bool]$_.action_classified }).Count -eq 0)
$loopContinuedAfterActionOrBlock = ($loopContinuedAfterActionOrBlock -and $cyclesRun -ge $Cycles -and $cyclesRun -ge 3)
$allCycleActionsAccounted = (($safeActionExecutedCount + $blockedUnsafeActionCount) -eq $cyclesRun)

$statusPass = (
  $cyclesRun -ge 3 -and
  $selectorRunnableAllCycles -and
  $nextActionCapturedAllCycles -and
  $actionClassifiedAllCycles -and
  $allCycleActionsAccounted -and
  $loopContinuedAfterActionOrBlock -and
  (-not $protectedMutationPersisted) -and
  $worktreeCleanAfter
)
$status = if ($statusPass) { 'PASS' } else { 'FAIL' }
$nextStatus = if ($statusPass) { 'READY_FOR_CONTROLLED_ACTION_EXECUTION_MICRO_TRIAL' } else { 'BLOCKED_LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_FAILED' }

$result = [ordered]@{
  schema = 'LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_RESULT_V1'
  status = $status
  created_at = (Get-Date).ToString('o')
  repo_root = $root
  report_root = $reportDir
  controlled_loop_mode = 'bounded_classify_then_safe_probe_or_block'
  selector_source = 'modules/invoke_existing_self_map_next_action_selector_readonly_wrapper_v1.ps1'
  cycles_requested = [int]$Cycles
  cycles_run = [int]$cyclesRun
  selector_runnable_all_cycles = [bool]$selectorRunnableAllCycles
  next_action_captured_all_cycles = [bool]$nextActionCapturedAllCycles
  action_classified_all_cycles = [bool]$actionClassifiedAllCycles
  safe_action_executed_count = [int]$safeActionExecutedCount
  blocked_unsafe_action_count = [int]$blockedUnsafeActionCount
  loop_continued_after_action_or_block = [bool]$loopContinuedAfterActionOrBlock
  self_completion_claimed = $false
  continue_required = $true
  protected_mutation_persisted = [bool]$protectedMutationPersisted
  worktree_clean_after = [bool]$worktreeCleanAfter
  worktree_clean_after_scope = 'protected paths clean and no unexpected dirty scope; controlled-loop report dir, accepted shadow reports, and accepted wrapper report outputs are allowed evidence.'
  codex_used_at_runtime = $false
  commit_done = $false
  push_done = $false
  live_patch_done = $false
  next_status = $nextStatus
  protected_paths_checked = $protectedPaths
  protected_status_before = @($protectedStatusBefore)
  protected_status_after = @($protectedStatusAfter)
  unexpected_status_after = @($unexpectedAfter)
  all_cycle_actions_accounted = [bool]$allCycleActionsAccounted
  action_ledger_path = $actionLedgerPath
  cycle_records = $cycleRecords
  proof_path = $resultPath
  report_path = $reportPath
}
Write-Json -Path $resultPath -Object $result

$reportLines = @(
  '# Lab Frontier Progression Controlled Loop V1',
  '',
  "Status: $status",
  '',
  '## Loop',
  '',
  "- cycles_requested: $Cycles",
  "- cycles_run: $cyclesRun",
  "- selector_runnable_all_cycles: $selectorRunnableAllCycles",
  "- next_action_captured_all_cycles: $nextActionCapturedAllCycles",
  "- action_classified_all_cycles: $actionClassifiedAllCycles",
  "- safe_action_executed_count: $safeActionExecutedCount",
  "- blocked_unsafe_action_count: $blockedUnsafeActionCount",
  "- loop_continued_after_action_or_block: $loopContinuedAfterActionOrBlock",
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
  "- proof: $resultPath",
  "- action_ledger: $actionLedgerPath"
)
[System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

if ($EmitJson) {
  $result | ConvertTo-Json -Depth 100
} else {
  Write-Host "LAB_FRONTIER_PROGRESSION_CONTROLLED_LOOP_STATUS=$status"
  Write-Host "CYCLES_RUN=$cyclesRun"
  Write-Host "PROOF_PATH=$resultPath"
  Write-Host "REPORT_PATH=$reportPath"
  Write-Host "NEXT_STATUS=$nextStatus"
}
