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
if([string]$proof.schema -ne 'agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'){ Fail 'SCHEMA_NOT_RECOVERY_WIRED' }
if($proof.failure_test_enabled -ne $true){ Fail 'FAILURE_TEST_ENABLED_NOT_TRUE' }
if([int]$proof.forced_failure_chunk -ne $ExpectedFailedChunk){ Fail 'FORCED_FAILURE_CHUNK_BAD' }
if([string]$proof.forced_failure_stage -ne $ExpectedStage){ Fail 'FORCED_FAILURE_STAGE_BAD' }
$expectedErrorPrefix=("FORCED_SCHOOL_CHUNK_FAILURE:chunk={0}:stage={1}" -f $ExpectedFailedChunk,$ExpectedStage)
if([string]$proof.error -notlike "$expectedErrorPrefix*"){ Fail 'ERROR_NOT_EXPECTED_FORCED_FAILURE' }
if(-not $proof.quarantine_record){ Fail 'QUARANTINE_RECORD_MISSING' }
if([int]$proof.quarantine_record.failed_chunk_index -ne $ExpectedFailedChunk){ Fail 'QUARANTINE_FAILED_CHUNK_BAD' }
if([int]$proof.quarantine_record.resume_ordinal_offset -ne $ExpectedResumeOffset){ Fail 'QUARANTINE_RESUME_OFFSET_BAD' }
if([string]$proof.resume_state.failure_state -ne 'FAILED_CHUNK_REQUIRES_DECISION'){ Fail 'RESUME_FAILURE_STATE_BAD' }
if([int]$proof.resume_state.current_chunk_index -ne $ExpectedFailedChunk){ Fail 'RESUME_CURRENT_CHUNK_BAD' }
if([int]$proof.resume_state.resume_ordinal_offset -ne $ExpectedResumeOffset){ Fail 'RESUME_OFFSET_BAD' }
if([int]$proof.resume_state.last_good_chunk_index -ne ([int]$proof.chunk_count)){ Fail 'LAST_GOOD_NOT_COMPLETED_CHUNK_COUNT' }
if([int]$proof.aggregation_summary.pass_count -ne [int]$proof.chunk_count){ Fail 'PASS_COUNT_NOT_COMPLETED_CHUNKS' }
if([int]$proof.aggregation_summary.failed_count -lt 1){ Fail 'FAILED_COUNT_LT_1' }
if($proof.no_fake_pass -ne $true){ Fail 'NO_FAKE_PASS_NOT_TRUE' }
if($proof.no_hidden_failures -ne $true){ Fail 'NO_HIDDEN_FAILURES_NOT_TRUE' }
if($proof.route_unchanged -ne $true){ Fail 'ROUTE_UNCHANGED_NOT_TRUE' }
if($proof.ledger_unchanged -ne $true){ Fail 'LEDGER_UNCHANGED_NOT_TRUE' }
if([bool]$proof.runtime_ready -ne $false){ Fail 'RUNTIME_READY_TRUE' }
Write-Host 'VALIDATION_PASS=SCHOOL_CHUNK_FORCED_FAILURE_RESUME_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "FAILED_CHUNK=$ExpectedFailedChunk"
Write-Host "RESUME_OFFSET=$ExpectedResumeOffset"
Write-Host "STAGE=$ExpectedStage"