param([string]$ProofPath='tests/live_like/SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'school_aimo_live_like_observation_gate_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1') "STATUS_NOT_PASS:$($P.status)"
Assert ($P.proof_label -eq 'PROVEN_LAB_LIVE_LIKE_OBSERVATION_NOT_LIVE_READY') 'PROOF_LABEL_MISMATCH'
Assert ($P.repo.root -eq 'H:/efab') 'REPO_ROOT_NOT_H_EFAB'
Assert ($P.repo.branch -eq 'main') 'BRANCH_NOT_MAIN'
Assert ($P.repo.origin -eq 'https://github.com/ries11217596955-hash/efab.git') 'ORIGIN_MISMATCH'
Assert (@($P.repo.dirty_before).Count -eq 0) 'DIRTY_BEFORE_NOT_EMPTY'
Assert (@($P.repo.dirty_after).Count -eq 0) 'DIRTY_AFTER_NOT_EMPTY'
Assert ($P.observation.duration_seconds -ge $P.observation.min_required_seconds) 'OBSERVATION_TOO_SHORT'
Assert ($P.observation.heartbeat_count -ge 2) 'INSUFFICIENT_HEARTBEATS'
Assert (@($P.observation.watchdog_violations).Count -eq 0) 'WATCHDOG_VIOLATIONS_PRESENT'
Assert ($P.observation.child_exit -eq 0) 'CHILD_EXIT_NOT_ZERO'
Assert ($P.parallel_harness.status -eq 'PASS_SCHOOL_AIMO_PARALLEL_LAB_V1') 'PARALLEL_STATUS_NOT_PASS'
Assert ($P.parallel_harness.validation_status -eq 'PASS_SCHOOL_AIMO_PARALLEL_LAB_V1') 'PARALLEL_VALIDATION_NOT_PASS'
Assert ($P.parallel_harness.validation_exit -eq 0) 'PARALLEL_VALIDATION_EXIT_NOT_ZERO'
Assert ($P.parallel_harness.aimo_cycles -ge 2) 'AIMO_CYCLES_TOO_LOW'
Assert ($P.parallel_harness.packet_status -eq 'PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF') 'PACKET_STATUS_NOT_PASS'
Assert ($P.parallel_harness.intake_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'INTAKE_STATUS_NOT_PASS'
Assert ($P.parallel_harness.merge_after_school_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1') 'MERGE_AFTER_SCHOOL_NOT_PASS'
Assert ($P.parallel_harness.runtime_ready -eq $false) 'RUNTIME_READY_BOUNDARY_MISMATCH'
Assert (@($P.blockers).Count -eq 0) "BLOCKERS_PRESENT:$(@($P.blockers) -join ',')"
Assert ($P.runtime_ready -eq $false) 'GATE_RUNTIME_READY_BOUNDARY_MISMATCH'
Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host 'RUNTIME_READY=false'