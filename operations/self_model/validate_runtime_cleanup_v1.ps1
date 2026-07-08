$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$reportPath='reports/self_development/RUNTIME_CLEANUP_V1_REPORT.json'
$proofPath='tests/self_development/RUNTIME_CLEANUP_V1_PROOF.json'
$docPath='docs/operations/RUNTIME_CLEANUP_V1_REPORT.md'
Assert (Test-Path $reportPath) 'RUNTIME_CLEANUP_REPORT_MISSING'
Assert (Test-Path $proofPath) 'RUNTIME_CLEANUP_PROOF_MISSING'
Assert (Test-Path $docPath) 'RUNTIME_CLEANUP_DOC_MISSING'
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_RUNTIME_CLEANUP_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_RUNTIME_CLEANUP_V1') 'PROOF_STATUS_BAD'
Assert ($r.runtime.size_mb_before -gt 4000) 'BEFORE_SIZE_TOO_SMALL_FOR_CLEANUP_CLAIM'
Assert ($r.runtime.size_mb_after -lt 100) 'AFTER_SIZE_TOO_LARGE'
Assert ($r.runtime.freed_mb -gt 4000) 'FREED_SIZE_TOO_SMALL'
Assert ($p.active_memory_mutated -eq $false -and $p.live_process_touched -eq $false) 'MUTATION_FLAGS_BAD'
foreach($path in @($p.preserved_paths_checked)){ Assert (Test-Path $path) ("PRESERVED_PATH_MISSING:{0}" -f $path) }
foreach($path in @($p.deleted_paths)){ Assert (-not(Test-Path $path)) ("DELETED_PATH_STILL_EXISTS:{0}" -f $path) }
$trackedRuntime=@(git ls-files .runtime)
Assert ($trackedRuntime.Count -eq 0) 'TRACKED_RUNTIME_FILES_PRESENT'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 100) 'CURRENT_RUNTIME_SIZE_TOO_LARGE'
$active=Get-Content .runtime/active_compact_semantic_memory_v1/manifest.json -Raw|ConvertFrom-Json
Assert ($active.status -eq 'PASS_COMPACT_SEMANTIC_DIGESTION_ORGAN_V1') 'ACTIVE_MEMORY_STATUS_BAD'
$school=Get-Content .runtime/school_runs/school_factory_digest_use_real_1000000_20260707_140233/AGENT_SCHOOL_CANONICAL_ENTRYPOINT_V1.json -Raw|ConvertFrom-Json
Assert ($school.status -eq 'PASS_REAL_FACTORY_DIGEST_RECALL_USE_V1') 'SCHOOL_CANONICAL_STATUS_BAD'
Assert ($school.ready_atoms -eq 1000000) 'SCHOOL_READY_ATOMS_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -like '*UseSourceAgnosticPathSelectionLabGate*') 'LIVE_AIMO_GATE_MISSING'
$validation=[ordered]@{
  schema='runtime_cleanup_v1_current_validation'
  status='PASS_RUNTIME_CLEANUP_V1_CURRENT_VALIDATION'
  report_path=$reportPath
  proof_path=$proofPath
  current_runtime_size_mb=[Math]::Round($runtimeSize/1MB,2)
  live_pid_now=[int]$liveNow[0].ProcessId
  tracked_runtime_count=$trackedRuntime.Count
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$validationPath='tests/self_development/RUNTIME_CLEANUP_V1_CURRENT_VALIDATION.json'
$validation|ConvertTo-Json -Depth 80|Set-Content $validationPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_RUNTIME_CLEANUP_V1_CURRENT_VALIDATION'
Write-Host ('VALIDATION_PATH='+$validationPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
