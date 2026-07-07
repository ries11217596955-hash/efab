param(
  [string]$LiveStartProofPath = 'tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_START_V1_PROOF.json',
  [string]$AimoMode = 'SandboxTestLife',
  [int]$ObserveSeconds = 60,
  [int]$HeartbeatSeconds = 10,
  [string]$ProofPath = 'tests/live_start/AIMO_AGENT_ONLY_RESTART_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 40 | Set-Content -Path $Path -Encoding UTF8 }
if(-not(Test-Path $LiveStartProofPath)){ throw "LIVE_START_PROOF_MISSING:$LiveStartProofPath" }
$live=Get-Content $LiveStartProofPath -Raw | ConvertFrom-Json
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
git fetch origin main --quiet
$aheadBehind=(git rev-list --left-right --count HEAD...origin/main).Trim()
$dirty=@(git status --short --untracked-files=all)
if(($RepoRoot -replace '\\','/') -ne 'H:/efab'){ throw "ROOT_MISMATCH:$RepoRoot" }
if($branch -ne 'main'){ throw "BRANCH_MISMATCH:$branch" }
if($origin -ne 'https://github.com/ries11217596955-hash/efab.git'){ throw "ORIGIN_MISMATCH:$origin" }
if(($aheadBehind -replace '\s+',' ') -ne '0 0'){ throw "AHEAD_BEHIND_NOT_SYNCED:$aheadBehind" }
if($dirty.Count -gt 0){ throw "DIRTY_BEFORE_AIMO_RESTART:$($dirty -join ';')" }
$schoolPid=[int]$live.launch.school_pid
$schoolProcess=Get-Process -Id $schoolPid -ErrorAction SilentlyContinue
if(-not $schoolProcess){ throw "SCHOOL_NOT_ALIVE_DO_NOT_RESTART_AIMO:$schoolPid" }
$oldAimoPid=[int]$live.launch.aimo_pid
$oldAimoAlive=$null -ne (Get-Process -Id $oldAimoPid -ErrorAction SilentlyContinue)
if($oldAimoAlive){ throw "OLD_AIMO_STILL_ALIVE_NOT_RESTARTING:$oldAimoPid" }
$policy=Get-Content 'operations/autonomous_inner_motor/motor_policy.json' -Raw | ConvertFrom-Json
if(@($policy.allowed_modes) -notcontains $AimoMode){ throw "AIMO_MODE_DENIED_BY_POLICY:$AimoMode" }
$started=Get-Date
$restartId='aimo_agent_only_restart_v1_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runRoot=Join-Path (Join-Path $live.controls.run_root 'aimo_agent_restarts') $restartId
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$stdout=Join-Path $runRoot 'aimo.stdout.txt'
$stderr=Join-Path $runRoot 'aimo.stderr.txt'
$aimoRunId='live_aimo_' + $restartId
$args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1','-Mode',$AimoMode,'-RunId',$aimoRunId)
$proc=Start-Process -FilePath 'powershell' -ArgumentList $args -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
$heartbeats=@()
$deadline=(Get-Date).AddSeconds($ObserveSeconds)
while((Get-Date) -lt $deadline){
  Start-Sleep -Seconds $HeartbeatSeconds
  try{$proc.Refresh()}catch{}
  $schoolAlive=$null -ne (Get-Process -Id $schoolPid -ErrorAction SilentlyContinue)
  $hb=[ordered]@{ at=(Get-Date).ToString('o'); school_pid=$schoolPid; school_alive=$schoolAlive; old_aimo_pid=$oldAimoPid; new_aimo_pid=$proc.Id; new_aimo_alive=(-not $proc.HasExited); elapsed_seconds=[Math]::Round(((Get-Date)-$started).TotalSeconds,3) }
  $heartbeats += $hb
  Write-Host ("AIMO_RESTART_HEARTBEAT school_alive={0} new_aimo_alive={1} elapsed={2}" -f $hb.school_alive,$hb.new_aimo_alive,$hb.elapsed_seconds)
}
try{$proc.Refresh()}catch{}
$aimoProofPath=Join-Path (Join-Path '.runtime/autonomous_inner_motor/test_life_runs' $aimoRunId) 'TEST_LIFE_PROOF.json'
$aimoProof=$null
if(Test-Path $aimoProofPath){ $aimoProof=Get-Content $aimoProofPath -Raw | ConvertFrom-Json }
$stderrSize=0
if(Test-Path $stderr){ $stderrSize=(Get-Item $stderr).Length }
$blockers=@()
if($proc.HasExited){ $blockers += "NEW_AIMO_EXITED_EARLY:$($proc.ExitCode)" }
if(@($heartbeats | Where-Object { $_.school_alive -ne $true }).Count -gt 0){ $blockers += 'SCHOOL_NOT_ALIVE_DURING_AIMO_RESTART' }
if(@($heartbeats | Where-Object { $_.new_aimo_alive -ne $true }).Count -gt 0){ $blockers += 'AIMO_NOT_ALIVE_IN_HEARTBEAT' }
if($stderrSize -gt 0){ $blockers += "AIMO_STDERR_NOT_EMPTY:$stderrSize" }
if(-not $aimoProof){ $blockers += 'AIMO_TEST_LIFE_PROOF_MISSING' } else {
  if($aimoProof.school_state.active_detected -ne $true){ $blockers += 'AIMO_DID_NOT_DETECT_SCHOOL_ACTIVE' }
  if($aimoProof.stop_reason -ne 'RUNNING_UNTIL_STOP_FILE'){ $blockers += "AIMO_STOP_REASON_UNEXPECTED:$($aimoProof.stop_reason)" }
  if([int]$aimoProof.test_life.total_cycles -lt 1){ $blockers += 'AIMO_CYCLES_ZERO' }
  if($aimoProof.memory_before.status -eq 'ACTIVE_MEMORY_READ_ERROR'){ $blockers += 'AIMO_MEMORY_READ_ERROR' }
}
$status='PASS_AIMO_AGENT_ONLY_RESTART_V1'
if($blockers.Count -gt 0){ $status='FAIL_AIMO_AGENT_ONLY_RESTART_V1' }
$out=[ordered]@{
  schema='aimo_agent_only_restart_v1'
  status=$status
  proof_label='PROVEN_LIVE_AIMO_AGENT_ONLY_RESTART_WITH_SCHOOL_UNTOUCHED'
  restart_id=$restartId
  live_run_id=$live.run_id
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind; dirty_before=@($dirty) }
  school=[ordered]@{ pid=$schoolPid; alive_before=$true; untouched=$true }
  old_aimo=[ordered]@{ pid=$oldAimoPid; alive_before=$oldAimoAlive }
  new_aimo=[ordered]@{ pid=$proc.Id; mode=$AimoMode; run_id=$aimoRunId; alive=(-not $proc.HasExited); stdout=$stdout; stderr=$stderr; stderr_size=$stderrSize; proof_path=$aimoProofPath; cycles=if($aimoProof){$aimoProof.test_life.total_cycles}else{$null}; school_active=if($aimoProof){$aimoProof.school_state.active_detected}else{$null}; memory_before_status=if($aimoProof -and $aimoProof.memory_before){$aimoProof.memory_before.status}else{$null}; memory_before_available=if($aimoProof -and $aimoProof.memory_before){$aimoProof.memory_before.available}else{$null} }
  observation=[ordered]@{ observe_seconds=$ObserveSeconds; heartbeat_seconds=$HeartbeatSeconds; heartbeats=@($heartbeats) }
  blockers=@($blockers)
  boundary='Agent-only restart. School process is observed but not modified or stopped.'
  started_at=$started.ToString('o')
  finished_at=(Get-Date).ToString('o')
}
WriteJson $ProofPath $out
Write-Host "AIMO_RESTART_STATUS=$status"
Write-Host "AIMO_RESTART_PROOF=$ProofPath"
Write-Host "OLD_AIMO_PID=$oldAimoPid"
Write-Host "NEW_AIMO_PID=$($proc.Id)"
Write-Host "NEW_AIMO_ALIVE=$(-not $proc.HasExited)"
Write-Host "SCHOOL_UNTOUCHED=true"
Write-Host "AIMO_CYCLES=$($out.new_aimo.cycles)"
Write-Host "AIMO_MEMORY_BEFORE_STATUS=$($out.new_aimo.memory_before_status)"
Write-Host "BLOCKERS=$($blockers -join ',')"
if($status -notlike 'PASS_*'){ exit 1 }