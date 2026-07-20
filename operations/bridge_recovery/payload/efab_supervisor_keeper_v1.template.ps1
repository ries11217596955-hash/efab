param([int]$IntervalSeconds=120)
$ErrorActionPreference='Continue'
$Root='__BRIDGE_ROOT__'
$Supervisor=Join-Path $Root 'efab_resilience_supervisor_v3.ps1'
$StateDir=Join-Path $Root 'resilience_state'
$LogDir=Join-Path $Root 'resilience_logs'
$Lock=Join-Path $StateDir 'keeper.lock'
$Log=Join-Path $LogDir ('keeper-' + (Get-Date -Format 'yyyyMMdd') + '.log')
New-Item -ItemType Directory -Force -Path $StateDir,$LogDir | Out-Null
function KLog([string]$m){Add-Content -Path $Log -Encoding UTF8 -Value "$(Get-Date -Format o) $m"}
function Rotate-Logs{
  Get-ChildItem $LogDir -File -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-14)} | Remove-Item -Force -ErrorAction SilentlyContinue
}
try{
  if(Test-Path $Lock){$old=Get-Content $Lock -ErrorAction SilentlyContinue|ConvertFrom-Json -ErrorAction SilentlyContinue;if($old.pid -and (Get-Process -Id $old.pid -ErrorAction SilentlyContinue)){KLog "DUPLICATE_EXIT existing_pid=$($old.pid)";exit 0}}
  @{pid=$PID;started=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $Lock -Encoding UTF8
  KLog "KEEPER_BEGIN pid=$PID"
  while($true){
    Rotate-Logs
    $alive=$false
    $slock=Join-Path $StateDir 'supervisor_v3.lock'
    if(Test-Path $slock){
      $s=Get-Content $slock -ErrorAction SilentlyContinue|ConvertFrom-Json -ErrorAction SilentlyContinue
      if($s.pid -and (Get-Process -Id $s.pid -ErrorAction SilentlyContinue)){$alive=$true}
    }
    if(-not $alive){
      if(Test-Path $Supervisor){
        Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Minimized','-File',$Supervisor) -WindowStyle Minimized
        KLog 'SUPERVISOR_RESTART_REQUESTED'
        Start-Sleep 10
      } else { KLog "SUPERVISOR_MISSING path=$Supervisor" }
    } else { }
    Start-Sleep $IntervalSeconds
  }
}finally{try{if(Test-Path $Lock){$lf=Get-Content $Lock -Raw|ConvertFrom-Json -ErrorAction SilentlyContinue;if($lf.pid -eq $PID){Remove-Item $Lock -Force -ErrorAction SilentlyContinue}}}catch{};KLog 'KEEPER_END'}



