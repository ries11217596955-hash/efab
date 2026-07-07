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
Assert ($P.repo.active_process_count -eq 0) 'ACTIVE_RUNTIME_CHILD_PROCESS_CONFLICT'
Assert ($P.checks.map_status -eq 'PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1') 'MAP_NOT_PASS'
Assert ($P.checks.map_exit -eq 0) 'MAP_EXIT_NOT_ZERO'
Assert ($P.checks.live_like_validation_status -eq 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1') 'LIVE_LIKE_VALIDATION_NOT_PASS'
Assert ($P.checks.live_like_validation_exit -eq 0) 'LIVE_LIKE_VALIDATION_EXIT_NOT_ZERO'
Assert ($P.checks.stopfile_contract_validation_status -eq 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1') 'STOPFILE_CONTRACT_VALIDATION_NOT_PASS'
Assert ($P.checks.stopfile_contract_validation_exit -eq 0) 'STOPFILE_CONTRACT_VALIDATION_EXIT_NOT_ZERO'
Assert ($P.checks.rollback_contract_validation_status -eq 'PASS_LIVE_ROLLBACK_CONTRACT_V1') 'ROLLBACK_CONTRACT_VALIDATION_NOT_PASS'
Assert ($P.checks.rollback_contract_validation_exit -eq 0) 'ROLLBACK_CONTRACT_VALIDATION_EXIT_NOT_ZERO'
Assert ($P.checks.reject_contract_validation_status -eq 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1') 'REJECT_CONTRACT_VALIDATION_NOT_PASS'
Assert ($P.checks.reject_contract_validation_exit -eq 0) 'REJECT_CONTRACT_VALIDATION_EXIT_NOT_ZERO'
Assert (@($P.checks.missing).Count -eq 0) "PREREQ_MISSING:$(@($P.checks.missing)-join ',')"
Assert ($P.checks.proof_checks.live_like_duration_seconds -ge 180) 'LIVE_LIKE_DURATION_TOO_SHORT'
Assert ($P.checks.proof_checks.live_like_heartbeats -ge 10) 'LIVE_LIKE_HEARTBEATS_TOO_LOW'
Assert ($P.checks.proof_checks.live_like_watchdog_violations -eq 0) 'LIVE_LIKE_WATCHDOG_VIOLATIONS'
Assert ($P.checks.proof_checks.packet_status -eq 'PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF') 'PACKET_NOT_PASS'
Assert ($P.checks.proof_checks.intake_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'INTAKE_NOT_PASS'
Assert ($P.checks.proof_checks.merge_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1') 'MERGE_NOT_PASS'
Assert ($P.checks.proof_checks.stopfile_contract_status -eq 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1') 'STOPFILE_CONTRACT_STATUS_NOT_PASS'
Assert ($P.checks.proof_checks.rollback_contract_status -eq 'PASS_LIVE_ROLLBACK_CONTRACT_V1') 'ROLLBACK_CONTRACT_STATUS_NOT_PASS'
Assert ($P.checks.proof_checks.rollback_contract_mutation_changed_hash -eq $true) 'ROLLBACK_MUTATION_DID_NOT_CHANGE_HASH'
Assert ($P.checks.proof_checks.rollback_contract_restored_to_checkpoint -eq $true) 'ROLLBACK_NOT_RESTORED'
Assert ($P.checks.proof_checks.rollback_contract_final_state -eq 'baseline') 'ROLLBACK_FINAL_STATE_NOT_BASELINE'
Assert ($P.checks.proof_checks.rollback_contract_active_memory_mutated -eq $false) 'ROLLBACK_ACTIVE_MEMORY_MUTATED'
Assert ($P.checks.proof_checks.rollback_contract_tracked_repo_mutated -eq $false) 'ROLLBACK_TRACKED_REPO_MUTATED'
Assert ($P.checks.proof_checks.reject_contract_status -eq 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1') 'REJECT_CONTRACT_STATUS_NOT_PASS'
Assert ($P.checks.proof_checks.reject_contract_mode -eq 'REJECT_AND_FORGET_NO_RAW_PAYLOAD') 'REJECT_CONTRACT_MODE_MISMATCH'
Assert ($P.checks.proof_checks.reject_contract_raw_packet_exists_after_disposal -eq $false) 'REJECT_RAW_PACKET_STILL_EXISTS'
Assert ($P.checks.proof_checks.reject_contract_manifest_contains_raw_payload -eq $false) 'REJECT_MANIFEST_CONTAINS_RAW_PAYLOAD'
Assert ($P.checks.proof_checks.reject_contract_accepted -eq $false) 'REJECT_BAD_PACKET_ACCEPTED'
Assert ($P.checks.proof_checks.reject_contract_merged -eq $false) 'REJECT_BAD_PACKET_MERGED'
Assert ($P.checks.proof_checks.reject_contract_executed -eq $false) 'REJECT_BAD_PACKET_EXECUTED'
if($P.status -eq 'PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_NO_GO_V1'){
  Assert ($P.live_ready -eq $false) 'NO_GO_BUT_LIVE_READY_TRUE'
  Assert ($P.decision -eq 'NO_GO_LIVE_READINESS_BLOCKED') 'NO_GO_DECISION_MISMATCH'
  Assert (@($P.checks.go_blockers).Count -gt 0) 'NO_GO_WITHOUT_GO_BLOCKERS'
  Assert (@($P.checks.go_blockers) -contains 'OWNER_LIVE_AUTHORIZATION_MISSING') 'OWNER_AUTH_BLOCKER_MISSING'
  Assert (-not (@($P.checks.go_blockers) -contains 'LIVE_QUARANTINE_PLAN_NOT_PROVEN')) 'QUARANTINE_BLOCKER_SHOULD_BE_CLEARED'
  Assert (-not (@($P.checks.go_blockers) -contains 'LIVE_ROLLBACK_PLAN_NOT_PROVEN')) 'ROLLBACK_BLOCKER_SHOULD_BE_CLEARED'
  Assert (-not (@($P.checks.go_blockers) -contains 'DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_NOT_PROVEN')) 'DETACHED_STOPFILE_BLOCKER_SHOULD_BE_CLEARED'
  Assert ($P.runtime_ready -eq $false) 'NO_GO_RUNTIME_READY_NOT_FALSE'
  Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_NO_GO_V1'
} elseif($P.status -eq 'PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_GO_V1'){
  Assert ($P.live_ready -eq $true) 'GO_BUT_LIVE_READY_FALSE'
  Assert ($P.decision -eq 'GO_LIVE_READY') 'GO_DECISION_MISMATCH'
  Assert (@($P.checks.go_blockers).Count -eq 0) 'GO_WITH_GO_BLOCKERS'
  Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_GO_V1'
} else { throw "STATUS_NOT_PASS:$($P.status)" }
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "LIVE_READY=$($P.live_ready)"
Write-Host 'RUNTIME_READY=false'