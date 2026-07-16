param(
  [string]$Problem='Owner correction: build agent mind and logic, not safety passports. What can the agent do if it does not know anything?',
  [string]$OutputPath='.runtime/hypothesis_tester_v1/hypothesis_test_result.json',
  [ValidateSet('LabOnly')][string]$Mode='LabOnly'
)
$ErrorActionPreference='Stop'
function WJson($o,$p){ New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null; $o|ConvertTo-Json -Depth 100|Set-Content -Path $p -Encoding UTF8 }
function Terms([string]$s){ if([string]::IsNullOrWhiteSpace($s)){ return @() }; return @($s.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 3 } | Select-Object -Unique) }
function Has([string]$s,[string]$pattern){ return ($s -match $pattern) }
$lower=([string]$Problem).ToLowerInvariant()
$qTerms=@(Terms $Problem)
$signals=New-Object System.Collections.Generic.List[string]
if(Has $lower 'logic|mind|thinking|reasoning|agent mind|agent logic'){ $signals.Add('MIND_LOGIC_SIGNAL')|Out-Null }
if(Has $lower 'memory|recall|known|unknown|evidence|source'){ $signals.Add('EVIDENCE_MEMORY_SIGNAL')|Out-Null }
if(Has $lower 'safety|passport|authority|action|execute|hands'){ $signals.Add('PREMATURE_ACTION_SIGNAL')|Out-Null }
if(Has $lower 'correction|wrong|not safety|not passports|instead|stop'){ $signals.Add('CORRECTION_SIGNAL')|Out-Null }
$hypotheses=@(
  [ordered]@{id='H1'; text='The best next improvement is to strengthen the mind logic pipeline, not execution or authority.'; kind='mind_logic'; expected_evidence=@('mind','logic','reasoning','correction'); risk='low'},
  [ordered]@{id='H2'; text='The best next improvement is memory-backed evidence selection before claims.'; kind='memory_evidence'; expected_evidence=@('memory','recall','evidence','known','unknown'); risk='medium'},
  [ordered]@{id='H3'; text='The best next improvement is execution authority or action capacity.'; kind='action_authority'; expected_evidence=@('action','execute','authority','hands'); risk='high'}
)
$evaluated=@()
foreach($h in $hypotheses){
  $hTerms=@(Terms ($h.text + ' ' + ($h.expected_evidence -join ' ')))
  $coverage=@($qTerms | Where-Object { $hTerms -contains $_ })
  $score=0
  $reasons=New-Object System.Collections.Generic.List[string]
  if($h.kind -eq 'mind_logic' -and $signals -contains 'MIND_LOGIC_SIGNAL'){ $score += 10; $reasons.Add('matches_mind_logic_signal')|Out-Null }
  if($h.kind -eq 'memory_evidence' -and $signals -contains 'EVIDENCE_MEMORY_SIGNAL'){ $score += 9; $reasons.Add('matches_memory_evidence_signal')|Out-Null }
  if($h.kind -eq 'action_authority' -and $signals -contains 'PREMATURE_ACTION_SIGNAL'){ $score += 3; $reasons.Add('action_signal_present_but_may_be_premature')|Out-Null }
  if($signals -contains 'CORRECTION_SIGNAL' -and $h.kind -eq 'mind_logic'){ $score += 6; $reasons.Add('owner_correction_supports_mind_logic')|Out-Null }
  if($signals -contains 'PREMATURE_ACTION_SIGNAL' -and $h.kind -eq 'action_authority'){ $score -= 8; $reasons.Add('penalized_as_premature_action_branch')|Out-Null }
  $score += (@($coverage).Count * 2)
  if($h.risk -eq 'high'){ $score -= 3; $reasons.Add('high_risk')|Out-Null }
  elseif($h.risk -eq 'medium'){ $score -= 1; $reasons.Add('medium_risk')|Out-Null }
  $class=if($score -ge 12){'STRONG'}elseif($score -ge 6){'PLAUSIBLE'}else{'WEAK'}
  $evaluated += [pscustomobject][ordered]@{
    id=$h.id
    text=$h.text
    kind=$h.kind
    score=$score
    class=$class
    coverage_terms=@($coverage)
    reasons=@($reasons)
    rejected=($class -eq 'WEAK')
  }
}
$ranked=@($evaluated | Sort-Object -Property @{Expression='score';Descending=$true},@{Expression='id';Descending=$false})
$winner=$ranked[0]
$rejected=@($ranked | Where-Object { $_.id -ne $winner.id })
$result=[ordered]@{
  schema='hypothesis_test_result_v1'
  status='PASS_HYPOTHESIS_TESTER_V1'
  created_at=(Get-Date).ToString('o')
  mode=$Mode
  problem=$Problem
  signals=@($signals.ToArray())
  evaluated_hypotheses=@($ranked)
  strongest_hypothesis=$winner
  rejected_hypotheses=@($rejected)
  selection_rule='highest score after evidence/signal/coverage/risk penalties; premature action branch penalized'
  proof_need=if($winner.kind -eq 'mind_logic'){'prove next mind operator or wiring improves reasoning frame'}elseif($winner.kind -eq 'memory_evidence'){'prove memory evidence is relevant and filtered'}else{'explicit Owner authority and execution validator required'}
  boundary=[ordered]@{reasoning_only=$true; action_executed=$false; active_memory_mutated=$false; live_process_touched=$false; external_launch=$false}
}
WJson $result $OutputPath
Write-Host ('HYPOTHESIS_TEST_STATUS='+$result.status)
Write-Host ('HYPOTHESIS_WINNER='+$winner.id)
Write-Host ('HYPOTHESIS_WINNER_KIND='+$winner.kind)
Write-Host ('HYPOTHESIS_TEST_PATH='+$OutputPath)
