param(
 [string]$BridgeRoot='C:\EFAB\bridge',
 [string]$PrimaryTokenPath='C:\ProgramData\EFAB\bridge_action_token.txt',
 [string]$RescueTokenPath='C:\ProgramData\EFAB-Rescue\rescue_token.txt',
 [string]$PrimaryPublicUrl,
 [string]$RescuePublicUrl,
 [string]$ProofPath='C:\ProgramData\EFAB-Reboot-Proof\migration_validation_latest.json'
)
$ErrorActionPreference='SilentlyContinue'
$checks=[ordered]@{}
foreach($p in 18787,18788,18789,4040){$checks["port_$p"]=[bool](Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue)}
$bt=if(Test-Path $PrimaryTokenPath){(Get-Content $PrimaryTokenPath -Raw).Trim()}else{$null};$rt=if(Test-Path $RescueTokenPath){(Get-Content $RescueTokenPath -Raw).Trim()}else{$null}
try{$checks.health_18787=[bool](Invoke-RestMethod 'http://127.0.0.1:18787/health' -Headers @{'X-Bridge-Token'=$bt} -TimeoutSec 5).ok}catch{$checks.health_18787=$false}
try{$checks.health_18788=[bool](Invoke-RestMethod 'http://127.0.0.1:18788/health' -Headers @{'X-Bridge-Token'=$bt} -TimeoutSec 5).ok}catch{$checks.health_18788=$false}
try{$checks.health_18789=[bool](Invoke-RestMethod 'http://127.0.0.1:18789/health' -Headers @{Authorization="Bearer $rt"} -TimeoutSec 5).ok}catch{$checks.health_18789=$false}
if($PrimaryPublicUrl){try{$checks.public_primary=((Invoke-WebRequest ($PrimaryPublicUrl.TrimEnd('/')+'/health') -UseBasicParsing -TimeoutSec 10).StatusCode -eq 200)}catch{$checks.public_primary=$false}}
if($RescuePublicUrl){try{$checks.public_rescue=[bool](Invoke-RestMethod ($RescuePublicUrl.TrimEnd('/')+'/health') -Headers @{Authorization="Bearer $rt"} -TimeoutSec 10).ok}catch{$checks.public_rescue=$false}}
$taskNames=@('EFAB Bridge Boot SYSTEM','EFAB Recovery Gateway SYSTEM','EFAB Rescue Control SYSTEM','EFAB Rescue Watchdog SYSTEM','EFAB Ngrok Primary SYSTEM','EFAB Ngrok Watchdog SYSTEM')
foreach($n in $taskNames){$checks['task_'+($n -replace ' ','_')]=[bool](Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue)}
$pass=$true;foreach($v in $checks.Values){if(-not [bool]$v){$pass=$false;break}}
$proof=[ordered]@{timestamp=(Get-Date).ToUniversalTime().ToString('o');status=if($pass){'PASS'}else{'FAIL'};checks=$checks;bridge_root=$BridgeRoot};New-Item -ItemType Directory -Force -Path (Split-Path $ProofPath -Parent)|Out-Null;$proof|ConvertTo-Json -Depth 8|Set-Content -Encoding UTF8 $ProofPath;$proof|ConvertTo-Json -Depth 8;if(-not $pass){exit 1}
