param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [int]$ExpectedCount = 50000,
  [string]$OutputRoot = 'reports/self_development/phase165s_d2_big_curriculum_material_factory'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Read-D2AJson {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-D2AJson {
  param([string]$Path, $Value)
  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Value | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Write-D2AText {
  param([string]$Path, [string[]]$Lines)
  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
}

function Get-D2AAcceptedIds {
  param([string]$Root)
  $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($spec in @(
    @{ path='packs/registry.json'; property='phase162_accepted_atom_references' },
    @{ path='reports/self_development/accepted_change_memory_snapshot.json'; property='phase162_accepted_atom_memory_records' }
  )) {
    $json = Read-D2AJson (Join-Path $Root $spec.path)
    if ($json.PSObject.Properties.Name -contains $spec.property) {
      foreach ($record in @($json.($spec.property))) {
        [void]$ids.Add([string]$record.atom_id)
      }
    }
  }
  return ,$ids
}

$root = (Resolve-Path $RepoRoot).Path
$outputFull = if ([System.IO.Path]::IsPathRooted($OutputRoot)) { [System.IO.Path]::GetFullPath($OutputRoot) } else { Join-Path $root $OutputRoot }
$indexPath = Join-Path $outputFull 'material_bank_index.json'
$manifestPath = Join-Path $outputFull 'school_ready_manifest.json'
$proofPath = Join-Path $root 'proofs/self_development/PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_FACTORY_V1.json'
$reportPath = Join-Path $root 'reports/self_development/PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_FACTORY_V1.md'
$index = Read-D2AJson $indexPath
$manifest = Read-D2AJson $manifestPath
$acceptedIds = Get-D2AAcceptedIds -Root $root
$requiredTopics = @(
  'filesystem_concepts_and_procedures','repository_and_git_procedures','proof_and_validation','reports_vs_proofs',
  'protected_state_governance','curriculum_school_atom_lifecycle','self_map_body_map_map_signal',
  'owner_task_hint_instruction_routing','material_catalogue_provenance_source_ladder','artifact_formats_and_conversion',
  'runtime_session_log_concepts','module_validator_runner_orchestrator','quarantine_rollback_risk_review',
  'delivery_handoff_evidence_pack','deepening_cycle_why_chain_gap_types','procedure_atoms_after_primitives',
  'proof_atoms','requirement_atoms','reuse_atoms','acceptance_visibility_and_persistence'
)
$requiredFields = @(
  'candidate_id','dedupe_key','topic','subtopic','atom_type_suggestion','candidate_status','accepted','trusted',
  'source','provenance','risk_level','risk_flags','concept_id','target_atom_id_suggestion','explanation',
  'guided_example','check_prompt','expected_check_result','behavior_change','next_layer_questions','allowed_actions',
  'forbidden_actions','requires_school_acceptance','requires_c2b_guard','requires_phase162_acceptance'
)
$dedupe = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$candidateIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$topicCounts = @{}
$atomTypeCounts = @{}
$riskCounts = @{}
$errors = New-Object System.Collections.Generic.List[string]
$total = 0
$acceptedFalse = 0
$trustedFalse = 0
$safeCount = 0
$quarantineCount = 0
$duplicateCount = 0
$candidateIdDuplicateCount = 0
$acceptedCollisionCount = 0
$parseFailureCount = 0
$requiredFieldFailureCount = 0
$statusFailureCount = 0
$guardFailureCount = 0
$shardLineCounts = [ordered]@{}
$shards = @($manifest.shard_paths)

foreach ($relative in $shards) {
  $full = Join-Path $root ([string]$relative)
  if (-not (Test-Path -LiteralPath $full)) {
    $errors.Add("SHARD_MISSING=$relative")
    continue
  }
  $lineCount = 0
  $reader = [System.IO.StreamReader]::new($full, [System.Text.UTF8Encoding]::new($false), $true)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      $lineCount += 1
      $total += 1
      try {
        $candidate = $line | ConvertFrom-Json
      } catch {
        $parseFailureCount += 1
        continue
      }
      $missing = @($requiredFields | Where-Object { -not ($candidate.PSObject.Properties.Name -contains $_) })
      if ($missing.Count -gt 0) {
        $requiredFieldFailureCount += 1
        continue
      }
      if (-not $dedupe.Add([string]$candidate.dedupe_key)) { $duplicateCount += 1 }
      if (-not $candidateIds.Add([string]$candidate.candidate_id)) { $candidateIdDuplicateCount += 1 }
      if ([bool]$candidate.accepted -eq $false) { $acceptedFalse += 1 }
      if ([bool]$candidate.trusted -eq $false) { $trustedFalse += 1 }
      if ([string]$candidate.candidate_status -ne 'STAGED_RAW_CURRICULUM_CANDIDATE') { $statusFailureCount += 1 }
      if (-not ([bool]$candidate.requires_school_acceptance -and [bool]$candidate.requires_c2b_guard -and [bool]$candidate.requires_phase162_acceptance)) {
        $guardFailureCount += 1
      }
      if ($acceptedIds.Contains([string]$candidate.target_atom_id_suggestion)) { $acceptedCollisionCount += 1 }
      $topic = [string]$candidate.topic
      $type = [string]$candidate.atom_type_suggestion
      $risk = [string]$candidate.risk_level
      if (-not $topicCounts.ContainsKey($topic)) { $topicCounts[$topic] = 0 }
      if (-not $atomTypeCounts.ContainsKey($type)) { $atomTypeCounts[$type] = 0 }
      if (-not $riskCounts.ContainsKey($risk)) { $riskCounts[$risk] = 0 }
      $topicCounts[$topic] = [int]$topicCounts[$topic] + 1
      $atomTypeCounts[$type] = [int]$atomTypeCounts[$type] + 1
      $riskCounts[$risk] = [int]$riskCounts[$risk] + 1
      if ($risk -eq 'HIGH') { $quarantineCount += 1 } else { $safeCount += 1 }
    }
  } finally {
    $reader.Dispose()
  }
  $shardLineCounts[[string]$relative] = $lineCount
}

$topicCoverageMissing = @($requiredTopics | Where-Object { -not $topicCounts.ContainsKey($_) -or [int]$topicCounts[$_] -lt 1 })
$expectedShardCount = [int][math]::Ceiling($ExpectedCount / [double][int]$index.shard_size)
$oversizedShards = @($shardLineCounts.GetEnumerator() | Where-Object { [int]$_.Value -gt [int]$index.shard_size })
$undersizedNonFinal = @()
$shardEntries = @($shardLineCounts.GetEnumerator())
for ($i = 0; $i -lt [math]::Max(0, $shardEntries.Count - 1); $i += 1) {
  if ([int]$shardEntries[$i].Value -ne [int]$index.shard_size) { $undersizedNonFinal += [string]$shardEntries[$i].Key }
}
$protectedDirty = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1 route_locks reports/self_development/accepted_change_memory_snapshot.json reports/self_development/SELF_MODEL_ACTIVE_MAP.json)

$checks = [ordered]@{
  exact_candidate_count = ($total -eq $ExpectedCount)
  manifest_count_consistent = ([int]$manifest.total_candidate_count -eq $total)
  index_count_consistent = ([int]$index.total_candidate_count -eq $total)
  shard_count_consistent = ($shards.Count -eq [int]$index.shard_count -and $shards.Count -eq $expectedShardCount)
  multiple_shards_present = ($shards.Count -gt 1)
  shard_size_supported = ([int]$index.shard_size -in @(500,1000))
  no_oversized_shards = ($oversizedShards.Count -eq 0)
  non_final_shards_full = ($undersizedNonFinal.Count -eq 0)
  all_shards_parse = ($parseFailureCount -eq 0)
  required_fields_present = ($requiredFieldFailureCount -eq 0)
  all_accepted_false = ($acceptedFalse -eq $total)
  all_trusted_false = ($trustedFalse -eq $total)
  staged_status_only = ($statusFailureCount -eq 0)
  all_acceptance_guards_required = ($guardFailureCount -eq 0)
  dedupe_keys_unique = ($duplicateCount -eq 0 -and $dedupe.Count -eq $total)
  candidate_ids_unique = ($candidateIdDuplicateCount -eq 0 -and $candidateIds.Count -eq $total)
  no_accepted_atom_id_collision = ($acceptedCollisionCount -eq 0)
  topic_coverage_present = ($topicCoverageMissing.Count -eq 0)
  safe_count_consistent = ([int]$manifest.safe_candidate_count -eq $safeCount)
  quarantine_count_consistent = ([int]$manifest.quarantine_candidate_count -eq $quarantineCount)
  index_duplicate_count_zero = ([int]$index.duplicate_count -eq 0)
  index_collision_count_zero = ([int]$index.accepted_collision_count -eq 0)
  manifest_next_action_correct = ([string]$manifest.next_required_action -eq 'PHASE165S_D2B_BIG_CURRICULUM_SCHOOL_WAVE_DRY_RUN_OR_AUTONOMOUS_RUN')
  protected_and_accepted_state_clean = ($protectedDirty.Count -eq 0)
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { [string]$_.Key })
$status = if ($failedChecks.Count -eq 0 -and $errors.Count -eq 0) { 'PASS' } else { 'FAIL' }
$nextAction = if ($status -eq 'PASS') { 'PHASE165S_D2B_BIG_CURRICULUM_SCHOOL_WAVE_DRY_RUN_OR_AUTONOMOUS_RUN' } else { 'PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_FACTORY_TRIAGE' }

$proof = [ordered]@{
  phase = 'PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_FACTORY'
  created_utc = (Get-Date).ToUniversalTime().ToString('o')
  status = $status
  validation_passed = ($status -eq 'PASS')
  total_candidate_count = $total
  shard_count = $shards.Count
  shard_size = [int]$index.shard_size
  safe_candidate_count = $safeCount
  quarantine_candidate_count = $quarantineCount
  accepted_false_count = $acceptedFalse
  trusted_false_count = $trustedFalse
  dedupe_unique = ($duplicateCount -eq 0)
  accepted_collision_count = $acceptedCollisionCount
  protected_state_dirty_check = @($protectedDirty)
  accepted_atoms_created = $false
  self_map_manually_updated = $false
  accepted_memory_updated = $false
  generator_path = 'modules/generate_phase165s_d2a_big_curriculum_material_factory_001.ps1'
  validator_path = 'validators/validate_phase165s_d2a_big_curriculum_material_factory_v1.ps1'
  output_root = [string]$manifest.output_root
  index_path = "$($manifest.output_root)/material_bank_index.json"
  manifest_path = "$($manifest.output_root)/school_ready_manifest.json"
  topic_counts = $topicCounts
  atom_type_counts = $atomTypeCounts
  risk_level_counts = $riskCounts
  checks = $checks
  failed_checks = $failedChecks
  errors = $errors.ToArray()
  next_required_action = $nextAction
}
Write-D2AJson -Path $proofPath -Value $proof

$report = @(
  '# PHASE165S-D2A Big Curriculum Material Factory',
  '',
  "Status: $status",
  '',
  '## Boundary',
  '',
  'This bank is raw staged curriculum material. It is not accepted memory, trusted knowledge, or an accepted atom set.',
  '',
  'Codex generated material only. Builder must consume selected shards through school, the C2B guard, and the existing PHASE162 acceptance path before any atom can become accepted.',
  '',
  '## Result',
  '',
  "- Candidates: $total",
  "- Shards: $($shards.Count)",
  "- Shard size: $($index.shard_size)",
  "- Safe candidates: $safeCount",
  "- Quarantine-review candidates: $quarantineCount",
  "- Duplicate dedupe keys: $duplicateCount",
  "- Accepted atom ID collisions: $acceptedCollisionCount",
  "- Protected or accepted state dirty: $($protectedDirty.Count -gt 0)",
  '',
  '## Generate',
  '',
  '```powershell',
  'powershell -NoProfile -ExecutionPolicy Bypass -File modules/generate_phase165s_d2a_big_curriculum_material_factory_001.ps1 -TargetCount 50000 -ShardSize 500',
  '```',
  '',
  '## Validate',
  '',
  '```powershell',
  'powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_phase165s_d2a_big_curriculum_material_factory_v1.ps1',
  '```',
  '',
  '## D2B Consumption',
  '',
  'D2B should read the manifest, select bounded shard slices, preserve `trusted=false` and `accepted=false`, quarantine HIGH-risk records for review, deduplicate again at intake, and send only bounded candidates through school/C2B/PHASE162. It must not bulk-promote the bank or treat JSONL presence as learning.',
  '',
  '## Next Required Action',
  '',
  $nextAction
)
Write-D2AText -Path $reportPath -Lines $report

if ($status -eq 'PASS') {
  Write-Host 'PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_FACTORY_VALIDATE_RESULT=PASS'
  Write-Host "TOTAL_CANDIDATE_COUNT=$total"
  Write-Host "SHARD_COUNT=$($shards.Count)"
  Write-Host "SAFE_CANDIDATE_COUNT=$safeCount"
  Write-Host "QUARANTINE_CANDIDATE_COUNT=$quarantineCount"
  Write-Host "ACCEPTED_COLLISION_COUNT=$acceptedCollisionCount"
  Write-Host 'PROTECTED_STATE_DIRTY_CHECK='
  Write-Host "NEXT_REQUIRED_ACTION=$nextAction"
  exit 0
}

Write-Host 'PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_FACTORY_VALIDATE_RESULT=FAIL'
Write-Host "FAIL_REASON=$(@($failedChecks + $errors.ToArray()) -join '; ')"
exit 1
