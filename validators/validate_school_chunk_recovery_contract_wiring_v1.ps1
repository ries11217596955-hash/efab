param(
  [Parameter(Mandatory=$true)][string]$ProofPath
)
$ErrorActionPreference='Stop'
function Fail($Reason){ Write-Host "FAIL=$Reason"; exit 1 }
if(-not (Test-Path $ProofPath)){ Fail 'PROOF_MISSING' }
try { $proof=Get-Content $ProofPath -Raw|ConvertFrom-Json } catch { Fail 'PROOF_JSON_PARSE_FAILED' }
if([string]$proof.schema -ne 'agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'){ Fail 'SCHEMA_NOT_V7_RECOVERY_WIRED' }
if(-not $proof.recovery_contracts){ Fail 'RECOVERY_CONTRACTS_MISSING' }
if([string]$proof.recovery_contracts.wiring_status -ne 'SCHOOL_CHUNK_RECOVERY_CONTRACTS_WIRED_V1'){ Fail 'RECOVERY_WIRING_STATUS_BAD' }
foreach($node in @('continue_on_failure_runtime','quarantine_blocker_registry','batch_proof_aggregator')){
  if(-not $proof.recovery_contracts.PSObject.Properties[$node]){ Fail "RECOVERY_NODE_MISSING:$node" }
  $path=$proof.recovery_contracts.$node.path
  if([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path $path)){ Fail "RECOVERY_CONTRACT_PATH_MISSING:$node" }
  if([string]::IsNullOrWhiteSpace([string]$proof.recovery_contracts.$node.sha256)){ Fail "RECOVERY_CONTRACT_HASH_MISSING:$node" }
}
if($proof.recovery_contracts.no_fake_pass_policy -ne $true){ Fail 'NO_FAKE_PASS_POLICY_NOT_TRUE' }
if($proof.recovery_contracts.no_hidden_failures_policy -ne $true){ Fail 'NO_HIDDEN_FAILURES_POLICY_NOT_TRUE' }
if(-not $proof.resume_state){ Fail 'RESUME_STATE_MISSING' }
if(-not $proof.aggregation_summary){ Fail 'AGGREGATION_SUMMARY_MISSING' }
if($proof.no_fake_pass -ne $true){ Fail 'NO_FAKE_PASS_NOT_TRUE' }
if($proof.no_hidden_failures -ne $true){ Fail 'NO_HIDDEN_FAILURES_NOT_TRUE' }
if([bool]$proof.runtime_ready -ne $false){ Fail 'RUNTIME_READY_TRUE' }
if([int]$proof.aggregation_summary.pass_count -ne [int]$proof.chunk_count){ Fail 'PASS_COUNT_NOT_CHUNK_COUNT' }
if($proof.status -like 'FAIL_*'){
  if(-not $proof.quarantine_record){ Fail 'FAIL_PROOF_QUARANTINE_RECORD_MISSING' }
  if([string]$proof.resume_state.failure_state -ne 'FAILED_CHUNK_REQUIRES_DECISION'){ Fail 'FAIL_RESUME_STATE_BAD' }
  if([int]$proof.aggregation_summary.failed_count -lt 1){ Fail 'FAIL_AGGREGATION_FAILED_COUNT_LT_1' }
} else {
  if([string]$proof.school_recovery_wiring_status -ne 'PASS_SCHOOL_CHUNK_RECOVERY_CONTRACTS_WIRED_V1'){ Fail 'SUCCESS_WIRING_STATUS_BAD' }
  if([string]$proof.resume_state.failure_state -ne 'NONE'){ Fail 'SUCCESS_FAILURE_STATE_NOT_NONE' }
  if([int]$proof.aggregation_summary.failed_count -ne 0){ Fail 'SUCCESS_FAILED_COUNT_NOT_ZERO' }
}
Write-Host 'VALIDATION_PASS=SCHOOL_CHUNK_RECOVERY_CONTRACT_WIRING_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "STATUS=$($proof.status)"
Write-Host "CHUNK_COUNT=$($proof.chunk_count)"
Write-Host "RECOVERY_WIRING_STATUS=$($proof.recovery_contracts.wiring_status)"