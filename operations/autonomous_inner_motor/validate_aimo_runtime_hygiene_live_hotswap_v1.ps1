$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$proofPath='tests/live_start/AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1_PROOF.json'
$checkpointPath='tests/live_start/AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1_CHECKPOINT.json'
$reportPath='reports/self_development/AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1.json'
$docPath='docs/operations/AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1.md'
foreach($p in @($proofPath,$checkpointPath,$reportPath,$docPath)){ Assert (Test-Path $p) ("MISSING:{0}" -f $p) }
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($p.status -eq 'PASS_AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1') 'PROOF_STATUS_BAD'
Assert ($p.old_live.stopped -eq $true) 'OLD_NOT_STOPPED'
Assert ($p.old_live.forced_stop -eq $false) 'OLD_FORCED_STOP_SHOULD_BE_FALSE'
Assert ($p.new_live.gated -eq $false) 'NEW_LIVE_GATED_BAD'
Assert ($p.new_live.observed_default_selection -eq $true) 'DEFAULT_SELECTION_NOT_OBSERVED'
Assert ($p.new_live.observed_runtime_hygiene_cleanup -eq $true) 'CLEANUP_NOT_OBSERVED'
Assert ($p.new_live.stderr_size -eq 0) 'NEW_STDERR_NOT_ZERO'
Assert ($p.new_live.alive_after_proof -eq $true) 'NEW_NOT_ALIVE_AFTER_PROOF'
Assert ($p.selection.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT') 'SELECTION_REASON_BAD'
Assert ($p.selection.task -eq 'build_source_agnostic_path_selector_v1') 'SELECTION_TASK_BAD'
foreach($t in @($p.transient_states_after)){ Assert ($t.exists -eq $false) ("TRANSIENT_STILL_EXISTS:{0}" -f $t.path) }
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
Assert ([int]$liveNow[0].ProcessId -eq [int]$p.new_live.pid) 'CURRENT_PID_MISMATCH'
Assert ([string]$liveNow[0].CommandLine -like ('*'+[string]$p.new_live.run_id+'*')) 'CURRENT_RUN_ID_MISMATCH'
Assert ([string]$liveNow[0].CommandLine -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'CURRENT_LIVE_HAS_GATE'
foreach($t in @('.runtime/compact_memory_intake_v1/checkpoints','.runtime/file_atom_absorption')){ Assert (-not(Test-Path $t)) ("TRANSIENT_PATH_EXISTS_NOW:{0}" -f $t) }
$stderrPath=[string]$p.new_live.stderr
Assert (Test-Path $stderrPath) 'STDERR_PATH_MISSING'
Assert ((Get-Item $stderrPath).Length -eq 0) 'STDERR_FILE_NOT_EMPTY'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 80) 'RUNTIME_SIZE_TOO_LARGE_AFTER_CLEANUP_HOTSWAP'
$out=[ordered]@{
  schema='aimo_runtime_hygiene_live_hotswap_validation_v1'
  status='PASS_AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1'
  proof_path=$proofPath
  checkpoint_path=$checkpointPath
  current_live_pid=[int]$liveNow[0].ProcessId
  current_live_run_id=[string]$p.new_live.run_id
  current_live_has_gate=$false
  cleanup_observed=$true
  transient_paths_absent=$true
  runtime_size_mb=[Math]::Round($runtimeSize/1MB,2)
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$validationPath='tests/live_start/AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1_VALIDATION.json'
$out|ConvertTo-Json -Depth 80|Set-Content $validationPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1'
Write-Host ('VALIDATION_PATH='+$validationPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
