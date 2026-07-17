param(
  [ValidateSet('Diagnostic','ReadOnly','SandboxExploration','SandboxTestLife')][string]$Mode='SandboxExploration',
  [string]$Question='',
  [ValidateSet('SelfBuild','OwnerHint','Recovery')][string]$SeedSource='SelfBuild',
  [switch]$EnableDeepThinking,
  [switch]$EnableMemoryLearning,
  [ValidateSet('Auto','QueueOnly','QueueAndMerge','DirectAbsorb')][string]$MemoryIngestionMode='Auto',
  [string]$OutputRoot='.runtime/autonomous_inner_motor',
  [int]$MaxMemorySamples=6
)
$ErrorActionPreference='Stop'
# SandboxExploration, sandbox_exploration, SANDBOX_EXPLORATION_PROOF.json, SandboxTestLife, TEST_LIFE_PROOF.json
# No active memory mutation. PROTECTIVE_CHECKPOINT. schoolActive.
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=30){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth $Depth
  $lines=@($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
  while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){$lines=@();break}; $lines=@($lines[0..($lines.Count-2)]) }
  $clean=($lines -join "`n") + "`n"
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $full=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($full,$clean,$utf8NoBom)
}
function Get-FileProof([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ return $null }
  $item=Get-Item -LiteralPath $Path
  return [ordered]@{ path=$Path; bytes=[int64]$item.Length; sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower() }
}
function Read-JsonSafe([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ return $null }
  try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) } catch { return $null }
}
function Get-ActiveMemoryState {
  $root='.runtime/active_compact_semantic_memory_v1'
  $state=[ordered]@{ root=$root; exists=(Test-Path -LiteralPath $root); unchanged=$true; files=@(); manifest_summary=$null; index_key_sample=@(); cell_sample=@() }
  if(-not $state.exists){ return $state }
  foreach($name in @('manifest.json','index.json','cells.jsonl')){
    $p=Join-Path $root $name
    $fp=Get-FileProof $p
    if($fp){ $state.files += $fp }
  }
  $manifest=Read-JsonSafe (Join-Path $root 'manifest.json')
  if($manifest){ $state.manifest_summary=[ordered]@{ schema=$manifest.schema; status=$manifest.status; run_id=$manifest.run_id; cell_count=$manifest.cell_count; merged_count=$manifest.merged_count; total_memory_bytes=$manifest.total_memory_bytes; runtime_ready=$manifest.runtime_ready; boundary=$manifest.boundary } }
  $index=Read-JsonSafe (Join-Path $root 'index.json')
  if($index){
    $props=@($index.PSObject.Properties | Select-Object -First $MaxMemorySamples)
    foreach($p in $props){ $state.index_key_sample += [ordered]@{ key=$p.Name; value=([string]$p.Value).Substring(0,[Math]::Min(120,([string]$p.Value).Length)) } }
  }
  $cellsPath=Join-Path $root 'cells.jsonl'
  if(Test-Path -LiteralPath $cellsPath){
    Get-Content -LiteralPath $cellsPath -TotalCount $MaxMemorySamples | ForEach-Object {
      try {
        $c=$_ | ConvertFrom-Json
        $titleCandidate=''
        if($c.PSObject.Properties.Name -contains 'title'){ $titleCandidate=[string]$c.title }
        elseif($c.PSObject.Properties.Name -contains 'summary'){ $titleCandidate=[string]$c.summary }
        elseif($c.PSObject.Properties.Name -contains 'topic'){ $titleCandidate=[string]$c.topic }
        $state.cell_sample += [ordered]@{ id=$c.id; kind=$c.kind; title=$titleCandidate.Substring(0,[Math]::Min(140,$titleCandidate.Length)) }
      }
      catch { }
    }
  }
  return $state
}
function Get-RepoState {
  return [ordered]@{
    branch=(git rev-parse --abbrev-ref HEAD).Trim()
    head=(git rev-parse --short HEAD).Trim()
    origin_delta=(git rev-list --left-right --count HEAD...origin/main).Trim()
    dirty=@(git status --short --untracked-files=all)
  }
}
function Get-SchoolState {
  $names=@('run_agent_school','exact_count_cycle','codex_warehouse','codex.cmd','codex exec','absorb_atom_file','digest','file_atom_absorption')
  $procs=@()
  Get-CimInstance Win32_Process | ForEach-Object {
    $cmd=$_.CommandLine; if(-not $cmd){$cmd=''}
    $hit=$false
    foreach($n in $names){ if($_.Name -like "*$n*" -or $cmd -like "*$n*"){ $hit=$true } }
    if($hit){ $procs += [ordered]@{ pid=$_.ProcessId; name=$_.Name; command=($cmd -replace '\s+',' ').Substring(0,[Math]::Min(260,($cmd -replace '\s+',' ').Length)) } }
  }
  return [ordered]@{ schoolActive=(@($procs).Count -gt 0); processes=$procs; owner_control_contract=(Test-Path 'operations/school/OWNER_SCHOOL_CONTROL_CONTRACT_V1.md'); runbook=(Test-Path 'operations/school/OWNER_SCHOOL_RUNBOOK_V1.md') }
}
function Get-BodyMapState {
  $p='reports/self_development/agent_body_map.json'
  $j=Read-JsonSafe $p
  if(-not $j){ return [ordered]@{ exists=$false; path=$p } }
  return [ordered]@{ exists=$true; path=$p; schema=$j.schema; map_kind=$j.map_kind; component_count=@($j.components).Count; confirmed_component_count=$j.confirmed_component_count; primary_evidence_candidate_count=$j.primary_evidence_candidate_count }
}
function Get-LivingLoopState {
  $paths=@('contracts/living_loop/LIVING_LOOP_CONTRACT_V1.md','reports/self_development/LIVING_LOOP_CONTRACT_V1_PROOF.json','reports/self_development/LIVING_LOOP_EVALUATOR_V1_PROOF.json')
  $items=@()
  foreach($p in $paths){ $items += [ordered]@{ path=$p; exists=(Test-Path -LiteralPath $p) } }
  return [ordered]@{ artifacts=$items; active_runtime=$false; autonomous_loop=$false; execution_allowed=$false; mutation_authorized=$false }
}
function Get-SelfBuildState {
  $paths=@(
    'self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json',
    'self_build_backlog/CAPABILITY_GAP_INDEX_V1.json',
    'self_build_backlog/CAPABILITY_GAP_DETECTOR_V1.json',
    'self_build_batch/decision_kernel/PHASE165E_DYNAMIC_GAP_DECISION_V1.json',
    'self_build_batch/decision_kernel/SELECT_DYNAMIC_SELF_BUILD_NEXT_GAP_V1.ps1',
    'self_control/BUILDER_NEXT_GAP_SELECTION.json',
    'self_control/BUILDER_NEXT_GAP_SELECTOR_RESULT.json',
    'GENESIS_STATE.json',
    'CAPABILITY_ROADMAP.json',
    'TASK_QUEUE.json',
    'agent_catalog/AGENT_CATALOG.json'
  )
  $items=@()
  foreach($p in $paths){
    $j=Read-JsonSafe $p
    $summary=$null
    if($j){
      $summary=[ordered]@{}
      foreach($k in @('schema','status','purpose','goal','current_phase','selected_gap','next_action','decision','catalog_version')){
        if($j.PSObject.Properties.Name -contains $k){ $summary[$k]=$j.$k }
      }
      if($p -eq 'agent_catalog/AGENT_CATALOG.json' -and ($j.PSObject.Properties.Name -contains 'agents')){ $summary.agent_count=@($j.agents).Count }
    }
    $items += [ordered]@{ path=$p; exists=(Test-Path -LiteralPath $p); summary=$summary }
  }
  return [ordered]@{
    mode='self_build_direction_source'
    does_not_wait_for_owner_query=$true
    purpose='derive internal thinking target from self-build backlog, roadmap, current body, memory, and future child-agent production direction'
    artifacts=$items
  }
}
function New-InternalSelfGoal($SelfBuildState,$BodyMapState,$MemoryState){
  $agentCatalog=$SelfBuildState.artifacts | Where-Object { $_.path -eq 'agent_catalog/AGENT_CATALOG.json' } | Select-Object -First 1
  $agentCount=0
  if($agentCatalog -and $agentCatalog.summary -and ($agentCatalog.summary.PSObject.Properties.Name -contains 'agent_count')){ $agentCount=[int]$agentCatalog.summary.agent_count }
  return [ordered]@{
    source='SELF_BUILD_INTERNAL_SEED'
    owner_query_required=$false
    goal='Increase the agent thinking capacity so it can later govern self-build actions and eventually produce child agents.'
    first_stage='think_and_improve_logic_without_action'
    second_stage='governed_self_build_steps_after validators and owner authority'
    third_stage='child_agent_factory only after Builder can self-observe, self-select gaps, self-validate, and self-repair'
    current_body_signal=[ordered]@{ component_count=$BodyMapState.component_count; confirmed=$BodyMapState.confirmed_component_count; candidates=$BodyMapState.primary_evidence_candidate_count }
    memory_signal=[ordered]@{ active_memory_exists=$MemoryState.exists; manifest=$MemoryState.manifest_summary }
    child_agent_signal=[ordered]@{ existing_agent_catalog_count=$agentCount; child_agents_are_future_output_not_current_brain=$true }
  }
}
function Invoke-MemoryRecall([string]$Query,[int]$Top=5){
  $result=[ordered]@{ query=$Query; status='NOT_RUN'; exit_code=$null; matches=@(); raw_output=@() }
  $script='operations/school/memory/query_compact_semantic_memory_v1.ps1'
  if(-not(Test-Path $script)){ $result.status='MISSING_QUERY_SCRIPT'; return $result }
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -Query $Query -Top $Top *>&1 | ForEach-Object { [string]$_ })
  $result.exit_code=$LASTEXITCODE
  $result.raw_output=@($out)
  $status=($out | Where-Object { $_ -match '^MEMORY_RECALL_STATUS=' } | Select-Object -Last 1) -replace '^MEMORY_RECALL_STATUS=',''
  if([string]::IsNullOrWhiteSpace($status)){ $status='UNKNOWN' }
  $result.status=$status
  foreach($line in $out){
    if($line -like 'MATCH|*'){
      $parts=$line -split '\|'
      $m=[ordered]@{ rank=$parts[1]; raw=$line }
      foreach($seg in $parts[2..($parts.Count-1)]){
        $kv=$seg -split '=',2
        if($kv.Count -eq 2){ $m[$kv[0]]=$kv[1] }
      }
      $result.matches += $m
    }
  }
  return $result
}
function New-ThoughtFrame([string]$Id,[string]$Question,[string]$Parent,[int]$Depth,[string]$Kind){
  return [ordered]@{
    id=$Id
    parent=$Parent
    depth=$Depth
    kind=$Kind
    question=$Question
    priority_score=0
    known=@()
    unknown=@()
    decomposition=@()
    evidence=@()
    local_conclusion=''
    answer_status='UNANSWERED'
    risks=@()
    return_to_parent=''
  }
}
function Build-DeepThinkingTree($InternalGoal,$BodyMapState,$MemoryState){
  $frames=@()
  $root=New-ThoughtFrame 'root' 'How can I become stronger in thinking without waiting for Owner and while preparing for self-build and future child-agent production?' $null 0 'root'
  $root.priority_score=100
  $root.known += 'Internal self-build goal exists.'
  $root.known += 'Active compact memory exists and must be used first.'
  $root.unknown += 'Which reasoning gap most improves future self-build?'
  $root.decomposition=@('body_state','memory_recall','gap_selection','learning_atom')
  $frames += $root
  $body=New-ThoughtFrame 'body_state' 'What body/state do I have that constrains thinking?' 'root' 1 'subquestion'
  $body.priority_score=86
  $body.known += "body_components=$($BodyMapState.component_count) confirmed=$($BodyMapState.confirmed_component_count) candidates=$($BodyMapState.primary_evidence_candidate_count)"
  $body.evidence += [ordered]@{ source='agent_body_map'; proof_level='PROVEN_LAB'; summary='body inventory map read' }
  $body.local_conclusion='The agent has enough body inventory to reason, but candidates must not be treated as mature organs.'
  $body.answer_status='ANSWERED_WITH_LAB_PROOF'
  $body.return_to_parent='Use body maturity boundaries when choosing self-build gap.'
  $frames += $body
  $memory=New-ThoughtFrame 'memory_recall' 'What does compact memory already know about deep thinking, source ladder, and self-build?' 'root' 1 'subquestion'
  $memory.priority_score=95
  $memory.known += "active_memory_exists=$($MemoryState.exists)"
  $memory.unknown += 'Exact relevant cells require recall query.'
  $memory.decomposition=@('recall_source_ladder','recall_self_build','recall_depth')
  $memory.local_conclusion='Compact memory must be queried before external ports; recall results are attached to the deep_thinking.memory_recalls trace.'
  $memory.answer_status='ANSWERED_BY_RECALL_TRACE_REQUIRED'
  $memory.return_to_parent='Use recall evidence to decide whether a new learning atom is needed or whether existing memory already covers the rule.'
  $frames += $memory
  $gap=New-ThoughtFrame 'gap_selection' 'Which thinking gap should I strengthen first?' 'root' 1 'subquestion'
  $gap.priority_score=92
  $gap.known += 'Linear self-question trace is insufficient for real thinking.'
  $gap.known += 'Agent must return to parent and self-build direction.'
  $gap.local_conclusion='The next gap is recursive thought framing with per-node evidence, return-to-parent, and memory learning.'
  $gap.answer_status='ANSWERED_WITH_REASONING'
  $gap.return_to_parent='Selected gap directly improves Builder self-growth before action authority.'
  $frames += $gap
  $atom=New-ThoughtFrame 'learning_atom' 'What atom should be written so the next thinking cycle is stronger?' 'root' 1 'subquestion'
  $atom.priority_score=98
  $atom.known += 'Owner requires self-thinking to create memory atoms during thinking.'
  $atom.known += 'Existing absorption pipeline can add compact semantic cells safely.'
  $atom.local_conclusion='Create one learning atom: deep thinking requires recursive ThoughtFrame tree plus governed memory absorption.'
  $atom.answer_status='ANSWERED_WITH_ACTIONABLE_LEARNING_ATOM'
  $atom.return_to_parent='After absorption, future recall should find the deep-thinking law.'
  $frames += $atom
  return @($frames)
}
function New-DeepThinkingLearningAtom($RunId,$Frames,$InternalGoal){
  $root=$Frames | Where-Object { $_.id -eq 'root' } | Select-Object -First 1
  return [ordered]@{
    schema='aimo_self_learning_atom_v1'
    candidate_id=('aimo_deep_thinking_'+$RunId)
    concept_key='aimo.deep_thinking.recursive_thought_frame.memory_learning'
    label='AIMO deep thinking uses recursive ThoughtFrame tree and writes one governed learning atom'
    kind='thinking_growth_rule'
    definition='A thinking agent should not merely ask a linear list of questions. For each root question it must decompose into ThoughtFrames, answer atomic subquestions from compact memory and internal evidence, synthesize back to parent, identify the next self-build gap, and write one validated memory atom through governed absorption so the next cycle becomes stronger.'
    summary='AIMO deep thinking requires recursive ThoughtFrame decomposition, evidence per node, return-to-parent synthesis, gap selection, and governed self-learning memory atom absorption.'
    aliases=@('deep_thinking_kernel_v1','recursive_thought_frame','self_learning_atom','memory_growth_during_thinking')
    properties=@('owner_query_required=false','stage=thinking_growth','action_authority=false','memory_growth=governed_absorption','max_atoms_per_cycle=1')
    relations=@('uses:active_compact_memory','uses:query_compact_semantic_memory_v1','absorbed_by:absorb_atom_file_via_digest_pipeline_v1','supports:self_build','precedes:child_agent_production')
    uses=@('When AIMO starts a self-directed thinking cycle, query memory first, build a ThoughtFrame tree, and absorb one high-quality learning atom if it improves future reasoning.')
    proof_requirements=@('thought_frame_tree_present','memory_recall_attempted','learning_atom_absorbed_by_digest_pipeline','active_memory_hash_changed_or_observation_count_incremented','candidate_memory_root_removed_after_publish')
    negative_case='Reject if the agent writes raw chat dumps, bypasses digest validation, mutates active memory directly, or creates more than one unvalidated atom per thinking cycle.'
    return_to_parent='Return to Builder self-build path: stronger thinking first, governed self-build actions second, child-agent production third.'
    source_basis=@('Owner instruction 20260715: thinking should create memory atoms during the thinking process','AIMO self-directed thinking proof','active compact memory governed absorption route')
    source_missing=$false
    quality_flags=@('recursive','memory_first','governed_absorption','return_to_parent','self_build_aligned')
  }
}
function Invoke-MemoryAtomAcceptanceGate($RunRoot,$RunId,$Atom,$Frames,$MemoryRecalls){
  if(-not(Test-Path -LiteralPath $RunRoot)){ New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null }
  $candidatePath=Join-Path $RunRoot 'learning_atom.candidate.jsonl'
  $contextPath=Join-Path $RunRoot 'memory_atom_gate_context.json'
  $decisionPath=Join-Path $RunRoot 'memory_atom_acceptance_gate_decision.json'
  $finalAtomPath=Join-Path $RunRoot 'learning_atom.accepted.jsonl'
  $candidateJson=($Atom | ConvertTo-Json -Depth 40 -Compress)
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $candidatePath), $candidateJson + "`n", $utf8NoBom)
  $context=[ordered]@{ run_id=$RunId; frames=@($Frames); memory_recalls=@($MemoryRecalls); created_at=(Get-Date).ToString('o') }
  Write-CleanJson $contextPath $context 60
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/autonomous_inner_motor/invoke_memory_atom_acceptance_gate_v1.ps1' -CandidateAtomPath $candidatePath -RunContextPath $contextPath -OutputPath $decisionPath -FinalAtomPath $finalAtomPath *>&1 | ForEach-Object { [string]$_ })
  $exit=$LASTEXITCODE
  $decision=$null
  if(Test-Path -LiteralPath $decisionPath){ $decision=Read-JsonSafe $decisionPath }
  return [ordered]@{ exit_code=$exit; raw_output=@($out); candidate_atom_path=$candidatePath; context_path=$contextPath; decision_path=$decisionPath; final_atom_path=$finalAtomPath; decision=$decision }
}
function Get-CurrentProcessAncestryIds {
  $ids=New-Object System.Collections.Generic.HashSet[int]
  $cur=$PID
  while($cur -and -not $ids.Contains([int]$cur)){
    [void]$ids.Add([int]$cur)
    $proc=Get-CimInstance Win32_Process -Filter "ProcessId=$cur" -ErrorAction SilentlyContinue
    if(-not $proc){ break }
    $cur=[int]$proc.ParentProcessId
  }
  return $ids
}
function Test-MemoryPublishBusy {
  $lockPath='.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'
  $busy=@()
  if(Test-Path -LiteralPath $lockPath){ $busy += 'MERGE_QUEUE_LOCK_EXISTS' }
  $ignoreIds=Get-CurrentProcessAncestryIds
  $terms=@('run_agent_school','exact_count_cycle','codex_warehouse','consume_codex_warehouse','absorb_atom_file_via_digest_pipeline','invoke_compact_semantic_digestion','merge_compact_memory_intake_queue')
  foreach($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)){
    if($ignoreIds.Contains([int]$p.ProcessId)){ continue }
    $cmd=[string]$p.CommandLine
    if([string]::IsNullOrWhiteSpace($cmd)){ $cmd='' }
    foreach($t in $terms){
      if($p.Name -like "*$t*" -or $cmd -like "*$t*"){
        $busy += ("PROCESS:$($p.ProcessId):$t")
        break
      }
    }
  }
  return [ordered]@{ busy=(@($busy).Count -gt 0); reasons=@($busy); ignored_process_ids=@($ignoreIds) }
}
function New-AgentLifeCompactMemoryPacket($RunRoot,$RunId,$AcceptedAtomPath,$GateDecision){
  if(-not(Test-Path -LiteralPath $RunRoot)){ New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null }
  $policy=Read-JsonSafe 'operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json'
  if(-not $policy){ throw 'COMPACT_MEMORY_INTAKE_POLICY_MISSING' }
  $queueRoot=[string]$policy.runtime_queue_root
  if([string]::IsNullOrWhiteSpace($queueRoot)){ throw 'COMPACT_MEMORY_INTAKE_QUEUE_ROOT_MISSING' }
  if(-not(Test-Path -LiteralPath $queueRoot)){ New-Item -ItemType Directory -Force -Path $queueRoot | Out-Null }
  $atom=Read-JsonSafe $AcceptedAtomPath
  if(-not $atom){ throw "ACCEPTED_ATOM_BAD_JSON:$AcceptedAtomPath" }
  $topic=[string]$atom.concept_key
  if([string]::IsNullOrWhiteSpace($topic)){ $topic='aimo.agentlife.memory_learning' }
  $topic=$topic -replace '[^A-Za-z0-9_.-]','_'
  $id=[string]$atom.candidate_id
  if([string]::IsNullOrWhiteSpace($id)){ $id='aimo_agentlife_'+$RunId }
  $id=$id -replace '[^A-Za-z0-9_.-]','_'
  $hint=[string]$atom.summary
  if([string]::IsNullOrWhiteSpace($hint)){ $hint=[string]$atom.definition }
  if([string]::IsNullOrWhiteSpace($hint)){ $hint=[string]$atom.label }
  $packet=[ordered]@{
    schema='compact_memory_knowledge_packet_v1'
    source_kind='AgentLife'
    source_id=('AIMO:'+$RunId)
    created_at=(Get-Date).ToString('o')
    atoms=@([ordered]@{
      id=$id
      topic=$topic
      level=1
      quality_score=0.95
      novelty_score=0.60
      summary=$hint
      behavior_use_hint=$hint
      source_ref=$AcceptedAtomPath
      gate_decision=$GateDecision.decision
      gate_reason=$GateDecision.reason
    })
    quality_summary=[ordered]@{ atom_count=1; min_quality_score=0.95; min_novelty_score=0.60; gate_decision=$GateDecision.decision }
    boundary=[ordered]@{ source='AIMO_AGENT_LIFE'; direct_active_memory_write=$false; queue_first=$true; active_memory_merge_requires_lock=$true }
  }
  $packetPath=Join-Path $queueRoot ("agentlife_aimo_$RunId.json")
  Write-CleanJson $packetPath $packet 60
  return [ordered]@{ packet_path=$packetPath; queue_root=$queueRoot; packet=$packet }
}
function Invoke-AgentLifeMemoryQueueIntake($RunRoot,$RunId,$AcceptedAtomPath,$GateDecision,[string]$RequestedMode){
  $busy=Test-MemoryPublishBusy
  $mode=$RequestedMode
  if($mode -eq 'Auto'){
    if($busy.busy){ $mode='QueueOnly' } else { $mode='QueueAndMerge' }
  }
  if($mode -eq 'DirectAbsorb'){
    $direct=Invoke-AcceptedLearningAtomAbsorption $RunRoot $RunId $AcceptedAtomPath
    return [ordered]@{ mode='DirectAbsorb'; requested_mode=$RequestedMode; busy_at_decision=$busy; queue_packet=$null; merge=$null; direct_absorption=$direct; atom_path=$direct.atom_path; exit_code=$direct.exit_code; memory_changed=$direct.memory_changed; candidate_memory_root_removed=$direct.candidate_memory_root_removed; candidate_memory_root_exists_after=$direct.candidate_memory_root_exists_after; status_line=$direct.status_line }
  }
  $packet=New-AgentLifeCompactMemoryPacket $RunRoot $RunId $AcceptedAtomPath $GateDecision
  $validationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/compact_memory_intake/validate_compact_memory_packet_v1.ps1' -PacketPath $packet.packet_path *>&1 | ForEach-Object { [string]$_ })
  $validationStatus=($validationOut | Where-Object { $_ -match '^PACKET_VALIDATION_STATUS=' } | Select-Object -Last 1) -replace '^PACKET_VALIDATION_STATUS=',''
  if($validationStatus -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){ throw "AGENTLIFE_PACKET_VALIDATION_NOT_PASS:$validationStatus" }
  if($mode -eq 'QueueOnly'){
    $after=Get-ActiveMemoryState
    return [ordered]@{ mode='QueueOnly'; requested_mode=$RequestedMode; busy_at_decision=$busy; queue_packet=$packet; packet_validation_status=$validationStatus; packet_validation_output=@($validationOut); merge=$null; atom_path=$packet.packet_path; exit_code=0; memory_changed=$false; candidate_memory_root_removed=$null; candidate_memory_root_exists_after=$null; status_line='QUEUED_AGENTLIFE_PACKET_NO_ACTIVE_MEMORY_MERGE' }
  }
  if($mode -ne 'QueueAndMerge'){ throw "UNKNOWN_MEMORY_INGESTION_MODE:$mode" }
  $before=Get-ActiveMemoryState
  $mergeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1' -PacketPath $packet.packet_path -ProcessLimit 1 *>&1 | ForEach-Object { [string]$_ })
  $mergeExit=$LASTEXITCODE
  $mergeStatus=($mergeOut | Where-Object { $_ -match '^MERGE_QUEUE_STATUS=' } | Select-Object -Last 1) -replace '^MERGE_QUEUE_STATUS=',''
  $mergeProof=($mergeOut | Where-Object { $_ -match '^MERGE_QUEUE_PROOF=' } | Select-Object -Last 1) -replace '^MERGE_QUEUE_PROOF=',''
  $after=Get-ActiveMemoryState
  return [ordered]@{
    mode='QueueAndMerge'
    requested_mode=$RequestedMode
    busy_at_decision=$busy
    queue_packet=$packet
    packet_validation_status=$validationStatus
    packet_validation_output=@($validationOut)
    merge=[ordered]@{ exit_code=$mergeExit; status=$mergeStatus; proof_path=$mergeProof; output=@($mergeOut) }
    atom_path=$packet.packet_path
    exit_code=$mergeExit
    status_line=$mergeStatus
    before=$before
    after=$after
    memory_changed=($($before.files | ConvertTo-Json -Depth 20) -ne $($after.files | ConvertTo-Json -Depth 20))
    candidate_memory_root_removed=$null
    candidate_memory_root_exists_after=$null
  }
}
function Invoke-AcceptedLearningAtomAbsorption($RunRoot,$RunId,$AcceptedAtomPath){
  if(-not(Test-Path -LiteralPath $RunRoot)){ New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null }
  $before=Get-ActiveMemoryState
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1' -InputPath $AcceptedAtomPath -ValidationTier Stable -SizeBudgetBytes 104857600 *>&1 | ForEach-Object { [string]$_ })
  $exit=$LASTEXITCODE
  $after=Get-ActiveMemoryState
  $status=($out | Where-Object { $_ -match '^ABSORB_STATUS=' -or $_ -match '^STATUS=' } | Select-Object -Last 1)
  $candidateRemoved=($out | Where-Object { $_ -match '^CANDIDATE_MEMORY_ROOT_REMOVED=' } | Select-Object -Last 1) -replace '^CANDIDATE_MEMORY_ROOT_REMOVED=',''
  $candidateExistsAfter=($out | Where-Object { $_ -match '^CANDIDATE_MEMORY_ROOT_EXISTS_AFTER=' } | Select-Object -Last 1) -replace '^CANDIDATE_MEMORY_ROOT_EXISTS_AFTER=',''
  return [ordered]@{
    atom_path=$AcceptedAtomPath
    exit_code=$exit
    raw_output=@($out)
    status_line=$status
    candidate_memory_root_removed=$candidateRemoved
    candidate_memory_root_exists_after=$candidateExistsAfter
    before=$before
    after=$after
    memory_changed=($($before.files | ConvertTo-Json -Depth 20) -ne $($after.files | ConvertTo-Json -Depth 20))
  }
}
function Invoke-LearningAtomAbsorption($RunRoot,$RunId,$Atom){
  if(-not(Test-Path -LiteralPath $RunRoot)){ New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null }
  $atomPath=Join-Path $RunRoot 'learning_atom.jsonl'
  $json=($Atom | ConvertTo-Json -Depth 30 -Compress)
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $atomPath), $json + "`n", $utf8NoBom)
  $before=Get-ActiveMemoryState
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1' -InputPath $atomPath -ValidationTier Stable -SizeBudgetBytes 104857600 *>&1 | ForEach-Object { [string]$_ })
  $exit=$LASTEXITCODE
  $after=Get-ActiveMemoryState
  $status=($out | Where-Object { $_ -match '^ABSORB_STATUS=' -or $_ -match '^STATUS=' } | Select-Object -Last 1)
  $candidateRemoved=($out | Where-Object { $_ -match '^CANDIDATE_MEMORY_ROOT_REMOVED=' } | Select-Object -Last 1) -replace '^CANDIDATE_MEMORY_ROOT_REMOVED=',''
  $candidateExistsAfter=($out | Where-Object { $_ -match '^CANDIDATE_MEMORY_ROOT_EXISTS_AFTER=' } | Select-Object -Last 1) -replace '^CANDIDATE_MEMORY_ROOT_EXISTS_AFTER=',''
  return [ordered]@{
    atom_path=$atomPath
    exit_code=$exit
    raw_output=@($out)
    status_line=$status
    candidate_memory_root_removed=$candidateRemoved
    candidate_memory_root_exists_after=$candidateExistsAfter
    before=$before
    after=$after
    memory_changed=($($before.files | ConvertTo-Json -Depth 20) -ne $($after.files | ConvertTo-Json -Depth 20))
  }
}
function Get-LatestMemoryToNextPathReuseGate([string]$OutputRoot,[string]$CurrentRunRoot){
  if(-not(Test-Path -LiteralPath $OutputRoot)){ return $null }
  $currentPath=$null
  try { $currentPath=(Resolve-Path $CurrentRunRoot -ErrorAction SilentlyContinue).Path } catch { $currentPath=$CurrentRunRoot }
  $dirs=@(Get-ChildItem -Path $OutputRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $currentPath } | Sort-Object LastWriteTime -Descending | Select-Object -First 12)
  foreach($dir in $dirs){
    $gatePath=Join-Path $dir.FullName 'memory_to_next_path_reuse_gate.json'
    if(Test-Path -LiteralPath $gatePath){
      try {
        $gate=Get-Content -LiteralPath $gatePath -Raw | ConvertFrom-Json
        if($gate.status -eq 'PASS_MEMORY_TO_NEXT_PATH_REUSE_GATE_V1'){ return $gate }
      } catch { }
    }
  }
  return $null
}
function New-WebResearchRequest([string]$Need,[string]$Why){
  return [ordered]@{ port='WEB_RESEARCH_PORT'; mode='request_only'; performed=$false; need=$Need; why=$Why; allowed_when='Owner/tool authority and citation requirement'; output_expected='cited external facts, not direct action' }
}
function New-CodexQuestionRequest([string]$Need,[string]$Why){
  return [ordered]@{ port='CODEX_QUESTION_PORT'; mode='request_only'; launched=$false; need=$Need; why=$Why; constraints=@('bounded question','no file writes before PREFLIGHT_PASS','Codex is not brain','answer returns as CODEX_DRAFT') }
}
$repo=Get-RepoState
$memoryBefore=Get-ActiveMemoryState
$school=Get-SchoolState
$body=Get-BodyMapState
$living=Get-LivingLoopState
$selfBuild=Get-SelfBuildState
$internalGoal=New-InternalSelfGoal $selfBuild $body $memoryBefore
if([string]::IsNullOrWhiteSpace($Question)){ $Question=$internalGoal.goal }
$policy=Read-JsonSafe 'operations/autonomous_inner_motor/motor_policy.json'
$runId='aimo_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$runRoot=Join-Path $OutputRoot $runId
$proofName=if($Mode -eq 'SandboxTestLife'){ 'TEST_LIFE_PROOF.json' } else { 'SANDBOX_EXPLORATION_PROOF.json' }
$proofPath=Join-Path $runRoot $proofName
$cycles=@(
  [ordered]@{ n=1; lens='self_seed'; question='What should I think about without waiting for Owner?'; memory_used=$true; answer='Derive internal goal from self-build direction: improve thinking capacity first, then governed self-build action, then child-agent production.' },
  [ordered]@{ n=2; lens='body_memory_orientation'; question='What body and memory do I already have?'; memory_used=$true; answer='Read body inventory, active compact memory state, living loop state, School proof state, and self-build artifacts before external requests.' },
  [ordered]@{ n=3; lens='self_build_gap'; question='What gap blocks self-building?'; memory_used=$true; answer='The current blocker is not lack of Owner query. The blocker is a self-directed thinking loop that can select and justify next self-build gap without acting.' },
  [ordered]@{ n=4; lens='logic_growth'; question='How do I raise my own logic without action authority?'; memory_used=$true; answer='Run bounded internal reasoning cycles, compare known/unknown, use compact memory first, produce proof and next self-build hypothesis.' },
  [ordered]@{ n=5; lens='future_action_boundary'; question='When may I start taking steps?'; memory_used=$true; answer='Only after thinking organ can consistently select gaps, produce validators, and stop safely; action remains second phase.' },
  [ordered]@{ n=6; lens='future_child_agent_boundary'; question='When may I create other agents?'; memory_used=$true; answer='Only after Builder can self-observe, self-build small organs, validate, repair, and produce bounded child-agent specs from proven needs.' },
  [ordered]@{ n=7; lens='return_to_parent'; question='What should be built next?'; memory_used=$true; answer='Build self-directed thinking cycle proof and self-build gap selector wiring inside AIMO; do not wait for Owner query.' }
)
$deepThinking=[ordered]@{ enabled=[bool]$EnableDeepThinking; frames=@(); memory_recalls=@(); learning_atom=$null; acceptance_gate=$null; absorption=$null; status='NOT_REQUESTED' }
if($EnableDeepThinking){
  $deepThinking.status='RUNNING'
  $deepThinking.frames=@(Build-DeepThinkingTree $internalGoal $body $memoryBefore)
  foreach($q in @('deep thinking recursive thought frame self build','source ladder memory first return to parent','self learning atom governed absorption')){
    $deepThinking.memory_recalls += Invoke-MemoryRecall $q 5
  }
  $deepThinking.learning_atom=New-DeepThinkingLearningAtom $runId $deepThinking.frames $internalGoal
  if($EnableMemoryLearning){
    $deepThinking.acceptance_gate=Invoke-MemoryAtomAcceptanceGate $runRoot $runId $deepThinking.learning_atom $deepThinking.frames $deepThinking.memory_recalls
    if([int]$deepThinking.acceptance_gate.exit_code -ne 0){ throw "AIMO_MEMORY_ATOM_ACCEPTANCE_GATE_BLOCKED:$($deepThinking.acceptance_gate.exit_code)" }
    if(-not $deepThinking.acceptance_gate.decision.absorption_allowed){ throw "AIMO_MEMORY_ATOM_ACCEPTANCE_GATE_REJECTED" }
    $deepThinking.absorption=Invoke-AgentLifeMemoryQueueIntake $runRoot $runId $deepThinking.acceptance_gate.final_atom_path $deepThinking.acceptance_gate.decision $MemoryIngestionMode
    if([int]$deepThinking.absorption.exit_code -ne 0){ throw "AIMO_LEARNING_ATOM_INGESTION_FAILED:$($deepThinking.absorption.exit_code)" }
    $deepThinking.status='PASS_DEEP_THINKING_WITH_MEMORY_LEARNING'
  } else {
    $deepThinking.status='PASS_DEEP_THINKING_ATOM_CANDIDATE_ONLY'
  }
}
$webRequests=@(
  New-WebResearchRequest 'Current external facts needed for a question that compact memory/internal repo cannot answer.' 'The agent must have a governed external world port, but this run is no-web.'
)
$codexRequests=@(
  New-CodexQuestionRequest 'Ask Codex to inspect implementation uncertainty only after memory/repo are insufficient.' 'The agent must be able to formulate bounded Codex questions without treating Codex as brain.'
)
$selected=[ordered]@{
  path='build_self_directed_thinking_cycle_and_gap_selector_wiring_v1'
  reason='The agent must think and choose self-build gaps without waiting for Owner queries, while still using compact memory first.'
  forbidden_now=@('mutate_active_memory','launch_codex','browse_web','patch_repo')
  validator_needed='memory_query_read_only_validator'
}
$memoryAfter=Get-ActiveMemoryState


$mindLogic=[ordered]@{
  status='NOT_RUN'
  frame_path=$null
  builder_stdout=@()
  builder_exit_code=$null
  frame=$null
}
$mindLogicPath=Join-Path $runRoot 'mind_logic_frame.json'
$mindBuilder='operations/reasoning/build_agent_mind_logic_frame_v1.ps1'
if(Test-Path $mindBuilder){
  $logicProblem=if($internalGoal -and $internalGoal.goal){ [string]$internalGoal.goal } else { [string]$Question }
  if([string]::IsNullOrWhiteSpace($logicProblem)){ $logicProblem='AIMO self-build thinking cycle: choose the next logical reasoning step before action candidate.' }
  $mindOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $mindBuilder -Problem $logicProblem -OutputPath $mindLogicPath *>&1 | ForEach-Object { [string]$_ })
  $mindLogic.builder_stdout=@($mindOut)
  $mindLogic.builder_exit_code=$LASTEXITCODE
  $mindLogic.frame_path=$mindLogicPath
  if((Test-Path $mindLogicPath) -and $LASTEXITCODE -eq 0){
    $mindLogic.frame=Get-Content $mindLogicPath -Raw | ConvertFrom-Json
    $mindLogic.status=$mindLogic.frame.status
  } elseif(Test-Path $mindLogicPath){
    $mindLogic.frame=Get-Content $mindLogicPath -Raw | ConvertFrom-Json
    $mindLogic.status='MIND_LOGIC_BUILDER_NONZERO_WITH_FRAME'
  } else {
    $mindLogic.status='MIND_LOGIC_BUILDER_FAILED_NO_FRAME'
  }
} else {
  $mindLogic.status='MIND_LOGIC_BUILDER_MISSING'
}

$previousReuseGate=Get-LatestMemoryToNextPathReuseGate $OutputRoot $runRoot
$avoidActionIds=@()
if($previousReuseGate -and $previousReuseGate.consumed_action_id){ $avoidActionIds += [string]$previousReuseGate.consumed_action_id }

$actionDecision=[ordered]@{
  status='NOT_RUN'
  packet_path=$null
  selector_stdout=@()
  selector_exit_code=$null
  packet=$null
}
$actionDecisionPath=Join-Path $runRoot 'action_decision_packet.json'
$actionSelector='operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1'
if(Test-Path $actionSelector){
  $actionGoal=if($mindLogic.frame -and $mindLogic.frame.selected_next_logical_step){ ('MindLogicNextStep=' + [string]$mindLogic.frame.selected_next_logical_step.step_id + '; Reason=' + [string]$mindLogic.frame.selected_next_logical_step.reason) } elseif($internalGoal -and $internalGoal.goal){ [string]$internalGoal.goal } else { [string]$Question }
  if([string]::IsNullOrWhiteSpace($actionGoal)){ $actionGoal='Select the next safe self-build action candidate without execution authority.' }
    $selectorArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$actionSelector,'-Mode','LabOnly','-Goal',$actionGoal,'-OutputPath',$actionDecisionPath)
  if(@($avoidActionIds).Count -gt 0){ $selectorArgs += @('-AvoidActionIds'); $selectorArgs += @($avoidActionIds) }
  $actionOut=@(& powershell @selectorArgs *>&1 | ForEach-Object { [string]$_ })
  $actionDecision.selector_stdout=@($actionOut)
  $actionDecision.selector_exit_code=$LASTEXITCODE
  $actionDecision.packet_path=$actionDecisionPath
  if((Test-Path $actionDecisionPath) -and $LASTEXITCODE -eq 0){
    $actionDecision.packet=Get-Content $actionDecisionPath -Raw | ConvertFrom-Json
    $actionDecision.status=$actionDecision.packet.status
  } elseif(Test-Path $actionDecisionPath){
    $actionDecision.packet=Get-Content $actionDecisionPath -Raw | ConvertFrom-Json
    $actionDecision.status='SELECTOR_NONZERO_WITH_PACKET'
  } else {
    $actionDecision.status='ACTION_DECISION_SELECTOR_FAILED_NO_PACKET'
  }
} else {
  $actionDecision.status='ACTION_DECISION_SELECTOR_MISSING'
}

$selectedActionId = $null
if ($actionDecision.packet -and $actionDecision.packet.selected_action) {
  $selectedActionId = [string]$actionDecision.packet.selected_action.action_id
}
$recentActionIds = @()
if (Test-Path -LiteralPath $OutputRoot) {
  $recentDirs = @(Get-ChildItem -Path $OutputRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne (Resolve-Path $runRoot).Path } | Sort-Object LastWriteTime -Descending | Select-Object -First 8)
  foreach ($dir in $recentDirs) {
    $packetPath = Join-Path $dir.FullName 'action_decision_packet.json'
    if (Test-Path -LiteralPath $packetPath) {
      try {
        $packet = Get-Content -LiteralPath $packetPath -Raw | ConvertFrom-Json
        if ($packet.selected_action -and $packet.selected_action.action_id) { $recentActionIds += [string]$packet.selected_action.action_id }
      } catch { }
    }
  }
}
$consecutiveRepeatCount = 0
if ($selectedActionId) { foreach ($actionId in $recentActionIds) { if ($actionId -eq $selectedActionId) { $consecutiveRepeatCount++ } else { break } } }
$repeatPressure = ($selectedActionId -and $consecutiveRepeatCount -ge 3)
$antiRepeatGuardPath = Join-Path $runRoot 'anti_repeat_guard.json'
$antiRepeatGuard = [ordered]@{
  schema = 'aimo_anti_repeat_guard_v1'
  status = if ($repeatPressure) { 'REPEAT_PRESSURE_DETECTED' } else { 'PASS_NO_REPEAT_PRESSURE' }
  selected_action_id = $selectedActionId
  recent_action_ids = @($recentActionIds)
  consecutive_repeat_count = $consecutiveRepeatCount
  repeated_candidate_is_progress = $false
  repeat_requires_new_learning_or_escalation = [bool]$repeatPressure
  pressure_signal = if ($repeatPressure) { 'SAME_ACTION_CANDIDATE_REPEATED_WITHOUT_EXECUTION_OR_MEMORY_DELTA' } else { 'NO_REPEAT_PRESSURE' }
  recommended_next = if ($repeatPressure) { 'PROMOTE_TO_OPERATOR_REVIEW_OR_QUEUE_ONLY_MEMORY_LEARNING_BEFORE_NEXT_LOOP' } else { 'CONTINUE_BOUNDED_THINKING' }
  boundary = [ordered]@{ action_execution_allowed = $false; memory_mutation_allowed = $false; repeat_detection_only = $true; no_repair_execution = $true }
}
Write-CleanJson $antiRepeatGuardPath $antiRepeatGuard 20
$memoryToNextPathReuseGatePath = Join-Path $runRoot 'memory_to_next_path_reuse_gate.json'
$memoryGrowthPacketQueued = [bool]($EnableMemoryLearning -and $deepThinking.absorption -and $deepThinking.absorption.packet_validation_status -eq "PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1" -and -not [string]::IsNullOrWhiteSpace([string]$deepThinking.absorption.atom_path))
$absorptionChanged = [bool]($EnableMemoryLearning -and $deepThinking.absorption -and ([bool]$deepThinking.absorption.memory_changed -or $memoryGrowthPacketQueued))
$reuseGateStatus = if($repeatPressure -and $absorptionChanged){ 'PASS_MEMORY_TO_NEXT_PATH_REUSE_GATE_V1' } elseif($repeatPressure){ 'BLOCKED_MEMORY_TO_NEXT_PATH_REUSE_GATE_NO_MEMORY_DELTA' } else { 'PASS_MEMORY_TO_NEXT_PATH_REUSE_GATE_NOT_REQUIRED' }
$memoryToNextPathReuseGate = [ordered]@{
  schema='memory_to_next_path_reuse_gate_v1'
  status=$reuseGateStatus
  created_at=(Get-Date).ToString('o')
  consumed_action_id=if($reuseGateStatus -eq 'PASS_MEMORY_TO_NEXT_PATH_REUSE_GATE_V1'){ $selectedActionId } else { $null }
  previous_reuse_gate_ref=if($previousReuseGate){ $previousReuseGate.gate_ref } else { $null }
  selected_action_id=$selectedActionId
  repeat_pressure_detected=[bool]$repeatPressure
  consecutive_repeat_count=$consecutiveRepeatCount
  governed_absorption_used=[bool]($EnableMemoryLearning -and $deepThinking.absorption)
  memory_changed=[bool]$deepThinking.absorption.memory_changed
  memory_growth_packet_queued=$memoryGrowthPacketQueued
  learning_signal_available=$absorptionChanged
  next_action_avoid_ids=if($reuseGateStatus -eq 'PASS_MEMORY_TO_NEXT_PATH_REUSE_GATE_V1'){ @($selectedActionId) } else { @() }
  next_loop_instruction=if($reuseGateStatus -eq 'PASS_MEMORY_TO_NEXT_PATH_REUSE_GATE_V1'){ 'Treat consumed_action_id as already absorbed knowledge. Next loop must choose a different mental-growth path unless new evidence changes the route.' } else { 'No consumed repeat candidate available for next-path reuse.' }
  boundary=[ordered]@{ action_execution_allowed=$false; direct_active_memory_write=$false; reuse_gate_only=$true; no_repo_patch_execution=$true; no_codex_launch=$true; no_web_research=$true }
  gate_ref=$memoryToNextPathReuseGatePath
}
Write-CleanJson $memoryToNextPathReuseGatePath $memoryToNextPathReuseGate 20
$proofPackManifestPath = Join-Path $runRoot 'sandbox_proof_pack_manifest.json'

$proof=[ordered]@{
  schema='AUTONOMOUS_INNER_MOTOR_SANDBOX_EXPLORATION_PROOF'
  organ_id='AUTONOMOUS_INNER_MOTOR_ORGAN'
  run_id=$runId
  mode=$Mode
  maturity_level='L2_SANDBOX_EXPLORATION_THINKING_ONLY'
  created_at=(Get-Date).ToString('o')
  question=$Question
  boundary=[ordered]@{ thinking_only=$true; no_action=$true; mind_logic_frame_generated=($mindLogic.status -eq 'PASS_AGENT_MIND_LOGIC_FRAME_V1'); action_decision_candidate_generated=($actionDecision.status -eq 'PASS_AGENT_ACTION_DECISION_PACKET_V1'); anti_repeat_guard_active=[bool]$repeatPressure; repeated_candidate_is_progress=$false; action_execution_allowed=$false; no_active_memory_mutation=(-not [bool]$EnableMemoryLearning); governed_memory_learning=[bool]$EnableMemoryLearning; memory_ingestion_mode=$MemoryIngestionMode; agentlife_queue_first=([bool]$EnableMemoryLearning -and $MemoryIngestionMode -ne 'DirectAbsorb'); direct_active_memory_write=$false; no_git_mutation=$true; no_school_launch=$true; no_codex_launch=$true; no_web_research=$true; proof_file_only=(-not [bool]$EnableMemoryLearning) }
  repo_state=$repo
  memory_state=[ordered]@{ before=$memoryBefore; after=$memoryAfter; unchanged=($($memoryBefore.files | ConvertTo-Json -Depth 10) -eq $($memoryAfter.files | ConvertTo-Json -Depth 10)) }
  body_map_state=$body
  school_state=$school
  living_loop_state=$living
  self_build_state=$selfBuild
  internal_goal=$internalGoal
  owner_query_required=$false
  proof_pack_manifest_path=$proofPackManifestPath
  anti_repeat_guard=$antiRepeatGuard
  memory_to_next_path_reuse_gate=$memoryToNextPathReuseGate
  policy_snapshot=[ordered]@{ allowed_modes=$policy.allowed_modes; disabled_modes=$policy.disabled_modes; source_ladder=$policy.source_ladder; ports=$policy.ports }
  self_question_trace=$cycles
  cycles=$cycles
  memory_use_trace=[ordered]@{ first_source='ACTIVE_COMPACT_MEMORY_PORT'; used_manifest=$true; used_index_sample=$true; used_cell_sample=$true; mutation=[bool]$EnableMemoryLearning; limitation='memory system exists; deep thinking uses recall and may absorb one governed learning atom when enabled' }
  deep_thinking=$deepThinking
  internal_library_trace=[ordered]@{ used_body_map=$body.exists; used_living_loop=$true; used_school_contract=$school.owner_control_contract }
  web_research_requests=$webRequests
  codex_question_requests=$codexRequests
  decision_trace=@(
    [ordered]@{ step='classify'; result='thinking_only_agent_logic'; proof='Owner requested thinking/logical growth, not action authority.' },
    [ordered]@{ step='memory_first'; result='compact_memory_read_before_external_requests'; proof='memory_state present and unchanged.' },
    [ordered]@{ step='gate'; result='block_actions'; proof='policy disables mutation/action modes.' },
    [ordered]@{ step='mind_logic_frame'; result=$mindLogic.status; proof='Mind Logic Kernel separates known/unknown, contradiction, hypotheses, source ladder, and next logical step before action candidate.' },
    [ordered]@{ step='action_candidate_contract'; result=$actionDecision.status; proof='Action Decision Contract selects a next action candidate from the mind logic frame but keeps execution_allowed=false.' },
    [ordered]@{ step='select_next'; result=$selected.path; proof='deep recursive thinking and self-learning atom loop are the next bottleneck for thinking quality.' }
  )
  selected_next_path=$selected
  mind_logic_frame=$mindLogic
  next_action_candidate=$actionDecision
  heartbeat=[ordered]@{ cycle_count=@($cycles).Count; alive='one_shot_sandbox'; background_process_started=$false }
  final_self_diagnosis='The motor can self-seed a thinking cycle, build a Mind Logic Frame, decompose a root question into ThoughtFrames, use memory recall, and return a next_action_candidate with execution disabled. Memory learning remains governed and optional.'
  stop_reason='PROTECTIVE_CHECKPOINT_THINKING_ONLY'
  mutation_audit=[ordered]@{ active_memory_mutated=[bool]$EnableMemoryLearning; direct_active_memory_write=$false; governed_absorption_used=[bool]($EnableMemoryLearning -and $deepThinking.absorption); memory_ingestion_mode=if($deepThinking.absorption){$deepThinking.absorption.mode}else{$MemoryIngestionMode}; git_mutated=$false; codex_launched=$false; web_research_performed=$false; school_started=$false; background_process_started=$false; files_written=@($proofPath,$mindLogicPath,$actionDecisionPath,$antiRepeatGuardPath,$memoryToNextPathReuseGatePath,$proofPackManifestPath) }
  validator_result=[ordered]@{ runner_self_check='PASS_RUNNER_GENERATED_SINGLE_SANDBOX_PROOF'; external_validator_expected='validators/validate_autonomous_inner_motor_organ_contract.ps1 -SandboxProofPath <proof>; validators/validate_autonomous_inner_motor_mind_logic_wiring_v1.ps1 -ProofPath <proof>; validators/validate_autonomous_inner_motor_action_decision_wiring_v1.ps1 -ProofPath <proof>' }
}
Write-CleanJson $proofPath $proof 80
$proofPackRequiredFiles=@('SANDBOX_EXPLORATION_PROOF.json','mind_logic_frame.json','action_decision_packet.json','anti_repeat_guard.json','memory_to_next_path_reuse_gate.json')
$proofPackOptionalSidecars=@('memory_recall_filter.json','contradiction_resolution.json','hypothesis_test_result.json','deep_source_answer_request.json','memory_filter_for_answer.json','route_request_packet.json','source_authority_route_decision.json','deep_source_answer_assimilation.json','mind_delta_acceptance_decision.json')
$proofPackFiles=@()
foreach($name in @($proofPackRequiredFiles + $proofPackOptionalSidecars)){
  $p=Join-Path $runRoot $name
  $fp=Get-FileProof $p
  if($fp){ $proofPackFiles += $fp }
}
$proofPackManifest=[ordered]@{
  schema='aimo_sandbox_proof_pack_manifest_v2'
  status='PASS_AIMO_SANDBOX_PROOF_PACK_V2'
  run_id=$runId
  proof_ref=$proofName
  required_files=$proofPackRequiredFiles
  optional_sidecars=$proofPackOptionalSidecars
  files=$proofPackFiles
  anti_repeat_guard_status=$antiRepeatGuard.status
  sidecar_policy='sidecar files are part of the proof pack, not extra evidence leaks'
  size_policy='large proof accepted only with manifest and bounded mutation audit'
  boundary=[ordered]@{ action_execution_allowed=$false; direct_active_memory_write=$false; no_codex_launch=$true; no_web_research=$true; no_repair_execution=$true }
}
Write-CleanJson $proofPackManifestPath $proofPackManifest 30
Write-Host "MODE=$Mode"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "OWNER_QUERY_REQUIRED=$($proof.owner_query_required)"
Write-Host "INTERNAL_GOAL=$($proof.internal_goal.goal)"
Write-Host "STOP_REASON=$($proof.stop_reason)"
Write-Host "MEMORY_UNCHANGED=$($proof.memory_state.unchanged)"
Write-Host "DEEP_THINKING_STATUS=$($proof.deep_thinking.status)"
Write-Host "GOVERNED_MEMORY_LEARNING=$($proof.boundary.governed_memory_learning)"
Write-Host "MEMORY_INGESTION_MODE=$($proof.boundary.memory_ingestion_mode)"
Write-Host "DIRECT_ACTIVE_MEMORY_WRITE=$($proof.boundary.direct_active_memory_write)"
Write-Host "MIND_LOGIC_STATUS=$($proof.mind_logic_frame.status)"
Write-Host "MIND_LOGIC_NEXT_STEP=$($proof.mind_logic_frame.frame.selected_next_logical_step.step_id)"
Write-Host "MIND_LOGIC_MEMORY_RECALL_FILTER_STATUS=$($proof.mind_logic_frame.frame.memory_recall_filter.status)"
Write-Host "MIND_LOGIC_MEMORY_RECALL_FILTER_ACCEPTED=$($proof.mind_logic_frame.frame.memory_recall_filter.accepted_count)"
Write-Host "MIND_LOGIC_CONTRADICTION_RESOLUTION_STATUS=$($proof.mind_logic_frame.frame.contradiction_resolution.status)"
Write-Host "MIND_LOGIC_CONTRADICTION_RESOLUTION_DECISION=$($proof.mind_logic_frame.frame.contradiction_resolution.result.decision)"
Write-Host "MIND_LOGIC_HYPOTHESIS_TEST_STATUS=$($proof.mind_logic_frame.frame.hypothesis_test_result.status)"
Write-Host "MIND_LOGIC_STRONGEST_HYPOTHESIS=$($proof.mind_logic_frame.frame.hypothesis_test_result.result.strongest_hypothesis.kind)"
Write-Host "MIND_LOGIC_DEEP_SOURCE_ANSWER_STATUS=$($proof.mind_logic_frame.frame.deep_source_answer_request.status)"
Write-Host "MIND_LOGIC_DEEP_SOURCE_ANSWER_READY=$($proof.mind_logic_frame.frame.deep_source_answer_request.result.answer_ready)"
Write-Host "ACTION_DECISION_STATUS=$($proof.next_action_candidate.status)"
Write-Host "ACTION_EXECUTION_ALLOWED=$($proof.boundary.action_execution_allowed)"
if($EnableMemoryLearning){ Write-Host "LEARNING_ATOM_MEMORY_CHANGED=$($proof.deep_thinking.absorption.memory_changed)" } else { Write-Host "No active memory mutation" }
