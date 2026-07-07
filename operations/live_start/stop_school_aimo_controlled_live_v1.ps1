param(
  [string]$ProofPath = 'tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_START_V1_PROOF.json',
  [int]$GraceSeconds = 30
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8 }
if(-not(Test-Path $ProofPath)){ throw "LIVE_START_PROOF_MISSING:$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
$started=Get-Date
$stopAll=$P.controls.stop_all_path
Set-Content -Path $stopAll -Value "stop requested at $($started.ToString('o')) for $($P.run_id)" -Encoding UTF8
$aimoStop=$null
if($P.launch.aimo_run_id){
  $aimoStop=Join-Path (Join-Path '.runtime/autonomous_inner_motor/test_life_runs' $P.launch.aimo_run_id) 'STOP_REQUESTED.txt'
  New-Item -ItemType Directory -Force -Path (Split-Path $aimoStop -Parent) | Out-Null
  Set-Content -Path $aimoStop -Value "stop requested by controlled live stop at $($started.ToString('o'))" -Encoding UTF8
}
$schoolPid=[int]$P.launch.school_pid
$aimoPid=[int]$P.launch.aimo_pid
$deadline=(Get-Date).AddSeconds($GraceSeconds)
$events=@()
while((Get-Date) -lt $deadline){
  Start-Sleep -Seconds 2
  $schoolAlive=$null -ne (Get-Process -Id $schoolPid -ErrorAction SilentlyContinue)
  $aimoAlive=$null -ne (Get-Process -Id $aimoPid -ErrorAction SilentlyContinue)
  $events += [ordered]@{ at=(Get-Date).ToString('o'); school_alive=$schoolAlive; aimo_alive=$aimoAlive }
  if(-not $aimoAlive){ break }
}
$forced=@()
foreach($procId in @($aimoPid,$schoolPid)){
  $proc=Get-Process -Id $procId -ErrorAction SilentlyContinue
  if($proc){ Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue; $forced += $procId }
}
Start-Sleep -Seconds 2
$schoolFinal=$null -ne (Get-Process -Id $schoolPid -ErrorAction SilentlyContinue)
$aimoFinal=$null -ne (Get-Process -Id $aimoPid -ErrorAction SilentlyContinue)
$status='PASS_SCHOOL_AIMO_CONTROLLED_LIVE_STOP_V1'
$blockers=@()
if($schoolFinal){$blockers+='SCHOOL_STILL_ALIVE'}
if($aimoFinal){$blockers+='AIMO_STILL_ALIVE'}
if($blockers.Count -gt 0){$status='FAIL_SCHOOL_AIMO_CONTROLLED_LIVE_STOP_V1'}
$out=[ordered]@{schema='school_aimo_controlled_live_stop_v1';status=$status;run_id=$P.run_id;stop_all_path=$stopAll;aimo_stop_path=$aimoStop;school_pid=$schoolPid;aimo_pid=$aimoPid;events=@($events);forced_stop_pids=@($forced);school_alive_after=$schoolFinal;aimo_alive_after=$aimoFinal;blockers=@($blockers);started_at=$started.ToString('o');finished_at=(Get-Date).ToString('o')}
$StopProof='tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_STOP_V1_PROOF.json'
WriteJson $StopProof $out
Write-Host "LIVE_STOP_STATUS=$status"
Write-Host "LIVE_STOP_PROOF=$StopProof"
Write-Host "SCHOOL_ALIVE_AFTER=$schoolFinal"
Write-Host "AIMO_ALIVE_AFTER=$aimoFinal"
Write-Host "FORCED_STOP_PIDS=$($forced -join ',')"
if($status -notlike 'PASS_*'){ exit 1 }