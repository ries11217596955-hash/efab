param(
  [string]$DecisionPath,
  [string]$ProofPath
)
$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message){ $script:errors.Add($Message) | Out-Null }
function Read-Json([string]$Path){ if(-not(Test-Path $Path)){ Add-Err "missing:$Path"; return $null }; try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { Add-Err "bad_json:$($Path):$($_.Exception.Message)"; return $null } }
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=20){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth $Depth
  $lines=@($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
  while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){$lines=@();break}; $lines=@($lines[0..($lines.Count-2)]) }
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $full=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($full,(($lines -join "`n") + "`n"),$utf8NoBom)
}
$runnerText=if(Test-Path 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'){ Get-Content 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Raw } else { Add-Err 'missing_runner'; '' }
foreach($needle in @('Invoke-MemoryAtomAcceptanceGate','invoke_memory_atom_acceptance_gate_v1.ps1','Invoke-AcceptedLearningAtomAbsorption','acceptance_gate')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$policy=Read-Json 'operations/autonomous_inner_motor/memory_atom_acceptance_gate_policy.json'
$schema=Read-Json 'operations/autonomous_inner_motor/memory_atom_acceptance_gate_schema.json'
if($null -ne $policy){
  foreach($d in @('ACCEPT','REWRITE_AS_EXPERIENCE_ATOM','REJECT_WITH_EXPLANATION','ESCALATE_TO_RULE_UPDATE')){ if(-not(@($policy.decisions) -contains $d)){ Add-Err "policy_missing_decision:$d" } }
  if(-not(@($policy.absorption_allowed_only_when) -contains 'decision_accept_or_rewrite')){ Add-Err 'policy_absorption_gate_missing' }
}
if($null -ne $schema){
  foreach($field in @('decision','reason','explanation','duplicate_rule_refs','delta','final_atom','absorption_allowed')){ if(-not(@($schema.required_fields) -contains $field)){ Add-Err "schema_missing:$field" } }
}
if([string]::IsNullOrWhiteSpace($ProofPath)){
  $latest=Get-ChildItem '.runtime/autonomous_inner_motor' -Filter 'SANDBOX_EXPLORATION_PROOF.json' -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($latest){ $ProofPath=$latest.FullName.Substring((Resolve-Path '.').Path.Length+1).Replace('\','/') }
}
$proof=$null
if(-not [string]::IsNullOrWhiteSpace($ProofPath)){ $proof=Read-Json $ProofPath }
if($proof -and $proof.deep_thinking.acceptance_gate){
  $gate=$proof.deep_thinking.acceptance_gate.decision
  if($gate.decision -notin @('ACCEPT','REWRITE_AS_EXPERIENCE_ATOM')){ Add-Err "proof_gate_decision_not_absorbable:$($gate.decision)" }
  if($gate.absorption_allowed -ne $true){ Add-Err 'proof_gate_absorption_not_allowed' }
  if([string]::IsNullOrWhiteSpace($gate.explanation)){ Add-Err 'proof_gate_explanation_missing' }
  if($gate.decision -eq 'REWRITE_AS_EXPERIENCE_ATOM'){
    if(@($gate.duplicate_rule_refs).Count -lt 1){ Add-Err 'rewrite_without_duplicate_rule_refs' }
    if($gate.final_atom.concept_key -ne 'aimo.memory_atom_acceptance_gate.delta_over_rule_duplicate'){ Add-Err "rewrite_final_atom_concept_bad:$($gate.final_atom.concept_key)" }
    if($gate.delta.local_experience -ne $true){ Add-Err 'rewrite_delta_local_experience_false' }
    if($proof.deep_thinking.absorption.atom_path -ne $proof.deep_thinking.acceptance_gate.final_atom_path){ Add-Err 'absorption_did_not_use_gate_final_atom' }
  }
} elseif(-not [string]::IsNullOrWhiteSpace($DecisionPath)){
  $decision=Read-Json $DecisionPath
  if($decision){
    if([string]::IsNullOrWhiteSpace($decision.explanation)){ Add-Err 'decision_explanation_missing' }
    if($decision.decision -eq 'REWRITE_AS_EXPERIENCE_ATOM' -and @($decision.duplicate_rule_refs).Count -lt 1){ Add-Err 'decision_rewrite_without_duplicate_refs' }
  }
} else {
  Add-Err 'no_proof_or_decision_to_validate'
}

# Negative case: a raw/generic rule duplicate with no run context must be rejected with explanation, not absorbed.
$negRoot='.runtime/autonomous_inner_motor_gate_validator'
New-Item -ItemType Directory -Force -Path $negRoot | Out-Null
$negCandidatePath=Join-Path $negRoot 'rule_duplicate_candidate.jsonl'
$negDecisionPath=Join-Path $negRoot 'rule_duplicate_decision.json'
$negFinalPath=Join-Path $negRoot 'rule_duplicate_final.jsonl'
$negCandidate=[ordered]@{
  schema='aimo_self_learning_atom_v1'
  candidate_id='negative_rule_duplicate_no_context'
  concept_key='aimo.deep_thinking.recursive_thought_frame.memory_learning'
  label='Agent must use ThoughtFrame recursive deep thinking'
  kind='rule_copy_candidate'
  definition='A thinking agent should not merely ask a linear list of questions. For each root question it must decompose into ThoughtFrames, answer atomic subquestions, synthesize back to parent, and use governed absorption.'
  summary='Generic restatement of AIMO deep-thinking rule with no local experience.'
  return_to_parent='Return to parent.'
  source_missing=$false
}
$utf8NoBom=New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $negCandidatePath), (($negCandidate | ConvertTo-Json -Depth 20 -Compress) + "`n"), $utf8NoBom)
$negOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/autonomous_inner_motor/invoke_memory_atom_acceptance_gate_v1.ps1' -CandidateAtomPath $negCandidatePath -OutputPath $negDecisionPath -FinalAtomPath $negFinalPath *>&1 | ForEach-Object { [string]$_ })
$negExit=$LASTEXITCODE
$negDecision=Read-Json $negDecisionPath
$negativeCase=[ordered]@{ exit_code=$negExit; decision=$null; absorption_allowed=$null; explanation=$null; output=@($negOut) }
if($negDecision){
  $negativeCase.decision=$negDecision.decision
  $negativeCase.absorption_allowed=$negDecision.absorption_allowed
  $negativeCase.explanation=$negDecision.explanation
  if($negDecision.decision -ne 'REJECT_WITH_EXPLANATION'){ Add-Err "negative_rule_duplicate_not_rejected:$($negDecision.decision)" }
  if($negDecision.absorption_allowed -ne $false){ Add-Err 'negative_rule_duplicate_absorption_allowed' }
  if([string]::IsNullOrWhiteSpace($negDecision.rejection_explanation)){ Add-Err 'negative_rule_duplicate_missing_rejection_explanation' }
  if(Test-Path $negFinalPath){ Add-Err 'negative_rule_duplicate_final_atom_created' }
} else {
  Add-Err 'negative_rule_duplicate_decision_missing'
}

$status=if($errors.Count -eq 0){'PASS_AUTONOMOUS_INNER_MOTOR_MEMORY_ATOM_ACCEPTANCE_GATE_V1'}else{'FAIL_AUTONOMOUS_INNER_MOTOR_MEMORY_ATOM_ACCEPTANCE_GATE_V1'}
$out=[ordered]@{
  schema='autonomous_inner_motor_memory_atom_acceptance_gate_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  proof_path=$ProofPath
  decision_path=$DecisionPath
  boundary=[ordered]@{ validates_explained_gate=$true; validates_no_rule_copy_absorption=$true; validates_rewrite_or_reject=$true }
  negative_case_rule_duplicate_without_context=$negativeCase
  errors=@($errors)
}
$proofOut='tests/self_development/AUTONOMOUS_INNER_MOTOR_MEMORY_ATOM_ACCEPTANCE_GATE_V1_PROOF.json'
Write-CleanJson $proofOut $out 30
Write-Host "STATUS=$status"
Write-Host "PROOF_OUT=$proofOut"
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }
