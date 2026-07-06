param(
  [int]$TargetCount = 50000,
  [ValidateSet(500, 1000)]
  [int]$ShardSize = 500,
  [string]$OutputRoot = 'reports/self_development/phase165s_d2_big_curriculum_material_factory',
  [string]$DeterministicSeed = '',
  [switch]$EmitJson
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Write-D2AJson {
  param([string]$Path, $Value)
  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Value | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function ConvertTo-D2ASlug {
  param([string]$Value)
  return (($Value.ToLowerInvariant() -replace '[^a-z0-9]+', '_').Trim('_'))
}

function Get-D2ASeedNumbers {
  param([string]$Seed, [int]$SpaceSize)
  if ([string]::IsNullOrWhiteSpace($Seed)) {
    return [pscustomobject]@{ offset = 0; step = 1 }
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Seed))
  } finally {
    $sha.Dispose()
  }
  $steps = @(3, 7, 9, 11, 13, 17, 19, 21, 23, 27, 29, 31, 33, 37, 39, 41, 43, 47, 49, 51)
  return [pscustomobject]@{
    offset = [int]([System.BitConverter]::ToUInt32($bytes, 0) % [uint32]$SpaceSize)
    step = [int]$steps[[System.BitConverter]::ToUInt32($bytes, 4) % [uint32]$steps.Count]
  }
}

function Get-D2AAcceptedAtomIds {
  param([string]$RepoRoot)
  $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $sources = @(
    @{ path = 'packs/registry.json'; property = 'phase162_accepted_atom_references' },
    @{ path = 'reports/self_development/accepted_change_memory_snapshot.json'; property = 'phase162_accepted_atom_memory_records' }
  )
  foreach ($source in $sources) {
    $full = Join-Path $RepoRoot $source.path
    if (-not (Test-Path -LiteralPath $full)) {
      throw "ACCEPTED_ATOM_SOURCE_MISSING=$($source.path)"
    }
    $root = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json
    if ($root.PSObject.Properties.Name -contains $source.property) {
      foreach ($record in @($root.($source.property))) {
        if (-not [string]::IsNullOrWhiteSpace([string]$record.atom_id)) {
          [void]$ids.Add([string]$record.atom_id)
        }
      }
    }
  }
  return ,$ids
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($TargetCount -lt 1 -or $TargetCount -gt 50000) {
  throw "TARGET_COUNT_MUST_BE_1_TO_50000=$TargetCount"
}

$protectedDirty = @(git -C $repoRoot status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1 route_locks reports/self_development/accepted_change_memory_snapshot.json reports/self_development/SELF_MODEL_ACTIVE_MAP.json)
if ($protectedDirty.Count -gt 0) {
  throw "PROTECTED_OR_ACCEPTED_STATE_DIRTY_BEFORE_GENERATION=$($protectedDirty -join '; ')"
}

$domains = @(
  [ordered]@{ topic='filesystem_concepts_and_procedures'; summary='Operate on filesystem artifacts with explicit path, type, existence, and mutation boundaries.'; subtopics=@('absolute_path_resolution','relative_path_resolution','file_existence_check','directory_creation','safe_file_read','safe_file_write','recursive_enumeration','file_hash_verification','encoding_selection','path_boundary_validation') },
  [ordered]@{ topic='repository_and_git_procedures'; summary='Use repository and Git state as verifiable operational context rather than assumption.'; subtopics=@('repo_identity_gate','branch_verification','head_origin_comparison','working_tree_inspection','tracked_untracked_distinction','diff_scope_review','commit_boundary','push_boundary','history_reading','non_destructive_recovery') },
  [ordered]@{ topic='proof_and_validation'; summary='Bind claims to executable checks, concrete evidence, and explicit failure conditions.'; subtopics=@('validator_contract','pass_fail_semantics','fresh_evidence_check','proof_json_shape','terminal_output_capture','negative_case_validation','cross_file_consistency','count_reconciliation','hash_integrity','acceptance_gate') },
  [ordered]@{ topic='reports_vs_proofs'; summary='Keep human explanation separate from machine-checkable evidence and avoid report-only success claims.'; subtopics=@('report_role','proof_role','claim_evidence_link','narrative_limit','proof_path_reference','status_consistency','report_freshness','proof_freshness','summary_without_overclaim','evidence_precedence') },
  [ordered]@{ topic='protected_state_governance'; summary='Treat protected state changes as authorized, bounded, atomic, validated, and rollback-capable operations.'; subtopics=@('protected_file_detection','authorization_gate','candidate_before_apply','atomic_write_plan','rollback_snapshot','post_mutation_validation','owner_approval_boundary','no_silent_mutation','protected_dirty_check','apply_scope_limit') },
  [ordered]@{ topic='curriculum_school_atom_lifecycle'; summary='Move learning material through curriculum, lesson, candidate, guard, acceptance, and visibility stages.'; subtopics=@('raw_material_stage','curriculum_pack_stage','lesson_normalization','school_execution','lesson_result','atom_candidate_creation','c2b_policy_guard','phase162_acceptance','accepted_atom_record','next_cycle_visibility') },
  [ordered]@{ topic='self_map_body_map_map_signal'; summary='Use maps as derived diagnostic inputs while preserving external decision authority.'; subtopics=@('self_map_role','body_map_role','map_refresh','map_signal_classification','not_direct_command','mode_decision_authority','derived_evidence_boundary','health_signal','selector_recommendation','stale_map_detection') },
  [ordered]@{ topic='owner_task_hint_instruction_routing'; summary='Classify Owner communication before execution and route tasks, hints, instructions, and controls correctly.'; subtopics=@('owner_task_detection','owner_hint_detection','instruction_detection','stop_control','pause_control','message_normalization','route_decision','inbox_consumption','malformed_message','authority_interpretation') },
  [ordered]@{ topic='material_catalogue_provenance_source_ladder'; summary='Track where material came from, its authority, and the review level required before learning.'; subtopics=@('catalogue_entry','provenance_chain','source_authority','owner_approved_source','generated_material_source','source_ladder','content_hash','dedupe_key','source_refresh','untrusted_material_label') },
  [ordered]@{ topic='artifact_formats_and_conversion'; summary='Select format-specific procedures and proof for markdown, JSON, text, office, and PDF artifacts.'; subtopics=@('markdown_artifact','json_artifact','text_artifact','docx_artifact','pptx_artifact','xlsx_artifact','pdf_artifact','format_conversion','round_trip_validation','binary_vs_text_handling') },
  [ordered]@{ topic='runtime_session_log_concepts'; summary='Use runtime sessions and logs as bounded evidence without confusing them with accepted persistent state.'; subtopics=@('runtime_session_root','event_log','decision_trace','error_ledger','experience_ledger','session_manifest','runtime_pointer','log_line_schema','session_cleanup_boundary','runtime_vs_persistent_state') },
  [ordered]@{ topic='module_validator_runner_orchestrator'; summary='Respect component ownership: modules implement logic, validators decide evidence, runners compose trials, orchestrators own flow.'; subtopics=@('module_contract','validator_contract','runner_scope','orchestrator_boundary','parameter_validation','child_process_result','function_reuse','script_idempotence','error_propagation','component_wiring') },
  [ordered]@{ topic='quarantine_rollback_risk_review'; summary='Isolate unsafe material, preserve reasons, and make recovery and review explicit.'; subtopics=@('quarantine_trigger','quarantine_record','risk_flagging','risk_level','rollback_plan','rollback_execution','snapshot_restore','partial_failure','safety_violation','review_release_gate') },
  [ordered]@{ topic='delivery_handoff_evidence_pack'; summary='Deliver results with paths, status, evidence, limitations, and a precise next action.'; subtopics=@('delivery_summary','changed_file_list','command_list','proof_link','report_link','remaining_risk','not_done_boundary','handoff_manifest','operator_command','next_required_action') },
  [ordered]@{ topic='deepening_cycle_why_chain_gap_types'; summary='Deepen knowledge by tracing causes, classifying gaps, and selecting the next bounded learning layer.'; subtopics=@('why_chain','knowledge_gap','procedure_gap','proof_gap','requirement_gap','reuse_gap','behavior_gap','visibility_gap','root_cause_boundary','next_layer_selection') },
  [ordered]@{ topic='procedure_atoms_after_primitives'; summary='Turn known primitive concepts into bounded, ordered, testable procedures.'; subtopics=@('precondition','ordered_steps','input_contract','output_contract','failure_branch','retry_rule','idempotence_rule','side_effect_boundary','completion_check','procedure_reuse') },
  [ordered]@{ topic='proof_atoms'; summary='Represent reusable evidence rules that specify what demonstrates a claim.'; subtopics=@('existence_proof','parse_proof','count_proof','identity_proof','mutation_proof','non_mutation_proof','runtime_proof','persistence_proof','visibility_proof','reuse_proof') },
  [ordered]@{ topic='requirement_atoms'; summary='Represent constraints as testable obligations with scope and failure meaning.'; subtopics=@('required_field','required_path','required_count','required_status','forbidden_action','scope_boundary','compatibility_requirement','freshness_requirement','authority_requirement','acceptance_requirement') },
  [ordered]@{ topic='reuse_atoms'; summary='Capture when accepted knowledge should be retrieved and applied instead of relearned.'; subtopics=@('known_scan','accepted_lookup','starts_from_zero_check','reuse_trigger','reuse_classification','reuse_next_layer','reuse_failure','reuse_visibility','reuse_consistency','reuse_behavior_delta') },
  [ordered]@{ topic='acceptance_visibility_and_persistence'; summary='Prove accepted knowledge survives process boundaries and is discoverable through canonical read paths.'; subtopics=@('accepted_memory_record','self_map_note','registry_reference','atomic_accept','controller_finalization','fresh_process_read','startup_visibility','next_cycle_read','exactly_once_record','persistent_evidence') }
)

$atomTypes = @(
  [ordered]@{ name='concept_atom'; purpose='define the operational meaning and distinctions' },
  [ordered]@{ name='procedure_atom'; purpose='define ordered actions, preconditions, and completion checks' },
  [ordered]@{ name='proof_atom'; purpose='define evidence that demonstrates the claim' },
  [ordered]@{ name='requirement_atom'; purpose='define a testable obligation and its failure meaning' },
  [ordered]@{ name='reuse_atom'; purpose='define when accepted knowledge should be retrieved and applied' }
)

$contexts = @(
  [ordered]@{ name='identify'; guidance='identify the artifact, state, authority, and applicable boundary before acting' },
  [ordered]@{ name='create'; guidance='create only the bounded output and declare every side effect' },
  [ordered]@{ name='inspect'; guidance='inspect the canonical source and collect exact-path evidence' },
  [ordered]@{ name='validate'; guidance='run explicit positive and negative checks before claiming success' },
  [ordered]@{ name='compare'; guidance='compare before and after state using stable identifiers and counts' },
  [ordered]@{ name='repair'; guidance='repair the smallest proven fault with rollback available' },
  [ordered]@{ name='route'; guidance='route the input to the owning organ without bypassing gates' },
  [ordered]@{ name='preserve'; guidance='preserve protected, historical, and unrelated state while working' },
  [ordered]@{ name='handoff'; guidance='handoff paths, status, evidence, limitations, and next action' },
  [ordered]@{ name='reuse'; guidance='reuse accepted knowledge and advance to the next unresolved layer' }
)

$layers = @(
  [ordered]@{ name='foundation'; focus='the base distinction that prevents starting from zero' },
  [ordered]@{ name='bounded_procedure'; focus='a safe operational sequence with explicit inputs and outputs' },
  [ordered]@{ name='failure_boundary'; focus='failure modes, quarantine conditions, and stop behavior' },
  [ordered]@{ name='evidence_gate'; focus='the proof required before a PASS or acceptance claim' },
  [ordered]@{ name='next_cycle_reuse'; focus='how a later process retrieves and applies the accepted result' }
)

$spaceSize = $domains.Count * 10 * $atomTypes.Count * $contexts.Count * $layers.Count
if ($spaceSize -ne 50000) {
  throw "CATALOGUE_SPACE_UNEXPECTED=$spaceSize"
}

$acceptedIds = Get-D2AAcceptedAtomIds -RepoRoot $repoRoot
$seedNumbers = Get-D2ASeedNumbers -Seed $DeterministicSeed -SpaceSize $spaceSize
$outputFull = if ([System.IO.Path]::IsPathRooted($OutputRoot)) { [System.IO.Path]::GetFullPath($OutputRoot) } else { [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputRoot)) }
$repoPrefix = $repoRoot.TrimEnd('\') + '\'
if (-not $outputFull.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "OUTPUT_ROOT_MUST_BE_INSIDE_REPO=$outputFull"
}
$rawRoot = Join-Path $outputFull 'raw_shards'
New-Item -ItemType Directory -Force -Path $rawRoot | Out-Null
Get-ChildItem -LiteralPath $rawRoot -File -Filter '*.jsonl' -ErrorAction SilentlyContinue | Remove-Item -Force

$topicCounts = [ordered]@{}
foreach ($domain in $domains) { $topicCounts[$domain.topic] = 0 }
$atomTypeCounts = [ordered]@{}
foreach ($type in $atomTypes) { $atomTypeCounts[$type.name] = 0 }
$riskLevelCounts = [ordered]@{ LOW=0; MEDIUM=0; HIGH=0 }
$shardPaths = New-Object System.Collections.Generic.List[string]
$dedupeKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$duplicateCount = 0
$acceptedCollisionCount = 0
$acceptedCollisionAvoidedCount = 0
$safeCount = 0
$quarantineCount = 0
$acceptedFalseCount = 0
$trustedFalseCount = 0
$writer = $null
$currentShard = 0
$currentShardCount = 0

try {
  for ($emitted = 0; $emitted -lt $TargetCount; $emitted += 1) {
    if (($emitted % $ShardSize) -eq 0) {
      if ($null -ne $writer) { $writer.Dispose() }
      $currentShard += 1
      $currentShardCount = 0
      $shardName = 'curriculum_candidates_{0:d5}.jsonl' -f $currentShard
      $shardFull = Join-Path $rawRoot $shardName
      $writer = [System.IO.StreamWriter]::new($shardFull, $false, [System.Text.UTF8Encoding]::new($false))
      $shardPaths.Add((($shardFull.Substring($repoRoot.Length + 1)) -replace '\\', '/'))
    }

    $linear = [int](($seedNumbers.offset + ([int64]$emitted * $seedNumbers.step)) % $spaceSize)
    $layerIndex = $linear % $layers.Count; $linear = [math]::Floor($linear / $layers.Count)
    $contextIndex = $linear % $contexts.Count; $linear = [math]::Floor($linear / $contexts.Count)
    $atomTypeIndex = $linear % $atomTypes.Count; $linear = [math]::Floor($linear / $atomTypes.Count)
    $subtopicIndex = $linear % 10; $linear = [math]::Floor($linear / 10)
    $domainIndex = $linear % $domains.Count

    $domain = $domains[$domainIndex]
    $subtopic = [string]$domain.subtopics[$subtopicIndex]
    $atomType = $atomTypes[$atomTypeIndex]
    $context = $contexts[$contextIndex]
    $layer = $layers[$layerIndex]
    $topicSlug = ConvertTo-D2ASlug $domain.topic
    $subtopicSlug = ConvertTo-D2ASlug $subtopic
    $dedupeKey = "d2a|$topicSlug|$subtopicSlug|$($atomType.name)|$($context.name)|$($layer.name)"
    if (-not $dedupeKeys.Add($dedupeKey)) {
      $duplicateCount += 1
      continue
    }

    $targetAtomId = "d2a.$($atomType.name).$topicSlug.$subtopicSlug.$($context.name).$($layer.name).v1"
    if ($acceptedIds.Contains($targetAtomId)) {
      $acceptedCollisionAvoidedCount += 1
      $targetAtomId = "d2a_candidate.$($atomType.name).$topicSlug.$subtopicSlug.$($context.name).$($layer.name).v1"
    }
    if ($acceptedIds.Contains($targetAtomId)) {
      $acceptedCollisionCount += 1
    }

    $riskLevel = 'LOW'
    $riskFlags = @()
    if ($domain.topic -eq 'protected_state_governance') {
      $riskLevel = 'MEDIUM'
      $riskFlags += 'protected_state_context'
      if ($context.name -in @('create', 'repair') -and $layer.name -in @('failure_boundary', 'evidence_gate')) {
        $riskLevel = 'HIGH'
        $riskFlags += 'requires_explicit_protected_apply_authorization'
      }
    } elseif ($domain.topic -in @('repository_and_git_procedures', 'quarantine_rollback_risk_review') -and $context.name -eq 'repair') {
      $riskLevel = 'MEDIUM'
      $riskFlags += 'state_change_requires_bounded_review'
    } elseif ($domain.topic -eq 'artifact_formats_and_conversion' -and $subtopic -in @('docx_artifact','pptx_artifact','xlsx_artifact','pdf_artifact','format_conversion')) {
      $riskLevel = 'MEDIUM'
      $riskFlags += 'format_specific_validation_required'
    }
    if ($riskFlags.Count -eq 0) { $riskFlags = @('none_identified_at_material_stage') }

    $expectedCheck = switch ($atomType.name) {
      'concept_atom' { 'CLASSIFY_AND_NAME_NEXT_LAYER' }
      'procedure_atom' { 'ORDERED_SAFE_STEPS_WITH_COMPLETION_CHECK' }
      'proof_atom' { 'EVIDENCE_PATH_AND_PASS_FAIL_RULE_IDENTIFIED' }
      'requirement_atom' { 'OBLIGATION_AND_FAILURE_MEANING_IDENTIFIED' }
      'reuse_atom' { 'KNOWN_SCAN_REUSES_ACCEPTED_ATOM_AND_ADVANCES' }
    }

    $candidate = [ordered]@{
      candidate_id = "PHASE165S_D2A_$topicSlug`_$subtopicSlug`_$($atomType.name)`_$($context.name)`_$($layer.name)"
      dedupe_key = $dedupeKey
      topic = [string]$domain.topic
      subtopic = $subtopic
      atom_type_suggestion = [string]$atomType.name
      candidate_status = 'STAGED_RAW_CURRICULUM_CANDIDATE'
      accepted = $false
      trusted = $false
      source = 'GENERATED_OWNER_APPROVED_CURRICULUM_CANDIDATE'
      provenance = 'PHASE165S_D2A_GENERATED_MATERIAL_FACTORY'
      risk_level = $riskLevel
      risk_flags = @($riskFlags)
      concept_id = "$topicSlug.$subtopicSlug.$($context.name).$($layer.name)"
      target_atom_id_suggestion = $targetAtomId
      explanation = "$($domain.summary) For '$subtopic', Builder should $($context.guidance). This $($atomType.name) candidate is limited to $($layer.focus)."
      guided_example = "When a task presents '$subtopic' in a '$($context.name)' situation, classify it under '$($domain.topic)', apply the $($layer.name) boundary, and keep the result staged until school and acceptance gates pass."
      check_prompt = "Can Builder handle '$subtopic' for '$($context.name)' as a $($atomType.name) without bypassing the $($layer.name) boundary?"
      expected_check_result = $expectedCheck
      behavior_change = "After acceptance, Builder should retrieve this $($atomType.name) for '$subtopic', avoid re-deriving the base rule, and move to the next unresolved operational layer."
      next_layer_questions = @(
        "What canonical source or accepted atom already covers '$subtopic'?",
        "Which validator or proof demonstrates the '$($layer.name)' requirement?",
        "What authority and rollback boundary applies before '$($context.name)' action?"
      )
      allowed_actions = @('read_repo','read_route_lock','parse_schema','write_runtime','observe_live_surface')
      forbidden_actions = @('commit','push','branch_switch','accepted_repo_mutation','protected_state_mutation')
      requires_school_acceptance = $true
      requires_c2b_guard = $true
      requires_phase162_acceptance = $true
    }

    $writer.WriteLine(($candidate | ConvertTo-Json -Depth 20 -Compress))
    $currentShardCount += 1
    $topicCounts[$domain.topic] = [int]$topicCounts[$domain.topic] + 1
    $atomTypeCounts[$atomType.name] = [int]$atomTypeCounts[$atomType.name] + 1
    $riskLevelCounts[$riskLevel] = [int]$riskLevelCounts[$riskLevel] + 1
    if ($riskLevel -eq 'HIGH') { $quarantineCount += 1 } else { $safeCount += 1 }
    $acceptedFalseCount += 1
    $trustedFalseCount += 1
  }
} finally {
  if ($null -ne $writer) { $writer.Dispose() }
}

$generatedAt = (Get-Date).ToUniversalTime().ToString('o')
$index = [ordered]@{
  schema = 'PHASE165S_D2A_MATERIAL_BANK_INDEX_V1'
  total_candidate_count = $acceptedFalseCount
  shard_count = $shardPaths.Count
  shard_size = $ShardSize
  topic_counts = $topicCounts
  atom_type_counts = $atomTypeCounts
  risk_level_counts = $riskLevelCounts
  duplicate_count = $duplicateCount
  accepted_collision_count = $acceptedCollisionCount
  accepted_collision_avoided_count = $acceptedCollisionAvoidedCount
  accepted_atom_reference_count = $acceptedIds.Count
  deterministic_seed = $DeterministicSeed
  permutation_offset = $seedNumbers.offset
  permutation_step = $seedNumbers.step
  generated_at = $generatedAt
  generator_version = 'PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_FACTORY_001'
  material_trust = 'RAW_STAGED_NOT_ACCEPTED_NOT_TRUSTED'
}
$manifest = [ordered]@{
  schema = 'PHASE165S_D2A_SCHOOL_READY_MANIFEST_V1'
  status = 'READY_FOR_SCHOOL_STAGING_REVIEW'
  output_root = (($outputFull.Substring($repoRoot.Length + 1)) -replace '\\', '/')
  shard_paths = $shardPaths.ToArray()
  total_candidate_count = $acceptedFalseCount
  safe_candidate_count = $safeCount
  quarantine_candidate_count = $quarantineCount
  accepted_false_count = $acceptedFalseCount
  trusted_false_count = $trustedFalseCount
  requires_school_acceptance = $true
  requires_c2b_guard = $true
  requires_phase162_acceptance = $true
  next_required_action = 'PHASE165S_D2B_BIG_CURRICULUM_SCHOOL_WAVE_DRY_RUN_OR_AUTONOMOUS_RUN'
}
Write-D2AJson -Path (Join-Path $outputFull 'material_bank_index.json') -Value $index
Write-D2AJson -Path (Join-Path $outputFull 'school_ready_manifest.json') -Value $manifest

$result = [pscustomobject][ordered]@{
  status = 'PASS_GENERATION_COMPLETED'
  output_root = $manifest.output_root
  total_candidate_count = $acceptedFalseCount
  shard_count = $shardPaths.Count
  shard_size = $ShardSize
  safe_candidate_count = $safeCount
  quarantine_candidate_count = $quarantineCount
  duplicate_count = $duplicateCount
  accepted_collision_count = $acceptedCollisionCount
  index_path = "$($manifest.output_root)/material_bank_index.json"
  manifest_path = "$($manifest.output_root)/school_ready_manifest.json"
  accepted_atoms_created = $false
  protected_state_mutated = $false
  next_required_action = $manifest.next_required_action
}

if ($EmitJson) {
  $result | ConvertTo-Json -Depth 20
} else {
  Write-Host 'PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_FACTORY_GENERATE_RESULT=PASS'
  Write-Host "TOTAL_CANDIDATE_COUNT=$($result.total_candidate_count)"
  Write-Host "SHARD_COUNT=$($result.shard_count)"
  Write-Host "SAFE_CANDIDATE_COUNT=$($result.safe_candidate_count)"
  Write-Host "QUARANTINE_CANDIDATE_COUNT=$($result.quarantine_candidate_count)"
  Write-Host "ACCEPTED_COLLISION_COUNT=$($result.accepted_collision_count)"
  Write-Host "NEXT_REQUIRED_ACTION=$($result.next_required_action)"
}
