$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$proofPath='tests/live_start/AIMO_SOURCE_AGNOSTIC_LIVE_HOTSWAP_V1_PROOF.json'
$checkpointPath='tests/live_start/AIMO_SOURCE_AGNOSTIC_LIVE_HOTSWAP_V1_CHECKPOINT.json'
Assert (Test-Path $proofPath) 'LIVE_HOTSWAP_PROOF_MISSING'
Assert (Test-Path $checkpointPath) 'LIVE_HOTSWAP_CHECKPOINT_MISSING'
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$c=Get-Content $checkpointPath -Raw|ConvertFrom-Json
Assert ($p.schema -eq 'aimo_source_agnostic_live_hotswap_v1') 'PROOF_SCHEMA_BAD'
Assert ($p.status -eq 'PASS_AIMO_SOURCE_AGNOSTIC_LIVE_HOTSWAP_V1') 'PROOF_STATUS_BAD'
Assert ($p.label -eq 'PROVEN_LIVE_AIMO_HOTSWAPPED_TO_SOURCE_AGNOSTIC_PATH_SELECTION_GATE') 'PROOF_LABEL_BAD'
Assert ($c.status -eq 'CHECKPOINT_BEFORE_STOP_OLD_AIMO') 'CHECKPOINT_STATUS_BAD'
Assert ($p.old_live.stopped -eq $true) 'OLD_LIVE_NOT_MARKED_STOPPED'
Assert ($p.old_live.forced_stop -eq $false) 'OLD_LIVE_FORCED_STOP_SHOULD_BE_FALSE'
Assert ($p.new_live.stderr_size -eq 0) 'NEW_LIVE_STDERR_NOT_ZERO'
Assert ($p.new_live.gate_flag_present -eq $true) 'NEW_LIVE_GATE_FLAG_BAD'
Assert ($p.new_live.live_count_after_hotswap -eq 1) 'PROOF_LIVE_COUNT_NOT_ONE'
Assert ($p.selected.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE') 'SELECTED_REASON_BAD'
Assert ($p.selected.task_name -eq 'build_source_agnostic_path_selector_v1') 'SELECTED_TASK_BAD'
Assert ($p.selected.specific_gap -eq 'source_agnostic_path_selector_missing') 'SELECTED_GAP_BAD'
Assert ($p.selected.query_contains_trace -eq $true) 'SELECTED_QUERY_TRACE_BAD'
Assert ($p.canonical_selection.fallback_if_source_missing -eq 'bounded_static_self_build_task_from_gap_map') 'CANONICAL_FALLBACK_BAD'
Assert (@($p.canonical_selection.source_refs_rejected) -contains 'school_as_required_brain') 'CANONICAL_REJECTS_SCHOOL_MISSING'
Assert (@($p.canonical_selection.source_refs_rejected) -contains 'latest_signal_as_authority') 'CANONICAL_REJECTS_LATEST_MISSING'
Assert ($p.school.required_for_selection -eq $false) 'SCHOOL_REQUIRED_BAD'
Assert ($p.live_process_touched -eq $true) 'LIVE_PROCESS_TOUCHED_SHOULD_BE_TRUE'
Assert ($p.old_live_replaced -eq $true) 'OLD_LIVE_REPLACED_BAD'
Assert ($p.active_memory_mutated -eq $false) 'ACTIVE_MEMORY_MUTATED_BAD'
$runtimeProofPath=[string]$p.new_live.proof_path
Assert (Test-Path $runtimeProofPath) 'RUNTIME_PROOF_MISSING'
$runtime=Get-Content $runtimeProofPath -Raw|ConvertFrom-Json
$trace=@($runtime.development_trace.task_selection_trace)
Assert ($trace.Count -gt 0) 'RUNTIME_TRACE_EMPTY'
$last=$trace[-1]
Assert ($last.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE') 'RUNTIME_LAST_REASON_BAD'
Assert ($last.task.name -eq 'build_source_agnostic_path_selector_v1') 'RUNTIME_LAST_TASK_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_NOW_BAD:{0}" -f @($liveNow).Count)
Assert ([int]$liveNow[0].ProcessId -eq [int]$p.new_live.pid) 'LIVE_AIMO_NOW_NOT_PROOF_PID'
Assert ([string]$liveNow[0].CommandLine -like '*UseSourceAgnosticPathSelectionLabGate*') 'LIVE_AIMO_NOW_GATE_FLAG_MISSING'
$stderr=[string]$p.new_live.stderr
Assert (Test-Path $stderr) 'NEW_STDERR_PATH_MISSING'
Assert ((Get-Item $stderr).Length -eq 0) 'NEW_STDERR_NOW_NOT_ZERO'
$out=[ordered]@{
  schema='aimo_source_agnostic_live_hotswap_validation_v1'
  status='PASS_AIMO_SOURCE_AGNOSTIC_LIVE_HOTSWAP_V1'
  proof_path=$proofPath
  checkpoint_path=$checkpointPath
  live_pid_now=[int]$liveNow[0].ProcessId
  live_run_id=[string]$p.new_live.run_id
  selected_task=[string]$p.selected.task_name
  selected_gap=[string]$p.selected.specific_gap
  stderr_size_now=(Get-Item $stderr).Length
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$outPath='tests/live_start/AIMO_SOURCE_AGNOSTIC_LIVE_HOTSWAP_V1_VALIDATION.json'
$out|ConvertTo-Json -Depth 80|Set-Content $outPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_SOURCE_AGNOSTIC_LIVE_HOTSWAP_V1'
Write-Host ('VALIDATION_PATH='+$outPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
