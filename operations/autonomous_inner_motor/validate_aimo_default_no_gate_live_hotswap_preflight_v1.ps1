$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$reportPath='reports/self_development/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_PREFLIGHT_V1.json'
$docPath='docs/operations/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_PREFLIGHT_V1.md'
Assert (Test-Path $reportPath) 'PREFLIGHT_REPORT_MISSING'
Assert (Test-Path $docPath) 'PREFLIGHT_DOC_MISSING'
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_PREFLIGHT_V1') 'PREFLIGHT_STATUS_BAD'
Assert ($r.repo.ahead_behind -eq "0`t0") 'REPO_NOT_SYNCED'
Assert ($r.repo.dirty -eq $false) 'REPO_DIRTY_AT_REPORT_TIME'
foreach($p in $r.proof_dependencies.PSObject.Properties){ Assert ([string]$p.Value -notmatch 'MISSING|FAIL|BAD|UNREADABLE') ("DEPENDENCY_BAD:{0}:{1}" -f $p.Name,$p.Value) }
Assert ($r.code_markers.default_reason_present -eq $true) 'DEFAULT_REASON_MARKER_MISSING'
Assert ($r.code_markers.default_enabled_marker_present -eq $true) 'DEFAULT_ENABLED_MARKER_MISSING'
Assert ($r.code_markers.explicit_gate_required_false_present -eq $true) 'GATE_FALSE_MARKER_MISSING'
Assert ($r.code_markers.legacy_demoted_marker_present -eq $true) 'LEGACY_DEMOTED_MARKER_MISSING'
Assert ($r.live_now.live_aimo_count -eq 1) 'LIVE_AIMO_COUNT_BAD'
Assert ($r.live_now.currently_gated -eq $true) 'CURRENT_LIVE_EXPECTED_GATED_BEFORE_HOTSWAP'
Assert ($r.proposed_live_hotswap.expected_selection_reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT') 'EXPECTED_REASON_BAD'
Assert ($r.proposed_live_hotswap.expected_task -eq 'build_source_agnostic_path_selector_v1') 'EXPECTED_TASK_BAD'
Assert ($r.boundaries.live_hotswap_not_performed -eq $true) 'LIVE_HOTSWAP_BOUNDARY_BAD'
Assert ($r.boundaries.active_memory_purity_not_claimed -eq $true) 'ACTIVE_MEMORY_BOUNDARY_BAD'
Assert ($r.boundaries.child_agent_factory_readiness -eq 'NOT_PROVEN') 'CHILD_AGENT_BOUNDARY_BAD'
Assert ($r.runtime_size_mb -lt 100) 'RUNTIME_SIZE_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_NOW_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -like '*UseSourceAgnosticPathSelectionLabGate*') 'CURRENT_LIVE_GATE_MISSING_BEFORE_HOTSWAP'
$proof=[ordered]@{
  schema='aimo_default_no_gate_live_hotswap_preflight_validation_v1'
  status='PASS_AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_PREFLIGHT_V1'
  report_path=$reportPath
  doc_path=$docPath
  live_pid_now=[int]$liveNow[0].ProcessId
  live_hotswap_performed=$false
  safe_to_attempt_next_phase=$true
  boundaries=@('active_memory_purity_not_claimed','legacy_emergency_fallback_not_proven','child_agent_factory_not_proven')
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/live_start/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_PREFLIGHT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_PREFLIGHT_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
