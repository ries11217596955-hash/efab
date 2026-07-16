param(
  [string]$Problem='Owner correction: build agent mind and logic, not safety passports. What can the agent do if it does not know anything?',
  [string]$OutputPath='.runtime/contradiction_resolver_v1/resolution.json',
  [ValidateSet('LabOnly')][string]$Mode='LabOnly'
)
$ErrorActionPreference='Stop'
function WJson($o,$p){ New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null; $o|ConvertTo-Json -Depth 80|Set-Content -Path $p -Encoding UTF8 }
function Has([string]$s,[string]$pattern){ return ($s -match $pattern) }
$lower=([string]$Problem).ToLowerInvariant()
$signals=New-Object System.Collections.Generic.List[string]
if(Has $lower 'logic|mind|thinking|reasoning|agent mind|agent logic'){ $signals.Add('MIND_LOGIC_BRANCH')|Out-Null }
if(Has $lower 'safety|passport|authority|permission|gate|execution authority'){ $signals.Add('SAFETY_AUTHORITY_BRANCH')|Out-Null }
if(Has $lower 'doesn.?t know|does not know|knows nothing|no evidence|no knowledge|no_evidence|no_knowledge|nothing'){ $signals.Add('KNOWLEDGE_GAP')|Out-Null }
if(Has $lower 'correction|wrong|not that|stop|instead|not safety|not passports'){ $signals.Add('OWNER_CORRECTION')|Out-Null }
if(Has $lower 'action|execute|can do|capability|hands'){ $signals.Add('ACTION_BRANCH')|Out-Null }
$contradictions=@()
if(($signals -contains 'MIND_LOGIC_BRANCH') -and ($signals -contains 'SAFETY_AUTHORITY_BRANCH')){
  $contradictions += [ordered]@{id='MIND_VS_SAFETY_BRANCH'; severity='HIGH'; losing_branch='SAFETY_AUTHORITY_BRANCH'; winning_branch='MIND_LOGIC_BRANCH'; statement='Current work risks drifting into passports/authority while Owner asked for agent mind/logic.'}
}
if(($signals -contains 'KNOWLEDGE_GAP') -and (($signals -contains 'ACTION_BRANCH') -or ($signals -contains 'SAFETY_AUTHORITY_BRANCH'))){
  $contradictions += [ordered]@{id='KNOWLEDGE_BEFORE_ACTION'; severity='HIGH'; losing_branch='ACTION_OR_AUTHORITY_BRANCH'; winning_branch='KNOWLEDGE_LOGIC_BRANCH'; statement='Action/authority is premature when the agent cannot separate known from unknown.'}
}
if(@($contradictions).Count -eq 0){
  $contradictions += [ordered]@{id='NO_MAJOR_CONTRADICTION'; severity='LOW'; losing_branch='NONE'; winning_branch='CURRENT_LOGIC_BRANCH'; statement='No high-severity branch conflict detected; continue reducing the largest unknown.'}
}
$branchCuts=@()
$preserve=@()
$proofNeeds=@()
foreach($c in $contradictions){
  if($c.losing_branch -ne 'NONE'){
    $branchCuts += [ordered]@{branch=$c.losing_branch; reason=$c.statement; cut_type='STOP_EXPANDING_THIS_BRANCH_NOW'}
  }
  $preserve += [ordered]@{branch=$c.winning_branch; reason='branch directly reduces the dominant contradiction or unknown'; preserve_type='CONTINUE'}
  if($c.id -eq 'MIND_VS_SAFETY_BRANCH'){
    $proofNeeds += [ordered]@{proof_id='PROVE_MIND_LOGIC_OPERATOR'; need='Show a cognitive operation that classifies mismatch and chooses a logic step, not a safety document.'; validator='validators/validate_agent_mind_logic_kernel_v1.ps1'}
  } elseif($c.id -eq 'KNOWLEDGE_BEFORE_ACTION'){
    $proofNeeds += [ordered]@{proof_id='PROVE_KNOWN_UNKNOWN_SOURCE_SELECTION'; need='Show no-evidence task selects memory/source recall before action.'; validator='validators/validate_agent_mind_logic_kernel_v1.ps1'}
  } else {
    $proofNeeds += [ordered]@{proof_id='PROVE_NEXT_UNKNOWN_REDUCTION'; need='Show selected next step reduces the largest unknown.'; validator='mind_logic_frame validator'}
  }
}
$decision='CONTINUE_CURRENT_LOGIC_BRANCH'
if(@($branchCuts).Count -gt 0){ $decision='CUT_LOSING_BRANCH_AND_CONTINUE_WINNING_BRANCH' }
$nextStep=if(($signals -contains 'KNOWLEDGE_GAP')){
  [ordered]@{step_id='RESOLVE_BY_SOURCE_OR_MEMORY_BEFORE_ACTION'; reason='knowledge gap has higher priority than action/authority'; proof_needed='memory/source evidence or explicit unknown list'}
}elseif(($signals -contains 'OWNER_CORRECTION') -or ($signals -contains 'MIND_LOGIC_BRANCH')){
  [ordered]@{step_id='RESOLVE_BY_MIND_LOGIC_OPERATOR'; reason='Owner correction requires cutting wrong branch and building cognitive operator'; proof_needed='logic frame with contradiction resolution'}
}else{
  [ordered]@{step_id='RESOLVE_BY_LARGEST_UNKNOWN'; reason='no high conflict; continue reducing largest unknown'; proof_needed='unknown reduction proof'}
}
$result=[ordered]@{
  schema='contradiction_resolution_v1'
  status='PASS_CONTRADICTION_RESOLUTION_V1'
  created_at=(Get-Date).ToString('o')
  mode=$Mode
  problem=$Problem
  signals=@($signals.ToArray())
  contradictions=@($contradictions)
  decision=$decision
  cut_branches=@($branchCuts)
  preserve_branches=@($preserve)
  proof_needs=@($proofNeeds)
  selected_resolution_step=$nextStep
  boundary=[ordered]@{reasoning_only=$true; action_executed=$false; active_memory_mutated=$false; live_process_touched=$false; external_launch=$false}
}
WJson $result $OutputPath
Write-Host ('CONTRADICTION_RESOLUTION_STATUS='+$result.status)
Write-Host ('CONTRADICTION_RESOLUTION_DECISION='+$result.decision)
Write-Host ('CONTRADICTION_RESOLUTION_NEXT_STEP='+$result.selected_resolution_step.step_id)
Write-Host ('CONTRADICTION_RESOLUTION_PATH='+$OutputPath)
