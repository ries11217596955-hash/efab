$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$proofPath='tests/live_start/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1_PROOF.json'
$checkpointPath='tests/live_start/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1_CHECKPOINT.json'
$reportPath='reports/self_development/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1.json'
$docPath='docs/operations/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1.md'
Assert (Test-Path $proofPath) 'HOTSWAP_PROOF_MISSING'
Assert (Test-Path $checkpointPath) 'HOTSWAP_CHECKPOINT_MISSING'
Assert (Test-Path $reportPath) 'HOTSWAP_REPORT_MISSING'
Assert (Test-Path $docPath) 'HOTSWAP_DOC_MISSING'
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$c=Get-Content $checkpointPath -Raw|ConvertFrom-Json
Assert ($p.status -eq 'PASS_AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1') 'HOTSWAP_STATUS_BAD'
Assert ($c.status -eq 'CHECKPOINT_BEFORE_STOP_GATED_AIMO') 'CHECKPOINT_STATUS_BAD'
Assert ($p.old_live.was_gated -eq $true) 'OLD_NOT_GATED'
Assert ($p.old_live.stopped -eq $true) 'OLD_NOT_STOPPED'
Assert ($p.old_live.forced_stop -eq $false) 'OLD_FORCED_STOP_SHOULD_BE_FALSE'
Assert ($p.new_live.gated -eq $false) 'NEW_LIVE_STILL_GATED'
Assert ($p.new_live.observed_expected_selection -eq $true) 'EXPECTED_SELECTION_NOT_OBSERVED'
Assert ($p.new_live.stderr_size -eq 0) 'NEW_LIVE_STDERR_NOT_ZERO'
Assert ($p.new_live.alive_after_proof -eq $true) 'NEW_LIVE_NOT_ALIVE_AFTER_PROOF'
Assert ($p.selection.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT') 'SELECTION_REASON_BAD'
Assert ($p.selection.task -eq 'build_source_agnostic_path_selector_v1') 'SELECTION_TASK_BAD'
Assert ($p.selection.lab_gate_enabled -eq $false) 'SELECTION_GATE_FLAG_BAD'
Assert ($p.selection.explicit_gate_required -eq $false) 'SELECTION_EXPLICIT_GATE_BAD'
Assert ($p.selection.legacy_selector_demoted -eq $true) 'SELECTION_LEGACY_DEMOTED_BAD'
Assert ($p.final_live.count -eq 1) 'FINAL_LIVE_COUNT_IN_PROOF_BAD'
Assert ($p.final_live.rollback_performed -eq $false) 'ROLLBACK_SHOULD_NOT_HAVE_OCCURRED'
Assert ($p.boundaries.child_agent_factory_readiness -eq 'NOT_PROVEN') 'CHILD_AGENT_BOUNDARY_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_NOW_BAD:{0}" -f @($liveNow).Count)
$cmd=[string]$liveNow[0].CommandLine
Assert ($cmd -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'CURRENT_LIVE_STILL_HAS_GATE'
Assert ($cmd -like ('*'+[string]$p.new_live.run_id+'*')) 'CURRENT_LIVE_RUN_ID_MISMATCH'
Assert ([int]$liveNow[0].ProcessId -eq [int]$p.new_live.pid) 'CURRENT_LIVE_PID_MISMATCH'
$stderrPath=[string]$p.new_live.stderr
Assert (Test-Path $stderrPath) 'NEW_STDERR_PATH_MISSING'
Assert ((Get-Item $stderrPath).Length -eq 0) 'NEW_STDERR_FILE_NOT_EMPTY'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 150) 'RUNTIME_SIZE_TOO_LARGE_AFTER_HOTSWAP'
$validation=[ordered]@{
  schema='aimo_default_no_gate_live_hotswap_validation_v1'
  status='PASS_AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1'
  proof_path=$proofPath
  checkpoint_path=$checkpointPath
  current_live_pid=[int]$liveNow[0].ProcessId
  current_live_run_id=[string]$p.new_live.run_id
  current_live_has_gate=$false
  selection_reason=[string]$p.selection.reason
  selected_task=[string]$p.selection.task
  runtime_size_mb=[Math]::Round($runtimeSize/1MB,2)
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$validationPath='tests/live_start/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1_VALIDATION.json'
$validation|ConvertTo-Json -Depth 80|Set-Content $validationPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1'
Write-Host ('VALIDATION_PATH='+$validationPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
