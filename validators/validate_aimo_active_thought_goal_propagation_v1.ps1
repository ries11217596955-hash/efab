$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Assert([bool]$ok,[string]$m){ if(-not $ok){ Add-Err $m } }
function Sha([string]$p){ if(-not(Test-Path $p)){return $null}; return (Get-FileHash $p -Algorithm SHA256).Hash }
function Normalize([string]$p){ if(Test-Path $p){ $raw=Get-Content $p -Raw; [IO.File]::WriteAllText((Resolve-Path $p),($raw -replace "`r`n","`n").TrimEnd()+"`n",(New-Object Text.UTF8Encoding($false))) } }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$reasoner='operations/reasoning/build_agent_mind_logic_frame_v1.ps1'
$proofPath='tests/self_development/AIMO_ACTIVE_THOUGHT_GOAL_PROPAGATION_V1_PROOF.json'
$runtimeRoot='.runtime/aimo_active_thought_goal_propagation_v1'
if(Test-Path $runtimeRoot){ Remove-Item $runtimeRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $runtimeRoot|Out-Null
foreach($p in @($runner,$reasoner)){ if(-not(Test-Path $p)){ Add-Err ('missing:'+ $p) } }
foreach($p in @($runner,$reasoner)){ if(Test-Path $p){$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $p),[ref]$t,[ref]$e)|Out-Null;foreach($x in $e){Add-Err ((Split-Path $p -Leaf)+':parse:'+ $x.Message)}} }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
$needles=@(
  '$ownerQuestionProvided=(-not [string]::IsNullOrWhiteSpace($Question))',
  "$internalGoal['source']='OWNER_QUESTION_ACTIVE_GOAL'",
  "$internalGoal['goal']=$Question",
  '$internalGoal[''owner_question_active'']=$true',
  'elseif([string]::IsNullOrWhiteSpace($Question))',
  '$consumed=($hasSeed -and -not $OwnerQuestionProvided)',
  '$logicProblem=if($internalGoal -and $internalGoal.goal){ [string]$internalGoal.goal } else { [string]$Question }',
  '$selectiveCompactMemoryRetrieval = New-SelectiveCompactMemoryRetrieval $runId $internalGoal $mindLogic $mentalFrontierRouter $dynamicMemoryRetrievalBudget'
)
foreach($n in $needles){ Assert ($runnerText.Contains($n)) ('runner_missing_contract:'+ $n) }
$idxOwner=$runnerText.IndexOf('$ownerQuestionProvided=(-not [string]::IsNullOrWhiteSpace($Question))')
$idxOwnerGoal=$runnerText.IndexOf("$internalGoal['goal']=$Question")
$idxRefocus=$runnerText.IndexOf('$newThoughtSeedToActiveGoal=New-NewThoughtSeedToActiveGoal')
$idxLogic=$runnerText.IndexOf('$logicProblem=if($internalGoal -and $internalGoal.goal)')
$idxRetrievalCall=$runnerText.IndexOf('$selectiveCompactMemoryRetrieval = New-SelectiveCompactMemoryRetrieval')
Assert ($idxOwner -ge 0 -and $idxOwnerGoal -gt $idxOwner -and $idxRefocus -gt $idxOwnerGoal -and $idxLogic -gt $idxRefocus -and $idxRetrievalCall -gt $idxLogic) 'owner_goal_order_invalid'
# Inspect retrieval function body: InternalGoal.goal must contribute to query before memory scan.
$retrievalStart=$runnerText.IndexOf('function New-SelectiveCompactMemoryRetrieval')
$retrievalEnd=$runnerText.IndexOf('function New-NextBuildTaskDecisionSpine',$retrievalStart)
Assert ($retrievalStart -ge 0 -and $retrievalEnd -gt $retrievalStart) 'retrieval_function_bounds_missing'
$retrievalBody=if($retrievalStart -ge 0 -and $retrievalEnd -gt $retrievalStart){$runnerText.Substring($retrievalStart,$retrievalEnd-$retrievalStart)}else{''}
Assert ($retrievalBody.Contains('$InternalGoal.goal')) 'retrieval_does_not_consume_internal_goal'
Assert ($retrievalBody.Contains('$queryParts')) 'retrieval_query_parts_missing'
# Real topic-general reasoner probes, no memory recall to isolate topic propagation.
$qA='thermofade braking friction vehicle safety'
$qB='orchid transaction isolation phantom concurrency database'
$pA=Join-Path $runtimeRoot 'topic_a.json'
$pB=Join-Path $runtimeRoot 'topic_b.json'
$oA=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $reasoner -Problem $qA -DisableMemoryRecall -OutputPath $pA *>&1 | ForEach-Object {[string]$_})
$cA=$LASTEXITCODE
$oB=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $reasoner -Problem $qB -DisableMemoryRecall -OutputPath $pB *>&1 | ForEach-Object {[string]$_})
$cB=$LASTEXITCODE
Assert ($cA -eq 0) ('reasoner_a_exit:'+ $cA)
Assert ($cB -eq 0) ('reasoner_b_exit:'+ $cB)
$a=if(Test-Path $pA){Get-Content $pA -Raw|ConvertFrom-Json}else{$null}
$b=if(Test-Path $pB){Get-Content $pB -Raw|ConvertFrom-Json}else{$null}
Assert ($null -ne $a) 'reasoner_a_missing'
Assert ($null -ne $b) 'reasoner_b_missing'
if($a){ Assert ($a.classification -eq 'GENERAL_LOGIC_TASK') ('a_class:'+ $a.classification); Assert ($a.known[0].claim -eq ('Current reasoning topic: '+$qA)) 'a_topic_not_preserved'; Assert ($a.strongest_hypothesis.kind -eq 'source_gap') ('a_winner:'+ $a.strongest_hypothesis.kind) }
if($b){ Assert ($b.classification -eq 'GENERAL_LOGIC_TASK') ('b_class:'+ $b.classification); Assert ($b.known[0].claim -eq ('Current reasoning topic: '+$qB)) 'b_topic_not_preserved'; Assert ($b.strongest_hypothesis.kind -eq 'source_gap') ('b_winner:'+ $b.strongest_hypothesis.kind) }
if($a -and $b){ Assert ($a.strongest_hypothesis.text -ne $b.strongest_hypothesis.text) 'two_topics_collapsed' }
$memRoot='.runtime/active_compact_semantic_memory_v1'
$memoryHashes=[ordered]@{}
foreach($f in @('manifest.json','index.json','cells.jsonl')){ $memoryHashes[$f]=Sha (Join-Path $memRoot $f) }
$status=if($errors.Count -eq 0){'PASS_AIMO_ACTIVE_THOUGHT_GOAL_PROPAGATION_V1'}else{'FAIL_AIMO_ACTIVE_THOUGHT_GOAL_PROPAGATION_V1'}
$proof=[ordered]@{
 schema='aimo_active_thought_goal_propagation_v1_proof'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o');
 runner=$runner; reasoner=$reasoner;
 wiring=[ordered]@{owner_question_sets_internal_goal=$runnerText.Contains("$internalGoal['goal']=$Question"); owner_source_marker=$runnerText.Contains("$internalGoal['source']='OWNER_QUESTION_ACTIVE_GOAL'"); owner_goal_before_refocus_and_reasoning=($idxOwnerGoal -gt $idxOwner -and $idxRefocus -gt $idxOwnerGoal -and $idxLogic -gt $idxRefocus); refocus_requires_no_owner_question=$runnerText.Contains('$consumed=($hasSeed -and -not $OwnerQuestionProvided)'); mind_logic_consumes_internal_goal=$runnerText.Contains('$logicProblem=if($internalGoal -and $internalGoal.goal)'); retrieval_consumes_internal_goal=$retrievalBody.Contains('$InternalGoal.goal') };
 topic_a=[ordered]@{problem=$qA;classification=if($a){$a.classification}else{$null};known0=if($a){$a.known[0].claim}else{$null};winner=if($a){$a.strongest_hypothesis}else{$null}};
 topic_b=[ordered]@{problem=$qB;classification=if($b){$b.classification}else{$null};known0=if($b){$b.known[0].claim}else{$null};winner=if($b){$b.strongest_hypothesis}else{$null}};
 active_memory_hashes=$memoryHashes;
 claims_proven=@('Owner question is wired into internalGoal before refocus, mind-logic and selective-retrieval call sites.','Existing refocus seed consumption remains gated off when OwnerQuestionProvided is true.','The current topic-general reasoner preserves two unrelated supplied topics at the AIMO reasoner boundary.','Selective retrieval function consumes InternalGoal.goal as query input.');
 does_not_prove=@('Full AIMO wake/body-self-inspection runtime completes for these two topics.','Retrieval returns useful cells for arbitrary domain topics.','Learning atom is topic-aware.','Active memory is mutated or learning is durable.','LIVE behavior or runtime_ready.');
 boundary=[ordered]@{lab_wiring_only=$true;full_aimo_runtime_launched=$false;active_memory_mutated=$false;action_execution_allowed=$false;school_launched=$false;codex_launched=$false;web_launched=$false};
 errors=@($errors)
}
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Normalize $proofPath
Write-Host ('STATUS='+$status)
Write-Host ('OWNER_GOAL_WIRED='+$proof.wiring.owner_question_sets_internal_goal)
Write-Host ('REFOCUS_OWNER_GUARD='+$proof.wiring.refocus_requires_no_owner_question)
Write-Host ('RETRIEVAL_CONSUMES_GOAL='+$proof.wiring.retrieval_consumes_internal_goal)
Write-Host ('TOPIC_A_WINNER='+$proof.topic_a.winner.kind)
Write-Host ('TOPIC_B_WINNER='+$proof.topic_b.winner.kind)
if($errors.Count -gt 0){$errors|ForEach-Object{Write-Host ('ERROR='+$_)};exit 1}
