$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 80|Set-Content $Path -Encoding UTF8}
function RuntimeProcesses(){ @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and ([string]$_.CommandLine -like '* -File *run_agent_school.ps1*' -or [string]$_.CommandLine -like '* -File *run_autonomous_inner_motor.ps1*') }) }
$passportPath='self_model/organ_passports/operations_live_start/ORGAN_PASSPORT_V1.json'
$startProofPath='tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_START_V1_PROOF.json'
$stopProofPath='tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_STOP_V1_PROOF.json'
$reportPath='reports/self_development/OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1.json'
$proofPath='tests/self_development/OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1_PROOF.json'
foreach($p in @($passportPath,$startProofPath,$stopProofPath)){Assert (Test-Path $p) "MISSING:$p"}
$start=Get-Content $startProofPath -Raw|ConvertFrom-Json
$stop=Get-Content $stopProofPath -Raw|ConvertFrom-Json
Assert ($start.status -eq 'PASS_SCHOOL_AIMO_CONTROLLED_LIVE_START_V1') 'START_STATUS_BAD'
Assert ($start.owner_authorized -eq $true) 'START_OWNER_AUTH_BAD'
Assert ($start.live_started -eq $true) 'START_LIVE_STARTED_BAD'
Assert ($start.launch.school_alive -eq $true) 'START_SCHOOL_NOT_ALIVE'
Assert ($start.launch.aimo_alive -eq $true) 'START_AIMO_NOT_ALIVE'
Assert (@($start.observation.heartbeats).Count -ge 2) 'START_HEARTBEATS_TOO_LOW'
Assert (@($start.blockers).Count -eq 0) 'START_BLOCKERS_PRESENT'
Assert ($stop.status -eq 'PASS_SCHOOL_AIMO_CONTROLLED_LIVE_STOP_V1') 'STOP_STATUS_BAD'
Assert ($stop.school_alive_after -eq $false) 'STOP_SCHOOL_STILL_ALIVE'
Assert ($stop.aimo_alive_after -eq $false) 'STOP_AIMO_STILL_ALIVE'
Assert (@($stop.blockers).Count -eq 0) 'STOP_BLOCKERS_PRESENT'
$active=@(RuntimeProcesses)
Assert ($active.Count -eq 0) "RUNTIME_STILL_ACTIVE:$($active.Count)"
$pp=Get-Content $passportPath -Raw|ConvertFrom-Json
$pp.maturity='VALIDATED_LIVE_INITIAL'
$pp.live_or_lab_status='PROVEN_LIVE_INITIAL_STOPPED'
$pp.last_validated_at=(Get-Date).ToString('o')
$pp.proof_refs=@(($pp.proof_refs + $startProofPath + $stopProofPath + $reportPath + $proofPath)|Where-Object{$_}|Sort-Object -Unique)
$pp.gaps=@('long-running live soak still required before PASSPORT_ACTIVE','PASSPORT_ACTIVE still requires separate activation validator and owner acceptance','initial controlled live cycle is proven and stopped')
$pp.safety_boundaries=@(($pp.safety_boundaries + 'initial live proof does not equal long soak' + 'controlled stop proof required after live start')|Where-Object{$_}|Sort-Object -Unique)
$pp|ConvertTo-Json -Depth 60|Set-Content $passportPath -Encoding UTF8
$report=[ordered]@{
 schema='operations_live_start_controlled_live_cycle_v1'
 status='PASS_OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1'
 organ_id='operations_live_start'
 passport_path=$passportPath
 start=[ordered]@{status=$start.status;run_id=$start.run_id;school_pid=$start.launch.school_pid;aimo_pid=$start.launch.aimo_pid;heartbeats=@($start.observation.heartbeats).Count;live_started=$start.live_started;owner_authorized=$start.owner_authorized;proof_path=$startProofPath}
 stop=[ordered]@{status=$stop.status;school_alive_after=$stop.school_alive_after;aimo_alive_after=$stop.aimo_alive_after;forced_stop_pids=@($stop.forced_stop_pids);proof_path=$stopProofPath}
 decision='PROMOTE_TO_VALIDATED_LIVE_INITIAL_STOPPED'
 boundaries=[ordered]@{controlled_live_cycle_only=$true;passport_active_created=$false;long_soak_proven=$false;runtime_active_after=$false;live_process_touched=$true;stopped_after_proof=$true}
 created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
 schema='operations_live_start_controlled_live_cycle_v1_proof'
 status='PASS_OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1'
 organ_id='operations_live_start'
 decision='PROMOTE_TO_VALIDATED_LIVE_INITIAL_STOPPED'
 maturity='VALIDATED_LIVE_INITIAL'
 live_or_lab_status='PROVEN_LIVE_INITIAL_STOPPED'
 start_pass=$true
 stop_pass=$true
 heartbeats=@($start.observation.heartbeats).Count
 owner_authorized=$true
 live_process_touched=$true
 runtime_active_after=$false
 passport_active_created=$false
 long_soak_proven=$false
 report_path=$reportPath
 passport_path=$passportPath
 created_at=(Get-Date).ToString('o')
}
WJson $report $reportPath
WJson $proof $proofPath
Write-Host 'LIVE_CYCLE_PASS=PASS_OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1'
Write-Host 'PASSPORT_MATURITY=VALIDATED_LIVE_INITIAL'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LIVE_INITIAL_STOPPED'
Write-Host 'RUNTIME_ACTIVE_AFTER=false'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
