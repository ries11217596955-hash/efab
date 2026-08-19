param()
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repo
$targets=@('operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1','operations/autonomous_inner_motor/start_agent_life_v1.ps1','operations/reasoning/build_agent_mind_logic_frame_v1.ps1','validators/validate_agent_life_multitick_productive_v1.ps1')
$errors=New-Object 'System.Collections.Generic.List[string]'
function Err([string]$m){[void]$errors.Add($m)}
$beforeTracked=@(git status --porcelain --untracked-files=no)
try {
 foreach($f in $targets){$tok=$null;$pe=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f),[ref]$tok,[ref]$pe)|Out-Null;if($pe.Count){Err ('parse:'+ $f+':'+(($pe|ForEach-Object Message)-join'|'))}}
 $runner=Get-Content 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Raw;$life=Get-Content 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Raw;$mind=Get-Content 'operations/reasoning/build_agent_mind_logic_frame_v1.ps1' -Raw
 foreach($needle in @("[ValidateSet('Full','LifeLight')][string]`$LifeProfile='Full'","body_inspection_invoked=`$false","full_audit_deferred=`$true","'-ReasoningProfile','LifeCycle'","memory_is_command=`$false","memory_can_force_next_step=`$false")){if(-not$runner.Contains($needle)){Err ('runner_contract_missing:'+ $needle)}}
 if(-not$life.Contains("'-MemoryIngestionMode','Auto'")){Err 'life_not_auto_memory'};if($life -notmatch 'TickBudgetSeconds=35'){Err 'tick_budget_default_missing'}
 if($life -match '\$latest\s*=.*Get-ChildItem.*Sort-Object LastWriteTime.*Select-Object -First 1'){Err 'stale_latest_inheritance_pattern_present'}
 foreach($needle in @('BOUND_CURRENT_TICK_RUN_DIR','SANITATION_REFUSED_NOT_CURRENT_LIFE_OWNED','continuity_files_per_run_max=6','owned_continuity_dirs_max=$maxOwnedContinuityDirs')){if(-not$life.Contains($needle)){Err ('life_contract_missing:'+ $needle)}}
 foreach($needle in @("[ValidateSet('Full','LifeCycle')][string]`$ReasoningProfile='Full'","System.Collections.Generic.List[object]","`$known.ToArray()","DEFERRED_LIFE_CYCLE_PROFILE","memory_is_command=`$false")){if(-not$mind.Contains($needle)){Err ('mind_contract_missing:'+ $needle)}}
 if(-not$runner.Contains('New-LifeCycleLearningAtom') -or -not$runner.Contains('LIFE_LIGHT_WAITING_FOR_MIND_LOGIC') -or -not$runner.Contains('PASS_LIFE_LIGHT_EPISTEMIC_DELTA_QUEUED_PENDING_GATE')){Err 'life_light_actual_reasoning_delta_contract_missing'}
if(-not$runner.Contains('PASS_LIFE_LIGHT_SHORT_TERM_STATE') -or -not$runner.Contains("buildTaskBoundedExecutor=[ordered]@{status='DEFERRED_LIFE_CYCLE_PROFILE'") -or -not$runner.Contains('$proofPackRequiredFiles=if($LifeProfile -eq ''LifeLight'')')){Err 'life_light_fast_finish_contract_missing'}
if(-not$runner.Contains("'-MemoryContextPath',`$lifeWorkingMemoryPath") -or -not$runner.Contains('active_memory_sample_refreshed_at') -or -not$runner.Contains('previous_cycle_delta')){Err 'life_working_memory_local_recall_wiring_missing'}
if(-not$mind.Contains("[string]`$MemoryContextPath=''") -or -not$mind.Contains('PASS_LIFE_CYCLE_LOCAL_MEMORY_CONTEXT_V1') -or -not$mind.Contains("memory_recall_mode=if(`$useLocalLifeMemory){'life_working_memory_local'}")){Err 'mind_local_memory_context_contract_missing'}
if(-not$runner.Contains("kind='epistemic_state_delta'") -or -not$runner.Contains('selected_next_logical_step_is_claim=$false') -or -not$runner.Contains('provisional_knowledge=$knowledge') -or -not$runner.Contains('long_term_admitted=$false')){Err 'epistemic_delta_producer_contract_missing'}
if(-not$runner.Contains('function Get-LifeEpistemicStateSignature') -or -not$runner.Contains('if(-not [string]::IsNullOrWhiteSpace($previousSignature) -and $previousSignature -eq $epistemicSignature){ return $null }') -or -not$runner.Contains("if(`$itemSource -eq 'life_working_memory_provisional'){ continue }")){Err 'material_epistemic_delta_anti_recursion_contract_missing'}
if(-not$runner.Contains('PROVISIONAL_EPISTEMIC_DELTA_PRODUCED') -or -not$runner.Contains('THOUGHT_COMPLETED_WITH_NO_MEANINGFUL_EPISTEMIC_DELTA_PREVIOUS_KNOWLEDGE_PRESERVED') -or -not$runner.Contains("New-LifePreviousCycleDelta `$mindLogic.frame `$selectedActionId `$deepThinking (Get-ObjectField `$lifeWorkingMemory.compact_context 'previous_cycle_delta')")){Err 'provisional_knowledge_carry_forward_contract_missing'}
if(-not$runner.Contains('function Set-ObjectField') -or -not$runner.Contains("Set-ObjectField `$lifeWorkingMemory.compact_context 'previous_cycle_delta' `$cycleDelta")){Err 'first_cycle_delta_dictionary_serialization_guard_missing'}
if(-not$mind.Contains("source='life_working_memory_provisional'") -or -not$mind.Contains("if(`$hits -gt 0){") -or $mind.Contains("`$c.source -eq 'life_working_memory'")){Err 'provisional_relevance_not_temporal_contract_missing'}
if(-not$runner.Contains('New-AgentLifePendingMemoryPacket') -or -not$runner.Contains('PASS_LIFE_LIGHT_EPISTEMIC_DELTA_QUEUED_PENDING_GATE') -or -not$runner.Contains('memory_admission_pending=')){Err 'pending_memory_gate_runner_contract_missing'}
$mergeText=Get-Content 'operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1' -Raw
$maintText=Get-Content 'operations/compact_memory_intake/run_compact_memory_queue_maintenance_v1.ps1' -Raw
if(-not$maintText.Contains("[string]`$MemoryRoot = '.runtime/active_compact_semantic_memory_v1'") -or -not$maintText.Contains("'-MemoryRoot',[string]`$MemoryRoot")){Err 'maintenance_memory_root_testability_missing'}
if(-not$maintText.Contains('REMOVED_OWNED_STALE_MERGE_LOCK') -or -not$maintText.Contains('REMOVED_OWNED_TIMEOUT_DIR:') -or -not$maintText.Contains('stale_lock_present_after')){Err 'maintenance_timeout_hygiene_guard_missing'}
if(-not$mergeText.Contains('DEFERRED_PENDING_MEMORY_ATOM_GATE') -or -not$mergeText.Contains('FULL_MEMORY_ATOM_GATE_REQUIRED_BEFORE_MERGE')){Err 'pending_memory_gate_merge_guard_missing'}
if(-not$maintText.Contains('Invoke-AgentLifePendingAcceptance') -or -not$maintText.Contains('REJECT_AND_DELETE_MEMORY_ATOM_GATE') -or -not$maintText.Contains('PASS_AGENTLIFE_REJECT_FEEDBACK_V1')){Err 'pending_memory_gate_maintenance_accept_reject_flow_missing'}
if(-not$runner.Contains('producer_feedback_context_path=$FeedbackContextPath') -or -not$runner.Contains('active_memory_mutated=[bool]($deepThinking.absorption -and $deepThinking.absorption.memory_changed)')){Err 'pending_memory_feedback_or_mutation_truth_missing'}
$known=New-Object 'System.Collections.Generic.List[object]';[void]$known.Add([ordered]@{claim='topic';evidence='input'});[void]$known.Add([ordered]@{claim='memory';evidence='memory'});if($known.Count-ne2 -or @($known.ToArray()).Count-ne2){Err 'known_collection_type_stability_failed'}
$relScratch=Join-Path '.runtime/self_development' ('provisional_relevance_validator_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $relScratch|Out-Null
try{
  $ctxPath=Join-Path $relScratch 'context.json';$relatedPath=Join-Path $relScratch 'related.json';$unrelatedPath=Join-Path $relScratch 'unrelated.json'
  $ctx=[ordered]@{status='PASS_LIFE_WORKING_MEMORY_V1';compact_context=[ordered]@{active_memory_sample=[ordered]@{cell_sample=@();index_key_sample=@()};previous_cycle_delta=[ordered]@{selected_step='metadata_only_step';provisional=$true;long_term_admitted=$false;memory_is_command=$false;useful_outcome='PROVISIONAL_EPISTEMIC_DELTA_PRODUCED';provisional_knowledge=[ordered]@{concept_key='engine.combustion_rotation';kind='epistemic_state_delta';label='Combustion drives piston rotation';summary='Combustion pressure drives piston motion that becomes crankshaft rotation.';definition='Expanding combustion gases push the piston and the connecting rod converts that motion into crankshaft rotation.';provisional=$true;long_term_admitted=$false;memory_is_command=$false}}}}
  $ctx|ConvertTo-Json -Depth 30|Set-Content $ctxPath -Encoding UTF8
  & powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/reasoning/build_agent_mind_logic_frame_v1.ps1' -Problem 'How does combustion piston motion become crankshaft rotation in an engine?' -ReasoningProfile LifeCycle -MemoryContextPath $ctxPath -OutputPath $relatedPath *> $null
  if($LASTEXITCODE-ne0 -or -not(Test-Path $relatedPath)){Err 'provisional_related_frame_failed'}else{$rf=Get-Content $relatedPath -Raw|ConvertFrom-Json;if(@($rf.memory_recall_filter.accepted_matches|?{$_.source -eq 'life_working_memory_provisional'}).Count-lt1){Err 'provisional_related_not_recalled'};if(@($rf.known|?{$_.confidence -eq 'PROVISIONAL_RELEVANT_MEMORY_EVIDENCE_CANDIDATE'}).Count-lt1){Err 'provisional_related_not_used'}}
  & powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/reasoning/build_agent_mind_logic_frame_v1.ps1' -Problem 'How should a list of names be sorted alphabetically?' -ReasoningProfile LifeCycle -MemoryContextPath $ctxPath -OutputPath $unrelatedPath *> $null
  if($LASTEXITCODE-ne0 -or -not(Test-Path $unrelatedPath)){Err 'provisional_unrelated_frame_failed'}else{$uf=Get-Content $unrelatedPath -Raw|ConvertFrom-Json;if(@($uf.memory_recall_filter.accepted_matches|?{$_.source -eq 'life_working_memory_provisional'}).Count-ne0){Err 'provisional_unrelated_false_positive'}}
}finally{if(Test-Path $relScratch){Remove-Item $relScratch -Recurse -Force -ErrorAction SilentlyContinue}}
if(Test-Path $relScratch){Err 'provisional_relevance_scratch_leftover'}
$deltaScratch=Join-Path '.runtime/self_development' ('material_epistemic_delta_validator_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $deltaScratch|Out-Null
try{
  $sharedContext=Join-Path $deltaScratch 'shared_life_context.json';$cycle1Root=Join-Path $deltaScratch 'cycle1';$cycle2Root=Join-Path $deltaScratch 'cycle2';$cycle3Root=Join-Path $deltaScratch 'cycle3'
  $question='Identify one high-value knowledge gap not already resolved by current memory, then determine the smallest trustworthy evidence needed to learn it.'
  & powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Mode SandboxExploration -Question $question -SeedSource OwnerHint -EnableDeepThinking -LifeProfile LifeLight -OutputRoot $cycle1Root -WakeContextPath $sharedContext *> $null
  if($LASTEXITCODE-ne0){Err 'material_delta_cycle1_failed'}else{
    $p1f=Get-ChildItem $cycle1Root -Recurse -File -Filter 'SANDBOX_EXPLORATION_PROOF.json'|Sort-Object LastWriteTime -Descending|Select-Object -First 1
    if(-not$p1f){Err 'material_delta_cycle1_proof_missing'}else{$p1=Get-Content $p1f.FullName -Raw|ConvertFrom-Json;if($null-eq$p1.deep_thinking.learning_atom -or $p1.deep_thinking.learning_atom.kind-ne'epistemic_state_delta'){Err 'material_delta_cycle1_atom_missing'}}
  }
  $bytes1=if(Test-Path $sharedContext){(Get-Item $sharedContext).Length}else{0}
  & powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Mode SandboxExploration -Question $question -SeedSource OwnerHint -EnableDeepThinking -LifeProfile LifeLight -OutputRoot $cycle2Root -WakeContextPath $sharedContext *> $null
  if($LASTEXITCODE-ne0){Err 'material_delta_cycle2_failed'}else{
    $p2f=Get-ChildItem $cycle2Root -Recurse -File -Filter 'SANDBOX_EXPLORATION_PROOF.json'|Sort-Object LastWriteTime -Descending|Select-Object -First 1
    if(-not$p2f){Err 'material_delta_cycle2_proof_missing'}else{$p2=Get-Content $p2f.FullName -Raw|ConvertFrom-Json;if($null-ne$p2.deep_thinking.learning_atom){Err 'duplicate_epistemic_state_not_suppressed'};if($p2.deep_thinking.status-ne'PASS_LIFE_LIGHT_THOUGHT_NO_MEANINGFUL_EPISTEMIC_DELTA'){Err 'duplicate_epistemic_state_wrong_status'}}
  }
  $bytes2=if(Test-Path $sharedContext){(Get-Item $sharedContext).Length}else{0}
  $ctx2=if(Test-Path $sharedContext){Get-Content $sharedContext -Raw|ConvertFrom-Json}else{$null}
  $d2=if($ctx2){$ctx2.compact_context.previous_cycle_delta}else{$null}
  if($null-eq$d2 -or -not[bool]$d2.provisional -or $null-eq$d2.provisional_knowledge -or [string]::IsNullOrWhiteSpace([string]$d2.provisional_knowledge.epistemic_state.signature)){Err 'provisional_knowledge_not_preserved_after_no_delta_cycle'}
  & powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Mode SandboxExploration -Question $question -SeedSource OwnerHint -EnableDeepThinking -LifeProfile LifeLight -OutputRoot $cycle3Root -WakeContextPath $sharedContext *> $null
  if($LASTEXITCODE-ne0){Err 'material_delta_cycle3_failed'}else{
    $p3f=Get-ChildItem $cycle3Root -Recurse -File -Filter 'SANDBOX_EXPLORATION_PROOF.json'|Sort-Object LastWriteTime -Descending|Select-Object -First 1
    if(-not$p3f){Err 'material_delta_cycle3_proof_missing'}else{$p3=Get-Content $p3f.FullName -Raw|ConvertFrom-Json;if($null-ne$p3.deep_thinking.learning_atom){Err 'duplicate_epistemic_state_reappeared_after_empty_cycle'};if($p3.deep_thinking.status-ne'PASS_LIFE_LIGHT_THOUGHT_NO_MEANINGFUL_EPISTEMIC_DELTA'){Err 'cycle3_duplicate_epistemic_state_wrong_status'}}
  }
  $bytes3=if(Test-Path $sharedContext){(Get-Item $sharedContext).Length}else{0}
  if($bytes1-le0 -or $bytes2-gt($bytes1*2) -or $bytes3-gt($bytes1*2)){Err 'provisional_context_recursive_growth_guard_failed'}
}finally{if(Test-Path $deltaScratch){Remove-Item $deltaScratch -Recurse -Force -ErrorAction SilentlyContinue}}
if(Test-Path $deltaScratch){Err 'material_epistemic_delta_scratch_leftover'}
 $tok=$null;$pe=$null;$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'operations/autonomous_inner_motor/start_agent_life_v1.ps1'),[ref]$tok,[ref]$pe);$fn=@($ast.FindAll({param($n)$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-AgentLifeOwnedRunSanitation'},$true))|Select-Object -First 1
 if(-not$fn){Err 'sanitation_function_ast_missing'} else { . ([scriptblock]::Create($fn.Extent.Text));$scratch=Join-Path '.runtime/self_development' ('agent_life_sanitation_validator_'+[guid]::NewGuid().ToString('N'));$aimo=Join-Path $scratch 'autonomous_inner_motor';$owned=Join-Path $aimo 'aimo_owned';$foreign=Join-Path $aimo 'aimo_foreign';New-Item -ItemType Directory -Force -Path $owned,$foreign|Out-Null;try{1..12|%{Set-Content -LiteralPath (Join-Path $owned ("file$_.json")) -Value '{}' -Encoding UTF8};foreach($n in @('memory_to_next_path_reuse_gate.json','short_term_mind_state.json','short_term_state_to_next_task_router.json','refocus_seed_diversification.json','refocus_to_new_thought_seed.json','action_decision_packet.json')){Set-Content -LiteralPath (Join-Path $owned $n) -Value '{}' -Encoding UTF8};$r=Invoke-AgentLifeOwnedRunSanitation -RunDir $owned -AimoRoot $aimo -OwnedRunDirs @($owned);if($r.status-ne'COMPACTED_SELF_OWNED_RUN_TO_CONTINUITY' -or (Get-ChildItem $owned -File).Count-gt6){Err 'owned_sanitation_compaction_failed'};$refused=$false;try{Invoke-AgentLifeOwnedRunSanitation -RunDir $foreign -AimoRoot $aimo -OwnedRunDirs @($owned)|Out-Null}catch{$refused=($_.Exception.Message -like 'SANITATION_REFUSED_NOT_CURRENT_LIFE_OWNED*')};if(-not$refused){Err 'foreign_sanitation_not_refused'}}finally{if(Test-Path $scratch){Remove-Item $scratch -Recurse -Force -ErrorAction SilentlyContinue}};if(Test-Path $scratch){Err 'validator_scratch_leftover'} }
 $afterTracked=@(git status --porcelain --untracked-files=no);if(($beforeTracked-join"`n")-ne($afterTracked-join"`n")){Err 'validator_mutated_tracked_repo_state'}
} finally {Pop-Location}
if($errors.Count){Write-Output ('FAIL_AGENT_LIFE_MULTITICK_PRODUCTIVE_V1|'+($errors-join';'));exit 1}
Write-Output 'PASS_AGENT_LIFE_MULTITICK_PRODUCTIVE_V1|STRUCTURE=PASS|MEMORY_NOT_COMMAND=PASS|TYPE_STABILITY=PASS|OWNED_SANITATION=PASS|FOREIGN_REFUSAL=PASS|SCRATCH_CLEAN=PASS|LIVE_MULTITICK=NOT_PROVEN_BY_THIS_VALIDATOR'
