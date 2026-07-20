param(
  [string]$BridgeRoot = 'C:\EFAB\bridge',
  [string]$RepoRoot = 'C:\EFAB\efab',
  [string]$PublicDomain = 'scabbed-corner-gap.ngrok-free.dev',
  [string]$WifiProfile = '',
  [switch]$SkipDependencyInstall,
  [switch]$SkipStartup
)
$ErrorActionPreference='Stop'
$PackRoot=Split-Path $PSScriptRoot -Parent
$Payload=Join-Path $PackRoot 'payload'
if(-not(Test-Path $Payload)){throw 'PAYLOAD_MISSING'}
$python=(Get-Command python.exe -ErrorAction SilentlyContinue).Source
if(-not $python){$python=(Get-Command py.exe -ErrorAction SilentlyContinue).Source}
if(-not $python){throw 'PYTHON_NOT_FOUND'}
$ngrok=(Get-Command ngrok.exe -ErrorAction SilentlyContinue).Source
if(-not $ngrok){throw 'NGROK_NOT_FOUND'}
New-Item -ItemType Directory -Force -Path $BridgeRoot | Out-Null
Copy-Item (Join-Path $Payload '*') $BridgeRoot -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $BridgeRoot 'runtime'),(Join-Path $BridgeRoot 'runs'),(Join-Path $BridgeRoot 'reports'),(Join-Path $BridgeRoot 'resilience_state'),(Join-Path $BridgeRoot 'resilience_logs') | Out-Null
if(-not $SkipDependencyInstall){& $python -m pip install -e $BridgeRoot; if($LASTEXITCODE -ne 0){throw 'PIP_INSTALL_FAILED'}}
$tokenFile=[Environment]::ExpandEnvironmentVariables('%USERPROFILE%\.bridge\bridge_action_token.txt')
if(-not(Test-Path $tokenFile)){throw "BRIDGE_TOKEN_MISSING: $tokenFile"}
$super=Get-Content (Join-Path $BridgeRoot 'efab_resilience_supervisor_v3.template.ps1') -Raw
$super=$super.Replace('__BRIDGE_ROOT__',$BridgeRoot.Replace("'","''"))
$super=$super.Replace('__PYTHON_EXE__',$python.Replace("'","''"))
$super=$super.Replace('__WIFI_PROFILE__',$WifiProfile.Replace("'","''"))
$super=$super.Replace('__PUBLIC_HEALTH_URL__',('https://'+$PublicDomain+'/health'))
$super | Set-Content (Join-Path $BridgeRoot 'efab_resilience_supervisor_v3.ps1') -Encoding UTF8
$keeper=Get-Content (Join-Path $BridgeRoot 'efab_supervisor_keeper_v1.template.ps1') -Raw
$keeper=$keeper.Replace('__BRIDGE_ROOT__',$BridgeRoot.Replace("'","''"))
$keeper | Set-Content (Join-Path $BridgeRoot 'efab_supervisor_keeper_v1.ps1') -Encoding UTF8
$launcher=@"
`$ErrorActionPreference='Stop'
`$env:PYTHONPATH='$BridgeRoot\src'
`$env:BRIDGE_ROOT='$BridgeRoot'
`$env:BRIDGE_AUTH_TOKEN=(Get-Content '$tokenFile' -Raw).Trim()
Start-Process -FilePath '$python' -ArgumentList @('-m','uvicorn','bridge_app.main:app','--host','127.0.0.1','--port','18787') -WorkingDirectory '$BridgeRoot' -WindowStyle Hidden
Start-Sleep 3
Start-Process -FilePath '$ngrok' -ArgumentList @('http','--domain=$PublicDomain','18787') -WorkingDirectory '$BridgeRoot' -WindowStyle Hidden
"@
$launcher | Set-Content (Join-Path $BridgeRoot 'start_gpt_action_bridge_dev.ps1') -Encoding UTF8
if(-not $SkipStartup){
  $startup=[Environment]::GetFolderPath('Startup')
  $ws=New-Object -ComObject WScript.Shell
  foreach($item in @(
    @{Name='EFAB Resilience Supervisor.lnk';Script='efab_resilience_supervisor_v3.ps1'},
    @{Name='EFAB Supervisor Keeper.lnk';Script='efab_supervisor_keeper_v1.ps1'}
  )){
    $lnk=Join-Path $startup $item.Name
    $s=$ws.CreateShortcut($lnk)
    $s.TargetPath='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    $s.Arguments='-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File "'+(Join-Path $BridgeRoot $item.Script)+'"'
    $s.WorkingDirectory=$BridgeRoot
    $s.WindowStyle=7
    $s.Save()
  }
}
[ordered]@{
  status='INSTALLED_NOT_YET_VALIDATED'
  bridge_root=$BridgeRoot
  repo_root=$RepoRoot
  python=$python
  ngrok=$ngrok
  public_domain=$PublicDomain
  token_file=$tokenFile
  startup_installed=(-not $SkipStartup)
}|ConvertTo-Json -Depth 4|Set-Content (Join-Path $BridgeRoot 'install_manifest.json') -Encoding UTF8
Write-Output 'INSTALL_COMPLETE_RUN_VALIDATE_NEXT'
