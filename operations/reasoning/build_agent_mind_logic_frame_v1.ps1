param(
  [string]$Problem='Owner correction: build agent mind and logic, not safety passports. What can the agent do if it does not know anything?',
  [string[]]$ContextRefs=@(),
  [int]$MemoryTop=5,
  [switch]$DisableMemoryRecall,
  [string]$OutputPath='.runtime/agent_mind_logic_kernel_v1/logic_frame.json',
  [ValidateSet('LabOnly')][string]$Mode='LabOnly'
)
$ErrorActionPreference='Stop'
function WJson($o,$p){ New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null; $o|ConvertTo-Json -Depth 80|Set-Content -Path $p -Encoding UTF8 }
function FileProof([string]$p){ if(Test-Path $p){ $i=Get-Item $p; return [ordered]@{path=$p; exists=$true; bytes=$i.Length; sha256=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower()} }; return [ordered]@{path=$p; exists=$false} }
function Has([string]$s,[string]$pattern){ return ($s -match $pattern) }
$kernelPath='operations/reasoning/agent_mind_logic_kernel_v1.json'
if(-not(Test-Path $kernelPath)){ throw 'MIND_LOGIC_KERNEL_MISSING' }
$problemText=[string]$Problem
$lower=$problemText.ToLowerInvariant()
$evidence=@()
$defaultRefs=@(
  'tests/self_development/AUTONOMOUS_INNER_MOTOR_ACTION_DECISION_WIRING_V1_PROOF.json',
  'tests/self_development/AGENT_ACTION_DECISION_CONTRACT_V1_PROOF.json',
  'tests/self_development/AGENT_EXECUTION_AUTHORITY_PASSPORT_V1_PROOF.json',
  'tests/self_development/SCHOOL_LIVE1000_DYNAMIC_PREFLIGHT_LIVE_V1_PROOF.json',
  'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1',
  'operations/reasoning/validate_reasoning_episode_v1.ps1'
)
foreach($r in @($defaultRefs + $ContextRefs)){ $evidence += (FileProof $r) }
$memoryRecall=[ordered]@{
  status='NOT_RUN'
  query=$Problem
  top=$MemoryTop
  stdout=@()
  exit_code=$null
  matches=@()
  used_in_known=$false
}
$memoryQueryScript='operations/school/memory/query_compact_semantic_memory_v1.ps1'
if(-not $DisableMemoryRecall -and (Test-Path $memoryQueryScript)){
  $recallOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $memoryQueryScript -Query $Problem -Top $MemoryTop *>&1 | ForEach-Object { [string]$_ })
  $memoryRecall.stdout=@($recallOut)
  $memoryRecall.exit_code=$LASTEXITCODE
  $statusLine=($recallOut | Where-Object { $_ -match '^MEMORY_RECALL_STATUS=' } | Select-Object -Last 1)
  if($statusLine){ $memoryRecall.status=($statusLine -replace '^MEMORY_RECALL_STATUS=','') }
  foreach($line in @($recallOut | Where-Object { $_ -match '^MATCH\|' })){
    # Format: MATCH|n|score=...|label=...|hits=...|obs=...|summary=...
    $parts=$line -split '\|'
    $m=[ordered]@{raw=$line; rank=$parts[1]; score=$null; label=$null; hits=$null; observation_count=$null; summary=$null}
    foreach($part in $parts[2..($parts.Count-1)]){
      if($part -like 'score=*'){ $m.score=($part -replace '^score=','') }
      elseif($part -like 'label=*'){ $m.label=($part -replace '^label=','') }
      elseif($part -like 'hits=*'){ $m.hits=($part -replace '^hits=','') }
      elseif($part -like 'obs=*'){ $m.observation_count=($part -replace '^obs=','') }
      elseif($part -like 'summary=*'){ $m.summary=($part -replace '^summary=','') }
    }
    $memoryRecall.matches += [pscustomobject]$m
  }
} elseif($DisableMemoryRecall){
  $memoryRecall.status='DISABLED_BY_CALLER'
} else {
  $memoryRecall.status='MEMORY_QUERY_SCRIPT_MISSING'
}

$memoryRecallFilter=[ordered]@{
  status='NOT_RUN'
  result_path=$null
  accepted_count=0
  accepted_matches=@()
  rejected_count=0
  used_in_known=$false
}
$memoryFilterScript='operations/reasoning/filter_memory_recall_relevance_v1.ps1'
$memoryFilterPath=Join-Path (Split-Path $OutputPath -Parent) 'memory_recall_filter.json'
if(-not $DisableMemoryRecall -and (Test-Path $memoryFilterScript)){
  $filterOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $memoryFilterScript -Query $Problem -Top $MemoryTop -AcceptTop 3 -OutputPath $memoryFilterPath *>&1 | ForEach-Object { [string]$_ })
  $memoryRecallFilter.stdout=@($filterOut)
  $memoryRecallFilter.exit_code=$LASTEXITCODE
  $memoryRecallFilter.result_path=$memoryFilterPath
  if((Test-Path $memoryFilterPath) -and $LASTEXITCODE -eq 0){
    $filterResult=Get-Content $memoryFilterPath -Raw | ConvertFrom-Json
    $memoryRecallFilter.status=$filterResult.status
    $memoryRecallFilter.accepted_count=[int]$filterResult.accepted_count
    $memoryRecallFilter.accepted_matches=@($filterResult.accepted_matches)
    $memoryRecallFilter.rejected_count=@($filterResult.rejected_matches).Count
  } elseif(Test-Path $memoryFilterPath){
    $filterResult=Get-Content $memoryFilterPath -Raw | ConvertFrom-Json
    $memoryRecallFilter.status='FILTER_NONZERO_WITH_RESULT'
    $memoryRecallFilter.accepted_count=[int]$filterResult.accepted_count
    $memoryRecallFilter.accepted_matches=@($filterResult.accepted_matches)
    $memoryRecallFilter.rejected_count=@($filterResult.rejected_matches).Count
  } else {
    $memoryRecallFilter.status='FILTER_FAILED_NO_RESULT'
  }
} elseif($DisableMemoryRecall){
  $memoryRecallFilter.status='DISABLED_BY_CALLER'
} else {
  $memoryRecallFilter.status='FILTER_SCRIPT_MISSING'
}

$signals=New-Object System.Collections.Generic.List[string]
if(Has $lower 'logic|mind|think|thinking|reasoning|agent mind|agent logic'){ $signals.Add('OWNER_WANTS_MIND_LOGIC') | Out-Null }
if(Has $lower 'safety|passport|authority|permission|gate|execution authority'){ $signals.Add('SAFETY_BRANCH_PRESENT') | Out-Null }
if(Has $lower 'doesn.?t know|does not know|knows nothing|no evidence|no knowledge|no_evidence|no_knowledge|nothing'){ $signals.Add('KNOWLEDGE_GAP_CHALLENGE') | Out-Null }
if(Has $lower 'wrong|not that|correction|stop|instead|not safety|not passports'){ $signals.Add('OWNER_CORRECTION') | Out-Null }
if(Has $lower 'can do|capability|can the agent|able to do|what can'){ $signals.Add('CAPABILITY_QUESTION') | Out-Null }
$classification=if($signals -contains 'OWNER_CORRECTION'){'CONTEXT_MISMATCH_CORRECTION'}elseif($signals -contains 'KNOWLEDGE_GAP_CHALLENGE'){'KNOWLEDGE_GAP_REASONING_TASK'}else{'GENERAL_LOGIC_TASK'}
$known=@(
  [ordered]@{claim='AIMO can produce thinking traces and next_action_candidate in sandbox.'; evidence='AUTONOMOUS_INNER_MOTOR_ACTION_DECISION_WIRING_V1_PROOF'; confidence='PROVEN_LAB'},
  [ordered]@{claim='Memory learning mechanism exists through governed queue/merge, but that is not general knowledge competence.'; evidence='AIMO memory learning mechanism proofs'; confidence='PROVEN_LIVE_FOR_MECHANISM_ONLY'},
  [ordered]@{claim='Recent work over-focused on authority layers relative to current Owner intent.'; evidence='Owner correction in current problem text'; confidence='OWNER_REPORTED_AND_CONTEXT_SUPPORTED'}
)
if($memoryRecallFilter.status -eq 'PASS_MEMORY_RECALL_RELEVANCE_FILTER_V1' -and @($memoryRecallFilter.accepted_matches).Count -gt 0){
  $memoryRecall.used_in_known=$true
  $memoryRecallFilter.used_in_known=$true
  $topLabels=(@($memoryRecallFilter.accepted_matches) | Select-Object -First 3 | ForEach-Object { $_.label }) -join '; '
  $known += [ordered]@{claim=('Filtered active memory recalls accepted as relevant evidence: ' + $topLabels); evidence='filter_memory_recall_relevance_v1'; confidence='FILTERED_MEMORY_RECALL_SUPPORTED'}
} elseif($memoryRecall.status -eq 'PASS_COMPACT_MEMORY_RECALL_V1' -and @($memoryRecall.matches).Count -gt 0){
  $memoryRecall.used_in_known=$true
  $topLabels=(@($memoryRecall.matches) | Select-Object -First 3 | ForEach-Object { $_.label }) -join '; '
  $known += [ordered]@{claim=('Unfiltered active memory returned recalls: ' + $topLabels); evidence='query_compact_semantic_memory_v1'; confidence='RAW_MEMORY_RECALL_SUPPORTED_FILTER_UNAVAILABLE'}
}
$unknown=@(
  [ordered]@{unknown='Can the agent autonomously choose the best reasoning operation for a novel task?'; impact='HIGH'; reduction='validate mind logic frame on correction and no-evidence cases'},
  [ordered]@{unknown='Does the agent know enough domain facts for a task?'; impact='HIGH'; reduction='query active memory/source ladder before claim'},
  [ordered]@{unknown='Can AIMO use this logic frame every cycle instead of static text answers?'; impact='HIGH'; reduction='wire kernel into AIMO after lab proof'}
)
$assumptions=@(
  [ordered]@{assumption='Building smarter logic now has higher priority than expanding execution authority.'; risk='LOW'; basis='Owner explicit correction'},
  [ordered]@{assumption='Lab proof is acceptable for cognitive operation before live wiring.'; risk='LOW'; basis='current self-build discipline'}
)
$contradictions=New-Object System.Collections.Generic.List[object]
if(($signals -contains 'OWNER_WANTS_MIND_LOGIC') -and ($signals -contains 'SAFETY_BRANCH_PRESENT')){
  $contradictions.Add([ordered]@{id='BRANCH_MISMATCH'; statement='Work drifted toward safety/passports while Owner asked for agent mind/logic.'; severity='HIGH'; repair='cut safety branch; build cognitive kernel that handles knowledge gaps and contradiction.'}) | Out-Null
}
if($signals -contains 'KNOWLEDGE_GAP_CHALLENGE'){
  $contradictions.Add([ordered]@{id='KNOWLEDGE_VS_ACTION'; statement='Execution capacity is meaningless if the agent cannot know what is true or what is unknown.'; severity='HIGH'; repair='make no-evidence/no-claim and source-ladder selection first-class logic.'}) | Out-Null
}
$contradictionResolution=[ordered]@{
  status='NOT_RUN'
  result_path=$null
  resolver_stdout=@()
  exit_code=$null
  result=$null
}
$contradictionResolver='operations/reasoning/resolve_mind_logic_contradiction_v1.ps1'
$contradictionResolutionPath=Join-Path (Split-Path $OutputPath -Parent) 'contradiction_resolution.json'
if(Test-Path $contradictionResolver){
  $resolverOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $contradictionResolver -Problem $Problem -OutputPath $contradictionResolutionPath *>&1 | ForEach-Object { [string]$_ })
  $contradictionResolution.resolver_stdout=@($resolverOut)
  $contradictionResolution.exit_code=$LASTEXITCODE
  $contradictionResolution.result_path=$contradictionResolutionPath
  if((Test-Path $contradictionResolutionPath) -and $LASTEXITCODE -eq 0){
    $contradictionResolution.result=Get-Content $contradictionResolutionPath -Raw | ConvertFrom-Json
    $contradictionResolution.status=$contradictionResolution.result.status
  } elseif(Test-Path $contradictionResolutionPath){
    $contradictionResolution.result=Get-Content $contradictionResolutionPath -Raw | ConvertFrom-Json
    $contradictionResolution.status='RESOLVER_NONZERO_WITH_RESULT'
  } else {
    $contradictionResolution.status='RESOLVER_FAILED_NO_RESULT'
  }
} else {
  $contradictionResolution.status='RESOLVER_SCRIPT_MISSING'
}

$hypotheses=@(
  [ordered]@{id='H1'; text='The next useful mind organ is a logic frame builder, not another authority layer.'; evidence_refs=@('Owner correction','existing AIMO thinking proof'); confidence='HIGH'; test='frame must name mismatch and select knowledge/logic next step.'},
  [ordered]@{id='H2'; text='The agent becomes smarter by adding a repeatable cognitive cycle, not by adding more static documents.'; evidence_refs=@('kernel cognitive_cycle','validator checks operator order'); confidence='HIGH'; test='validator rejects missing contradiction/unknown/source ladder.'},
  [ordered]@{id='H3'; text='If the agent lacks knowledge, it should choose memory/source acquisition rather than action.'; evidence_refs=@('knowledge gap challenge'); confidence='HIGH'; test='no-evidence task selects ASK_OR_RECALL_SOURCE step.'}
)
$sourceLadder=@(
  [ordered]@{rank=1; source='current input / Owner correction'; use='highest priority intent and mismatch signal'},
  [ordered]@{rank=2; source='fresh repo proof'; use='what agent can actually do now'},
  [ordered]@{rank=3; source='active compact memory recall'; use='prior lessons and reusable rules; used_in_this_frame=' + [string]$memoryRecallFilter.used_in_known},
  [ordered]@{rank=4; source='external/source material'; use='only for facts absent from memory/repo or current unstable facts'}
)
$nextStep=if($classification -eq 'CONTEXT_MISMATCH_CORRECTION'){
  [ordered]@{step_id='BUILD_MIND_LOGIC_KERNEL'; type='cognitive_self_build'; reason='highest contradiction is branch mismatch; building logic frame directly improves agent mind.'; reduces_unknown='Can the agent detect mismatch and choose logic over safety?'; not_action='does not grant execution authority'}
}elseif($classification -eq 'KNOWLEDGE_GAP_REASONING_TASK'){
  [ordered]@{step_id='ASK_OR_RECALL_SOURCE_BEFORE_ACTION'; type='knowledge_acquisition'; reason='agent cannot act intelligently without distinguishing known/unknown.'; reduces_unknown='Does the agent know enough?'; not_action='no execution'}
}else{
  [ordered]@{step_id='RUN_LOGIC_FRAME_AND_VALIDATE'; type='reasoning_validation'; reason='prove cognitive cycle on lab task.'; reduces_unknown='can produce structured reasoning frame'; not_action='no execution'}
}
$frame=[ordered]@{
  schema='agent_mind_logic_frame_v1'
  status='PASS_AGENT_MIND_LOGIC_FRAME_V1'
  created_at=(Get-Date).ToString('o')
  mode=$Mode
  problem=$Problem
  classification=$classification
  signals=@($signals.ToArray())
  memory_recall=$memoryRecall
  memory_recall_filter=$memoryRecallFilter
  evidence_refs=@($evidence)
  restored_context=[ordered]@{current_branch='Owner corrected direction from safety/passports to mind/logic'; nearest_project_context='AIMO has thinking proof and action-candidate proof, but needs stable cognitive operator.'}
  known=@($known)
  unknown=@($unknown)
  assumptions=@($assumptions)
  contradictions=@($contradictions.ToArray())
  contradiction_resolution=$contradictionResolution
  hypotheses=@($hypotheses)
  source_ladder=@($sourceLadder)
  selected_next_logical_step=$nextStep
  selected_resolution_step=if($contradictionResolution.result){$contradictionResolution.result.selected_resolution_step}else{$null}
  no_evidence_no_claim=$true
  return_to_parent='Use this frame to build/wire AIMO cognitive logic before any further execution authority work.'
  boundary=[ordered]@{reasoning_only=$true; action_executed=$false; live_process_touched=$false; active_memory_mutated=$false; repo_mutated_by_kernel=$false}
  kernel_ref=$kernelPath
}
WJson $frame $OutputPath
Write-Host ('MIND_LOGIC_FRAME_STATUS='+$frame.status)
Write-Host ('MIND_LOGIC_CLASSIFICATION='+$frame.classification)
Write-Host ('MIND_LOGIC_NEXT_STEP='+$frame.selected_next_logical_step.step_id)
Write-Host ('MIND_LOGIC_FRAME_PATH='+$OutputPath)
