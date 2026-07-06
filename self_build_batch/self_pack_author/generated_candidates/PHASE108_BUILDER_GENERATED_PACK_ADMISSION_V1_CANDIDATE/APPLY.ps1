[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
,
  [string]$RunId = "BUILDER_GENERATED_CANDIDATE_RUNTIME_COMPAT",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"
function Write-JsonFileInternal($Path, $Object) {
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 $Path
}

$AdmissionResultPath = Join-Path $RepoRoot "self_build_batch/self_pack_author/admission/PHASE108_BUILDER_GENERATED_PACK_ADMISSION_RESULT.json"
$AdmissionProofPath = Join-Path $RepoRoot "proofs/self_development/BUILDER_GENERATED_PACK_ADMISSION_V1.json"

if (-not (Test-Path $AdmissionResultPath)) {
  throw "PHASE108_ADMISSION_RESULT_MISSING"
}
if (-not (Test-Path $AdmissionProofPath)) {
  throw "PHASE108_ADMISSION_PROOF_MISSING"
}

$AdmissionResult = Get-Content $AdmissionResultPath -Raw | ConvertFrom-Json
$AdmissionProof = Get-Content $AdmissionProofPath -Raw | ConvertFrom-Json

if ($AdmissionResult.status -ne "ADMITTED_FOR_PHASE109_CONTROLLED_EXECUTION") {
  throw "PHASE108_ADMISSION_RESULT_NOT_EXECUTION_ADMITTED"
}
if ($AdmissionResult.candidate_pack_id -ne "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE") {
  throw "PHASE108_ADMISSION_CANDIDATE_PACK_ID_MISMATCH"
}
if ($AdmissionResult.next_allowed_step -ne "PHASE109_BUILDER_EXECUTES_OWN_GENERATED_NEXT_PACK_V1") {
  throw "PHASE108_ADMISSION_NEXT_ALLOWED_UNEXPECTED"
}
if ($AdmissionProof.status -ne "PASS") {
  throw "PHASE108_ADMISSION_PROOF_NOT_PASS"
}
if ($AdmissionProof.builder_generated_candidate_admitted -ne $true) {
  throw "PHASE108_ADMISSION_PROOF_CANDIDATE_NOT_ADMITTED"
}
if ($AdmissionProof.candidate_executed -ne $false) {
  throw "PHASE108_ADMISSION_PROOF_ALREADY_EXECUTED"
}

$CandidateExecutionDir = Join-Path $RepoRoot "self_build_batch/self_pack_author/execution"
$CandidateExecutionPath = Join-Path $CandidateExecutionDir "PHASE108_CANDIDATE_CONTROLLED_EXECUTION_MARKER.json"

$Marker = [ordered]@{
  status = "PASS"
  marker_id = "PHASE108_CANDIDATE_CONTROLLED_EXECUTION_MARKER"
  candidate_pack_id = "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE"
  executed_in_phase = "PHASE109_BUILDER_EXECUTES_OWN_GENERATED_NEXT_PACK_V1"
  run_id = $RunId
  invoked_by_orchestrator = [bool]$InvokedByOrchestrator
  admission_result_verified = $true
  admission_proof_verified = $true
  candidate_registered_live_in_main = $false
  external_fetch_performed = $false
  external_install_performed = $false
  external_agent_production_performed = $false
  next_allowed_step = "PHASE110_SANDBOX_AUTONOMY_TRIAL_20_CYCLES_V1"
  created_at = (Get-Date).ToString("o")
}

Write-JsonFileInternal $CandidateExecutionPath $Marker

$QueuePath = Join-Path $RepoRoot "TASK_QUEUE.json"
if (Test-Path $QueuePath) {
  $Queue = Get-Content $QueuePath -Raw | ConvertFrom-Json
  $Queue.active_task_id = "NONE"
  foreach ($task in @($Queue.tasks)) {
    if ($task.task_id -eq "TASK_BUILDER_GENERATED_PACK_ADMISSION_V1_001") {
      $task.status = "COMPLETED"
    }
  }
  Write-JsonFileInternal $QueuePath $Queue
}

Write-Output "PHASE108_CANDIDATE_EXECUTION_STATUS=PASS"
Write-Output "PHASE108_CANDIDATE_ADMISSION_RESULT_VERIFIED=YES"
Write-Output "PHASE108_CANDIDATE_ADMISSION_PROOF_VERIFIED=YES"
Write-Output "PHASE108_CANDIDATE_MARKER_CREATED=$CandidateExecutionPath"


