param([string]$BridgeRoot='C:\EFAB\bridge',[string]$PublicDomain='scabbed-corner-gap.ngrok-free.dev')
$ErrorActionPreference='SilentlyContinue'
$local=$false;$public=$false;$super=$false;$keeper=$false
try{$h=Invoke-RestMethod 'http://127.0.0.1:18787/health' -TimeoutSec 5;$local=($h.ok -eq $true)}catch{}
try{$r=Invoke-WebRequest ('https://'+$PublicDomain+'/health') -Headers @{'ngrok-skip-browser-warning'='true'} -UseBasicParsing -TimeoutSec 8;$public=($r.StatusCode -eq 200 -and $r.Content -match '"ok"\s*:\s*true')}catch{}
foreach($x in @(@{Name='supervisor';Lock='supervisor_v3.lock'},@{Name='keeper';Lock='keeper.lock'})){ $p=Join-Path $BridgeRoot ('resilience_state\'+$x.Lock);$alive=$false;if(Test-Path $p){try{$o=Get-Content $p -Raw|ConvertFrom-Json;$alive=[bool](Get-Process -Id $o.pid -ErrorAction SilentlyContinue)}catch{}};if($x.Name -eq 'supervisor'){$super=$alive}else{$keeper=$alive}}
$proof=[ordered]@{timestamp=(Get-Date).ToString('o');bridge_root=$BridgeRoot;local=$local;public=$public;supervisor_alive=$super;keeper_alive=$keeper;status=if($local -and $public -and $super -and $keeper){'PASS'}else{'FAIL'}}
$dir=Join-Path $BridgeRoot 'resilience_state';New-Item -ItemType Directory -Force -Path $dir|Out-Null;$path=Join-Path $dir ('restore_proof_'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.json');$proof|ConvertTo-Json -Depth 4|Set-Content $path -Encoding UTF8;Get-Content $path -Raw;if($proof.status -ne 'PASS'){exit 1}
