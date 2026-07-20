param([string]$BridgeRoot='C:\EFAB\bridge',[string]$PublicDomain='scabbed-corner-gap.ngrok-free.dev')
$ErrorActionPreference='Stop'
foreach($name in 'keeper.lock','supervisor_v3.lock'){ $p=Join-Path $BridgeRoot ('resilience_state\'+$name);if(Test-Path $p){try{$o=Get-Content $p -Raw|ConvertFrom-Json;if($o.pid){Stop-Process -Id $o.pid -Force -ErrorAction SilentlyContinue}}catch{};Remove-Item $p -Force -ErrorAction SilentlyContinue}}
Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Minimized','-File',(Join-Path $BridgeRoot 'efab_supervisor_keeper_v1.ps1')) -WindowStyle Minimized
Start-Sleep 2
Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Minimized','-File',(Join-Path $BridgeRoot 'efab_resilience_supervisor_v3.ps1')) -WindowStyle Minimized
Start-Sleep 15
& (Join-Path $PSScriptRoot 'validate_bridge.ps1') -BridgeRoot $BridgeRoot -PublicDomain $PublicDomain
