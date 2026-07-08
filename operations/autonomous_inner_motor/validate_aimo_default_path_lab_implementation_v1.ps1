$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Get-Sha256Hex([string]$Path){ if(-not(Test-Path $Path)){ return '' }; return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash }
$script='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$contractPath='self_model/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTOR_CONTRACT_V1.json'
$selectionPath='reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1.json'
Assert (Test-Path $script) 'AIMO_SCRIPT_MISSING'
Assert (Test-Path $contractPath) 'CONTRACT_MISSING'
Assert (Test-Path $selectionPath) 'SOURCE_AGNOSTIC_SELECTION_REPORT_MISSING'
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($c.default_selector.must_be_default -eq $true) 'CONTRACT_DEFAULT_BAD'
Assert ($c.default_selector.requires_explicit_gate_for_normal_operation -eq $false) 'CONTRACT_GATE_REQUIREMENT_BAD'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
foreach($name in @('Get-SelectorField','Normalize-GrowthSignalTopicForTask','Select-GrowthDirectedDevelopmentTask')){
  $func=@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))[0]
  Assert ($null -ne $func) ("FUNCTION_MISSING:{0}" -f $name)
  Invoke-Expression $func.Extent.Text
}
$tasks=@([ordered]@{ name='choose_next_safe_growth_step'; query='baseline growth'; target='policy.json' },[ordered]@{ name='understand_own_policy_limits'; query='policy limits'; target='policy.json' })
$prev=[pscustomobject]@{ available=$true; run_id='old_run'; cells_sha256='OLD_HASH' }
$curr=[pscustomobject]@{ available=$true; run_id='new_run'; cells_sha256='NEW_HASH' }
$noGrowth=[pscustomobject]@{ available=$false; topics=@(); focus_boosts=@() }
$defaultSel=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $noGrowth -CurrentMemoryState $curr -PreviousMemoryState $prev
Assert ($defaultSel.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT') 'DEFAULT_REASON_BAD'
Assert ($defaultSel.task.name -eq 'build_source_agnostic_path_selector_v1') 'DEFAULT_TASK_BAD'
Assert ($defaultSel.specific_gap -eq 'source_agnostic_path_selector_missing') 'DEFAULT_GAP_BAD'
Assert ($defaultSel.lab_gate_enabled -eq $false) 'DEFAULT_GATE_FLAG_BAD'
Assert ($defaultSel.source_agnostic_default_enabled -eq $true) 'DEFAULT_ENABLED_BAD'
Assert ($defaultSel.explicit_gate_required -eq $false) 'EXPLICIT_GATE_REQUIRED_BAD'
Assert ($defaultSel.legacy_selector_demoted -eq $true) 'LEGACY_DEMOTED_BAD'
Assert (@($defaultSel.source_refs_rejected) -contains 'school_as_required_brain') 'DEFAULT_REJECTS_SCHOOL_MISSING'
Assert (@($defaultSel.source_refs_rejected) -contains 'latest_signal_as_authority') 'DEFAULT_REJECTS_LATEST_MISSING'
Assert (-not [string]::IsNullOrWhiteSpace([string]$defaultSel.fallback_if_source_missing)) 'DEFAULT_FALLBACK_EMPTY'
$gateSel=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $noGrowth -CurrentMemoryState $curr -PreviousMemoryState $prev -UseSourceAgnosticPathSelectionLabGate
Assert ($gateSel.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE') 'GATE_REASON_COMPAT_BAD'
Assert ($gateSel.lab_gate_enabled -eq $true) 'GATE_FLAG_COMPAT_BAD'
Assert ($gateSel.task.name -eq $defaultSel.task.name) 'GATE_DEFAULT_TASK_MISMATCH'
$activeCellsPath='.runtime/active_compact_semantic_memory_v1/cells.jsonl'
$activeManifestPath='.runtime/active_compact_semantic_memory_v1/manifest.json'
$activeCellsBeforeSha256=Get-Sha256Hex $activeCellsPath
$activeManifestBeforeSha256=Get-Sha256Hex $activeManifestPath
foreach($preClean in @('.runtime/compact_memory_intake_v1/checkpoints','.runtime/file_atom_absorption')){
  if(Test-Path $preClean){ $tracked=@(git ls-files -- $preClean); if($tracked.Count -eq 0){ Remove-Item -LiteralPath $preClean -Recurse -Force } }
}
$runId='phase_c_default_source_agnostic_no_gate_'+(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$stdout='.runtime/autonomous_inner_motor/phase_c_default_source_agnostic_no_gate_stdout.txt'
$stderr='.runtime/autonomous_inner_motor/phase_c_default_source_agnostic_no_gate_stderr.txt'
$p=Start-Process -FilePath 'powershell' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,'-Mode','SandboxTestLife','-RunId',$runId,'-DisableKnowledgeAcquisitionForLabProof') -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
$proofPath=Join-Path (Join-Path '.runtime/autonomous_inner_motor/test_life_runs' $runId) 'TEST_LIFE_PROOF.json'
$observed=$false
$deadline=(Get-Date).AddSeconds(35)
while((Get-Date) -lt $deadline){
  Start-Sleep -Seconds 2
  if(Test-Path $proofPath){
    try{
      $runtimeProof=Get-Content $proofPath -Raw|ConvertFrom-Json
      $trace=@($runtimeProof.development_trace.task_selection_trace)
      if($trace.Count -gt 0 -and $trace[-1].reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT'){$observed=$true; break}
    } catch {}
  }
}
$stopPath=Join-Path (Split-Path $proofPath -Parent) 'STOP_REQUESTED.txt'
New-Item -ItemType Directory -Force -Path (Split-Path $stopPath -Parent)|Out-Null
Set-Content -Path $stopPath -Value ('phase_c validator stop '+(Get-Date).ToString('o')) -Encoding UTF8
$waitDeadline=(Get-Date).AddSeconds(35)
while((Get-Date) -lt $waitDeadline -and (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)){ Start-Sleep -Seconds 2 }
$forced=$false
if(Get-Process -Id $p.Id -ErrorAction SilentlyContinue){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; $forced=$true; Start-Sleep -Seconds 1 }
Assert ($observed -eq $true) 'NO_GATE_RUNTIME_DID_NOT_OBSERVE_DEFAULT_SOURCE_AGNOSTIC_SELECTION'
Assert (Test-Path $proofPath) 'NO_GATE_RUNTIME_PROOF_MISSING'
$runtimeProof=Get-Content $proofPath -Raw|ConvertFrom-Json
$runtimeTrace=@($runtimeProof.development_trace.task_selection_trace)
$runtimeSelector=$runtimeTrace[-1]
Assert ($runtimeSelector.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT') 'RUNTIME_DEFAULT_REASON_BAD'
Assert ($runtimeSelector.task.name -eq 'build_source_agnostic_path_selector_v1') 'RUNTIME_DEFAULT_TASK_BAD'
Assert ($runtimeSelector.lab_gate_enabled -eq $false) 'RUNTIME_DEFAULT_GATE_FLAG_BAD'
Assert ($runtimeSelector.explicit_gate_required -eq $false) 'RUNTIME_EXPLICIT_GATE_REQUIRED_BAD'
Assert ($runtimeProof.development_trace.knowledge_acquisition_disabled_for_lab_proof -eq $true) 'KNOWLEDGE_ACQUISITION_DISABLE_MARKER_BAD'
$stderrSize=if(Test-Path $stderr){(Get-Item $stderr).Length}else{0}
Assert ($stderrSize -eq 0) ("NO_GATE_RUNTIME_STDERR_NOT_EMPTY:{0}" -f $stderrSize)
$cleanupItems=@('.runtime/compact_memory_intake_v1/checkpoints','.runtime/file_atom_absorption')
$cleanupReport=@()
foreach($cleanupPath in $cleanupItems){
  $tracked=@(git ls-files -- $cleanupPath)
  $existsBefore=Test-Path $cleanupPath
  $sizeBefore=0; $filesBefore=0
  if($existsBefore){ $sizeBefore=(Get-ChildItem $cleanupPath -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum; $filesBefore=(Get-ChildItem $cleanupPath -Recurse -File -ErrorAction SilentlyContinue|Measure-Object).Count }
  $deleted=$false
  if($existsBefore -and $tracked.Count -eq 0){ Remove-Item -LiteralPath $cleanupPath -Recurse -Force; $deleted=$true }
  $cleanupReport += [ordered]@{path=$cleanupPath;exists_before=$existsBefore;tracked_count=$tracked.Count;size_mb_before=[Math]::Round($sizeBefore/1MB,2);file_count_before=$filesBefore;deleted=$deleted}
}
$activeCellsAfterSha256=Get-Sha256Hex $activeCellsPath
$activeManifestAfterSha256=Get-Sha256Hex $activeManifestPath
$activeCellsUnchanged=($activeCellsBeforeSha256 -eq $activeCellsAfterSha256)
$activeManifestUnchanged=($activeManifestBeforeSha256 -eq $activeManifestAfterSha256)
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 100) 'RUNTIME_SIZE_GUARD_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -like '*UseSourceAgnosticPathSelectionLabGate*') 'CURRENT_LIVE_GATE_SHOULD_REMAIN_UNTOUCHED'
$out=[ordered]@{
  schema='aimo_default_path_lab_implementation_v1'
  status='PASS_AIMO_DEFAULT_PATH_LAB_IMPLEMENTATION_V1_WITH_SHARED_RUNTIME_WARNING'
  script=$script
  contract_path=$contractPath
  direct_default=[ordered]@{reason=[string]$defaultSel.reason;task=[string]$defaultSel.task.name;gap=[string]$defaultSel.specific_gap;lab_gate_enabled=[bool]$defaultSel.lab_gate_enabled;explicit_gate_required=[bool]$defaultSel.explicit_gate_required;legacy_selector_demoted=[bool]$defaultSel.legacy_selector_demoted}
  compatibility_gate=[ordered]@{reason=[string]$gateSel.reason;task=[string]$gateSel.task.name;lab_gate_enabled=[bool]$gateSel.lab_gate_enabled}
  no_gate_lab_runtime=[ordered]@{run_id=$runId;pid=$p.Id;proof_path=$proofPath;stdout=$stdout;stderr=$stderr;stderr_size=$stderrSize;forced_stop=$forced;observed_default_source_agnostic_selection=$observed;cycles=$runtimeProof.test_life.total_cycles;knowledge_acquisition_disabled_for_lab_proof=$true}
  transient_cleanup=@($cleanupReport)
  active_memory_hash_guard=[ordered]@{cells_before=$activeCellsBeforeSha256;cells_after=$activeCellsAfterSha256;cells_unchanged=$activeCellsUnchanged;manifest_before=$activeManifestBeforeSha256;manifest_after=$activeManifestAfterSha256;manifest_unchanged=$activeManifestUnchanged;boundary='Cannot attribute active memory hash changes while live AIMO shares the same active memory runtime.'}
  warning=[ordered]@{shared_runtime_active_memory_attribution='UNKNOWN_WHILE_LIVE_AIMO_ACTIVE';repair_added='DisableKnowledgeAcquisitionForLabProof';boundary='Selector default is proven. Active memory purity requires isolated runtime or stopped live AIMO; not claimed here.'}
  live_state=[ordered]@{live_aimo_count=@($liveNow).Count;live_pid=[int]$liveNow[0].ProcessId;current_live_still_gated=$true}
  runtime_size_mb_after_cleanup=[Math]::Round($runtimeSize/1MB,2)
  live_process_touched=$false
  active_memory_mutation_attribution='UNKNOWN_SHARED_RUNTIME_LIVE_AIMO_ACTIVE'
  next_phase='PHASE_D_LEGACY_SELECTOR_DEMOTION_VALIDATOR'
  created_at=(Get-Date).ToString('o')
}
$proofOut='tests/autonomous_inner_motor/AIMO_DEFAULT_PATH_LAB_IMPLEMENTATION_V1_PROOF.json'
$out|ConvertTo-Json -Depth 100|Set-Content $proofOut -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_DEFAULT_PATH_LAB_IMPLEMENTATION_V1_WITH_SHARED_RUNTIME_WARNING'
Write-Host ('PROOF_PATH='+$proofOut)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
