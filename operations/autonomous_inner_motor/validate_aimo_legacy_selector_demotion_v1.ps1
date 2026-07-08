$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$script='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$selectionPath='reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1.json'
$contractPath='self_model/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTOR_CONTRACT_V1.json'
Assert (Test-Path $script) 'AIMO_SCRIPT_MISSING'
Assert (Test-Path $selectionPath) 'SOURCE_AGNOSTIC_SELECTION_REPORT_MISSING'
Assert (Test-Path $contractPath) 'CONTRACT_MISSING'
$scriptText=Get-Content $script -Raw
foreach($needle in @('SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT','ACTIVE_MEMORY_DELTA_FROM_SCHOOL','ACTIVE_GROWTH_SIGNAL_TOPIC','legacy_selector_demoted=$true','explicit_gate_required=$false')){ Assert ($scriptText -like ('*'+$needle+'*')) ("SCRIPT_MARKER_MISSING:{0}" -f $needle) }
$defaultLine=@(Select-String -Path $script -Pattern 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT')[0].LineNumber
$schoolLine=@(Select-String -Path $script -Pattern 'ACTIVE_MEMORY_DELTA_FROM_SCHOOL')[0].LineNumber
$growthLine=@(Select-String -Path $script -Pattern 'ACTIVE_GROWTH_SIGNAL_TOPIC')[0].LineNumber
Assert ($defaultLine -lt $schoolLine) 'DEFAULT_SELECTOR_NOT_BEFORE_SCHOOL_LEGACY'
Assert ($defaultLine -lt $growthLine) 'DEFAULT_SELECTOR_NOT_BEFORE_GROWTH_LEGACY'
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($c.legacy_selector.status -eq 'DEMOTE_TO_BOUNDED_FALLBACK') 'CONTRACT_LEGACY_STATUS_BAD'
Assert (@($c.legacy_selector.forbidden_as_default_authority) -contains 'ACTIVE_MEMORY_DELTA_FROM_SCHOOL') 'CONTRACT_SCHOOL_LEGACY_FORBID_MISSING'
Assert (@($c.legacy_selector.forbidden_as_default_authority) -contains 'latest_runtime_packet_as_authority') 'CONTRACT_LATEST_FORBID_MISSING'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
foreach($name in @('Get-SelectorField','Normalize-GrowthSignalTopicForTask','Select-GrowthDirectedDevelopmentTask')){
  $func=@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))[0]
  Assert ($null -ne $func) ("FUNCTION_MISSING:{0}" -f $name)
  Invoke-Expression $func.Extent.Text
}
$tasks=@(
  [ordered]@{ name='choose_next_safe_growth_step'; query='baseline growth'; target='policy.json' },
  [ordered]@{ name='use_memory_before_repeating'; query='memory use'; target='manifest.json' }
)
$prev=[pscustomobject]@{ available=$true; run_id='old_school_run'; cells_sha256='OLD_HASH' }
$curr=[pscustomobject]@{ available=$true; run_id='fresh_school_run'; cells_sha256='NEW_HASH' }
$missingPrev=[pscustomobject]@{ available=$false; run_id=''; cells_sha256='' }
$missingCurr=[pscustomobject]@{ available=$false; run_id=''; cells_sha256='' }
$noGrowth=[pscustomobject]@{ available=$false; topics=@(); focus_boosts=@() }
$freshGrowth=[pscustomobject]@{
  available=$true
  source_kind='latest_runtime_packet'
  packet_id='fresh_latest_signal_should_not_command_default'
  topics=@('fresh_school_memory_delta')
  focus_boosts=@('latest_signal')
  next_action_candidate='follow_latest_school_packet'
  specific_gap='latest_signal_overfit_risk'
  validator_hint='must_not_be_default_authority'
  proof_needed=@('negative proof that latest signal loses default authority')
}
$cases=@(
  [ordered]@{name='school_memory_delta_present';growth=$noGrowth;curr=$curr;prev=$prev;forbidden='ACTIVE_MEMORY_DELTA_FROM_SCHOOL'},
  [ordered]@{name='latest_growth_signal_present';growth=$freshGrowth;curr=$missingCurr;prev=$missingPrev;forbidden='ACTIVE_GROWTH_SIGNAL_TOPIC'},
  [ordered]@{name='school_delta_and_latest_signal_present';growth=$freshGrowth;curr=$curr;prev=$prev;forbidden='ACTIVE_MEMORY_DELTA_FROM_SCHOOL'},
  [ordered]@{name='no_optional_signals';growth=$noGrowth;curr=$missingCurr;prev=$missingPrev;forbidden='NO_FRESH_GROWTH_SIGNAL_OR_MEMORY_DELTA'}
)
$results=@()
foreach($case in $cases){
  $sel=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $case.growth -CurrentMemoryState $case.curr -PreviousMemoryState $case.prev
  Assert ($sel.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT') ("CASE_NOT_DEFAULT_SOURCE_AGNOSTIC:{0}:{1}" -f $case.name,$sel.reason)
  Assert ($sel.task.name -eq 'build_source_agnostic_path_selector_v1') ("CASE_TASK_BAD:{0}:{1}" -f $case.name,$sel.task.name)
  Assert ($sel.legacy_selector_demoted -eq $true) ("CASE_LEGACY_NOT_DEMOTED:{0}" -f $case.name)
  Assert ($sel.explicit_gate_required -eq $false) ("CASE_GATE_REQUIRED:{0}" -f $case.name)
  Assert ($sel.reason -ne $case.forbidden) ("CASE_FORBIDDEN_REASON_SELECTED:{0}:{1}" -f $case.name,$case.forbidden)
  Assert (@($sel.source_refs_rejected) -contains 'school_as_required_brain') ("CASE_REJECTION_SCHOOL_MISSING:{0}" -f $case.name)
  Assert (@($sel.source_refs_rejected) -contains 'latest_signal_as_authority') ("CASE_REJECTION_LATEST_MISSING:{0}" -f $case.name)
  $results += [ordered]@{case=$case.name;status='PASS';selected_reason=[string]$sel.reason;selected_task=[string]$sel.task.name;forbidden_reason_not_selected=[string]$case.forbidden;legacy_selector_demoted=[bool]$sel.legacy_selector_demoted;explicit_gate_required=[bool]$sel.explicit_gate_required;source_refs_rejected=@($sel.source_refs_rejected)}
}
$gateSel=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $freshGrowth -CurrentMemoryState $curr -PreviousMemoryState $prev -UseSourceAgnosticPathSelectionLabGate
Assert ($gateSel.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE') 'GATE_COMPAT_REASON_BAD'
Assert ($gateSel.task.name -eq 'build_source_agnostic_path_selector_v1') 'GATE_COMPAT_TASK_BAD'
# Missing source-agnostic report behavior: current code fails closed, so legacy fallback is not claimed as implemented/proven in this phase.
$missingReportStatus='NOT_TESTED'
$missingReportBoundary='legacy emergency fallback on missing/invalid SOURCE_AGNOSTIC_PATH_SELECTION_V1 is NOT proven by PHASE_D; current acceptance is only demotion from default authority.'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 100) 'RUNTIME_SIZE_GUARD_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
$out=[ordered]@{
  schema='aimo_legacy_selector_demotion_v1'
  status='PASS_AIMO_LEGACY_SELECTOR_DEMOTION_V1'
  script=$script
  selection_report=$selectionPath
  contract=$contractPath
  line_order=[ordered]@{default_selector_line=$defaultLine;school_legacy_line=$schoolLine;growth_legacy_line=$growthLine;default_before_legacy=$true}
  cases=@($results)
  compatibility_gate=[ordered]@{status='PASS';reason=[string]$gateSel.reason;task=[string]$gateSel.task.name}
  legacy_default_authority=[ordered]@{status='DEMOTED';forbidden_reasons_not_selected=@('ACTIVE_MEMORY_DELTA_FROM_SCHOOL','ACTIVE_GROWTH_SIGNAL_TOPIC','NO_FRESH_GROWTH_SIGNAL_OR_MEMORY_DELTA');source_refs_rejected_required=@('school_as_required_brain','latest_signal_as_authority')}
  boundary=[ordered]@{legacy_fallback_on_missing_source_agnostic_report=$missingReportStatus;note=$missingReportBoundary;child_agent_factory_readiness='NOT_PROVEN'}
  runtime_size_mb=[Math]::Round($runtimeSize/1MB,2)
  live_state=[ordered]@{live_aimo_count=@($liveNow).Count;live_pid=[int]$liveNow[0].ProcessId;live_process_touched=$false}
  active_memory_mutated=$false
  live_process_touched=$false
  next_phase='PHASE_E_DEFAULT_SELECTOR_LIVE_HOTSWAP_PREFLIGHT_OR_ISOLATED_PROOF_GUARD'
  created_at=(Get-Date).ToString('o')
}
$proofOut='tests/autonomous_inner_motor/AIMO_LEGACY_SELECTOR_DEMOTION_V1_PROOF.json'
$out|ConvertTo-Json -Depth 100|Set-Content $proofOut -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_LEGACY_SELECTOR_DEMOTION_V1'
Write-Host ('PROOF_PATH='+$proofOut)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
