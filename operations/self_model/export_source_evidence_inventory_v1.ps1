param(
  [string]$OutputPath='reports/self_development/SOURCE_EVIDENCE_INVENTORY_V1.json',
  [switch]$SimulateSchoolMissing,
  [switch]$SimulateRuntimeSourcesMissing
)
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Exists([string]$Path){ return (Test-Path -LiteralPath $Path) }
function JsonStatus([string]$Path){
  if(Test-Path $Path){
    try{
      $j=Get-Content $Path -Raw|ConvertFrom-Json
      if($j.PSObject.Properties['status']){ return [string]$j.status }
      return 'PRESENT_NO_STATUS'
    } catch { return 'UNREADABLE' }
  }
  return 'MISSING'
}
function Add-Source($List,[string]$SourceId,[string]$Kind,[string]$Authority,[string]$Path,[string]$Health,[int]$PriorityHint,[string[]]$Signals,[string[]]$ProofRefs,[string]$Notes){
  $row = New-Object PSObject
  $row | Add-Member -NotePropertyName id -NotePropertyValue $SourceId
  $row | Add-Member -NotePropertyName kind -NotePropertyValue $Kind
  $row | Add-Member -NotePropertyName authority -NotePropertyValue $Authority
  $row | Add-Member -NotePropertyName path -NotePropertyValue $Path
  $row | Add-Member -NotePropertyName health -NotePropertyValue $Health
  $row | Add-Member -NotePropertyName priority_hint -NotePropertyValue $PriorityHint
  $row | Add-Member -NotePropertyName signals -NotePropertyValue ([string[]]@($Signals))
  $row | Add-Member -NotePropertyName proof_refs -NotePropertyValue ([string[]]@($ProofRefs))
  $row | Add-Member -NotePropertyName notes -NotePropertyValue $Notes
  $row | Add-Member -NotePropertyName can_command -NotePropertyValue $false
  $row | Add-Member -NotePropertyName can_suggest -NotePropertyValue ($Health -notin @('MISSING','STALE','FAILED'))
  $row | Add-Member -NotePropertyName required_for_selection -NotePropertyValue $false
  $List = @($List) + $row
  return @($List)
}
$sources=@()
$identityPath='self_model/BUILDER_IDENTITY_CONTRACT_V1.json'
$snapshotPath='reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json'
$gapMapPath='reports/self_development/BUILDER_GAP_MAP_V1.json'
$routeLock='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md'
$identityHealth=if(Exists $identityPath){'AVAILABLE'}else{'MISSING'}
$snapshotHealth=if(Exists $snapshotPath){'AVAILABLE'}else{'MISSING'}
$gapMapHealth=if(Exists $gapMapPath){'AVAILABLE'}else{'MISSING'}
$routeLockHealth=if(Exists $routeLock){'AVAILABLE'}else{'MISSING'}
$sources=Add-Source $sources 'builder_identity_contract' 'identity_contract' 'primary_internal_law' $identityPath $identityHealth 100 @('self_build_first','child_agents_second','latest_signal_not_authority','school_not_required') @('tests/self_model/BUILDER_IDENTITY_CONTRACT_V1_PROOF.json') 'Selection law, not a source packet.'
$sources=Add-Source $sources 'current_body_capability_snapshot' 'body_capability_snapshot' 'primary_internal_state' $snapshotPath $snapshotHealth 95 @('built_wired_lab_live_distinction','capability_map') @('tests/self_model/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1_PROOF.json') 'Current self/body/capability map.'
$sources=Add-Source $sources 'builder_gap_map' 'gap_map' 'primary_internal_state' $gapMapPath $gapMapHealth 94 @('known_gaps','mission_relevance','proof_needed','validator_needed') @('tests/self_model/BUILDER_GAP_MAP_V1_PROOF.json') 'Primary source for what to build next.'
$sources=Add-Source $sources 'owner_route_lock_v4' 'owner_route' 'strong_route_signal' $routeLock $routeLockHealth 90 @('route_boundaries','review_gate','do_not_require_school') @($routeLock) 'Owner-approved route lock; becomes bounded tasks through validators.'
$validatorProofs=@('tests/self_model/BUILDER_IDENTITY_CONTRACT_V1_PROOF.json','tests/self_model/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1_PROOF.json','tests/self_model/BUILDER_GAP_MAP_V1_PROOF.json','tests/compact_memory_intake/GROWTH_SIGNAL_QUALITY_V1_PROOF.json','tests/autonomous_inner_motor/GROWTH_DIRECTED_TASK_SELECTION_V1_PROOF.json')
$passCount=@($validatorProofs|Where-Object{(JsonStatus $_) -like 'PASS_*'}).Count
$validatorHealth=if($passCount -ge 3){'AVAILABLE'}else{'WEAK'}
$sources=Add-Source $sources 'validator_proof_set' 'validator_reports' 'high_value_evidence' 'tests/*' $validatorHealth 80 @('proof_state','validator_state','acceptance_boundaries') @($validatorProofs) 'Validators can raise gaps and proof paths but do not choose alone.'
$aimoLive='tests/live_start/AIMO_CONCRETE_GROWTH_TASK_SELECTION_LIVE_V1_PROOF.json'
$aimoLiveHealth=if(Exists $aimoLive){JsonStatus $aimoLive}else{'MISSING'}
$sources=Add-Source $sources 'aimo_live_baseline' 'live_proof' 'evidence_not_brain' $aimoLive $aimoLiveHealth 70 @('current_live_baseline','concrete_task_selection','not_source_agnostic_yet') @($aimoLive) 'Useful live baseline; not proof of identity-based selection.'
$schoolProof='tests/live_start/SCHOOL_ONLY_RESTART_AFTER_MEMORY_FIX_V1_PROOF.json'
$schoolHealth=if($SimulateSchoolMissing){'MISSING'}elseif(Exists $schoolProof){JsonStatus $schoolProof}else{'MISSING'}
$sources=Add-Source $sources 'school_optional_source' 'optional_material_source' 'optional_evidence_only' $schoolProof $schoolHealth 30 @('fresh_material_possible','optional_not_required','not_brain') @($schoolProof) 'School may provide material if healthy; selection must continue without it.'
$episodicHealth=if((JsonStatus 'tests/memory/episodic/EPISODIC_RECALL_V1_PROOF.json') -like 'PASS_*'){'AVAILABLE'}else{'MISSING'}
$sources=Add-Source $sources 'episodic_memory_proofs' 'memory_lesson_source' 'evidence_not_proof_by_itself' 'tests/memory/episodic' $episodicHealth 50 @('lessons','recall','prior_failures') @('tests/memory/episodic/EPISODIC_RECALL_V1_PROOF.json','tests/memory/episodic/EPISODIC_MEMORY_CELL_V1_PROOF.json') 'Memory can inform candidates but is not authority or proof alone.'
$reasoningHealth=if((JsonStatus 'tests/reasoning/REASONING_EPISODE_V1_PROOF.json') -like 'PASS_*'){'AVAILABLE'}else{'MISSING'}
$sources=Add-Source $sources 'reasoning_episode_proofs' 'reasoning_lesson_source' 'evidence_not_proof_by_itself' 'tests/reasoning' $reasoningHealth 50 @('reasoning_episode','decision_lessons') @('tests/reasoning/REASONING_EPISODE_V1_PROOF.json','tests/reasoning/EPISODIC_RECALL_DECISION_V1_PROOF.json') 'Reasoning traces can suggest candidate shapes.'
$queueRoot='.runtime/compact_memory_intake_v1/queue'
$runtimeHealth='MISSING'
$latestPackets=@()
if((-not $SimulateRuntimeSourcesMissing) -and (Test-Path $queueRoot)){
  $latestPackets=@(Get-ChildItem $queueRoot -File -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 8 | ForEach-Object {
    try{
      $j=Get-Content $_.FullName -Raw|ConvertFrom-Json
      $firstAtom=@($j.atoms|Select-Object -First 1)
      [ordered]@{path=$_.FullName;name=$_.Name;last_write_time=$_.LastWriteTime.ToString('o');source_kind=[string]$j.source_kind;source_id=[string]$j.source_id;topic=[string]$firstAtom.topic;next_action_candidate=[string]$j.influence.next_action_candidate;specific_gap=[string]$j.influence.specific_gap}
    } catch { [ordered]@{path=$_.FullName;name=$_.Name;error='UNREADABLE'} }
  })
  if($latestPackets.Count -gt 0){ $runtimeHealth='AVAILABLE' }
}
$sources=Add-Source $sources 'latest_runtime_packets' 'runtime_source_packets' 'freshness_modifier_only' $queueRoot $runtimeHealth 20 @('freshness_modifier','possible_residue','must_be_filtered') @() 'Latest packets are evidence only and must not command selection.'
$inventory=[ordered]@{
  schema='source_evidence_inventory_v1'
  status='SOURCE_EVIDENCE_INVENTORY_EXPORTED'
  route_lock=$routeLock
  source_authority_rule='sources_can_suggest_not_command; builder_identity_and_gap_map_drive_selection'
  school_dependency_rule='school_optional_and_non_blocking'
  latest_signal_rule='latest_signal_is_freshness_modifier_not_authority'
  simulation=[ordered]@{school_missing=[bool]$SimulateSchoolMissing;runtime_sources_missing=[bool]$SimulateRuntimeSourcesMissing}
  sources=@($sources)
  latest_runtime_packets=@($latestPackets)
  required_sources_for_selection=@('builder_identity_contract','current_body_capability_snapshot','builder_gap_map')
  optional_sources=@('school_optional_source','latest_runtime_packets','episodic_memory_proofs','reasoning_episode_proofs')
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent)|Out-Null
$inventory|ConvertTo-Json -Depth 100|Set-Content $OutputPath -Encoding UTF8
Write-Host 'EXPORT_STATUS=SOURCE_EVIDENCE_INVENTORY_EXPORTED'
Write-Host ('OUTPUT_PATH='+$OutputPath)
Write-Host ('SOURCE_COUNT='+@($sources).Count)
Write-Host 'LIVE_PROCESS_TOUCHED=false'


