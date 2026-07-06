param(
  [Parameter(Mandatory=$true)][string]$ProofPath,
  [Parameter(Mandatory=$true)][int]$ExpectedFailedChunk,
  [Parameter(Mandatory=$true)][int]$ExpectedResumeOffset,
  [Parameter(Mandatory=$true)][string]$ExpectedStage
)
$ErrorActionPreference='Stop'
function Fail($Reason){ Write-Host "FAIL=$Reason"; exit 1 }
if(-not (Test-Path $ProofPath)){ Fail 'PROOF_MISSING' }
try { $proof=Get-Content $ProofPath -Raw|ConvertFrom-Json } catch { Fail 'PROOF_JSON_PARSE_FAILED' }
if([string]$proof.status -ne 'FAIL_CHUNKED_SCHOOL_CLEANED_TRANSIENTS_V1'){ Fail 'STATUS_NOT_FAIL_CHUNKED' }
if([string]$proof.memory_rollback_capability -ne 'SCHOOL_REAL_CHUNK_MEMORY_CHECKPOINT_ROLLBACK_V1'){ Fail 'MEMORY_ROLLBACK_CAPABILITY_MISSING' }
if(-not $proof.memory_checkpoint){ Fail 'MEMORY_CHECKPOINT_MISSING' }
if(-not $proof.memory_rollback){ Fail 'MEMORY_ROLLBACK_MISSING' }
if([string]$proof.memory_checkpoint.status -ne 'CHECKPOINT_READY'){ Fail 'MEMORY_CHECKPOINT_NOT_READY' }
if([int]$proof.memory_checkpoint.chunk_index -ne $ExpectedFailedChunk){ Fail 'CHECKPOINT_CHUNK_BAD' }
if([int]$proof.memory_checkpoint.ordinal_offset -ne $ExpectedResumeOffset){ Fail 'CHECKPOINT_OFFSET_BAD' }
if([string]$proof.memory_rollback.status -ne 'ROLLBACK_RESTORED_ACTIVE_MEMORY_V1'){ Fail 'MEMORY_ROLLBACK_STATUS_BAD' }
if($proof.memory_rollback.restored -ne $true){ Fail 'MEMORY_ROLLBACK_RESTORED_NOT_TRUE' }
if([int]$proof.memory_rollback.chunk_index -ne $ExpectedFailedChunk){ Fail 'ROLLBACK_CHUNK_BAD' }
if([int]$proof.memory_rollback.ordinal_offset -ne $ExpectedResumeOffset){ Fail 'ROLLBACK_OFFSET_BAD' }
if([string]$proof.memory_rollback.restored_state.cells_sha256 -ne [string]$proof.memory_rollback.expected_state.cells_sha256){ Fail 'ROLLBACK_CELLS_HASH_MISMATCH' }
if([string]$proof.memory_rollback.restored_state.manifest_sha256 -ne [string]$proof.memory_rollback.expected_state.manifest_sha256){ Fail 'ROLLBACK_MANIFEST_HASH_MISMATCH' }
if([string]$proof.memory_rollback.restored_state.run_id -ne [string]$proof.memory_rollback.expected_state.run_id){ Fail 'ROLLBACK_RUN_ID_MISMATCH' }
if([string]$proof.error -notlike ("FORCED_SCHOOL_CHUNK_FAILURE:chunk={0}:stage={1}*" -f $ExpectedFailedChunk,$ExpectedStage)){ Fail 'ERROR_NOT_EXPECTED_FORCED_FAILURE' }
if([int]$proof.resume_state.resume_ordinal_offset -ne $ExpectedResumeOffset){ Fail 'RESUME_OFFSET_BAD' }
if($proof.route_unchanged -ne $true){ Fail 'ROUTE_UNCHANGED_NOT_TRUE' }
if($proof.ledger_unchanged -ne $true){ Fail 'LEDGER_UNCHANGED_NOT_TRUE' }
if($proof.no_fake_pass -ne $true){ Fail 'NO_FAKE_PASS_NOT_TRUE' }
if($proof.no_hidden_failures -ne $true){ Fail 'NO_HIDDEN_FAILURES_NOT_TRUE' }
Write-Host 'VALIDATION_PASS=SCHOOL_REAL_CHUNK_MEMORY_CHECKPOINT_ROLLBACK_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "FAILED_CHUNK=$ExpectedFailedChunk"
Write-Host "RESUME_OFFSET=$ExpectedResumeOffset"
Write-Host "STAGE=$ExpectedStage"
Write-Host "ROLLBACK_STATUS=$($proof.memory_rollback.status)"