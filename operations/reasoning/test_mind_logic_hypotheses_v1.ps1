param(
  [string]$Problem='Owner correction: build agent mind and logic, not safety passports. What can the agent do if it does not know anything?',
  [int]$RelevantMemoryCount=0,
  [string]$OutputPath='.runtime/hypothesis_tester_v1/hypothesis_test_result.json',
  [ValidateSet('LabOnly')][string]$Mode='LabOnly'
)
$ErrorActionPreference='Stop'
function WJson($o,$p){ New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null; $o|ConvertTo-Json -Depth 100|Set-Content -Path $p -Encoding UTF8 }
function Terms([string]$s){ if([string]::IsNullOrWhiteSpace($s)){ return @() }; return @($s.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 3 } | Select-Object -Unique) }
function Has([string]$s,[string]$pattern){ return ($s -match $pattern) }
$lower=([string]$Problem).ToLowerInvariant()
$qTerms=@(Terms $Problem)
$legacySelfBuildTopic=(Has $lower 'aimo|agent mind|agent logic|mind logic|self-build|self development|cognitive operator|execution authority|safety passport|agent action') -or ((Has $lower 'memory recall') -and (Has $lower 'evidence') -and (Has $lower 'known|unknown') -and (Has $lower 'source|filter|relevance'))
$signals=New-Object System.Collections.Generic.List[string]
if(Has $lower 'aimo|agent mind|agent logic|mind logic|self-build|cognitive operator'){ $signals.Add('MIND_LOGIC_SIGNAL')|Out-Null }
if(Has $lower 'memory|recall|known|unknown|evidence|source'){ $signals.Add('EVIDENCE_MEMORY_SIGNAL')|Out-Null }
if(Has $lower 'passport|authority|execute|execution|hands|agent action'){ $signals.Add('PREMATURE_ACTION_SIGNAL')|Out-Null }
if(Has $lower 'correction|wrong|not safety|not passports|instead|stop'){ $signals.Add('CORRECTION_SIGNAL')|Out-Null }
if($RelevantMemoryCount -gt 0){ $signals.Add('RELEVANT_MEMORY_AVAILABLE')|Out-Null }else{ $signals.Add('RELEVANT_MEMORY_ABSENT')|Out-Null }
if($legacySelfBuildTopic){
  $hypotheses=@(
    [ordered]@{id='H1'; text='The best next improvement is to strengthen the mind logic pipeline, not execution or authority.'; kind='mind_logic'; expected_evidence=@('mind','logic','reasoning','correction'); risk='low'},
    [ordered]@{id='H2'; text='The best next improvement is memory-backed evidence selection before claims.'; kind='memory_evidence'; expected_evidence=@('memory','recall','evidence','known','unknown'); risk='medium'},
    [ordered]@{id='H3'; text='The best next improvement is execution authority or action capacity.'; kind='action_authority'; expected_evidence=@('action','execute','authority','hands'); risk='high'}
  )
}else{
  $hypotheses=@(
    [ordered]@{id='H_TOPIC_EVIDENCE'; text=('Relevant evidence can support a provisional synthesis for current topic: ' + $Problem); kind='topic_evidence'; expected_evidence=@($qTerms); risk='medium'},
    [ordered]@{id='H_SOURCE_GAP'; text=('Current topic needs verified evidence before a factual conclusion: ' + $Problem); kind='source_gap'; expected_evidence=@($qTerms); risk='low'},
    [ordered]@{id='H_TOPIC_DECOMPOSITION'; text=('Current topic may need decomposition into smaller discriminating questions: ' + $Problem); kind='topic_decomposition'; expected_evidence=@($qTerms); risk='low'}
  )
}
$evaluated=@()
foreach($h in $hypotheses){
  $hTerms=@(Terms ($h.text + ' ' + ($h.expected_evidence -join ' ')))
  $coverage=@($qTerms | Where-Object { $hTerms -contains $_ })
  $score=0
  $reasons=New-Object System.Collections.Generic.List[string]
  if($legacySelfBuildTopic){
    if($h.kind -eq 'mind_logic' -and $signals -contains 'MIND_LOGIC_SIGNAL'){ $score += 10; $reasons.Add('matches_mind_logic_signal')|Out-Null }
    if($h.kind -eq 'memory_evidence' -and $signals -contains 'EVIDENCE_MEMORY_SIGNAL'){ $score += 9; $reasons.Add('matches_memory_evidence_signal')|Out-Null }
    if($h.kind -eq 'action_authority' -and $signals -contains 'PREMATURE_ACTION_SIGNAL'){ $score += 3; $reasons.Add('action_signal_present_but_may_be_premature')|Out-Null }
    if($signals -contains 'CORRECTION_SIGNAL' -and $h.kind -eq 'mind_logic'){ $score += 6; $reasons.Add('owner_correction_supports_mind_logic')|Out-Null }
    if($signals -contains 'PREMATURE_ACTION_SIGNAL' -and $h.kind -eq 'action_authority'){ $score -= 8; $reasons.Add('penalized_as_premature_action_branch')|Out-Null }
  }else{
    if($h.kind -eq 'topic_evidence'){
      if($RelevantMemoryCount -gt 0){ $score += 14; $reasons.Add('relevant_memory_supports_topic_evidence')|Out-Null }else{ $score -= 6; $reasons.Add('no_relevant_memory_for_topic_evidence')|Out-Null }
    }
    if($h.kind -eq 'source_gap'){
      if($RelevantMemoryCount -eq 0){ $score += 14; $reasons.Add('no_relevant_memory_requires_source')|Out-Null }else{ $score += 1; $reasons.Add('source_gap_reduced_by_relevant_memory')|Out-Null }
    }
    if($h.kind -eq 'topic_decomposition'){
      if(@($qTerms).Count -ge 7){ $score += 5; $reasons.Add('complex_topic_supports_decomposition')|Out-Null }else{ $score += 2; $reasons.Add('decomposition_is_secondary')|Out-Null }
    }
  }
  $score += (@($coverage).Count * 2)
  if($h.risk -eq 'high'){ $score -= 3; $reasons.Add('high_risk')|Out-Null }
  elseif($h.risk -eq 'medium'){ $score -= 1; $reasons.Add('medium_risk')|Out-Null }
  $class=if($score -ge 12){'STRONG'}elseif($score -ge 6){'PLAUSIBLE'}else{'WEAK'}
  $evaluated += [pscustomobject][ordered]@{id=$h.id;text=$h.text;kind=$h.kind;score=$score;class=$class;coverage_terms=@($coverage);reasons=@($reasons);rejected=($class -eq 'WEAK')}
}
$ranked=@($evaluated | Sort-Object -Property @{Expression='score';Descending=$true},@{Expression='id';Descending=$false})
$winner=$ranked[0]
$rejected=@($ranked | Where-Object { $_.id -ne $winner.id })
$proofNeed=if($winner.kind -eq 'mind_logic'){'prove next mind operator or wiring improves reasoning frame'}elseif($winner.kind -eq 'memory_evidence'){'prove memory evidence is relevant and filtered'}elseif($winner.kind -eq 'topic_evidence'){'synthesize only the accepted topic-relevant evidence, then verify the resulting claim'}elseif($winner.kind -eq 'source_gap'){'acquire the smallest authoritative source that reduces the current topic uncertainty'}elseif($winner.kind -eq 'topic_decomposition'){'decompose the current topic without changing it, then test the highest-value subquestion'}else{'explicit proof required'}
$result=[ordered]@{
  schema='hypothesis_test_result_v1'; status='PASS_HYPOTHESIS_TESTER_V1'; created_at=(Get-Date).ToString('o'); mode=$Mode; problem=$Problem; hypothesis_mode=if($legacySelfBuildTopic){'LEGACY_SELF_BUILD'}else{'TOPIC_GENERAL'}; relevant_memory_count=$RelevantMemoryCount; signals=@($signals.ToArray()); evaluated_hypotheses=@($ranked); strongest_hypothesis=$winner; rejected_hypotheses=@($rejected); selection_rule='legacy self-build signals preserved; general topics select topic_evidence when relevant memory exists, otherwise source_gap; coverage and risk remain secondary'; proof_need=$proofNeed; boundary=[ordered]@{reasoning_only=$true; action_executed=$false; active_memory_mutated=$false; live_process_touched=$false; external_launch=$false}
}
WJson $result $OutputPath
Write-Host ('HYPOTHESIS_TEST_STATUS='+$result.status)
Write-Host ('HYPOTHESIS_WINNER='+$winner.id)
Write-Host ('HYPOTHESIS_WINNER_KIND='+$winner.kind)
Write-Host ('HYPOTHESIS_MODE='+$result.hypothesis_mode)
Write-Host ('HYPOTHESIS_TEST_PATH='+$OutputPath)
