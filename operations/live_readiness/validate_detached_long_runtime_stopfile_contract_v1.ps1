param([string]$ProofPath='tests/live_readiness/DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'detached_long_runtime_stopfile_contract_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1') "STATUS_NOT_PASS:$($P.status)"
Assert ($P.proof_label -eq 'PROVEN_LAB_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_NOT_LIVE') 'PROOF_LABEL_MISMATCH'
Assert ($P.repo.root -eq 'H:/efab') 'REPO_ROOT_NOT_H_EFAB'
Assert ($P.repo.branch -eq 'main') 'BRANCH_NOT_MAIN'
Assert ($P.repo.origin -eq 'https://github.com/ries11217596955-hash/efab.git') 'ORIGIN_MISMATCH'
Assert ((($P.repo.ahead_behind -replace '\s+',' ') -eq '0 0')) "AHEAD_BEHIND_NOT_SYNCED:$($P.repo.ahead_behind)"
Assert (@($P.repo.dirty_before).Count -eq 0) 'DIRTY_BEFORE_NOT_EMPTY'
Assert ($P.detached_process.child_exit -eq 0) 'WORKER_EXIT_NOT_ZERO'
Assert ($P.detached_process.stopped_within_grace -eq $true) 'NOT_STOPPED_WITHIN_GRACE'
Assert ($P.detached_process.worker_alive_after_stop -eq $false) 'WORKER_STILL_ALIVE'
Assert ($P.contract.worker_exit_proof.status -eq 'PASS_DETACHED_STOPFILE_WORKER_EXIT_V1') 'WORKER_EXIT_PROOF_NOT_PASS'
Assert ($P.contract.worker_exit_proof.stopfile_seen -eq $true) 'STOPFILE_NOT_SEEN'
Assert ($P.contract.worker_exit_proof.exit_reason -eq 'STOPFILE_OBSERVED') 'EXIT_REASON_NOT_STOPFILE'
Assert ($P.contract.worker_exit_proof.heartbeat_count -ge $P.contract.min_heartbeat_count) 'HEARTBEAT_COUNT_TOO_LOW'
Assert ($P.contract.worker_exit_proof.active_memory_mutated -eq $false) 'ACTIVE_MEMORY_MUTATED'
Assert (@($P.blockers).Count -eq 0) "BLOCKERS_PRESENT:$(@($P.blockers)-join ',')"
Assert ($P.runtime_ready -eq $false) 'RUNTIME_READY_BOUNDARY_MISMATCH'
Write-Host 'VALIDATION_PASS=PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host 'RUNTIME_READY=false'