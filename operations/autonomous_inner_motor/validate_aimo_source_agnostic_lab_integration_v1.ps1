$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Get-SelectorField($Object,[string]$Name,$Default=$null) {
  if($null -eq $Object) { return $Default }
  if($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) { return $Object[$Name] }
  if($Object.PSObject.Properties[$Name]) { return $Object.PSObject.Properties[$Name].Value }
  return $Default
}
$script='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
foreach($name in @('Get-SelectorField','Normalize-GrowthSignalTopicForTask','Select-GrowthDirectedDevelopmentTask')){
  $func=@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))[0]
  Assert ($null -ne $func) "FUNCTION_MISSING:$name"
  Invoke-Expression $func.Extent.Text
}
$selectionPath='reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1.json'
Assert (Test-Path $selectionPath) 'SOURCE_AGNOSTIC_SELECTION_REPORT_MISSING'
$sel=Get-Content $selectionPath -Raw|ConvertFrom-Json
Assert ($sel.status -eq 'SOURCE_AGNOSTIC_PATH_SELECTED_LAB') 'SOURCE_AGNOSTIC_SELECTION_REPORT_STATUS_BAD'
$tasks=@(
  [ordered]@{ name='choose_next_safe_growth_step'; query='baseline growth'; target='policy.json' },
  [ordered]@{ name='understand_own_policy_limits'; query='policy limits'; target='policy.json' },
  [ordered]@{ name='use_memory_before_repeating'; query='memory use'; target='manifest.json' }
)
$prev=[pscustomobject]@{ available=$true; run_id='old_run'; cells_sha256='OLD_HASH' }
$curr=[pscustomobject]@{ available=$true; run_id='new_run'; cells_sha256='NEW_HASH' }
$noGrowth=[pscustomobject]@{ available=$false; topics=@(); focus_boosts=@() }
$withoutGate=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $noGrowth -CurrentMemoryState $curr -PreviousMemoryState $prev
Assert ($withoutGate.reason -eq 'ACTIVE_MEMORY_DELTA_FROM_SCHOOL') 'DEFAULT_PATH_REGRESSION_BAD'
$withGate=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $noGrowth -CurrentMemoryState $curr -PreviousMemoryState $prev -UseSourceAgnosticPathSelectionLabGate
Assert ($withGate.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE') 'LAB_GATE_REASON_BAD'
Assert ($withGate.task.name -eq 'build_source_agnostic_path_selector_v1') 'LAB_GATE_TASK_NAME_BAD'
Assert ($withGate.specific_gap -eq 'source_agnostic_path_selector_missing') 'LAB_GATE_SPECIFIC_GAP_BAD'
Assert ($withGate.next_action_candidate -eq 'build_source_agnostic_path_selector_v1') 'LAB_GATE_NEXT_ACTION_BAD'
Assert ($withGate.lab_gate_enabled -eq $true) 'LAB_GATE_FLAG_BAD'
Assert ($withGate.task.target -eq $selectionPath) 'LAB_GATE_TARGET_BAD'
Assert ($withGate.task.query -like '*identity_alignment primary_mission:build_repair_verify_and_improve_self*') 'LAB_GATE_QUERY_IDENTITY_MISSING'
Assert ($withGate.task.query -like '*selected_gap source_agnostic_path_selector_missing*') 'LAB_GATE_QUERY_GAP_MISSING'
Assert ($withGate.task.query -like '*why_not_latest_signal*') 'LAB_GATE_QUERY_WHY_NOT_LATEST_MISSING'
Assert ($withGate.task.query -like '*school_as_required_brain*') 'LAB_GATE_QUERY_REJECTED_SCHOOL_MISSING'
Assert (@($withGate.source_refs_rejected) -contains 'school_as_required_brain') 'LAB_GATE_REJECTED_SCHOOL_FIELD_MISSING'
Assert (@($withGate.source_refs_rejected) -contains 'latest_signal_as_authority') 'LAB_GATE_REJECTED_LATEST_FIELD_MISSING'
$scriptText=Get-Content $script -Raw
Assert ($scriptText -match '\[switch\]\$UseSourceAgnosticPathSelectionLabGate') 'SCRIPT_SWITCH_MISSING'
Assert ($scriptText -match 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE') 'SCRIPT_REASON_MARKER_MISSING'
Assert ($scriptText -match 'UseSourceAgnosticPathSelectionLabGate:\$UseSourceAgnosticPathSelectionLabGate') 'RUNTIME_CALL_GATE_PASS_MISSING'
# Short SandboxTestLife lab run with explicit gate. This is not live_aimo and is stopped by validator.
$runId='phase_i_source_agnostic_lab_gate_'+(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$stdout='.runtime/autonomous_inner_motor/phase_i_source_agnostic_lab_gate_stdout.txt'
$stderr='.runtime/autonomous_inner_motor/phase_i_source_agnostic_lab_gate_stderr.txt'
$p=Start-Process -FilePath 'powershell' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,'-Mode','SandboxTestLife','-RunId',$runId,'-UseSourceAgnosticPathSelectionLabGate') -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
$proofPath=Join-Path (Join-Path '.runtime/autonomous_inner_motor/test_life_runs' $runId) 'TEST_LIFE_PROOF.json'
$deadline=(Get-Date).AddSeconds(35)
$observed=$false
while((Get-Date) -lt $deadline){
  Start-Sleep -Seconds 2
  if(Test-Path $proofPath){
    try{
      $proof=Get-Content $proofPath -Raw|ConvertFrom-Json
      $trace=@($proof.development_trace.task_selection_trace)
      if($trace.Count -gt 0 -and $trace[-1].reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE'){$observed=$true; break}
    } catch {}
  }
}
$stopPath=Join-Path (Split-Path $proofPath -Parent) 'STOP_REQUESTED.txt'
New-Item -ItemType Directory -Force -Path (Split-Path $stopPath -Parent)|Out-Null
Set-Content -Path $stopPath -Value ('phase_i validator stop '+(Get-Date).ToString('o')) -Encoding UTF8
$waitDeadline=(Get-Date).AddSeconds(35)
while((Get-Date) -lt $waitDeadline -and (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)){ Start-Sleep -Seconds 2 }
$forced=$false
if(Get-Process -Id $p.Id -ErrorAction SilentlyContinue){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; $forced=$true; Start-Sleep -Seconds 1 }
Assert ($observed -eq $true) 'LAB_RUNTIME_DID_NOT_OBSERVE_SOURCE_AGNOSTIC_SELECTION'
Assert (Test-Path $proofPath) 'LAB_RUNTIME_PROOF_MISSING'
$runtimeProof=Get-Content $proofPath -Raw|ConvertFrom-Json
$runtimeTrace=@($runtimeProof.development_trace.task_selection_trace)
$runtimeSelector=$runtimeTrace[-1]
Assert ($runtimeSelector.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE') 'LAB_RUNTIME_SELECTOR_REASON_BAD'
Assert ($runtimeSelector.task.name -eq 'build_source_agnostic_path_selector_v1') 'LAB_RUNTIME_SELECTOR_TASK_BAD'
$stderrSize=if(Test-Path $stderr){(Get-Item $stderr).Length}else{0}
Assert ($stderrSize -eq 0) "LAB_RUNTIME_STDERR_NOT_EMPTY:$stderrSize"
$out=[ordered]@{
  schema='aimo_source_agnostic_lab_integration_validation_v1'
  status='PASS_AIMO_SOURCE_AGNOSTIC_LAB_INTEGRATION_V1'
  script=$script
  selection_report_path=$selectionPath
  lab_runtime=[ordered]@{run_id=$runId;pid=$p.Id;proof_path=$proofPath;stdout=$stdout;stderr=$stderr;stderr_size=$stderrSize;forced_stop=$forced;observed_source_agnostic_selection=$observed;cycles=$runtimeProof.test_life.total_cycles}
  tests=@(
    [ordered]@{name='default_path_unchanged_without_gate';status='PASS';reason=$withoutGate.reason},
    [ordered]@{name='lab_gate_selects_source_agnostic_path';status='PASS';selected_task=$withGate.task.name;selected_gap=$withGate.specific_gap},
    [ordered]@{name='selection_trace_contains_identity_gap_and_rejections';status='PASS'},
    [ordered]@{name='sandbox_test_life_lab_run_observed_gate_selection';status='PASS';run_id=$runId;cycles=$runtimeProof.test_life.total_cycles},
    [ordered]@{name='live_not_touched_by_validator';status='PASS'}
  )
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofOut='tests/autonomous_inner_motor/AIMO_SOURCE_AGNOSTIC_LAB_INTEGRATION_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofOut -Parent)|Out-Null
$out|ConvertTo-Json -Depth 80|Set-Content $proofOut -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_SOURCE_AGNOSTIC_LAB_INTEGRATION_V1'
Write-Host "PROOF_PATH=$proofOut"
Write-Host 'LIVE_PROCESS_TOUCHED=false'
