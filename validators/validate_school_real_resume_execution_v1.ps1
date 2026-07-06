param(
  [Parameter(Mandatory=$true)][string]$ProofPath,
  [Parameter(Mandatory=$true)][int]$ExpectedResumeOffset,
  [Parameter(Mandatory=$true)][int]$ExpectedRemainingTarget,
  [Parameter(Mandatory=$true)][int]$ExpectedCompletedChunks,
  [Parameter(Mandatory=$true)][int]$ExpectedPlannedTotal
)
$ErrorActionPreference='Stop'
function Fail($Reason){ Write-Host "FAIL=$Reason"; exit 1 }
if(-not (Test-Path $ProofPath)){ Fail 'PROOF_MISSING' }
try { $proof=Get-Content $ProofPath -Raw|ConvertFrom-Json } catch { Fail 'PROOF_JSON_PARSE_FAILED' }
if([string]$proof.status -ne 'PASS_REAL_FACTORY_DIGEST_RECALL_USE_V1'){ Fail 'STATUS_NOT_REAL_PASS' }
if(-not $proof.resume_execution){ Fail 'RESUME_EXECUTION_MISSING' }
if($proof.resume_execution.mode -ne $true){ Fail 'RESUME_MODE_NOT_TRUE' }
if([int]$proof.resume_execution.resume_ordinal_offset -ne $ExpectedResumeOffset){ Fail 'RESUME_OFFSET_BAD' }
if([int]$proof.resume_execution.resume_remaining_target -ne $ExpectedRemainingTarget){ Fail 'RESUME_REMAINING_BAD' }
if([int]$proof.resume_execution.resume_completed_chunks -ne $ExpectedCompletedChunks){ Fail 'RESUME_COMPLETED_CHUNKS_BAD' }
if([int]$proof.resume_execution.planned_total_accepted -ne $ExpectedPlannedTotal){ Fail 'RESUME_PLANNED_TOTAL_BAD' }
if([int]$proof.resume_execution.processed_in_this_run -ne $ExpectedRemainingTarget){ Fail 'RESUME_PROCESSED_BAD' }
if([int]$proof.resume_state.resume_ordinal_offset -ne ($ExpectedResumeOffset + $ExpectedRemainingTarget)){ Fail 'FINAL_RESUME_OFFSET_BAD' }
if([int]$proof.chunk_count -ne 1){ Fail 'RESUME_RUN_SHOULD_HAVE_ONE_CHUNK' }
$c=@($proof.chunks)[0]
if([int]$c.chunk_index -ne ($ExpectedCompletedChunks + 1)){ Fail 'CHUNK_INDEX_BAD' }
if([int]$c.ordinal_offset -ne $ExpectedResumeOffset){ Fail 'CHUNK_OFFSET_BAD' }
if([int]$c.chunk_target -ne $ExpectedRemainingTarget){ Fail 'CHUNK_TARGET_BAD' }
if([int]$c.ready_atoms -ne $ExpectedRemainingTarget){ Fail 'READY_ATOMS_BAD' }
if($c.digested -ne $true){ Fail 'CHUNK_NOT_DIGESTED' }
if($c.behavior_delta -ne $true){ Fail 'BEHAVIOR_DELTA_NOT_TRUE' }
if($proof.cumulative_memory_merge -ne $true){ Fail 'CUMULATIVE_MEMORY_MERGE_NOT_TRUE' }
if($proof.existing_memory_seeded -ne $true){ Fail 'EXISTING_MEMORY_NOT_SEEDED' }
if($proof.route_after -ne $proof.route_before){ Fail 'ROUTE_CHANGED' }
if($proof.ledger_after -ne $proof.ledger_before){ Fail 'LEDGER_CHANGED' }
if($proof.no_fake_pass -ne $true){ Fail 'NO_FAKE_PASS_NOT_TRUE' }
if($proof.no_hidden_failures -ne $true){ Fail 'NO_HIDDEN_FAILURES_NOT_TRUE' }
Write-Host 'VALIDATION_PASS=SCHOOL_REAL_RESUME_EXECUTION_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "RESUME_OFFSET=$ExpectedResumeOffset"
Write-Host "REMAINING_TARGET=$ExpectedRemainingTarget"
Write-Host "PLANNED_TOTAL=$ExpectedPlannedTotal"