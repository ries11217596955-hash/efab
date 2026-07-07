param([string]$ProofPath='tests/live_start/AIMO_AGENT_ONLY_RESTART_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING:$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'aimo_agent_only_restart_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS_AIMO_AGENT_ONLY_RESTART_V1') "STATUS_NOT_PASS:$($P.status)"
Assert ($P.proof_label -eq 'PROVEN_LIVE_AIMO_AGENT_ONLY_RESTART_WITH_SCHOOL_UNTOUCHED') 'PROOF_LABEL_MISMATCH'
Assert ($P.repo.root -eq 'H:/efab') 'ROOT_MISMATCH'
Assert ($P.repo.branch -eq 'main') 'BRANCH_MISMATCH'
Assert ((($P.repo.ahead_behind -replace '\s+',' ') -eq '0 0')) 'AHEAD_BEHIND_NOT_SYNCED'
Assert (@($P.repo.dirty_before).Count -eq 0) 'DIRTY_BEFORE_NOT_EMPTY'
Assert ($P.school.untouched -eq $true) 'SCHOOL_NOT_MARKED_UNTOUCHED'
Assert ($P.school.alive_before -eq $true) 'SCHOOL_NOT_ALIVE_BEFORE'
Assert ($P.old_aimo.alive_before -eq $false) 'OLD_AIMO_WAS_ALIVE'
Assert ($P.new_aimo.alive -eq $true) 'NEW_AIMO_NOT_ALIVE'
Assert ($P.new_aimo.mode -eq 'SandboxTestLife') 'AIMO_MODE_MISMATCH'
Assert ($P.new_aimo.stderr_size -eq 0) 'AIMO_STDERR_NOT_EMPTY'
Assert ($P.new_aimo.cycles -ge 1) 'AIMO_CYCLES_TOO_LOW'
Assert ($P.new_aimo.school_active -eq $true) 'AIMO_SCHOOL_ACTIVE_NOT_TRUE'
Assert ($P.new_aimo.memory_before_status -ne 'ACTIVE_MEMORY_READ_ERROR') 'AIMO_MEMORY_READ_ERROR'
Assert (@($P.observation.heartbeats).Count -ge 1) 'NO_HEARTBEATS'
Assert (@($P.observation.heartbeats | Where-Object { $_.school_alive -ne $true -or $_.new_aimo_alive -ne $true }).Count -eq 0) 'HEARTBEAT_NOT_ALIVE'
Assert (@($P.blockers).Count -eq 0) "BLOCKERS_PRESENT:$(@($P.blockers)-join ',')"
Write-Host 'VALIDATION_PASS=PASS_AIMO_AGENT_ONLY_RESTART_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "NEW_AIMO_PID=$($P.new_aimo.pid)"
Write-Host 'SCHOOL_UNTOUCHED=true'