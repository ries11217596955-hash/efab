$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$route='route_locks/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_V1_ROUTE_LOCK.md'
$health='reports/self_development/NEXT_ROUTE_PREFLIGHT_HEALTH_AUDIT_V1.json'
$doc='docs/operations/NEXT_SEQUENCE_AND_HEALTH_AUDIT_20260708.md'
Assert (Test-Path $route) 'ROUTE_LOCK_MISSING'
Assert (Test-Path $health) 'HEALTH_AUDIT_MISSING'
Assert (Test-Path $doc) 'HEALTH_DOC_MISSING'
$h=Get-Content $health -Raw|ConvertFrom-Json
Assert ($h.status -eq 'PASS_WITH_WARNINGS_NEXT_ROUTE_PREFLIGHT_HEALTH_AUDIT_V1') 'HEALTH_STATUS_BAD'
Assert ($h.sequence_decision.step_1 -like 'Runtime autonomy hardening*') 'STEP1_BAD'
Assert ($h.sequence_decision.step_4 -like 'Child-agent factory deferred*') 'CHILD_AGENT_DEFER_BAD'
Assert ($h.repo.dirty -eq $false) 'REPO_DIRTY_FLAG_BAD'
Assert ($h.repo.tracked_size_mb -lt 50) 'TRACKED_REPO_TOO_LARGE_FOR_CURRENT_BOUNDARY'
Assert ($h.runtime.runtime_size_mb -gt 1000) 'RUNTIME_SIZE_WARNING_EXPECTED_BUT_MISSING'
Assert ($h.runtime.school_checkpoint_size_mb -gt 1000) 'SCHOOL_CHECKPOINT_WARNING_EXPECTED_BUT_MISSING'
Assert ($h.school.last_status -eq 'PASS_REAL_FACTORY_DIGEST_RECALL_USE_V1') 'SCHOOL_LAST_STATUS_BAD'
Assert ($h.school.ready_atoms -eq 1000000) 'SCHOOL_READY_ATOMS_BAD'
Assert ($h.school.process_alive -eq $false) 'SCHOOL_PROCESS_EXPECTED_NOT_ALIVE_IN_AUDIT'
Assert ($h.school.runtime_ready -eq $false) 'SCHOOL_RUNTIME_READY_BOUNDARY_EXPECTED_FALSE'
Assert ($h.live_aimo.count -eq 1) 'LIVE_AIMO_COUNT_BAD'
Assert ($h.live_aimo.gate_present -eq $true) 'CURRENT_LIVE_GATE_EXPECTED_TRUE_BEFORE_NEXT_ROUTE'
$r=Get-Content $route -Raw
$needles=@(
  'Runtime autonomy hardening',
  'Deeper self-model',
  'Memory/provenance hardening',
  'Child-agent factory deferred',
  'PHASE_H - Controlled live hotswap without explicit source-agnostic gate',
  'checkpoint mass without explicit cleanup authority',
  'Do not claim child-agent readiness'
)
foreach($needle in $needles){ Assert ($r -like ('*'+$needle+'*')) ("ROUTE_NEEDLE_MISSING:{0}" -f $needle) }
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_NOW_BAD:{0}" -f @($liveNow).Count)
$proof=[ordered]@{
  schema='next_route_lock_and_health_audit_validation_v1'
  status='PASS_NEXT_ROUTE_LOCK_AND_HEALTH_AUDIT_V1'
  route_lock=$route
  health_audit=$health
  doc=$doc
  live_pid_now=[int]$liveNow[0].ProcessId
  child_agent_deferred=$true
  runtime_large_warning_recorded=$true
  school_completed_not_alive_boundary_recorded=$true
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/NEXT_ROUTE_LOCK_AND_HEALTH_AUDIT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_NEXT_ROUTE_LOCK_AND_HEALTH_AUDIT_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
