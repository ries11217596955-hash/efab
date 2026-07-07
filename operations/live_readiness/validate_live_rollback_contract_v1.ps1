param([string]$ProofPath='tests/live_readiness/LIVE_ROLLBACK_CONTRACT_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'live_rollback_contract_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS_LIVE_ROLLBACK_CONTRACT_V1') "STATUS_NOT_PASS:$($P.status)"
Assert ($P.proof_label -eq 'PROVEN_LAB_LIVE_ROLLBACK_CONTRACT_NOT_LIVE') 'PROOF_LABEL_MISMATCH'
Assert ($P.repo.root -eq 'H:/efab') 'REPO_ROOT_NOT_H_EFAB'
Assert ($P.repo.branch -eq 'main') 'BRANCH_NOT_MAIN'
Assert ($P.repo.origin -eq 'https://github.com/ries11217596955-hash/efab.git') 'ORIGIN_MISMATCH'
Assert ((($P.repo.ahead_behind -replace '\s+',' ') -eq '0 0')) "AHEAD_BEHIND_NOT_SYNCED:$($P.repo.ahead_behind)"
Assert (@($P.repo.dirty_before).Count -eq 0) 'DIRTY_BEFORE_NOT_EMPTY'
Assert (@($P.repo.dirty_after_before_proof_write).Count -eq 0) 'DIRTY_AFTER_BEFORE_PROOF_WRITE_NOT_EMPTY'
Assert ($P.rollback.mutation_changed_hash -eq $true) 'MUTATION_DID_NOT_CHANGE_HASH'
Assert ($P.rollback.restored_to_checkpoint -eq $true) 'ROLLBACK_NOT_RESTORED_TO_CHECKPOINT'
Assert ($P.rollback.hash_before -eq $P.rollback.hash_after_rollback) 'HASH_BEFORE_AFTER_MISMATCH'
Assert ($P.rollback.hash_before -eq $P.rollback.checkpoint_hash) 'CHECKPOINT_HASH_MISMATCH'
Assert ($P.rollback.hash_before -ne $P.rollback.hash_mutated) 'MUTATED_HASH_NOT_DIFFERENT'
Assert ($P.rollback.final_state -eq 'baseline') 'FINAL_STATE_NOT_BASELINE'
Assert ($P.safety.active_memory_mutated -eq $false) 'ACTIVE_MEMORY_MUTATED'
Assert ($P.safety.tracked_repo_mutated -eq $false) 'TRACKED_REPO_MUTATED'
Assert ($P.safety.sandbox_only -eq $true) 'SANDBOX_ONLY_NOT_TRUE'
Assert (@($P.blockers).Count -eq 0) "BLOCKERS_PRESENT:$(@($P.blockers)-join ',')"
Assert ($P.runtime_ready -eq $false) 'RUNTIME_READY_BOUNDARY_MISMATCH'
Write-Host 'VALIDATION_PASS=PASS_LIVE_ROLLBACK_CONTRACT_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host 'RUNTIME_READY=false'