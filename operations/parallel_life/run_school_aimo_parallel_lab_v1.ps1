param(
  [int]$SchoolCount = 50000,
  [int]$MinAimoCycles = 3,
  [int]$MaxWaitSeconds = 600,
  [string]$TopicsPlan = 'operations/school/curriculum/topics/builder_night_school_topics_v1.json',
  [string]$ProofPath = 'tests/parallel_life/SCHOOL_AIMO_PARALLEL_LAB_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function WriteJson($Path,$Obj,[int]$Depth=50){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Obj | ConvertTo-Json -Depth $Depth | Set-Content -Path $Path -Encoding UTF8
}
function ReadJsonSafe($Path){ if(Test-Path $Path){ try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { return $null } }; return $null }
function GitStatusShort(){ return @((git status --short --untracked-files=all) | ForEach-Object {[string]$_}) }
function GetMatches(){
  $patterns=@('run_agent_school','run_autonomous_school_cycle','run_autonomous_inner_motor','compact_memory_intake','merge_compact_memory')
  return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and (@($patterns | Where-Object { [string]$_.CommandLine -like "*$_*" }).Count -gt 0)
  } | Select-Object ProcessId,Name,CommandLine)
}
function WaitProcExit($Proc,[int]$MaxSeconds){
  $start=Get-Date
  while(-not $Proc.HasExited){
    if(((Get-Date)-$start).TotalSeconds -gt $MaxSeconds){ return $false }
    Start-Sleep -Milliseconds 500
    try { $Proc.Refresh() } catch {}
  }
  return $true
}
$startedAt=Get-Date
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
$dirtyBefore=GitStatusShort
if($RepoRoot -replace '\\','/' -ne 'H:/efab'){ throw "REPO_ROOT_MISMATCH:$RepoRoot" }
if($branch -ne 'main'){ throw "BRANCH_MISMATCH:$branch" }
if($origin -ne 'https://github.com/ries11217596955-hash/efab.git'){ throw "ORIGIN_MISMATCH:$origin" }
if($dirtyBefore.Count -gt 0){ throw "DIRTY_BEFORE_PARALLEL_LAB:$($dirtyBefore -join ';')" }
$existing=GetMatches
if(@($existing).Count -gt 0){ throw "ACTIVE_PROCESS_CONFLICT:$(@($existing).Count)" }
$RunId='school_aimo_parallel_lab_v1_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$RunRoot=Join-Path '.runtime/parallel_life' $RunId
New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
$schoolOut=Join-Path $RunRoot 'school.stdout.txt'
$schoolErr=Join-Path $RunRoot 'school.stderr.txt'
$aimoOut=Join-Path $RunRoot 'aimo.stdout.txt'
$aimoErr=Join-Path $RunRoot 'aimo.stderr.txt'
$aimoRunId='parallel_aimo_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$aimoRunRoot=Join-Path 'operations/autonomous_inner_motor/test_life_runs' $aimoRunId
$aimoProof=Join-Path $aimoRunRoot 'TEST_LIFE_PROOF.json'
$aimoStop=Join-Path $aimoRunRoot 'STOP_REQUESTED.txt'
$schoolArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/school/run_agent_school.ps1','-Count',[string]$SchoolCount,'-Mode','Test','-TopicsPlan',$TopicsPlan)
$school=Start-Process -FilePath 'powershell' -ArgumentList $schoolArgs -RedirectStandardOutput $schoolOut -RedirectStandardError $schoolErr -PassThru -WindowStyle Hidden
$schoolSeen=$false
$schoolSeenAt=$null
for($i=0;$i -lt 480;$i++){
  Start-Sleep -Milliseconds 250
  $m=@(GetMatches | Where-Object { $_.ProcessId -eq $school.Id -or $_.CommandLine -like '*run_agent_school.ps1*' })
  if($m.Count -gt 0 -and -not $school.HasExited){ $schoolSeen=$true; $schoolSeenAt=Get-Date; break }
  try { $school.Refresh() } catch {}
  if($school.HasExited){ break }
}
if(-not $schoolSeen){ try { if(-not $school.HasExited){ Stop-Process -Id $school.Id -Force -ErrorAction SilentlyContinue } } catch {}; throw 'SCHOOL_PROCESS_NOT_OBSERVED_ACTIVE_BEFORE_AIMO' }
$aimoArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1','-Mode','SandboxTestLife','-RunId',$aimoRunId)
$aimo=Start-Process -FilePath 'powershell' -ArgumentList $aimoArgs -RedirectStandardOutput $aimoOut -RedirectStandardError $aimoErr -PassThru -WindowStyle Hidden
$aimoProofSeen=$false
$schoolDuringAimo=$false
$aimoCycles=0
$packetBeforeStop=$null
$aimoStart=Get-Date
while(((Get-Date)-$aimoStart).TotalSeconds -lt [Math]::Min($MaxWaitSeconds,180)){
  Start-Sleep -Seconds 1
  $m=@(GetMatches | Where-Object { $_.ProcessId -eq $school.Id -or $_.CommandLine -like '*run_agent_school.ps1*' })
  if($m.Count -gt 0 -and -not $school.HasExited){ $schoolDuringAimo=$true }
  $p=ReadJsonSafe $aimoProof
  if($p){
    $aimoProofSeen=$true
    if($p.test_life){ $aimoCycles=[int]$p.test_life.total_cycles }
    if($aimoCycles -ge $MinAimoCycles){ break }
  }
  try { $school.Refresh(); $aimo.Refresh() } catch {}
  if($aimo.HasExited){ break }
}
if(-not $aimoProofSeen){ throw 'AIMO_PROOF_NOT_SEEN_DURING_RUN' }
if($aimoCycles -lt $MinAimoCycles){ throw "AIMO_MIN_CYCLES_NOT_REACHED:$aimoCycles<$MinAimoCycles" }
New-Item -ItemType Directory -Force -Path (Split-Path $aimoStop -Parent) | Out-Null
Set-Content -Path $aimoStop -Value "stop requested by $RunId after $aimoCycles cycles" -Encoding UTF8
$aimoExited=WaitProcExit $aimo 180
if(-not $aimoExited){ try { Stop-Process -Id $aimo.Id -Force -ErrorAction SilentlyContinue } catch {}; throw 'AIMO_DID_NOT_EXIT_AFTER_STOP_FILE' }
$schoolExited=WaitProcExit $school $MaxWaitSeconds
if(-not $schoolExited){ try { Stop-Process -Id $school.Id -Force -ErrorAction SilentlyContinue } catch {}; throw 'SCHOOL_DID_NOT_EXIT_WITHIN_MAX_WAIT_SECONDS' }
$aimoProofObj=ReadJsonSafe $aimoProof
if(-not $aimoProofObj){ throw 'AIMO_FINAL_PROOF_MISSING' }
$packet=$aimoProofObj.agentlife_packet_emitter
$mergeAfterSchool=[ordered]@{ attempted=$false; status='NOT_ATTEMPTED'; raw_output=@(); queue_path=$null; exit_code=$null }
if($packet -and $packet.queue_path -and (Test-Path $packet.queue_path)){
  $mergeAfterSchool.attempted=$true
  $mergeAfterSchool.queue_path=$packet.queue_path
  $mergeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1 -PacketPath $packet.queue_path -ProcessLimit 1 *>&1 | ForEach-Object {[string]$_})
  $mergeAfterSchool.raw_output=@($mergeOut)
  $mergeAfterSchool.status=(($mergeOut|Where-Object{$_ -match '^MERGE_QUEUE_STATUS='}|Select-Object -Last 1)-replace '^MERGE_QUEUE_STATUS=','')
  $mergeAfterSchool.exit_code=$LASTEXITCODE
}
$schoolStdoutTail=@(); if(Test-Path $schoolOut){ $schoolStdoutTail=@(Get-Content $schoolOut -Tail 40) }
$aimoStdoutTail=@(); if(Test-Path $aimoOut){ $aimoStdoutTail=@(Get-Content $aimoOut -Tail 40) }
$schoolExit=$school.ExitCode
$aimoExit=$aimo.ExitCode
$blockers=@()
if($schoolExit -ne 0){$blockers += "SCHOOL_EXIT_$schoolExit"}
if($aimoExit -ne 0){$blockers += "AIMO_EXIT_$aimoExit"}
if(-not $schoolSeen){$blockers += 'SCHOOL_NOT_SEEN_BEFORE_AIMO'}
if(-not $schoolDuringAimo){$blockers += 'NO_SCHOOL_PROCESS_OBSERVED_DURING_AIMO'}
if(-not $aimoProofObj.school_state.active_detected){$blockers += 'AIMO_DID_NOT_DETECT_ACTIVE_SCHOOL'}
if(-not $aimoProofObj.school_coordination_hint -or -not $aimoProofObj.school_coordination_hint.active_school_detected){$blockers += 'AIMO_SCHOOL_COORDINATION_HINT_MISSING'}
if($aimoProofObj.school_coordination_hint.memory_write_rule -ne 'no_direct_active_memory_write_use_intake_merge_queue_only'){$blockers += 'AIMO_MEMORY_WRITE_RULE_MISMATCH'}
if($aimoProofObj.mutation_audit.active_memory_mutated -ne $false){$blockers += 'AIMO_DIRECT_MEMORY_MUTATION_REPORTED'}
if(-not $packet){$blockers += 'AGENTLIFE_PACKET_EMITTER_MISSING'}
else{
  if($packet.intake_status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'){$blockers += "AGENTLIFE_INTAKE_NOT_PASS:$($packet.intake_status)"}
  if($packet.status -notin @('PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF','PASS_AGENTLIFE_PACKET_SUBMITTED_MERGE_BACKOFF_LOCK')){$blockers += "AGENTLIFE_BACKOFF_STATUS_NOT_PASS:$($packet.status)"}
  if($packet.merge_attempted -ne $false){$blockers += 'AGENTLIFE_MERGED_WHILE_BACKOFF_EXPECTED'}
}
if($mergeAfterSchool.attempted -and $mergeAfterSchool.status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){$blockers += "POST_SCHOOL_MERGE_NOT_PASS:$($mergeAfterSchool.status)"}
$status='PASS_SCHOOL_AIMO_PARALLEL_LAB_V1'
if($blockers.Count -gt 0){$status='FAIL_SCHOOL_AIMO_PARALLEL_LAB_V1'}
$result=[ordered]@{
  schema='school_aimo_parallel_lab_v1'
  status=$status
  proof_label='PROVEN_LAB_PARALLEL_MECHANICS_NOT_LIVE'
  run_id=$RunId
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; dirty_before=@($dirtyBefore); dirty_after_before_proof_write=GitStatusShort }
  school=[ordered]@{ started=$true; pid=$school.Id; exit_code=$schoolExit; count=$SchoolCount; topics_plan=$TopicsPlan; seen_before_aimo=$schoolSeen; seen_at=if($schoolSeenAt){$schoolSeenAt.ToString('o')}else{$null}; stdout_path=$schoolOut; stderr_path=$schoolErr; stdout_tail=@($schoolStdoutTail) }
  aimo=[ordered]@{ started=$true; pid=$aimo.Id; exit_code=$aimoExit; run_id=$aimoRunId; proof_path=$aimoProof; stop_file=$aimoStop; cycles=$aimoCycles; stdout_path=$aimoOut; stderr_path=$aimoErr; stdout_tail=@($aimoStdoutTail); proof_summary=[ordered]@{ mode=$aimoProofObj.mode; school_active_detected=$aimoProofObj.school_state.active_detected; school_coordination_hint=$aimoProofObj.school_coordination_hint; memory_coordination=$aimoProofObj.memory_coordination; mutation_audit=$aimoProofObj.mutation_audit; memory_unchanged=$aimoProofObj.memory_state.unchanged; agentlife_packet_emitter=$packet } }
  parallel_evidence=[ordered]@{ school_seen_before_aimo=$schoolSeen; school_process_observed_during_aimo=$schoolDuringAimo; aimo_detected_school_active=$aimoProofObj.school_state.active_detected; aimo_coordination_hint_present=($null -ne $aimoProofObj.school_coordination_hint) }
  intake_merge=[ordered]@{ agentlife_packet=$packet; merge_after_school=$mergeAfterSchool }
  blockers=@($blockers)
  started_at=$startedAt.ToString('o')
  finished_at=(Get-Date).ToString('o')
  boundary='Lab proves controlled parallel mechanics only: School active while AIMO SandboxTestLife runs; AgentLife packet uses compact memory intake; merge is deferred/backed off during school and can be merged after school. Not live readiness.'
}
WriteJson $ProofPath $result 100
Write-Host "SCHOOL_AIMO_PARALLEL_LAB_STATUS=$($result.status)"
Write-Host "SCHOOL_AIMO_PARALLEL_LAB_PROOF=$ProofPath"
Write-Host "SCHOOL_EXIT=$schoolExit"
Write-Host "AIMO_EXIT=$aimoExit"
Write-Host "AIMO_CYCLES=$aimoCycles"
Write-Host "AIMO_DETECTED_SCHOOL_ACTIVE=$($result.parallel_evidence.aimo_detected_school_active)"
Write-Host "AGENTLIFE_PACKET_STATUS=$($packet.status)"
Write-Host "AGENTLIFE_INTAKE_STATUS=$($packet.intake_status)"
Write-Host "POST_SCHOOL_MERGE_STATUS=$($mergeAfterSchool.status)"
Write-Host "PROOF_LABEL=$($result.proof_label)"
if($status -notlike 'PASS_*'){ exit 1 }