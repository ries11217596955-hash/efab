$ErrorActionPreference='SilentlyContinue'
$Root='C:\ProgramData\EFAB-Bridge-Monitor'
$Samples=Join-Path $Root 'samples.jsonl'
$StatePath=Join-Path $Root 'state.json'
$SummaryPath=Join-Path $Root 'daily_summary_latest.json'
$PrimaryUrl='https://scabbed-corner-gap.ngrok-free.dev/health'
function Bool($v){return [bool]$v}
$now=Get-Date
$bt=$null
try{$bt=(Get-Content 'H:\bridge\recovery_gateway_v1\bridge_token.txt' -Raw).Trim()}catch{}
$localRecovery=$false;$localPrimary=$false;$publicPrimary=$false
try{$localRecovery=Bool((Invoke-RestMethod 'http://127.0.0.1:18787/health' -Headers @{'X-Bridge-Token'=$bt} -TimeoutSec 5).ok)}catch{}
try{$localPrimary=Bool((Invoke-RestMethod 'http://127.0.0.1:18788/health' -Headers @{'X-Bridge-Token'=$bt} -TimeoutSec 5).ok)}catch{}
try{$publicPrimary=((Invoke-WebRequest $PrimaryUrl -UseBasicParsing -TimeoutSec 10).StatusCode -eq 200)}catch{}
$ngrokCount=(Get-Process ngrok -ErrorAction SilentlyContinue|Measure-Object).Count
$recoveryCount=@(Get-CimInstance Win32_Process|Where-Object{$_.Name -eq 'python.exe' -and $_.CommandLine -like '*recovery_gateway_v1\recovery_gateway.py*'}).Count
$primaryCount=@(Get-CimInstance Win32_Process|Where-Object{$_.Name -eq 'python.exe' -and $_.CommandLine -like '*uvicorn*bridge_app.main:app*18788*'}).Count
$taskNames=@('EFAB Bridge Boot SYSTEM','EFAB Recovery Gateway SYSTEM','EFAB Ngrok Primary SYSTEM','EFAB Ngrok Watchdog SYSTEM')
$taskFailures=0
$taskStates=[ordered]@{}
foreach($n in $taskNames){$t=Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue;if(-not $t){$taskFailures++;$taskStates[$n]='MISSING';continue};$i=$t|Get-ScheduledTaskInfo;$r=[int64]$i.LastTaskResult;$ok=($r -eq 0 -or $r -eq 267009 -or $r -eq 267014);if(-not $ok){$taskFailures++};$taskStates[$n]=[ordered]@{state=[string]$t.State;last_result=$r}}
$healthy=($localRecovery -and $localPrimary -and $publicPrimary -and $ngrokCount -eq 1 -and $recoveryCount -eq 1 -and $primaryCount -eq 1 -and $taskFailures -eq 0)
$state=[ordered]@{in_outage=$false;outage_started_at=$null;last_healthy_at=$null}
if(Test-Path $StatePath){try{$state=Get-Content $StatePath -Raw|ConvertFrom-Json}catch{}}
$event='healthy_sample';$recoverySeconds=$null
if(-not $healthy -and -not [bool]$state.in_outage){$state.in_outage=$true;$state.outage_started_at=$now.ToUniversalTime().ToString('o');$event='outage_start'}
elseif(-not $healthy){$event='outage_continue'}
elseif($healthy -and [bool]$state.in_outage){$start=[datetime]$state.outage_started_at;$recoverySeconds=[int](($now.ToUniversalTime())-$start.ToUniversalTime()).TotalSeconds;$state.in_outage=$false;$state.outage_started_at=$null;$event='outage_recovered'}
if($healthy){$state.last_healthy_at=$now.ToUniversalTime().ToString('o')}
$row=[ordered]@{ts=$now.ToUniversalTime().ToString('o');event=$event;healthy=$healthy;local_recovery=$localRecovery;local_primary=$localPrimary;public_primary=$publicPrimary;ngrok_process_count=$ngrokCount;recovery_process_count=$recoveryCount;primary_process_count=$primaryCount;duplicate_process_event=($ngrokCount -gt 1 -or $recoveryCount -gt 1 -or $primaryCount -gt 1);task_failure_count=$taskFailures;recovery_seconds=$recoverySeconds;task_states=$taskStates}
Add-Content -Path $Samples -Value ($row|ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
$state|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 $StatePath
$cutoff=$now.ToUniversalTime().AddDays(-7)
$rows=@();if(Test-Path $Samples){Get-Content $Samples -Tail 20000|ForEach-Object{try{$x=$_|ConvertFrom-Json;if([datetime]$x.ts -ge $cutoff){$rows+=$x}}catch{}}}
$total=$rows.Count;$healthyCount=@($rows|Where-Object{$_.healthy}).Count;$outages=@($rows|Where-Object{$_.event -eq 'outage_start'}).Count;$recoveries=@($rows|Where-Object{$_.event -eq 'outage_recovered' -and $_.recovery_seconds -ne $null}|ForEach-Object{[int]$_.recovery_seconds});$dup=@($rows|Where-Object{$_.duplicate_process_event}).Count;$taskFailSamples=@($rows|Where-Object{[int]$_.task_failure_count -gt 0}).Count
$summary=[ordered]@{generated_at=$now.ToUniversalTime().ToString('o');window_days=7;window_start=$cutoff.ToString('o');sample_count=$total;availability_percent=if($total){[math]::Round(($healthyCount*100.0/$total),4)}else{$null};outage_count=$outages;max_recovery_seconds=if($recoveries.Count){($recoveries|Measure-Object -Maximum).Maximum}else{0};duplicate_process_events=$dup;task_failure_samples=$taskFailSamples;current_status=if($healthy){'HEALTHY'}else{'DEGRADED'};maturity=if($total -ge 10080){'SEVEN_DAY_WINDOW_COMPLETE'}else{'ACCUMULATING'}}
$summary|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 $SummaryPath
