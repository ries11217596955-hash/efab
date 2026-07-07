param([string]$OutputPath='reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json')
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function HasPath([string]$Path){ return (Test-Path -LiteralPath $Path) }
function ProofStatus([string]$Path){ if(Test-Path $Path){ try{ return [string](Get-Content $Path -Raw|ConvertFrom-Json).status }catch{return 'UNREADABLE'} } return 'MISSING' }
$head=(git rev-parse HEAD).Trim()
$branch=(git branch --show-current).Trim()
$compositionPath='reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
$compositionStatus=$(if(Test-Path $compositionPath){'PRESENT'}else{'MISSING'})
$liveAimoProof='tests/live_start/AIMO_CONCRETE_GROWTH_TASK_SELECTION_LIVE_V1_PROOF.json'
$schoolProof='tests/live_start/SCHOOL_ONLY_RESTART_AFTER_MEMORY_FIX_V1_PROOF.json'
$components=@(
  [ordered]@{name='autonomous_inner_motor';kind='organ';built=HasPath 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1';wired=HasPath 'tests/live_start/AIMO_CONCRETE_GROWTH_TASK_SELECTION_LIVE_V1_PROOF.json';lab_proven=HasPath 'tests/autonomous_inner_motor/GROWTH_DIRECTED_TASK_SELECTION_V1_PROOF.json';live_proven=(ProofStatus $liveAimoProof) -like 'PASS_*';proof_refs=@($liveAimoProof,'tests/autonomous_inner_motor/GROWTH_DIRECTED_TASK_SELECTION_V1_PROOF.json')},
  [ordered]@{name='compact_memory_intake';kind='organ';built=HasPath 'operations/compact_memory_intake/submit_compact_memory_packet_v1.ps1';wired=HasPath 'operations/compact_memory_intake/validate_growth_signal_quality_v1.ps1';lab_proven=(ProofStatus 'tests/compact_memory_intake/GROWTH_SIGNAL_QUALITY_V1_PROOF.json') -like 'PASS_*';live_proven=$false;proof_refs=@('tests/compact_memory_intake/GROWTH_SIGNAL_QUALITY_V1_PROOF.json')},
  [ordered]@{name='episodic_memory';kind='memory';built=HasPath 'operations/memory/episodic/get_episode_recall_v1.ps1';wired=HasPath 'operations/memory/episodic/validate_episode_recall_v1.ps1';lab_proven=(ProofStatus 'tests/memory/episodic/EPISODIC_RECALL_V1_PROOF.json') -like 'PASS_*';live_proven=$false;proof_refs=@('tests/memory/episodic/EPISODIC_RECALL_V1_PROOF.json','tests/memory/episodic/EPISODIC_MEMORY_CELL_V1_PROOF.json')},
  [ordered]@{name='reasoning_episode';kind='reasoning';built=HasPath 'operations/reasoning/validate_reasoning_episode_v1.ps1';wired=HasPath 'operations/reasoning/validate_episodic_recall_decision_v1.ps1';lab_proven=(ProofStatus 'tests/reasoning/REASONING_EPISODE_V1_PROOF.json') -like 'PASS_*';live_proven=$false;proof_refs=@('tests/reasoning/REASONING_EPISODE_V1_PROOF.json','tests/reasoning/EPISODIC_RECALL_DECISION_V1_PROOF.json')},
  [ordered]@{name='school';kind='optional_source';built=HasPath 'operations';wired=HasPath $schoolProof;lab_proven=$false;live_proven=(ProofStatus $schoolProof) -like 'PASS_*';proof_refs=@($schoolProof);selection_authority='optional_material_source_not_required_brain'},
  [ordered]@{name='builder_identity_contract';kind='selection_law';built=HasPath 'self_model/BUILDER_IDENTITY_CONTRACT_V1.json';wired=$false;lab_proven=(ProofStatus 'tests/self_model/BUILDER_IDENTITY_CONTRACT_V1_PROOF.json') -like 'PASS_*';live_proven=$false;proof_refs=@('tests/self_model/BUILDER_IDENTITY_CONTRACT_V1_PROOF.json')},
  [ordered]@{name='source_agnostic_path_selector';kind='selector';built=$false;wired=$false;lab_proven=$false;live_proven=$false;proof_refs=@()},
  [ordered]@{name='builder_mission_scoring';kind='selector_scoring';built=$false;wired=$false;lab_proven=$false;live_proven=$false;proof_refs=@()},
  [ordered]@{name='provenance_rejection_trace';kind='trace';built=$false;wired=$false;lab_proven=$false;live_proven=$false;proof_refs=@()},
  [ordered]@{name='child_agent_factory';kind='future_factory';built=$false;wired=$false;lab_proven=$false;live_proven=$false;proof_refs=@();acceptance='not_current_slice'}
)
$snapshot=[ordered]@{
  schema='current_body_capability_snapshot_v1'
  status='SNAPSHOT_EXPORTED'
  route_lock='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md'
  repo=[ordered]@{head=$head;branch=$branch;composition_map_path=$compositionPath;composition_status=$compositionStatus}
  distinction_rule='built_vs_wired_vs_lab_proven_vs_live_proven_are_separate_fields'
  components=@($components)
  proven_live_baseline=[ordered]@{aimo_concrete_growth_task=(ProofStatus $liveAimoProof);school=(ProofStatus $schoolProof)}
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent)|Out-Null
$snapshot|ConvertTo-Json -Depth 80|Set-Content $OutputPath -Encoding UTF8
Write-Host 'EXPORT_STATUS=SNAPSHOT_EXPORTED'
Write-Host ('OUTPUT_PATH='+$OutputPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
