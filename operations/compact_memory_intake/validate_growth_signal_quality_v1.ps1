$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$submit='operations/compact_memory_intake/submit_compact_memory_packet_v1.ps1'
$policy='operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json'
Assert (Test-Path $submit) 'SUBMIT_SCRIPT_MISSING'
$testRoot='.runtime/compact_memory_growth_signal_v1/validator'
Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$policyObj=Get-Content $policy -Raw|ConvertFrom-Json
$policyObj.runtime_queue_root=(Join-Path $testRoot 'queue')
$policyObj.runtime_report_root=(Join-Path $testRoot 'reports')
$policyObj.active_growth_signal_path=(Join-Path $testRoot 'ACTIVE_GROWTH_SIGNAL.json')
$policyPath=Join-Path $testRoot 'policy.json'
$policyObj|ConvertTo-Json -Depth 40|Set-Content $policyPath -Encoding UTF8
$genericPacket=[ordered]@{
  schema='compact_memory_knowledge_packet_v1'; source_kind='AgentLife'; source_id='validator_generic'; source_proof='tests/live_start/AIMO_GROWTH_TASK_SLUG_NORMALIZATION_HOTSWAP_V1_PROOF.json'; emitted_at=(Get-Date).ToString('o')
  influence=[ordered]@{ maturity_delta=0.1; memory_support_policy='ALLOW_BOUNDED_TASK_SELECTION_WHEN_TOPIC_OR_MEMORY_DELTA_MATCHES'; focus_boosts=@('active_growth_signal','aimo_sandbox_test_life') }
  quality_summary=[ordered]@{ atom_count=1; min_quality_score=0.62; min_novelty_score=0.1; classifier='VALIDATOR_GENERIC' }
  atoms=@([ordered]@{ id='generic-1'; topic='active_growth_signal'; level=1; quality_score=0.62; novelty_score=0.1; kind='validator'; summary='Generic signal for quality validator.' })
}
$genericPath=Join-Path $testRoot 'generic_packet.json'
$genericPacket|ConvertTo-Json -Depth 50|Set-Content $genericPath -Encoding UTF8
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $submit -PacketPath $genericPath -PolicyPath $policyPath *>&1|ForEach-Object{[string]$_})
$status=($out|Where-Object{$_ -match '^INTAKE_STATUS='}|Select-Object -Last 1)-replace '^INTAKE_STATUS=',''
Assert ($status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'GENERIC_PACKET_SUBMIT_NOT_PASS'
$signal=Get-Content $policyObj.active_growth_signal_path -Raw|ConvertFrom-Json
Assert (@($signal.topics) -notcontains 'active_growth_signal') 'GENERIC_SIGNAL_RAW_TOPIC_LEAKED'
Assert (@($signal.topics) -contains 'growth_signal_topic_is_too_generic_for_useful_task_selection') 'GENERIC_SIGNAL_SPECIFICITY_TOPIC_MISSING'
Assert ($signal.specific_gap -eq 'growth_signal_topic_is_too_generic_for_useful_task_selection') 'GENERIC_SIGNAL_SPECIFIC_GAP_BAD'
Assert ($signal.next_action_candidate -eq 'derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta') 'GENERIC_SIGNAL_NEXT_ACTION_BAD'
Assert ($signal.validator_hint -like '*specific_gap*') 'GENERIC_SIGNAL_VALIDATOR_HINT_BAD'
Assert (@($signal.proof_needed).Count -ge 3) 'GENERIC_SIGNAL_PROOF_NEEDED_BAD'
Assert ($signal.signal_quality -eq 'NEEDS_SPECIFICITY') 'GENERIC_SIGNAL_QUALITY_BAD'
Assert ($signal.actionable_contract.generated_task_name_as_topic_allowed -eq $false) 'GENERIC_SIGNAL_CONTRACT_BAD'
$schoolContext=[ordered]@{
  schema='compact_memory_knowledge_packet_v1'; source_kind='School'; source_id='validator_school_context'; created_at=(Get-Date).ToString('o')
  quality_summary=[ordered]@{ atom_count=12000; chunk_count=3; proof_status='PASS_TEST_FACTORY_STREAMING_READY_V1'; semantic_growth=$true }
  atoms=@([ordered]@{ id='school-summary:validator'; topic='school_topics_plan'; level=5; quality_score=1.0; novelty_score=0.7; proof_ref='tests/live_start/SCHOOL_ONLY_RESTART_AFTER_MEMORY_FIX_V1_PROOF.json'; behavior_use_hint='Use fresh school memory before next autonomous path selection; prefer tasks that exploit newly accepted concepts.' })
  influence=[ordered]@{ maturity_delta=0.0; memory_support_policy='USE_SCHOOL_MEMORY_WHEN_SELECTED_PATH_TOPIC_MATCHES'; focus_boosts=@('fresh_school_memory','recall_use_behavior_delta','avoid_idle_repeat') }
  refs=[ordered]@{ proof_path='tests/live_start/SCHOOL_ONLY_RESTART_AFTER_MEMORY_FIX_V1_PROOF.json'; active_memory_manifest='.runtime/active_compact_semantic_memory_v1/manifest.json'; memory_run_id='validator_memory_run'; memory_cells_sha256='abc123' }
}
$schoolPath=Join-Path $testRoot 'school_context_packet.json'
$schoolContext|ConvertTo-Json -Depth 50|Set-Content $schoolPath -Encoding UTF8
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $submit -PacketPath $schoolPath -PolicyPath $policyPath *>&1|ForEach-Object{[string]$_})
$status=($out|Where-Object{$_ -match '^INTAKE_STATUS='}|Select-Object -Last 1)-replace '^INTAKE_STATUS=',''
Assert ($status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'SCHOOL_CONTEXT_SUBMIT_NOT_PASS'
$agentLifeResidue=[ordered]@{
  schema='compact_memory_knowledge_packet_v1'; source_kind='AgentLife'; source_id='validator_agentlife_residue_after_school'; source_proof='tests/live_start/AIMO_CONCRETE_GROWTH_TOPIC_DERIVATION_LIVE_V1_PROOF.json'; emitted_at=(Get-Date).ToString('o')
  influence=[ordered]@{ maturity_delta=0.1; memory_support_policy='ALLOW_BOUNDED_TASK_SELECTION_WHEN_TOPIC_OR_MEMORY_DELTA_MATCHES'; focus_boosts=@('understand_own_policy_limits','aimo_sandbox_test_life') }
  quality_summary=[ordered]@{ atom_count=1; min_quality_score=0.62; min_novelty_score=0.10; classifier='AGENTLIFE_RUNTIME_SUMMARY_ATOM' }
  atoms=@([ordered]@{ id='agentlife-residue'; topic='understand_own_policy_limits'; level=1; quality_score=0.62; novelty_score=0.10; kind='agentlife_cycle_summary'; summary='More recent AgentLife residue should not override fresher School-memory priority when resolving meta derivation.' })
}
$residuePath=Join-Path $testRoot 'agentlife_residue_after_school.json'
$agentLifeResidue|ConvertTo-Json -Depth 50|Set-Content $residuePath -Encoding UTF8
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $submit -PacketPath $residuePath -PolicyPath $policyPath *>&1|ForEach-Object{[string]$_})
$status=($out|Where-Object{$_ -match '^INTAKE_STATUS='}|Select-Object -Last 1)-replace '^INTAKE_STATUS=',''
Assert ($status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'AGENTLIFE_RESIDUE_SUBMIT_NOT_PASS'
$derivedGeneric=[ordered]@{
  schema='compact_memory_knowledge_packet_v1'; source_kind='AgentLife'; source_id='validator_generic_after_school'; source_proof='tests/live_start/AIMO_AGENTLIFE_SPECIFIC_GROWTH_TOPIC_LIVE_V1_PROOF.json'; emitted_at=(Get-Date).ToString('o')
  influence=[ordered]@{ maturity_delta=0.1; memory_support_policy='ALLOW_BOUNDED_TASK_SELECTION_WHEN_TOPIC_OR_MEMORY_DELTA_MATCHES'; focus_boosts=@('derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta','aimo_sandbox_test_life'); next_action_candidate='derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta'; specific_gap='validated_memory_topic_requires_bounded_next_action:growth_signal_topic_is_too_generic_for_useful_task' }
  quality_summary=[ordered]@{ atom_count=1; min_quality_score=0.66; min_novelty_score=0.14; classifier='AGENTLIFE_ACTIONABLE_RUNTIME_SUMMARY_ATOM' }
  atoms=@([ordered]@{ id='agentlife-derive'; topic='derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta'; level=1; quality_score=0.66; novelty_score=0.14; kind='agentlife_actionable_cycle_summary'; summary='AIMO selected meta derivation action after generic signal.' })
}
$derivedPath=Join-Path $testRoot 'generic_after_school_packet.json'
$derivedGeneric|ConvertTo-Json -Depth 50|Set-Content $derivedPath -Encoding UTF8
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $submit -PacketPath $derivedPath -PolicyPath $policyPath *>&1|ForEach-Object{[string]$_})
$status=($out|Where-Object{$_ -match '^INTAKE_STATUS='}|Select-Object -Last 1)-replace '^INTAKE_STATUS=',''
Assert ($status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'DERIVED_GENERIC_SUBMIT_NOT_PASS'
$signal=Get-Content $policyObj.active_growth_signal_path -Raw|ConvertFrom-Json
Assert (@($signal.topics) -contains 'route_fresh_school_memory_to_next_growth_action') 'DERIVED_SIGNAL_TOPIC_BAD'
Assert ($signal.next_action_candidate -eq 'select_one_fresh_school_memory_delta_and_convert_to_bounded_builder_task') 'DERIVED_SIGNAL_NEXT_ACTION_BAD'
Assert ($signal.specific_gap -eq 'fresh_school_memory_exists_but_autonomous_selector_needs_one_concrete_builder_task') 'DERIVED_SIGNAL_SPECIFIC_GAP_BAD'
Assert ($signal.signal_quality -eq 'ACTIONABLE_DERIVED') 'DERIVED_SIGNAL_QUALITY_BAD'
Assert ($signal.derived_from_recent_packet.found -eq $true) 'DERIVED_SIGNAL_SOURCE_MISSING'
Assert ($signal.derived_from_recent_packet.source_kind -eq 'School') 'DERIVED_SIGNAL_SOURCE_KIND_BAD'
Assert (@($signal.proof_needed).Count -ge 4) 'DERIVED_SIGNAL_PROOF_NEEDED_BAD'
$actionPacket=[ordered]@{
  schema='compact_memory_knowledge_packet_v1'; source_kind='School'; source_id='validator_actionable'; source_proof='tests/live_start/AIMO_GROWTH_TASK_SLUG_NORMALIZATION_HOTSWAP_V1_PROOF.json'; emitted_at=(Get-Date).ToString('o')
  influence=[ordered]@{ maturity_delta=0.5; memory_support_policy='ALLOW_BOUNDED_TASK_SELECTION_WHEN_TOPIC_OR_MEMORY_DELTA_MATCHES'; focus_boosts=@('selector','payload_shape'); specific_gap='selector_validator_missing_live_payload_shape'; next_action_candidate='add_ordered_payload_negative_case_to_selector_validator'; proof_needed=@('selector validator PASS','ordered payload regression proof'); validator_hint='validate ordered dictionary and PSCustomObject selector inputs' }
  quality_summary=[ordered]@{ atom_count=1; min_quality_score=0.82; min_novelty_score=0.2; classifier='VALIDATOR_ACTIONABLE' }
  atoms=@([ordered]@{ id='action-1'; topic='selector_validator_missing_live_payload_shape'; level=2; quality_score=0.82; novelty_score=0.2; kind='validator'; summary='Actionable selector validator gap.' })
}
$actionPath=Join-Path $testRoot 'action_packet.json'
$actionPacket|ConvertTo-Json -Depth 50|Set-Content $actionPath -Encoding UTF8
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $submit -PacketPath $actionPath -PolicyPath $policyPath *>&1|ForEach-Object{[string]$_})
$status=($out|Where-Object{$_ -match '^INTAKE_STATUS='}|Select-Object -Last 1)-replace '^INTAKE_STATUS=',''
Assert ($status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'ACTION_PACKET_SUBMIT_NOT_PASS'
$signal=Get-Content $policyObj.active_growth_signal_path -Raw|ConvertFrom-Json
Assert (@($signal.topics) -contains 'selector_validator_missing_live_payload_shape') 'ACTION_SIGNAL_TOPIC_BAD'
Assert ($signal.specific_gap -eq 'selector_validator_missing_live_payload_shape') 'ACTION_SIGNAL_SPECIFIC_GAP_BAD'
Assert ($signal.next_action_candidate -eq 'add_ordered_payload_negative_case_to_selector_validator') 'ACTION_SIGNAL_NEXT_ACTION_BAD'
Assert (@($signal.proof_needed).Count -eq 2) 'ACTION_SIGNAL_PROOF_NEEDED_BAD'
Assert ($signal.signal_quality -eq 'ACTIONABLE') 'ACTION_SIGNAL_QUALITY_BAD'
Assert (@($signal.focus_boosts) -contains 'add_ordered_payload_negative_case_to_selector_validator') 'ACTION_SIGNAL_FOCUS_BOOST_NEXT_ACTION_MISSING'
$aimoText=Get-Content operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1 -Raw
Assert ($aimoText -match 'next_action_candidate') 'AIMO_SELECTOR_NEXT_ACTION_WIRING_MISSING'
$proof=[ordered]@{
  schema='growth_signal_quality_validation_v1'
  status='PASS_GROWTH_SIGNAL_QUALITY_V1'
  tests=@([ordered]@{name='generic_topic_becomes_specificity_gap_contract';status='PASS'},[ordered]@{name='generic_topic_derives_from_recent_school_packet';status='PASS'},[ordered]@{name='actionable_packet_preserves_specific_contract';status='PASS'},[ordered]@{name='aimo_selector_next_action_static_check';status='PASS'})
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/compact_memory_intake/GROWTH_SIGNAL_QUALITY_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent)|Out-Null
$proof|ConvertTo-Json -Depth 50|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_GROWTH_SIGNAL_QUALITY_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'

