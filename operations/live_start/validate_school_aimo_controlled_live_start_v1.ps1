param([string]$ProofPath='tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_START_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'school_aimo_controlled_live_start_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS_SCHOOL_AIMO_CONTROLLED_LIVE_START_V1') "STATUS_NOT_PASS:$($P.status)"
Assert ($P.proof_label -eq 'PROVEN_LIVE_INITIAL_CONTROLLED_START_NOT_LONG_SOAK') 'PROOF_LABEL_MISMATCH'
Assert ($P.owner_authorized -eq $true) 'OWNER_NOT_AUTHORIZED'
Assert ($P.repo.root -eq 'H:/efab') 'ROOT_MISMATCH'
Assert ($P.repo.branch -eq 'main') 'BRANCH_MISMATCH'
Assert ((($P.repo.ahead_behind -replace '\s+',' ') -eq '0 0')) 'AHEAD_BEHIND_NOT_SYNCED'
Assert (@($P.repo.dirty_before).Count -eq 0) 'DIRTY_BEFORE'
Assert ($P.launch.school_alive -eq $true) 'SCHOOL_NOT_ALIVE'
Assert ($P.launch.aimo_alive -eq $true) 'AIMO_NOT_ALIVE'
Assert ($P.repo.active_processes_after -ge 2) 'ACTIVE_PROCESS_COUNT_TOO_LOW'
Assert (@($P.observation.heartbeats).Count -ge 1) 'NO_HEARTBEATS'
Assert (@($P.observation.heartbeats | Where-Object { $_.school_alive -ne $true -or $_.aimo_alive -ne $true }).Count -eq 0) 'HEARTBEAT_NOT_ALIVE'
Assert (@($P.blockers).Count -eq 0) "BLOCKERS_PRESENT:$(@($P.blockers)-join ',')"
Assert ($P.live_started -eq $true) 'LIVE_STARTED_NOT_TRUE'
Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_CONTROLLED_LIVE_START_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "SCHOOL_PID=$($P.launch.school_pid)"
Write-Host "AIMO_PID=$($P.launch.aimo_pid)"
Write-Host "STOP_ALL_PATH=$($P.controls.stop_all_path)"