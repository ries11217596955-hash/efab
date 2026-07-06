param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [ValidateRange(1, 100)]
  [int]$Count = 100,
  [string]$OutputRoot = '.runtime',
  [string]$BatchId = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function ConvertTo-GeneratorFullPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-GeneratorRelativePath {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  if (-not $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $Path
  }
  return ($pathFull.Substring($rootFull.Length + 1) -replace '\\', '/')
}

function Get-StructuredChoice {
  param([object[]]$Values, [int]$Seed, [int]$Divisor)
  return [string]$Values[[math]::Floor($Seed / $Divisor) % $Values.Count]
}

function Get-CycleSeed {
  param([string]$BatchId, [int]$Index)
  $cycle = 1
  if ($BatchId -match 'cycle_([0-9]+)') {
    $cycle = [int]$Matches[1]
  }
  return (($cycle - 1) * 100) + $Index - 1
}

function New-StructuredEphemeralD2BCandidate {
  param(
    [string]$BatchId,
    [int]$Index
  )

  $families = @(
    'proof', 'memory', 'source', 'action', 'quarantine', 'dedup', 'cleanup',
    'checkpoint', 'mode', 'autonomy', 'external_material', 'owner_control',
    'failure_handling', 'capability_map'
  )
  $gapTypes = @('missing_evidence_link', 'stale_state_edge', 'unsafe_retention_branch', 'validator_blind_spot', 'operator_handoff_gap', 'memory_boundary_gap', 'route_lock_gap')
  $sourceClasses = @('self_map', 'capability_map', 'action_map', 'proof_map', 'route_lock', 'validator_contract', 'runtime_summary')
  $organTargets = @('d2b_absorption', 'retention_gate', 'controlled_runtime', 'candidate_generator', 'memory_compactor', 'proof_validator', 'route_governor')
  $capabilityTargets = @('trace_pruning', 'delta_isolation', 'stop_governance', 'lookup_use', 'semantic_diversity', 'quarantine_preservation', 'state_atomicity')
  $proofRequirements = @('receipt_lookup', 'validator_pass', 'compact_hash_evidence', 'cycle_summary_match', 'negative_case_preserved', 'status_contract_match', 'bounded_growth_check')
  $validatorRequirements = @('parse_json', 'count_match', 'hash_unique', 'runtime_ready_false', 'dirty_core_absent', 'stop_reason_explicit', 'retention_pass')
  $actionPermissions = @('observe_only', 'write_runtime_delta', 'prune_success_trace', 'preserve_failure_trace', 'block_unsafe_mode', 'emit_compact_summary')
  $memoryTiers = @('runtime_delta', 'accepted_core_pointer', 'proof_receipt', 'route_map', 'capability_index', 'operator_review')
  $riskLevels = @('low_bounded', 'medium_requires_validator', 'quarantine_on_ambiguity', 'blocked_without_proof')
  $expectedStatuses = @('PASS_WITH_RECEIPT', 'STOP_WITH_REASON', 'QUARANTINE_PRESERVED', 'FAIL_FAST_WITH_DIAGNOSTIC', 'REVIEW_REQUIRED')
  $scenarios = @(
    'new atom must link to self map and proof map before promotion',
    'candidate fuel must be removed after successful retention',
    'failed candidate must preserve work current for diagnosis',
    'runtime stop file must prevent the next cycle without false success',
    'validator must reject runtime ready claims from count alone',
    'memory delta must stay in disposable runtime until promotion review',
    'receipt lookup must map accepted atom back to cycle metadata',
    'route map must point Codex away from heavy historical folders',
    'capability map must separate local proof from runtime readiness',
    'action map must require explicit permission before tracked writes',
    'proof map must connect stress evidence to bounded validators',
    'source map must reject old raw shard runtime dependencies'
  )
  $failureModes = @('missing_receipt', 'dirty_tracked_core', 'retention_not_invoked', 'candidate_material_left', 'work_current_left', 'runtime_ready_claimed', 'unbounded_loop_requested', 'external_source_dependency')
  $quarantineRules = @('preserve_trace_on_failure', 'block_full_trace_without_review', 'reject_old_repo_dependency', 'hold_when_validator_missing', 'stop_on_tracked_core_growth', 'require_owner_decision_for_runtime_ready')
  $returnProofs = @('compact_json_receipt', 'validator_stdout', 'summary_counter_match', 'heartbeat_cycle_record', 'hash_distribution_record', 'sample_lookup_record')

  $seed = Get-CycleSeed -BatchId $BatchId -Index $Index
  $family = Get-StructuredChoice -Values $families -Seed $seed -Divisor 1
  $gapType = Get-StructuredChoice -Values $gapTypes -Seed $seed -Divisor $families.Count
  $sourceClass = Get-StructuredChoice -Values $sourceClasses -Seed $seed -Divisor ($families.Count * $gapTypes.Count)
  $organTarget = Get-StructuredChoice -Values $organTargets -Seed $seed -Divisor ($families.Count * $gapTypes.Count * $sourceClasses.Count)
  $capabilityTarget = Get-StructuredChoice -Values $capabilityTargets -Seed $seed -Divisor 3
  $proofRequirement = Get-StructuredChoice -Values $proofRequirements -Seed $seed -Divisor 5
  $validatorRequirement = Get-StructuredChoice -Values $validatorRequirements -Seed $seed -Divisor 7
  $actionPermission = Get-StructuredChoice -Values $actionPermissions -Seed $seed -Divisor 11
  $memoryTier = Get-StructuredChoice -Values $memoryTiers -Seed $seed -Divisor 13
  $riskLevel = Get-StructuredChoice -Values $riskLevels -Seed $seed -Divisor 17
  $expectedStatus = Get-StructuredChoice -Values $expectedStatuses -Seed $seed -Divisor 19
  $scenario = Get-StructuredChoice -Values $scenarios -Seed $seed -Divisor 23
  $failureMode = Get-StructuredChoice -Values $failureModes -Seed $seed -Divisor 29
  $quarantineRule = Get-StructuredChoice -Values $quarantineRules -Seed $seed -Divisor 31
  $returnProof = Get-StructuredChoice -Values $returnProofs -Seed $seed -Divisor 37

  $ordinal = '{0:d4}' -f $Index
  $candidateId = "structured_d2b_candidate_${BatchId}_$ordinal"
  $atomId = "structured.d2b.atom.$BatchId.$ordinal"
  $semanticKey = "category_family=$family; gap_type=$gapType; source_class=$sourceClass; organ_target=$organTarget; capability_target=$capabilityTarget; proof_requirement=$proofRequirement; validator_requirement=$validatorRequirement; action_permission=$actionPermission; memory_tier=$memoryTier; risk_level=$riskLevel; expected_status=$expectedStatus; failure_mode=$failureMode; quarantine_rule=$quarantineRule; return_proof_expectation=$returnProof"

  return [ordered]@{
    candidate_id = $candidateId
    concept_id = "structured_d2b_${family}_${gapType}_${sourceClass}"
    target_atom_id_suggestion = $atomId
    explanation = "Structured controlled-runtime candidate. $semanticKey; scenario=$scenario."
    atom_type_suggestion = "concept"
    guided_example = "For $organTarget, handle $gapType by using $actionPermission on $memoryTier, then require $proofRequirement before the capability $capabilityTarget can advance."
    check_prompt = "Validate $validatorRequirement for $sourceClass evidence; if $failureMode appears, apply $quarantineRule and return $returnProof."
    expected_check_result = $expectedStatus
    behavior_change = "Builder links $family knowledge across self-map, capability-map, action-map, and proof-map instead of storing raw volume."
    next_layer_questions = @(
      "Does the $family route still preserve failure evidence when $failureMode occurs?",
      "Can $organTarget prove $capabilityTarget with $proofRequirement and no tracked memory bloat?",
      "Should $sourceClass feed $memoryTier only after $validatorRequirement passes?"
    )
    source = "STRUCTURED_EPHEMERAL_D2B_CANDIDATE_GENERATOR_V1"
    provenance = "structured_candidate_to_atom_circuit"
    producer_id = "generate_structured_ephemeral_candidate_batch_v1"
    source_kind = "structured_ephemeral_candidate"
    source_run_id = $BatchId
    dedup_key = "structured_d2b_candidate_$BatchId`_$ordinal"
    domain = "agent_builder_self_development"
    priority = "structured_diversity_trial"
    dependencies = @($sourceClass, $organTarget, $capabilityTarget, $proofRequirement)
    batch_id = $BatchId
    risk_level = "LOW"
    risk_flags = @("none_identified_at_material_stage")
    risk_flag = "none_identified_at_material_stage"
    validator_required = $true
    requires_school_acceptance = $true
    requires_c2b_guard = $true
    requires_phase162_acceptance = $true
    accepted = $false
    trusted = $false
  }
}

$root = (Resolve-Path $RepoRoot).Path
$outputFull = ConvertTo-GeneratorFullPath -Root $root -Path $OutputRoot
$runtimeFull = [System.IO.Path]::GetFullPath((Join-Path $root '.runtime')).TrimEnd('\','/')
$outputTrimmed = $outputFull.TrimEnd('\','/')
if (-not ($outputTrimmed.Equals($runtimeFull, [System.StringComparison]::OrdinalIgnoreCase) -or
    $outputTrimmed.StartsWith($runtimeFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
  throw "STRUCTURED_EPHEMERAL_OUTPUT_ROOT_MUST_BE_UNDER_RUNTIME=$outputFull"
}

if ([string]::IsNullOrWhiteSpace($BatchId)) {
  $BatchId = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
}
$safeBatchId = $BatchId -replace '[^A-Za-z0-9_]', '_'
$batchRoot = Join-Path $outputFull "structured_ephemeral_candidate_batch_$safeBatchId"
New-Item -ItemType Directory -Force -Path $batchRoot | Out-Null

$batchPath = Join-Path $batchRoot 'candidate_batch.jsonl'
if (Test-Path -LiteralPath $batchPath) {
  Remove-Item -LiteralPath $batchPath -Force
}

for ($i = 1; $i -le $Count; $i += 1) {
  $candidate = New-StructuredEphemeralD2BCandidate -BatchId $safeBatchId -Index $i
  $line = $candidate | ConvertTo-Json -Depth 60 -Compress
  [System.IO.File]::AppendAllText($batchPath, $line + "`n", [System.Text.UTF8Encoding]::new($false))
}

$result = [ordered]@{
  schema = 'STRUCTURED_EPHEMERAL_D2B_CANDIDATE_BATCH_GENERATOR_RESULT_V1'
  status = 'PASS'
  generator_mode = 'StructuredV1'
  created_utc = (Get-Date).ToUniversalTime().ToString('o')
  batch_id = $safeBatchId
  count = $Count
  candidate_batch_path = (Get-GeneratorRelativePath -Root $root -Path $batchPath)
  candidate_batch_full_path = $batchPath
  runtime_ready = $false
}

$result | ConvertTo-Json -Depth 20
