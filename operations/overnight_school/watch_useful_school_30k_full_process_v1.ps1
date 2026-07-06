param(
  [string]$ManagedRunId = 'managed_run-20260629-204736-8a6b4c8f',
  [string]$RunDir = '',
  [int]$RefreshSeconds = 5,
  [int]$TailLines = 18
)
$ErrorActionPreference='Continue'
Set-Location 'C:/Users/Azerbaijan/Downloads/e-factory-agent-builder'

function Read-JsonSafe([string]$Path){
  if(Test-Path $Path){
    try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { return $null }
  }
  return $null
}
function Get-LatestSchoolRunDir(){
  $root='H:/bridge/overnight_school_runs'
  if(Test-Path $root){
    return (Get-ChildItem $root -Directory -Filter 'useful_school_30k_full_process_v1_*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).FullName
  }
  return $null
}
function Get-ProcessCount(){
  $patterns=@('run_useful_school_30k_full_process_v1.ps1','USEFUL_SCHOOL_30K_FULL_PROCESS','managed_run-20260629-204736-8a6b4c8f')
  $self=$PID
  $p=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessId -ne $self -and -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and (@($patterns | Where-Object { [string]$_.CommandLine -like "*$_*" }).Count -gt 0)
  }
  return @($p).Count
}

while($true){
  Clear-Host
  $now=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  Write-Host "EFAB 30K OVERNIGHT SCHOOL WATCH" -ForegroundColor Cyan
  Write-Host "TIME: $now"
  Write-Host "Press Ctrl+C to close this watcher. It is read-only."
  Write-Host ""

  try {
    $health=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:18787/health' -TimeoutSec 2
    Write-Host "BRIDGE_18787: OK $($health.StatusCode)" -ForegroundColor Green
  } catch {
    Write-Host "BRIDGE_18787: ERROR $($_.Exception.Message)" -ForegroundColor Red
  }

  $procCount=Get-ProcessCount
  if($procCount -gt 0){ Write-Host "RUN_PROCESS: ACTIVE count=$procCount" -ForegroundColor Green }
  else { Write-Host "RUN_PROCESS: not found or finished" -ForegroundColor Yellow }

  $stdout="H:/bridge/runs/$ManagedRunId/stdout.txt"
  $stderr="H:/bridge/runs/$ManagedRunId/stderr.txt"
  $managedReport="H:/bridge/reports/$ManagedRunId.json"
  $managed=Read-JsonSafe $managedReport
  if($managed){
    Write-Host "MANAGED_RUN: $($managed.status) elapsed_ms=$($managed.elapsed_ms) pid=$($managed.pid)" -ForegroundColor Cyan
  } else {
    Write-Host "MANAGED_RUN: report not available yet ($ManagedRunId)" -ForegroundColor DarkYellow
  }

  if([string]::IsNullOrWhiteSpace($RunDir)){ $CurrentRunDir=Get-LatestSchoolRunDir } else { $CurrentRunDir=$RunDir }
  Write-Host "SCHOOL_RUN_DIR: $CurrentRunDir"
  $live=$null
  if($CurrentRunDir){ $live=Read-JsonSafe (Join-Path $CurrentRunDir 'LIVE_STATUS.json') }
  if($live){
    Write-Host ""
    Write-Host "LIVE STATUS" -ForegroundColor Cyan
    Write-Host "status=$($live.status) chunk=$($live.chunk_completed)/$($live.chunk_count) accepted=$($live.accepted_total) rejected=$($live.rejected_total) deltas=$($live.promoted_delta_count)"
    Write-Host "state_hash=$($live.current_state_hash)"
    Write-Host "updated_utc=$($live.updated_utc) runtime_ready=$($live.runtime_ready)"
  } else {
    Write-Host "LIVE_STATUS: not created yet" -ForegroundColor Yellow
  }

  $repoProof='tests/accepted_atom_retention/USEFUL_SCHOOL_30K_FULL_PROCESS_V1_PROOF.json'
  $proof=Read-JsonSafe $repoProof
  if($proof){
    Write-Host ""
    Write-Host "FINAL PROOF" -ForegroundColor Green
    Write-Host "status=$($proof.status) final=$($proof.final_status)"
    Write-Host "accepted=$($proof.accepted_total) rejected=$($proof.rejected_total) chunks=$($proof.chunk_count) subchunks=$($proof.subchunk_count)"
    Write-Host "before_score=$($proof.before_score) after_score=$($proof.after_score) improved=$($proof.improved_case_count) critical_regressions=$($proof.critical_regression_count)"
    Write-Host "retrieval=$($proof.retrieval_status) decision_reuse=$($proof.decision_reuse_status) runtime_ready=$($proof.runtime_ready)"
  } else {
    Write-Host "FINAL_PROOF: not created yet" -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "LAST STDOUT" -ForegroundColor Cyan
  if(Test-Path $stdout){ Get-Content $stdout -Tail $TailLines } else { Write-Host "stdout not found: $stdout" }
  if(Test-Path $stderr){
    $errTail=Get-Content $stderr -Tail 8
    if($errTail){
      Write-Host ""
      Write-Host "LAST STDERR" -ForegroundColor Red
      $errTail
    }
  }

  Write-Host ""
  Write-Host "Refresh every $RefreshSeconds sec. Ctrl+C to exit."
  Start-Sleep -Seconds $RefreshSeconds
}
