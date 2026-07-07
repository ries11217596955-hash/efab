param([string]$ProofPath='tests/live_readiness/SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'school_aimo_continuous_runtime_proof_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1') "STATUS_NOT_PASS:$($P.status)"
Assert ($P.proof_label -eq 'PROVEN_LAB_SUPERVISED_CONTINUOUS_RUNTIME_READY_CANDIDATE_NOT_OWNER_LIVE') 'PROOF_LABEL_MISMATCH'
Assert ($P.repo.root -eq 'H:/efab') 'REPO_ROOT_NOT_H_EFAB'
Assert ($P.repo.branch -eq 'main') 'BRANCH_NOT_MAIN'
Assert ($P.repo.origin -eq 'https://github.com/ries11217596955-hash/efab.git') 'ORIGIN_MISMATCH'
Assert ((($P.repo.ahead_behind -replace '\s+',' ') -eq '0 0')) "AHEAD_BEHIND_NOT_SYNCED:$($P.repo.ahead_behind)"
Assert (@($P.repo.dirty_before).Count -eq 0) 'DIRTY_BEFORE_NOT_EMPTY'
Assert ($P.repo.active_processes_before -eq 0) 'ACTIVE_PROCESS_BEFORE'
Assert ($P.repo.active_processes_after -eq 0) 'ACTIVE_PROCESS_AFTER'
Assert ($P.safety_contracts.stopfile_status -eq 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1') 'STOPFILE_NOT_PASS'
Assert ($P.safety_contracts.rollback_status -eq 'PASS_LIVE_ROLLBACK_CONTRACT_V1') 'ROLLBACK_NOT_PASS'
Assert ($P.safety_contracts.reject_and_forget_status -eq 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1') 'REJECT_NOT_PASS'
Assert ($P.continuous_observation.child_status -eq 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1') 'CHILD_LIVE_LIKE_NOT_PASS'
Assert ($P.continuous_observation.duration_seconds -ge $P.continuous_observation.min_required_seconds) 'DURATION_TOO_SHORT'
Assert ($P.continuous_observation.heartbeat_count -ge 2) 'HEARTBEATS_TOO_LOW'
Assert (@($P.continuous_observation.watchdog_violations).Count -eq 0) 'WATCHDOG_VIOLATIONS'
Assert ($P.continuous_observation.child_exit -eq 0) 'CHILD_EXIT_NOT_ZERO'
Assert ($P.continuous_observation.live_like_validation_status -eq 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1') 'CHILD_VALIDATOR_NOT_PASS'
Assert ($P.parallel_runtime.school_plus_aimo_status -eq 'PASS_SCHOOL_AIMO_PARALLEL_LAB_V1') 'PARALLEL_NOT_PASS'
Assert ($P.parallel_runtime.packet_status -eq 'PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF') 'PACKET_NOT_PASS'
Assert ($P.parallel_runtime.intake_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'INTAKE_NOT_PASS'
Assert ($P.parallel_runtime.merge_after_school_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1') 'MERGE_NOT_PASS'
Assert ($P.technical_runtime_ready -eq $true) 'TECHNICAL_RUNTIME_READY_NOT_TRUE'
Assert ($P.owner_live_authorized -eq $false) 'OWNER_LIVE_AUTH_SHOULD_BE_FALSE'
Assert ($P.live_ready -eq $false) 'LIVE_READY_SHOULD_BE_FALSE_WITHOUT_OWNER_AUTH'
Assert ($P.runtime_ready -eq $true) 'RUNTIME_READY_NOT_TRUE'
Assert (@($P.blockers).Count -eq 0) "BLOCKERS_PRESENT:$(@($P.blockers)-join ',')"
Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host 'TECHNICAL_RUNTIME_READY=true'
Write-Host 'LIVE_READY=false'