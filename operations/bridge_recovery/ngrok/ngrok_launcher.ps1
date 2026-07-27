$ErrorActionPreference='Stop'
$Root='C:\ProgramData\EFAB-Ngrok'
$Ngrok='C:\Windows\ngrok.exe'
$Config=Join-Path $Root 'ngrok.yml'
$Policy=Join-Path $Root 'traffic_policy.yml'
$BridgeTokenPath='C:\ProgramData\EFAB\bridge_action_token.txt'
$Log=Join-Path $Root 'launcher.log'
$StatePath=Join-Path $Root 'circuit_state.json'
$MaxRapidFailures=5
$RapidWindowSeconds=120
$QuarantineSeconds=300
$Mutex=New-Object Threading.Mutex($false,'Global\EFAB_NGROK_PRIMARY_SINGLETON')
if(-not $Mutex.WaitOne(0,$false)){exit 0}
function Log($event,$data){$row=[ordered]@{ts=(Get-Date).ToUniversalTime().ToString('o');event=$event;data=$data};Add-Content -Path $Log -Value ($row|ConvertTo-Json -Compress -Depth 6) -Encoding UTF8}
function Load-State(){if(Test-Path $StatePath){try{return Get-Content $StatePath -Raw|ConvertFrom-Json}catch{}};return [pscustomobject]@{failures=@();quarantined_until=$null}}
function Save-State($s){$s|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 $StatePath}
function Write-Policy($token){
  $safe=$token.Replace('"','\"')
  $body=@"
on_http_request:
  - actions:
      - type: add-headers
        config:
          headers:
            x-bridge-token: "$safe"
"@
  [IO.File]::WriteAllText($Policy,$body,[Text.UTF8Encoding]::new($false))
  icacls $Policy /inheritance:r /grant:r 'SYSTEM:F' 'Administrators:F'|Out-Null
}
try{
  while($true){
    $state=Load-State
    $now=(Get-Date).ToUniversalTime()
    if($state.quarantined_until){$until=[datetime]$state.quarantined_until;if($now -lt $until){Log 'circuit_quarantined' @{until=$until.ToString('o')};Start-Sleep 30;continue}else{$state.quarantined_until=$null;$state.failures=@();Save-State $state;Log 'circuit_half_open' @{}}}
    if(Get-Process ngrok -ErrorAction SilentlyContinue){Start-Sleep 10;continue}
    $token=(Get-Content $BridgeTokenPath -Raw).Trim();if([string]::IsNullOrWhiteSpace($token)){throw 'EMPTY_BRIDGE_TOKEN'}
    Write-Policy $token
    $started=Get-Date
    Log 'ngrok_start' @{version=((& $Ngrok version)-join ' ')}
    & $Ngrok http http://127.0.0.1:18787 --config $Config --log (Join-Path $Root 'ngrok.log') --log-format json --traffic-policy-file $Policy
    $runtime=[int]((Get-Date)-$started).TotalSeconds
    Log 'ngrok_exit' @{exit_code=$LASTEXITCODE;runtime_seconds=$runtime}
    if($runtime -lt $RapidWindowSeconds){
      $state=Load-State;$cutoff=(Get-Date).ToUniversalTime().AddSeconds(-$RapidWindowSeconds);$f=@($state.failures|Where-Object{[datetime]$_ -ge $cutoff});$f+=,(Get-Date).ToUniversalTime().ToString('o');$state.failures=$f
      if($f.Count -ge $MaxRapidFailures){$state.quarantined_until=(Get-Date).ToUniversalTime().AddSeconds($QuarantineSeconds).ToString('o');Log 'circuit_open' @{failures=$f.Count;quarantine_seconds=$QuarantineSeconds}}
      Save-State $state
    }else{$state=Load-State;$state.failures=@();Save-State $state}
    Start-Sleep 5
  }
}finally{$Mutex.ReleaseMutex();$Mutex.Dispose()}
