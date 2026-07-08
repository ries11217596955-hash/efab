$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$reportJson='reports/self_development/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_ROUTE_EXECUTION_REPORT_V1.json'
$reportMd='docs/operations/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_ROUTE_EXECUTION_REPORT_V1.md'
Assert (Test-Path $reportJson) 'REPORT_JSON_MISSING'
Assert (Test-Path $reportMd) 'REPORT_MD_MISSING'
$r=Get-Content $reportJson -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ROUTE_EXECUTION_REPORT_V1_OWNER_REVIEW_REQUIRED') 'REPORT_STATUS_BAD'
foreach($p in $r.completed.PSObject.Properties){ Assert ([string]$p.Value -notmatch 'MISSING|FAIL|BAD|UNREADABLE') ("COMPLETED_PROOF_BAD:{0}:{1}" -f $p.Name,$p.Value) }
Assert ($r.live_current.live_aimo_count -eq 1) 'LIVE_COUNT_BAD'
Assert ($r.live_current.has_explicit_gate -eq $false) 'LIVE_HAS_GATE_BAD'
Assert ($r.proven.source_agnostic_selector_is_default_in_live -eq $true) 'LIVE_DEFAULT_NOT_PROVEN_FLAG_BAD'
Assert ($r.proven.explicit_gate_not_required_for_live_default -eq $true) 'GATE_NOT_REQUIRED_FLAG_BAD'
Assert ($r.proven.live_runtime_hygiene_cleanup_enabled -eq $true) 'RUNTIME_HYGIENE_FLAG_BAD'
Assert ($r.not_proven.child_agent_factory_readiness -eq $true) 'CHILD_AGENT_NOT_PROVEN_MISSING'
Assert ($r.not_proven.emergency_fallback_when_source_agnostic_report_missing_or_invalid -eq $true) 'FALLBACK_NOT_PROVEN_MISSING'
Assert ($r.blockers_before_large_school.school_runtime_hygiene_repair_required -eq $true) 'SCHOOL_HYGIENE_BLOCKER_MISSING'
Assert ($r.owner_review_gate.status -eq 'OWNER_REVIEW_REQUIRED') 'OWNER_REVIEW_GATE_MISSING'
Assert ($r.owner_review_gate.do_not_continue_to_next_route_without_owner_acceptance -eq $true) 'OWNER_GATE_CONTINUE_RULE_BAD'
Assert ($r.recommended_next_route.name -eq 'DEEPER_SELF_MODEL_V1') 'NEXT_ROUTE_BAD'
Assert ($r.runtime_size_mb -lt 80) 'RUNTIME_SIZE_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_NOW_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'CURRENT_LIVE_HAS_GATE'
foreach($t in @('.runtime/compact_memory_intake_v1/checkpoints','.runtime/file_atom_absorption')){ Assert (-not(Test-Path $t)) ("TRANSIENT_EXISTS:{0}" -f $t) }
$proof=[ordered]@{
  schema='aimo_default_source_agnostic_selection_route_execution_report_validation_v1'
  status='PASS_AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_ROUTE_EXECUTION_REPORT_V1'
  report_json=$reportJson
  report_md=$reportMd
  current_live_pid=[int]$liveNow[0].ProcessId
  current_live_has_gate=$false
  runtime_size_mb=[Math]::Round((Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum/1MB,2)
  owner_review_required=$true
  next_route='DEEPER_SELF_MODEL_V1'
  child_agent_factory_readiness='NOT_PROVEN'
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_ROUTE_EXECUTION_REPORT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_ROUTE_EXECUTION_REPORT_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
