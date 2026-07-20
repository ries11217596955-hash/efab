param(
  [int]$IntervalSeconds=60,
  [int]$FailureThreshold=2,
  [int]$NetworkRetrySeconds=60
)
$ErrorActionPreference='Continue'
$Root='__BRIDGE_ROOT__'
$StateDir=Join-Path $Root 'resilience_state'
$LogDir=Join-Path $Root 'resilience_logs'
$LockFile=Join-Path $StateDir 'supervisor_v3.lock'
$StateFile=Join-Path $StateDir 'state_v3.json'
$LogFile=Join-Path $LogDir ('supervisor-v3-' + (Get-Date -Format 'yyyyMMdd') + '.log')
$StartScript=Join-Path $Root 'start_gpt_action_bridge_dev.ps1'
$LocalHealth='http://127.0.0.1:18787/health'
$PublicHealth='__PUBLIC_HEALTH_URL__'
$NgrokApi='http://127.0.0.1:4040/api/tunnels'
$Python='__PYTHON_EXE__'
$WifiProfile='__WIFI_PROFILE__'
New-Item -ItemType Directory -Force -Path $StateDir,$LogDir | Out-Null
function Log([string]$m){Add-Content -Path $LogFile -Encoding UTF8 -Value "$(Get-Date -Format o) $m"}
function Save-State($o){$o|ConvertTo-Json -Depth 6|Set-Content -Path $StateFile -Encoding UTF8}
function Test-Internet{try{return (Test-NetConnection 1.1.1.1 -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue)}catch{return $false}}
function Test-Local{try{$r=Invoke-RestMethod $LocalHealth -TimeoutSec 5;return ($r.ok -eq $true -and $r.status -eq 'ok')}catch{return $false}}
function Test-Ngrok{try{$t=Invoke-RestMethod $NgrokApi -TimeoutSec 5;return (@($t.tunnels|Where-Object{$_.config.addr -match '127.0.0.1:18787'}).Count -gt 0)}catch{return $false}}
function Test-Public{try{$r=Invoke-WebRequest $PublicHealth -Headers @{'ngrok-skip-browser-warning'='true'} -UseBasicParsing -TimeoutSec 8;return ($r.StatusCode -eq 200 -and $r.Content -match '"ok"\s*:\s*true')}catch{return $false}}
function Get-BridgePid{@(Get-NetTCPConnection -LocalPort 18787 -State Listen -ErrorAction SilentlyContinue|Select-Object -ExpandProperty OwningProcess -Unique)}
function Get-NgrokPid{@(Get-Process ngrok -ErrorAction SilentlyContinue|Select-Object -ExpandProperty Id)}
function Start-Bridge([string]$reason){
  if(Test-Local){Log "BRIDGE_START_SKIP healthy reason=$reason";return}
  foreach($p in @(Get-BridgePid)){Stop-Process -Id $p -Force -ErrorAction SilentlyContinue;Log "BRIDGE_KILL pid=$p reason=$reason"}
  if(-not(Test-Path $Python)){Log "BRIDGE_START_BLOCKED python_missing=$Python";return}
  Start-Process -FilePath $Python -ArgumentList @('-m','uvicorn','bridge_app.main:app','--host','127.0.0.1','--port','18787') -WorkingDirectory $Root -WindowStyle Hidden
  Log "BRIDGE_START reason=$reason"
}
function Start-Ngrok([string]$reason){
  if(Test-Ngrok){Log "NGROK_START_SKIP healthy reason=$reason";return}
  foreach($p in @(Get-NgrokPid)){Stop-Process -Id $p -Force -ErrorAction SilentlyContinue;Log "NGROK_KILL pid=$p reason=$reason"}
  if(Test-Path $StartScript){Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Minimized','-File',$StartScript) -WorkingDirectory $Root -WindowStyle Minimized;Log "NGROK_ROUTE_START reason=$reason"}else{Log "NGROK_START_BLOCKED script_missing=$StartScript"}
}
function Reconnect-Wifi{try{netsh wlan connect name="$WifiProfile"|Out-Null;Log "WIFI_RECONNECT_REQUEST profile=$WifiProfile"}catch{Log "WIFI_RECONNECT_ERROR $($_.Exception.Message)"}}
try{
  if(Test-Path $LockFile){$old=Get-Content $LockFile -ErrorAction SilentlyContinue|ConvertFrom-Json -ErrorAction SilentlyContinue;if($old.pid -and (Get-Process -Id $old.pid -ErrorAction SilentlyContinue)){Log "DUPLICATE_EXIT existing_pid=$($old.pid)";exit 0}}
  @{pid=$PID;started=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content $LockFile -Encoding UTF8
  Log "SUPERVISOR_V3_BEGIN pid=$PID user=$([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
  $localFail=0;$ngrokFail=0;$publicFail=0;$restartBridge=0;$restartNgrok=0;$lastNetRetry=[datetime]::MinValue;$lastLoggedState=$null
  while($true){
    $internet=Test-Internet
    if(-not $internet){
      if(((Get-Date)-$lastNetRetry).TotalSeconds -ge $NetworkRetrySeconds){Reconnect-Wifi;$lastNetRetry=Get-Date}
      $state=[ordered]@{timestamp=(Get-Date).ToString('o');status='WAIT_NETWORK';internet=$false;local=(Test-Local);ngrok=(Test-Ngrok);public=$false;bridge_failures=$localFail;ngrok_failures=$ngrokFail;public_failures=$publicFail;bridge_restarts=$restartBridge;ngrok_restarts=$restartNgrok;pid=$PID}
      Save-State $state;Log 'WAIT_NETWORK';Start-Sleep $IntervalSeconds;continue
    }
    $local=Test-Local;$ngrok=Test-Ngrok;$public=$false
    if($local -and $ngrok){$public=Test-Public}
    if($local){$localFail=0}else{$localFail++}
    if($ngrok){$ngrokFail=0}else{$ngrokFail++}
    if($public){$publicFail=0}else{$publicFail++}
    if($localFail -ge $FailureThreshold){Start-Bridge "health_timeout n=$localFail";$restartBridge++;$localFail=0;Start-Sleep 12}
    if($ngrokFail -ge $FailureThreshold){Start-Ngrok "tunnel_missing n=$ngrokFail";$restartNgrok++;$ngrokFail=0;Start-Sleep 15}
    if($local -and $ngrok -and -not $public -and $publicFail -ge $FailureThreshold){Start-Ngrok "public_unreachable n=$publicFail";$restartNgrok++;$publicFail=0;Start-Sleep 15}
    $status=if($local -and $ngrok -and $public){'OK'}else{'DEGRADED'}
    Save-State ([ordered]@{timestamp=(Get-Date).ToString('o');status=$status;internet=$internet;local=$local;ngrok=$ngrok;public=$public;bridge_failures=$localFail;ngrok_failures=$ngrokFail;public_failures=$publicFail;bridge_restarts=$restartBridge;ngrok_restarts=$restartNgrok;pid=$PID})
    if($lastLoggedState -ne $status){Log "STATE status=$status internet=$internet local=$local ngrok=$ngrok public=$public";$lastLoggedState=$status}
    $keeperLock=Join-Path $StateDir 'keeper.lock'
    $keeperAlive=$false
    if(Test-Path $keeperLock){
      try{$k=Get-Content $keeperLock -Raw|ConvertFrom-Json;if($k.pid -and (Get-Process -Id $k.pid -ErrorAction SilentlyContinue)){$keeperAlive=$true}}catch{}
    }
    if(-not $keeperAlive){
      $keeperScript=Join-Path $Root 'efab_supervisor_keeper_v1.ps1'
      if(Test-Path $keeperScript){Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Minimized','-File',$keeperScript) -WindowStyle Minimized;Log 'KEEPER_RESTART_REQUESTED'}else{Log "KEEPER_MISSING path=$keeperScript"}
    }
    Start-Sleep $IntervalSeconds
  }
}finally{try{if(Test-Path $LockFile){$lf=Get-Content $LockFile -Raw|ConvertFrom-Json -ErrorAction SilentlyContinue;if($lf.pid -eq $PID){Remove-Item $LockFile -Force -ErrorAction SilentlyContinue}}}catch{};Log 'SUPERVISOR_V3_END'}



