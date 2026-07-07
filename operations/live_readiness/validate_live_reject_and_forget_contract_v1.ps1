param([string]$ProofPath='tests/live_readiness/LIVE_REJECT_AND_FORGET_CONTRACT_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'live_reject_and_forget_contract_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1') "STATUS_NOT_PASS:$($P.status)"
Assert ($P.proof_label -eq 'PROVEN_LAB_REJECT_AND_FORGET_QUARANTINE_ALTERNATIVE_NOT_LIVE') 'PROOF_LABEL_MISMATCH'
Assert ($P.repo.root -eq 'H:/efab') 'REPO_ROOT_NOT_H_EFAB'
Assert ($P.repo.branch -eq 'main') 'BRANCH_NOT_MAIN'
Assert ($P.repo.origin -eq 'https://github.com/ries11217596955-hash/efab.git') 'ORIGIN_MISMATCH'
Assert ((($P.repo.ahead_behind -replace '\s+',' ') -eq '0 0')) "AHEAD_BEHIND_NOT_SYNCED:$($P.repo.ahead_behind)"
Assert (@($P.repo.dirty_before).Count -eq 0) 'DIRTY_BEFORE_NOT_EMPTY'
Assert (@($P.repo.dirty_after_before_proof_write).Count -eq 0) 'DIRTY_AFTER_BEFORE_PROOF_WRITE_NOT_EMPTY'
Assert ($P.bad_input.raw_packet_exists_after_disposal -eq $false) 'RAW_PACKET_STILL_EXISTS'
Assert ($P.bad_input.payload_value_retained_in_proof -eq $false) 'PAYLOAD_VALUE_RETAINED_IN_PROOF'
Assert ($P.reject.mode -eq 'REJECT_AND_FORGET_NO_RAW_PAYLOAD') 'REJECT_MODE_MISMATCH'
Assert ($P.reject.manifest_contains_raw_payload -eq $false) 'MANIFEST_CONTAINS_RAW_PAYLOAD'
Assert ($P.reject.accepted -eq $false) 'BAD_PACKET_ACCEPTED'
Assert ($P.reject.merged -eq $false) 'BAD_PACKET_MERGED'
Assert ($P.reject.executed -eq $false) 'BAD_PACKET_EXECUTED'
Assert ($P.reject.merge_target_exists -eq $false) 'MERGE_TARGET_EXISTS'
Assert ($P.reject.disposal_action -eq 'raw_packet_deleted_after_digest') 'DISPOSAL_ACTION_MISMATCH'
Assert ($P.safety.active_memory_mutated -eq $false) 'ACTIVE_MEMORY_MUTATED'
Assert ($P.safety.tracked_repo_mutated -eq $false) 'TRACKED_REPO_MUTATED'
Assert ($P.safety.raw_payload_retained -eq $false) 'RAW_PAYLOAD_RETAINED'
Assert ($P.safety.compact_digest_retained -eq $true) 'COMPACT_DIGEST_NOT_RETAINED'
Assert (@($P.blockers).Count -eq 0) "BLOCKERS_PRESENT:$(@($P.blockers)-join ',')"
Assert ($P.runtime_ready -eq $false) 'RUNTIME_READY_BOUNDARY_MISMATCH'
Write-Host 'VALIDATION_PASS=PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host 'RUNTIME_READY=false'