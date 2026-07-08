$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$route='route_locks/AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_V1_ROUTE_LOCK.md'
$health='reports/self_development/NEXT_ROUTE_PREFLIGHT_HEALTH_AUDIT_V1.json'
$gap='reports/self_development/SCHOOL_RUNTIME_HYGIENE_GAP_V1.json'
Assert (Test-Path $route) 'ROUTE_LOCK_MISSING'
Assert (Test-Path $health) 'HEALTH_AUDIT_MISSING'
Assert (Test-Path $gap) 'SCHOOL_HYGIENE_GAP_MISSING'
$r=Get-Content $route -Raw
foreach($needle in @('SCHOOL_RUNTIME_HYGIENE_REPAIR_V1','School runtime hygiene is NOT clean','Do not run another large School job')){ Assert ($r -like ('*'+$needle+'*')) ("ROUTE_MISSING:{0}" -f $needle) }
$h=Get-Content $health -Raw|ConvertFrom-Json
Assert ($h.runtime.runtime_size_mb_after_cleanup -lt 100) 'AFTER_CLEANUP_RUNTIME_SIZE_BAD'
Assert ($h.runtime.reports_size_mb -lt 5) 'REPORTS_SIZE_TOO_LARGE'
Assert ($h.school.runtime_hygiene_gap -eq 'SCHOOL_RUNTIME_HYGIENE_REPAIR_V1_REQUIRED_BEFORE_LARGE_SCHOOL_RERUNS') 'SCHOOL_GAP_FLAG_BAD'
$g=Get-Content $gap -Raw|ConvertFrom-Json
Assert ($g.status -eq 'SCHOOL_RUNTIME_HYGIENE_REPAIR_REQUIRED') 'GAP_STATUS_BAD'
Assert ($g.label -eq 'NOT_CRASH_BUT_RUNTIME_HYGIENE_DEFECT') 'GAP_LABEL_BAD'
Assert ($g.evidence.school_last_status -eq 'PASS_REAL_FACTORY_DIGEST_RECALL_USE_V1') 'SCHOOL_STATUS_BAD'
Assert ($g.evidence.runtime_after_cleanup_mb -lt 100) 'GAP_AFTER_SIZE_BAD'
Assert ($g.evidence.reports_size_mb -lt 5) 'GAP_REPORT_SIZE_BAD'
Assert (@($g.required_future_repair) -contains 'runtime_budget_validator') 'RUNTIME_BUDGET_VALIDATOR_REPAIR_MISSING'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 100) 'CURRENT_RUNTIME_TOO_LARGE'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
$proof=[ordered]@{
  schema='school_runtime_hygiene_gap_validation_v1'
  status='PASS_SCHOOL_RUNTIME_HYGIENE_GAP_V1'
  gap_report=$gap
  route_lock=$route
  health_audit=$health
  current_runtime_size_mb=[Math]::Round($runtimeSize/1MB,2)
  live_pid_now=[int]$liveNow[0].ProcessId
  reports_not_bloated=$true
  school_hygiene_future_repair_recorded=$true
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/SCHOOL_RUNTIME_HYGIENE_GAP_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_SCHOOL_RUNTIME_HYGIENE_GAP_V1'
Write-Host ('PROOF_PATH='+$proofPath)
