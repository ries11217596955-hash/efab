param(
  [string]$ProofPath = 'tests/live_readiness/LIVE_ROLLBACK_CONTRACT_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function GitStatusShort(){ @(git status --short --untracked-files=all) }
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8 }
function Sha256File($Path){ (Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
$started=Get-Date
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
git fetch origin main --quiet
$aheadBehind=(git rev-list --left-right --count HEAD...origin/main).Trim()
$aheadBehindNorm=($aheadBehind -replace '\s+',' ')
$dirtyBefore=GitStatusShort
if(($RepoRoot -replace '\\','/') -ne 'H:/efab'){ throw "REPO_ROOT_MISMATCH:$RepoRoot" }
if($branch -ne 'main'){ throw "BRANCH_MISMATCH:$branch" }
if($origin -ne 'https://github.com/ries11217596955-hash/efab.git'){ throw "ORIGIN_MISMATCH:$origin" }
if($aheadBehindNorm -ne '0 0'){ throw "AHEAD_BEHIND_NOT_SYNCED:$aheadBehind" }
if($dirtyBefore.Count -gt 0){ throw "DIRTY_BEFORE_LIVE_ROLLBACK_CONTRACT:$($dirtyBefore -join ';')" }
$runId='live_rollback_contract_v1_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runRoot=Join-Path '.runtime/live_readiness' $runId
$target=Join-Path $runRoot 'sandbox_state.json'
$checkpoint=Join-Path $runRoot 'checkpoint_sandbox_state.json'
$manifest=Join-Path $runRoot 'rollback_manifest.json'
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$initial=[ordered]@{
  schema='live_rollback_contract_sandbox_state_v1'
  state='baseline'
  run_id=$runId
  created_at=(Get-Date).ToString('o')
  active_memory_mutated=$false
  tracked_repo_mutated=$false
}
WriteJson $target $initial
Copy-Item -LiteralPath $target -Destination $checkpoint -Force
$hashBefore=Sha256File $target
$checkpointHash=Sha256File $checkpoint
$mutated=[ordered]@{
  schema='live_rollback_contract_sandbox_state_v1'
  state='mutated_for_rollback_test'
  run_id=$runId
  mutation_at=(Get-Date).ToString('o')
  active_memory_mutated=$false
  tracked_repo_mutated=$false
  mutation_marker='CONTROLLED_SANDBOX_MUTATION_ONLY'
}
WriteJson $target $mutated
$hashMutated=Sha256File $target
$mutationChanged=($hashMutated -ne $hashBefore)
$manifestObj=[ordered]@{
  schema='live_rollback_manifest_v1'
  run_id=$runId
  target_path=$target
  checkpoint_path=$checkpoint
  hash_before=$hashBefore
  hash_mutated=$hashMutated
  checkpoint_hash=$checkpointHash
  rollback_action='copy_checkpoint_over_target'
  active_memory_mutated=$false
  tracked_repo_mutated=$false
}
WriteJson $manifest $manifestObj
Copy-Item -LiteralPath $checkpoint -Destination $target -Force
$hashAfterRollback=Sha256File $target
$restored=($hashAfterRollback -eq $hashBefore -and $hashAfterRollback -eq $checkpointHash)
$targetObj=Get-Content $target -Raw | ConvertFrom-Json
$dirtyAfter=GitStatusShort
$blockers=@()
if(-not $mutationChanged){ $blockers += 'CONTROLLED_MUTATION_DID_NOT_CHANGE_HASH' }
if(-not $restored){ $blockers += 'ROLLBACK_HASH_NOT_RESTORED' }
if($targetObj.state -ne 'baseline'){ $blockers += "TARGET_STATE_NOT_BASELINE_AFTER_ROLLBACK:$($targetObj.state)" }
if($targetObj.active_memory_mutated -ne $false){ $blockers += 'ACTIVE_MEMORY_MUTATION_REPORTED' }
if($targetObj.tracked_repo_mutated -ne $false){ $blockers += 'TRACKED_REPO_MUTATION_REPORTED' }
if($dirtyAfter.Count -gt 0){ $blockers += "DIRTY_AFTER_BEFORE_PROOF_WRITE:$($dirtyAfter -join ';')" }
$status='PASS_LIVE_ROLLBACK_CONTRACT_V1'
if($blockers.Count -gt 0){ $status='FAIL_LIVE_ROLLBACK_CONTRACT_V1' }
$result=[ordered]@{
  schema='live_rollback_contract_v1'
  status=$status
  proof_label='PROVEN_LAB_LIVE_ROLLBACK_CONTRACT_NOT_LIVE'
  run_id=$runId
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind; dirty_before=@($dirtyBefore); dirty_after_before_proof_write=@($dirtyAfter) }
  rollback=[ordered]@{
    run_root=$runRoot
    target_path=$target
    checkpoint_path=$checkpoint
    manifest_path=$manifest
    hash_before=$hashBefore
    hash_mutated=$hashMutated
    hash_after_rollback=$hashAfterRollback
    checkpoint_hash=$checkpointHash
    mutation_changed_hash=$mutationChanged
    restored_to_checkpoint=$restored
    final_state=$targetObj.state
    rollback_action='copy_checkpoint_over_target'
  }
  safety=[ordered]@{ active_memory_mutated=$false; tracked_repo_mutated=$false; sandbox_only=$true }
  blockers=@($blockers)
  boundary='Lab rollback contract only: checkpoint, controlled sandbox mutation, rollback restore verified by hash/state. Not live runtime rollback execution.'
  runtime_ready=$false
  started_at=$started.ToString('o')
  finished_at=(Get-Date).ToString('o')
}
WriteJson $ProofPath $result
Write-Host "LIVE_ROLLBACK_CONTRACT_STATUS=$status"
Write-Host "LIVE_ROLLBACK_CONTRACT_PROOF=$ProofPath"
Write-Host "RUN_ID=$runId"
Write-Host "HASH_BEFORE=$hashBefore"
Write-Host "HASH_MUTATED=$hashMutated"
Write-Host "HASH_AFTER_ROLLBACK=$hashAfterRollback"
Write-Host "RESTORED_TO_CHECKPOINT=$restored"
Write-Host "BLOCKERS=$($blockers -join ',')"
Write-Host 'RUNTIME_READY=false'
if($status -notlike 'PASS_*'){ exit 1 }