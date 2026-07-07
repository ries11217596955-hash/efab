param([string]$ProofPath='tests/live_readiness/SCHOOL_AIMO_LIVE_READINESS_GATE_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'school_aimo_live_readiness_gate_v1') 'SCHEMA_MISMATCH'
Assert ($P.proof_label -eq 'PROVEN_LAB_LIVE_READINESS_GATE_DECISION_NOT_LIVE_EXECUTION') 'PROOF_LABEL_MISMATCH'
Assert ($P.repo.root -eq 'H:/efab') 'REPO_ROOT_NOT_H_EFAB'
Assert ($P.repo.branch -eq 'main') 'BRANCH_NOT_MAIN'
Assert ($P.repo.origin -eq 'https://github.com/ries11217596955-hash/efab.git') 'ORIGIN_MISMATCH'
Assert ((($P.repo.ahead_behind -replace '\s+',' ') -eq '0 0')) "AHEAD_BEHIND_NOT_SYNCED:$($P.repo.ahead_behind)"
Assert (@($P.repo.dirty_before).Count -eq 0) 'DIRTY_BEFORE_NOT_EMPTY'
Assert ($P.repo.active_process_count -eq 0) 'ACTIVE_RUNTIME_PROCESS_CONFLICT'
Assert ($P.checks.map_status -eq 'PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1') 'MAP_NOT_PASS'
Assert ($P.checks.map_exit -eq 0) 'MAP_EXIT_NOT_ZERO'
Assert ($P.checks.live_like_validation_status -eq 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1') 'LIVE_LIKE_NOT_PASS'
Assert ($P.checks.stopfile_contract_validation_status -eq 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1') 'STOPFILE_NOT_PASS'
Assert ($P.checks.rollback_contract_validation_status -eq 'PASS_LIVE_ROLLBACK_CONTRACT_V1') 'ROLLBACK_NOT_PASS'
Assert ($P.checks.reject_contract_validation_status -eq 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1') 'REJECT_NOT_PASS'
Assert ($P.checks.continuous_runtime_validation_status -eq 'PASS_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1') 'CONTINUOUS_NOT_PASS'
Assert (@($P.checks.missing).Count -eq 0) "PREREQ_MISSING:$(@($P.checks.missing)-join ',')"
Assert ($P.checks.proof_checks.continuous_status -eq 'PASS_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1') 'CONTINUOUS_STATUS_NOT_PASS'
Assert ($P.checks.proof_checks.continuous_technical_runtime_ready -eq $true) 'CONTINUOUS_TECHNICAL_READY_NOT_TRUE'
Assert ($P.checks.proof_checks.continuous_runtime_ready -eq $true) 'CONTINUOUS_RUNTIME_READY_NOT_TRUE'
Assert ($P.checks.proof_checks.continuous_duration -ge 180) 'CONTINUOUS_DURATION_TOO_SHORT'
Assert ($P.checks.proof_checks.continuous_heartbeats -ge 2) 'CONTINUOUS_HEARTBEATS_TOO_LOW'
Assert ($P.checks.proof_checks.continuous_packet -eq 'PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF') 'CONTINUOUS_PACKET_NOT_PASS'
Assert ($P.checks.proof_checks.continuous_intake -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'CONTINUOUS_INTAKE_NOT_PASS'
Assert ($P.checks.proof_checks.continuous_merge -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1') 'CONTINUOUS_MERGE_NOT_PASS'
Assert ($P.technical_runtime_ready -eq $true) 'TECHNICAL_RUNTIME_READY_NOT_TRUE'
Assert ($P.runtime_ready -eq $true) 'RUNTIME_READY_NOT_TRUE'
if($P.status -eq 'PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_NO_GO_V1'){
  Assert ($P.live_ready -eq $false) 'NO_GO_BUT_LIVE_READY_TRUE'
  Assert ($P.owner_live_authorized -eq $false) 'NO_GO_OWNER_AUTH_NOT_FALSE'
  Assert (@($P.checks.go_blockers).Count -eq 1) "NO_GO_UNEXPECTED_BLOCKERS:$(@($P.checks.go_blockers)-join ',')"
  Assert (@($P.checks.go_blockers) -contains 'OWNER_LIVE_AUTHORIZATION_MISSING') 'OWNER_AUTH_BLOCKER_MISSING'
  Assert ($P.decision -eq 'NO_GO_LIVE_AUTHORIZATION_REQUIRED') 'NO_GO_DECISION_MISMATCH'
  Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_NO_GO_V1'
} elseif($P.status -eq 'PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_GO_V1'){
  Assert ($P.live_ready -eq $true) 'GO_BUT_LIVE_READY_FALSE'
  Assert ($P.owner_live_authorized -eq $true) 'GO_OWNER_AUTH_NOT_TRUE'
  Assert (@($P.checks.go_blockers).Count -eq 0) 'GO_WITH_BLOCKERS'
  Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_GO_V1'
} else { throw "STATUS_NOT_PASS:$($P.status)" }
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "TECHNICAL_RUNTIME_READY=$($P.technical_runtime_ready)"
Write-Host "LIVE_READY=$($P.live_ready)"