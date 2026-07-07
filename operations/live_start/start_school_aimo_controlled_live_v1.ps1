param(
  [int]$SchoolCount = 1000000,
  [string]$TopicsPlan = 'useful_school_live_parallel_default_v1',
  [string]$AimoMode = 'Continuous',
  [int]$ObserveSeconds = 60,
  [int]$HeartbeatSeconds = 10,
  [string]$OwnerAuthProofPath = 'tests/live_readiness/SCHOOL_AIMO_LIVE_READINESS_GATE_OWNER_AUTH_PROOF.json',
  [string]$ProofPath = 'tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_START_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function GitStatusShort(){ @(git status --short --untracked-files=all) }
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 50 | Set-Content -Path $Path -Encoding UTF8 }
function ReadJson($Path){ if(-not(Test-Path $Path)){ return $null }; return (Get-Content $Path -Raw | ConvertFrom-Json) }
function RuntimeProcesses(){
  @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and (
      [string]$_.CommandLine -like '* -File *run_agent_school.ps1*' -or
      [string]$_.CommandLine -like '* -File *run_autonomous_inner_motor.ps1*'
    )
  })
}
$started=Get-Date
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
git fetch origin main --quiet
$aheadBehind=(git rev-list --left-right --count HEAD...origin/main).Trim()
$aheadBehindNorm=($aheadBehind -replace '\s+',' ')
$dirtyBefore=GitStatusShort
if(($RepoRoot -replace '\\','/') -ne 'H:/efab'){ throw "REPO_ROOT_MISMATCH:$RepoRoot" }
if($branch -ne 'main'){ throw "BRANCH_MISMATCH:$branch" }
if($origin -ne 'https://github.com/ries11217596955-hash/efab.git'){ throw "ORIGIN_MISMATCH:$origin" }
if($aheadBehindNorm -ne '0 0'){ throw "AHEAD_BEHIND_NOT_SYNCED:$aheadBehind" }
if($dirtyBefore.Count -gt 0){ throw "DIRTY_BEFORE_LIVE_START:$($dirtyBefore -join ';')" }
$go=ReadJson $OwnerAuthProofPath
if(-not $go){ throw 'OWNER_AUTH_GO_PROOF_MISSING' }
if($go.status -ne 'PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_GO_V1' -or $go.live_ready -ne $true -or $go.owner_live_authorized -ne $true){ throw 'OWNER_AUTH_GO_PROOF_NOT_GO' }
$activeBefore=@(RuntimeProcesses)
if($activeBefore.Count -gt 0){ throw "ACTIVE_RUNTIME_CONFLICT_BEFORE_LIVE_START:$($activeBefore.Count)" }
$runId='controlled_live_school_aimo_v1_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runRoot=Join-Path '.runtime/live_start' $runId
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$schoolOut=Join-Path $runRoot 'school.stdout.txt'
$schoolErr=Join-Path $runRoot 'school.stderr.txt'
$aimoOut=Join-Path $runRoot 'aimo.stdout.txt'
$aimoErr=Join-Path $runRoot 'aimo.stderr.txt'
$passportPath=Join-Path $runRoot 'LIVE_START_PASSPORT.json'
$stopAllPath=Join-Path $runRoot 'STOP_ALL_REQUESTED.txt'
$aimoRunId='live_aimo_' + $runId
$schoolArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/school/run_agent_school.ps1','-Count',[string]$SchoolCount,'-Mode','Live','-TopicsPlan',$TopicsPlan)
$aimoArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1','-Mode',$AimoMode,'-RunId',$aimoRunId)
$passport=[ordered]@{
  schema='school_aimo_controlled_live_start_passport_v1'
  run_id=$runId
  owner_authorized=$true
  owner_auth_proof=$OwnerAuthProofPath
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind }
  commands=[ordered]@{ school=@($schoolArgs); aimo=@($aimoArgs) }
  controls=[ordered]@{ run_root=$runRoot; stop_all_path=$stopAllPath; school_stdout=$schoolOut; school_stderr=$schoolErr; aimo_stdout=$aimoOut; aimo_stderr=$aimoErr }
  boundary='Owner-authorized controlled live start. Processes are started detached; this proof covers launch and initial observation, not long-term PROVEN_LIVE soak.'
  created_at=$started.ToString('o')
}
WriteJson $passportPath $passport
$school=Start-Process -FilePath 'powershell' -ArgumentList $schoolArgs -RedirectStandardOutput $schoolOut -RedirectStandardError $schoolErr -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3
$aimo=Start-Process -FilePath 'powershell' -ArgumentList $aimoArgs -RedirectStandardOutput $aimoOut -RedirectStandardError $aimoErr -PassThru -WindowStyle Hidden
$heartbeats=@()
$deadline=(Get-Date).AddSeconds($ObserveSeconds)
while((Get-Date) -lt $deadline){
  Start-Sleep -Seconds $HeartbeatSeconds
  try{$school.Refresh()}catch{}
  try{$aimo.Refresh()}catch{}
  $hb=[ordered]@{ at=(Get-Date).ToString('o'); school_pid=$school.Id; school_alive=(-not $school.HasExited); aimo_pid=$aimo.Id; aimo_alive=(-not $aimo.HasExited); elapsed_seconds=[Math]::Round(((Get-Date)-$started).TotalSeconds,3) }
  $heartbeats += $hb
  Write-Host ("LIVE_HEARTBEAT school_alive={0} aimo_alive={1} elapsed={2}" -f $hb.school_alive,$hb.aimo_alive,$hb.elapsed_seconds)
}
try{$school.Refresh()}catch{}
try{$aimo.Refresh()}catch{}
$activeAfter=@(RuntimeProcesses)
$blockers=@()
if($school.HasExited){ $blockers += "SCHOOL_EXITED_EARLY:$($school.ExitCode)" }
if($aimo.HasExited){ $blockers += "AIMO_EXITED_EARLY:$($aimo.ExitCode)" }
if(@($heartbeats | Where-Object { -not $_.school_alive }).Count -gt 0){ $blockers += 'SCHOOL_NOT_ALIVE_IN_HEARTBEAT' }
if(@($heartbeats | Where-Object { -not $_.aimo_alive }).Count -gt 0){ $blockers += 'AIMO_NOT_ALIVE_IN_HEARTBEAT' }
if($activeAfter.Count -lt 2){ $blockers += "ACTIVE_RUNTIME_PROCESS_COUNT_TOO_LOW:$($activeAfter.Count)" }
$status='PASS_SCHOOL_AIMO_CONTROLLED_LIVE_START_V1'
if($blockers.Count -gt 0){ $status='FAIL_SCHOOL_AIMO_CONTROLLED_LIVE_START_V1' }
$result=[ordered]@{
  schema='school_aimo_controlled_live_start_v1'
  status=$status
  proof_label='PROVEN_LIVE_INITIAL_CONTROLLED_START_NOT_LONG_SOAK'
  run_id=$runId
  owner_authorized=$true
  owner_auth_proof=$OwnerAuthProofPath
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind; dirty_before=@($dirtyBefore); active_processes_before=$activeBefore.Count; active_processes_after=$activeAfter.Count }
  launch=[ordered]@{ school_pid=$school.Id; aimo_pid=$aimo.Id; school_alive=(-not $school.HasExited); aimo_alive=(-not $aimo.HasExited); school_count=$SchoolCount; topics_plan=$TopicsPlan; aimo_mode=$AimoMode; aimo_run_id=$aimoRunId }
  controls=[ordered]@{ run_root=$runRoot; passport_path=$passportPath; stop_all_path=$stopAllPath; school_stdout=$schoolOut; school_stderr=$schoolErr; aimo_stdout=$aimoOut; aimo_stderr=$aimoErr }
  observation=[ordered]@{ observe_seconds=$ObserveSeconds; heartbeat_seconds=$HeartbeatSeconds; heartbeats=@($heartbeats) }
  blockers=@($blockers)
  boundary='Initial live start proof only. It proves owner-authorized launch and initial parallel aliveness, not long-term live soak.'
  live_started=($status -eq 'PASS_SCHOOL_AIMO_CONTROLLED_LIVE_START_V1')
  started_at=$started.ToString('o')
  finished_at=(Get-Date).ToString('o')
}
WriteJson $ProofPath $result
Write-Host "LIVE_START_STATUS=$status"
Write-Host "LIVE_RUN_ID=$runId"
Write-Host "SCHOOL_PID=$($school.Id)"
Write-Host "AIMO_PID=$($aimo.Id)"
Write-Host "SCHOOL_ALIVE=$(-not $school.HasExited)"
Write-Host "AIMO_ALIVE=$(-not $aimo.HasExited)"
Write-Host "STOP_ALL_PATH=$stopAllPath"
Write-Host "LIVE_START_PROOF=$ProofPath"
Write-Host "BLOCKERS=$($blockers -join ',')"
if($status -notlike 'PASS_*'){ exit 1 }