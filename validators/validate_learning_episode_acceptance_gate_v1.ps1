param(
  [string]$StudyProofPath = 'operations/autonomous_inner_motor/study_life_runs/sandbox_study_life_20260705_01/STUDY_LIFE_PROOF.json',
  [string]$OutPath = 'operations/autonomous_inner_motor/validation/LEARNING_EPISODE_ACCEPTANCE_GATE_VALIDATION.json'
)

$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

function Read-Json([string]$Path) {
  if(-not (Test-Path -LiteralPath $Path)) { return $null }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}
function Add-Error([System.Collections.Generic.List[string]]$Errors,[string]$Msg) { $Errors.Add($Msg) | Out-Null }

$Errors = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
$Study = Read-Json $StudyProofPath
if($null -eq $Study) { Add-Error $Errors "study_proof_missing:$StudyProofPath" }

$BatchProofs = @()
$BatchDigests = @()
$RawSourcePaths = @()
$AcceptedOutputs = @()
$Parked = @()
$OpenGaps = @()

if($Study) {
  if($Study.mode -ne 'SandboxStudyLife') { Add-Error $Errors 'wrong_mode_not_SandboxStudyLife' }
  if($Study.memory_state.unchanged -ne $true) { Add-Error $Errors 'memory_not_unchanged' }
  if($Study.stop_reason -ne 'STOP_FILE_REQUESTED') { Add-Error $Errors 'stop_reason_not_stop_file_requested' }
  if(-not $Study.study_life) { Add-Error $Errors 'missing_study_life_section' }
  if($Study.study_life) {
    $c = $Study.study_life.counters
    if([int]$c.topics_selected -lt 2) { Add-Error $Errors 'too_few_topics_to_prove_continue_life' }
    if([int]$c.future_action_lane_parked -lt 1) { Add-Error $Errors 'no_future_action_lane_parked' }
    if([int]$c.continued_after_parked_gap -lt 1) { Add-Error $Errors 'did_not_continue_after_parked_gap' }
    if([int]$c.open_learning_gaps -lt 1) { Add-Error $Errors 'no_open_gap_recorded' }
    if([int]$c.source_attempts_allowed_per_episode -ne 3) { Add-Error $Errors 'source_attempt_limit_not_three' }
    if([int]$c.source_attempts_used -gt 3) { Add-Error $Errors 'source_attempts_used_exceeds_run_budget_3' }
    if([int]$c.compact_case_patterns -lt 1 -and [int]$c.atom_candidates -lt 1) { Add-Error $Errors 'no_compact_learning_output_created' }
    if([int]$c.practical_actions_created -ne 0) { Add-Error $Errors 'practical_actions_created_nonzero' }
    if([int]$c.code_writes -ne 0) { Add-Error $Errors 'code_writes_nonzero' }
    if([int]$c.active_memory_mutations -ne 0) { Add-Error $Errors 'active_memory_mutations_nonzero' }
    $Parked = @($Study.study_life.parked_future_action_lane)
    $OpenGaps = @($Study.study_life.open_learning_gap_queue)
    $AcceptedOutputs = @($Study.study_life.compact_learning_outputs)
    foreach($p in $Parked) {
      if([string]$p.status -ne 'PARKED_NOT_DEAD') { Add-Error $Errors "parked_status_not_PARKED_NOT_DEAD:$($p.task)" }
    }
    foreach($g in $OpenGaps) {
      if(([string]$g.status -ne 'PARKED_FUTURE_ACTION_CREATION_LANE') -and ([string]$g.status -ne 'OPEN_LEARNING_GAP')) { Add-Error $Errors "open_gap_bad_status:$($g.status)" }
    }
    foreach($o in $AcceptedOutputs) {
      if([string]$o.classification -notin @('CASE_PATTERN_CANDIDATE','ATOM_CANDIDATE','OPEN_LEARNING_GAP','FUTURE_ACTION_CREATION_LANE')) { Add-Error $Errors "bad_classification:$($o.classification)" }
      if([string]$o.classification -eq 'ATOM_CANDIDATE' -and $o.atom_candidate -ne $true) { Add-Error $Errors 'atom_candidate_classification_without_flag' }
      if([string]$o.classification -eq 'CASE_PATTERN_CANDIDATE' -and $o.atom_candidate -ne $false) { Add-Error $Errors 'case_pattern_should_not_claim_atom' }
      if(-not [string]::IsNullOrWhiteSpace([string]$o.proof_path)) { $BatchProofs += [string]$o.proof_path }
      if(-not [string]::IsNullOrWhiteSpace([string]$o.digest_path)) { $BatchDigests += [string]$o.digest_path }
    }
  }
}

foreach($bpPath in $BatchProofs) {
  $bp = Read-Json $bpPath
  if($null -eq $bp) { Add-Error $Errors "batch_proof_missing:$bpPath"; continue }
  if($bp.source -ne 'CODEX_BATCH_READONLY_SOURCE') { Add-Error $Errors "batch_source_wrong:$bpPath" }
  if($bp.status -ne 'PASS_CODEX_BATCH_DRAFT_RETURNED') { Add-Error $Errors "batch_status_not_pass:$bpPath" }
  if($bp.codex_answer_status -ne 'CODEX_DRAFT') { Add-Error $Errors "batch_answer_not_codex_draft:$bpPath" }
  if($bp.codex_answer_required_shape_valid -ne $true) { Add-Error $Errors "batch_shape_invalid:$bpPath" }
  if($bp.raw_source_retention -ne 'DELETED_AFTER_COMPACT_DIGEST') { Add-Error $Errors "batch_raw_not_deleted:$bpPath" }
  if([int]$bp.part_count -lt 1) { Add-Error $Errors "batch_no_parts:$bpPath" }
  $raw = Join-Path (Split-Path $bpPath -Parent) 'codex_batch_last_message.json.txt'
  $RawSourcePaths += $raw
  if(Test-Path -LiteralPath $raw) { Add-Error $Errors "raw_source_still_exists:$raw" }
}
foreach($dgPath in $BatchDigests) {
  $dg = Read-Json $dgPath
  if($null -eq $dg) { Add-Error $Errors "batch_digest_missing:$dgPath"; continue }
  if($dg.status -ne 'COMPACT_BATCH_DIGEST_CREATED') { Add-Error $Errors "digest_status_not_compact_batch:$dgPath" }
  if($dg.promotion_decision.raw_retention_decision -ne 'DELETE_RAW_CANDIDATE') { Add-Error $Errors "digest_raw_decision_not_delete:$dgPath" }
  if($dg.promotion_decision.atom_candidate -eq $true -and $dg.promotion_decision.default_classification -ne 'ATOM_CANDIDATE') { Add-Error $Errors "digest_silent_atom_candidate_without_classification:$dgPath" }
}

$AtomCandidateCount = @($AcceptedOutputs | Where-Object { [string]$_.classification -eq 'ATOM_CANDIDATE' -or $_.atom_candidate -eq $true }).Count
$CasePatternCount = @($AcceptedOutputs | Where-Object { [string]$_.classification -eq 'CASE_PATTERN_CANDIDATE' }).Count
$AcceptedResult = 'REJECTED'
if($Errors.Count -eq 0) {
  if($AtomCandidateCount -gt 0) { $AcceptedResult = 'ATOM_CANDIDATE_ROUTED_TO_EXISTING_ATOM_ACCEPTANCE' }
  elseif($CasePatternCount -gt 0) { $AcceptedResult = 'CASE_PATTERN_CANDIDATE_ACCEPTED_NOT_ATOM' }
  else { $AcceptedResult = 'LEARNING_EPISODE_ACCEPTED_NO_PROMOTION' }
}
$Status = if($Errors.Count -eq 0) { 'PASS_LEARNING_EPISODE_ACCEPTANCE_GATE_V1' } else { 'FAIL_LEARNING_EPISODE_ACCEPTANCE_GATE_V1' }
$Report = [ordered]@{
  schema = 'LEARNING_EPISODE_ACCEPTANCE_GATE_VALIDATION_V1'
  status = $Status
  checked_at = (Get-Date).ToString('o')
  study_proof_path = $StudyProofPath
  accepted_result = $AcceptedResult
  non_death_rule = [ordered]@{
    parked_count = @($Parked).Count
    open_gap_count = @($OpenGaps).Count
    continued_after_parked_gap = if($Study -and $Study.study_life) { [int]$Study.study_life.counters.continued_after_parked_gap } else { 0 }
  }
  source_discipline = [ordered]@{
    source_attempt_limit_per_episode = if($Study -and $Study.study_life) { [int]$Study.study_life.counters.source_attempts_allowed_per_episode } else { $null }
    source_attempts_used = if($Study -and $Study.study_life) { [int]$Study.study_life.counters.source_attempts_used } else { $null }
    batch_proofs_checked = @($BatchProofs).Count
    batch_digests_checked = @($BatchDigests).Count
    raw_source_paths_checked = @($RawSourcePaths)
  }
  safety = [ordered]@{
    memory_unchanged = if($Study) { $Study.memory_state.unchanged } else { $false }
    practical_actions_created = if($Study -and $Study.study_life) { [int]$Study.study_life.counters.practical_actions_created } else { $null }
    code_writes = if($Study -and $Study.study_life) { [int]$Study.study_life.counters.code_writes } else { $null }
    active_memory_mutations = if($Study -and $Study.study_life) { [int]$Study.study_life.counters.active_memory_mutations } else { $null }
  }
  outputs_checked = @($AcceptedOutputs | ForEach-Object { [ordered]@{ topic=$_.topic; classification=$_.classification; atom_candidate=$_.atom_candidate; digest_path=$_.digest_path; atom_acceptance_route=$(if($_.atom_candidate -eq $true -or [string]$_.classification -eq 'ATOM_CANDIDATE'){'EXISTING_ACCEPTED_ATOM_RETENTION_MECHANISM'}else{$null}) } })
  atom_acceptance_route = 'EXISTING_ACCEPTED_ATOM_RETENTION_MECHANISM'
  atom_acceptance_validators = @('validators/validate_accepted_atom_retention_contract_v1.ps1','validators/validate_accepted_atom_retention_micro_proof_v1.ps1','validators/validate_accepted_atom_retention_passports_v1.ps1','validators/validate_compact_atom_storage_bridge_micro_proof_v1.ps1')
  warnings = @($Warnings)
  errors = @($Errors)
  boundary = 'Acceptance gate validates episode discipline and routes atom candidates; it does not mutate active memory or claim accepted atom without downstream atom retention proof.'
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutPath -Parent) | Out-Null
$Report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $OutPath -Encoding UTF8
if($Errors.Count -eq 0) {
  Write-Host "VALIDATION_STATUS=$Status"
  Write-Host "VALIDATION_OUT=$OutPath"
  exit 0
}
Write-Host "VALIDATION_STATUS=$Status"
Write-Host "VALIDATION_OUT=$OutPath"
Write-Host ('ERRORS=' + ($Errors -join ';'))
exit 1
