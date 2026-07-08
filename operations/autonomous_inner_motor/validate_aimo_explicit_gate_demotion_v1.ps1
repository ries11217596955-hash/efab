$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$reportPath='reports/self_development/AIMO_EXPLICIT_GATE_DEMOTION_V1.json'
$docPath='docs/operations/AIMO_EXPLICIT_GATE_DEMOTION_V1.md'
Assert (Test-Path $reportPath) 'REPORT_MISSING'
Assert (Test-Path $docPath) 'DOC_MISSING'
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_AIMO_EXPLICIT_GATE_DEMOTION_V1') 'STATUS_BAD'
Assert ($r.decision -eq 'KEEP_AS_EMERGENCY_DEBUG_SWITCH_NOT_DEFAULT_AUTHORITY') 'DECISION_BAD'
Assert ($r.evidence.live_runtime_hygiene_status -eq 'PASS_AIMO_RUNTIME_HYGIENE_LIVE_HOTSWAP_V1') 'LIVE_HYGIENE_EVIDENCE_BAD'
Assert ($r.evidence.default_no_gate_live_status -eq 'PASS_AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1') 'DEFAULT_LIVE_EVIDENCE_BAD'
Assert ($r.evidence.legacy_demotion_status -eq 'PASS_AIMO_LEGACY_SELECTOR_DEMOTION_V1') 'LEGACY_DEMOTION_EVIDENCE_BAD'
Assert ($r.evidence.current_live_count -eq 1) 'LIVE_COUNT_BAD'
Assert ($r.evidence.current_live_has_gate -eq $false) 'CURRENT_LIVE_HAS_GATE_BAD'
Assert ($r.code_state.switch_still_present -eq $true) 'SWITCH_EXPECTED_PRESENT'
Assert ($r.code_state.gate_reason_still_present -eq $true) 'GATE_REASON_EXPECTED_PRESENT'
Assert ($r.code_state.default_reason_present -eq $true) 'DEFAULT_REASON_MISSING'
Assert ($r.code_state.explicit_gate_required_false_present -eq $true) 'EXPLICIT_GATE_FALSE_MISSING'
Assert ($r.code_state.legacy_demoted_marker_present -eq $true) 'LEGACY_DEMOTED_MARKER_MISSING'
Assert ($r.policy.default_behavior -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_DEFAULT_WITHOUT_GATE') 'DEFAULT_POLICY_BAD'
Assert (@($r.policy.forbidden_use) -contains 'normal live default') 'FORBIDDEN_DEFAULT_MISSING'
Assert ($r.boundaries.switch_removed -eq $false) 'SWITCH_REMOVAL_FALSE_CLAIM'
Assert ($r.boundaries.emergency_fallback_missing_source_report_not_proven -eq $true) 'FALLBACK_BOUNDARY_BAD'
Assert ($r.boundaries.child_agent_factory_readiness -eq 'NOT_PROVEN') 'CHILD_AGENT_BOUNDARY_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_NOW_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'CURRENT_LIVE_GATE_PRESENT_NOW'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 80) 'RUNTIME_SIZE_TOO_LARGE'
$proof=[ordered]@{
  schema='aimo_explicit_gate_demotion_validation_v1'
  status='PASS_AIMO_EXPLICIT_GATE_DEMOTION_V1'
  report_path=$reportPath
  doc_path=$docPath
  current_live_pid=[int]$liveNow[0].ProcessId
  current_live_has_gate=$false
  gate_kept_as_emergency_debug_switch=$true
  gate_not_default_authority=$true
  switch_removed=$false
  runtime_size_mb=[Math]::Round($runtimeSize/1MB,2)
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/autonomous_inner_motor/AIMO_EXPLICIT_GATE_DEMOTION_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_EXPLICIT_GATE_DEMOTION_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
