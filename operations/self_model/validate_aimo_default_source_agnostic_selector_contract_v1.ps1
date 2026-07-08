$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$contractPath='self_model/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTOR_CONTRACT_V1.json'
$docPath='docs/operations/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTOR_CONTRACT_V1.md'
Assert (Test-Path $contractPath) 'CONTRACT_MISSING'
Assert (Test-Path $docPath) 'DOC_MISSING'
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($c.schema -eq 'aimo_default_source_agnostic_selector_contract_v1') 'SCHEMA_BAD'
Assert ($c.status -eq 'ACTIVE_CONTRACT') 'STATUS_BAD'
Assert ($c.default_selector.must_be_default -eq $true) 'DEFAULT_SELECTOR_NOT_REQUIRED'
Assert ($c.default_selector.requires_explicit_gate_for_normal_operation -eq $false) 'DEFAULT_SELECTOR_REQUIRES_GATE_BAD'
Assert ($c.legacy_selector.status -eq 'DEMOTE_TO_BOUNDED_FALLBACK') 'LEGACY_NOT_DEMOTED'
Assert (@($c.legacy_selector.forbidden_as_default_authority) -contains 'ACTIVE_MEMORY_DELTA_FROM_SCHOOL') 'LEGACY_SCHOOL_REASON_NOT_FORBIDDEN'
Assert (@($c.legacy_selector.forbidden_as_default_authority) -contains 'latest_runtime_packet_as_authority') 'LATEST_AUTHORITY_NOT_FORBIDDEN'
Assert ($c.school_policy.school_is_required_for_selection -eq $false) 'SCHOOL_REQUIRED_BAD'
Assert ($c.school_policy.large_school_rerun_blocked_until -eq 'SCHOOL_RUNTIME_HYGIENE_REPAIR_V1') 'SCHOOL_RERUN_BLOCK_BAD'
foreach($f in @('selected_next_action','identity_alignment','selected_gap','proof_needed','validator_needed','source_refs_used','source_refs_rejected','why_not_latest_signal','why_not_school_dependency','fallback_if_source_missing')){ Assert (@($c.default_selector.required_output_fields) -contains $f) ("REQUIRED_FIELD_MISSING:{0}" -f $f) }
foreach($r in @('school_as_required_brain','latest_signal_as_authority','agentlife_residue_as_direction')){ Assert (@($c.default_selector.required_rejections) -contains $r) ("REQUIRED_REJECTION_MISSING:{0}" -f $r) }
Assert ($c.default_selector.required_fallback -eq 'bounded_static_self_build_task_from_gap_map') 'FALLBACK_BAD'
Assert ($c.acceptance.contract_only -eq $true) 'CONTRACT_ONLY_BAD'
Assert ($c.acceptance.no_aimo_runtime_code_change -eq $true) 'NO_RUNTIME_CODE_CHANGE_BAD'
Assert ($c.acceptance.no_live_process_touch -eq $true) 'NO_LIVE_TOUCH_BAD'
Assert (@($c.not_proven) -contains 'default_no_gate_live_selection') 'NOT_PROVEN_LIVE_NO_GATE_MISSING'
$aimo='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
Assert (Test-Path $aimo) 'AIMO_SCRIPT_MISSING'
$gateMarkers=@(Select-String -Path $aimo -Pattern 'UseSourceAgnosticPathSelectionLabGate' -ErrorAction SilentlyContinue)
$legacyMarkers=@(Select-String -Path $aimo -Pattern 'ACTIVE_MEMORY_DELTA_FROM_SCHOOL' -ErrorAction SilentlyContinue)
Assert ($gateMarkers.Count -gt 0) 'CURRENT_GATE_MARKER_EXPECTED'
Assert ($legacyMarkers.Count -gt 0) 'CURRENT_LEGACY_MARKER_EXPECTED_FOR_GAP'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 100) 'RUNTIME_SIZE_GUARD_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
$proof=[ordered]@{
  schema='aimo_default_source_agnostic_selector_contract_validation_v1'
  status='PASS_AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTOR_CONTRACT_V1'
  contract_path=$contractPath
  doc_path=$docPath
  current_gate_marker_count=$gateMarkers.Count
  current_legacy_marker_count=$legacyMarkers.Count
  current_runtime_size_mb=[Math]::Round($runtimeSize/1MB,2)
  live_pid_now=[int]$liveNow[0].ProcessId
  contract_only=$true
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  next_phase='PHASE_C_AIMO_DEFAULT_PATH_LAB_IMPLEMENTATION'
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTOR_CONTRACT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTOR_CONTRACT_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
