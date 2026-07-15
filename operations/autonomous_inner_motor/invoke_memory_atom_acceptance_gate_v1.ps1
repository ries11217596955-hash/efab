param(
  [Parameter(Mandatory=$true)][string]$CandidateAtomPath,
  [string]$RunContextPath,
  [string]$OutputPath,
  [string]$FinalAtomPath
)
$ErrorActionPreference='Stop'
function Read-JsonAny([string]$Path){
  if(-not(Test-Path -LiteralPath $Path)){ throw "missing:$Path" }
  $raw=Get-Content -LiteralPath $Path -Raw
  $trim=$raw.Trim()
  if($trim.StartsWith('{')){ return ($trim | ConvertFrom-Json) }
  $first=($raw -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
  if(-not $first){ throw "empty_json:$Path" }
  return ($first | ConvertFrom-Json)
}
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
function Write-CleanJsonLine([string]$Path,$Obj){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth 40 -Compress
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $full=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($full,$json + "`n",$utf8NoBom)
}
function Get-FileTextSample([string]$Path){
  if(-not(Test-Path -LiteralPath $Path)){ return '' }
  return (Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue)
}
function Invoke-MemoryRecallLite([string]$Query){
  $result=[ordered]@{ query=$Query; status='NOT_RUN'; matches=@(); raw=@() }
  $script='operations/school/memory/query_compact_semantic_memory_v1.ps1'
  if(-not(Test-Path $script)){ $result.status='MISSING_QUERY_SCRIPT'; return $result }
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -Query $Query -Top 5 *>&1 | ForEach-Object { [string]$_ })
  $result.raw=@($out)
  $status=($out | Where-Object { $_ -match '^MEMORY_RECALL_STATUS=' } | Select-Object -Last 1) -replace '^MEMORY_RECALL_STATUS=',''
  if([string]::IsNullOrWhiteSpace($status)){ $status='UNKNOWN' }
  $result.status=$status
  foreach($line in $out){ if($line -like 'MATCH|*'){ $result.matches += $line } }
  return $result
}
$candidate=Read-JsonAny $CandidateAtomPath
$context=$null
if(-not [string]::IsNullOrWhiteSpace($RunContextPath) -and (Test-Path -LiteralPath $RunContextPath)){ $context=Read-JsonAny $RunContextPath }
if([string]::IsNullOrWhiteSpace($OutputPath)){ $OutputPath=(Join-Path (Split-Path $CandidateAtomPath -Parent) 'memory_atom_acceptance_gate_decision.json') }
if([string]::IsNullOrWhiteSpace($FinalAtomPath)){ $FinalAtomPath=(Join-Path (Split-Path $CandidateAtomPath -Parent) 'learning_atom.accepted.jsonl') }
$gatePolicy=Read-JsonAny 'operations/autonomous_inner_motor/memory_atom_acceptance_gate_policy.json'
$definition=[string]$candidate.definition
$summary=[string]$candidate.summary
$label=[string]$candidate.label
$combined=($definition + ' ' + $summary + ' ' + $label).ToLowerInvariant()
$contractRefs=@(
  'operations/autonomous_inner_motor/AUTONOMOUS_INNER_MOTOR_ORGAN_SPEC.md',
  'operations/autonomous_inner_motor/deep_thinking_policy.json',
  'operations/autonomous_inner_motor/thought_frame_schema.json',
  'validators/validate_autonomous_inner_motor_deep_thinking_memory_learning_v1.ps1'
)
$duplicateRuleRefs=@()
foreach($p in $contractRefs){
  $txt=(Get-FileTextSample $p).ToLowerInvariant()
  if($txt.Length -gt 0){
    $score=0
    foreach($term in @('thoughtframe','return-to-parent','return_to_parent','governed absorption','memory atom','deep thinking','recursive')){
      if($combined -like "*$term*" -and $txt -like "*$term*"){ $score++ }
    }
    if($score -ge 3){ $duplicateRuleRefs += [ordered]@{ path=$p; overlap_score=$score; reason='candidate repeats existing AIMO thinking law / validator / policy vocabulary' } }
  }
}
$recall=Invoke-MemoryRecallLite (($candidate.concept_key + ' ' + $candidate.label) -replace '\s+',' ')
$duplicateMemoryRefs=@()
foreach($m in @($recall.matches)){ $duplicateMemoryRefs += [ordered]@{ raw=$m; reason='existing compact memory recall match for same or near-same concept' } }
$genericRuleLike=($combined -like '*should not merely ask*' -or $combined -like '*must decompose*' -or $combined -like '*for each root question*')
$hasLocalExperience=($combined -like '*during*' -or $combined -like '*validator*' -or $combined -like '*repair*' -or $combined -like '*gate*' -or $combined -like '*detected*')
$delta=[ordered]@{
  discovered_in_run=$false
  evidence_backed=$false
  local_experience=$false
  transferable=$false
  actionable_next_cycle=$false
}
if($context){
  $delta.discovered_in_run=$true
  $delta.evidence_backed=$true
}
if($hasLocalExperience){ $delta.local_experience=$true }
if($combined -like '*future reasoning*' -or $combined -like '*next cycle*' -or $combined -like '*self-build*' -or $combined -like '*self build*'){ $delta.transferable=$true; $delta.actionable_next_cycle=$true }
$decision='ACCEPT'
$reason='candidate_contains_delta_and_is_not_a_rule_duplicate'
$explanation='The candidate has enough local experience and does not appear to be only a copied rule.'
$rejection=''
$finalAtom=$candidate
if($genericRuleLike -or @($duplicateRuleRefs).Count -gt 0){
  if($context){
    $decision='REWRITE_AS_EXPERIENCE_ATOM'
    $reason='candidate_too_close_to_existing_rule_but_run_has_experience_delta'
    $explanation='The candidate repeats existing AIMO deep-thinking rules. It is rewritten into an experience atom about this run: the gate detected rule-duplication risk before absorption and converted the candidate into a DELTA-backed operational lesson.'
    $runId=[string]$context.run_id
    if([string]::IsNullOrWhiteSpace($runId)){ $runId='unknown_run' }
    $frames=0; $missingReturn='unknown'; $recalls=0
    try { $frames=@($context.frames).Count } catch {}
    try { $missingReturn=@($context.frames | Where-Object { $_.id -ne 'root' -and [string]::IsNullOrWhiteSpace($_.return_to_parent) }).Count } catch {}
    try { $recalls=@($context.memory_recalls).Count } catch {}
    $finalAtom=[ordered]@{
      schema='aimo_self_learning_atom_v1'
      candidate_id=('aimo_memory_atom_gate_experience_'+$runId)
      concept_key='aimo.memory_atom_acceptance_gate.delta_over_rule_duplicate'
      label='AIMO memory atom gate rewrites rule-like candidates into DELTA experience atoms'
      kind='memory_acceptance_repair_pattern'
      definition="During AIMO run $runId, the pre-absorption gate detected that the proposed learning atom was too close to existing deep-thinking policy/validator language. The gate did not silently reject it; it rewrote the candidate into a DELTA-backed experience atom. Reusable lesson: compact memory should store local, evidence-backed learning from a run, not raw copies of settings, contracts, or validators."
      summary="AIMO memory atom acceptance gate prevents rule-copy memory pollution by explaining duplicate-rule risk and rewriting useful generic candidates into evidence-backed experience atoms before governed absorption."
      aliases=@('memory_atom_acceptance_gate_v1','delta_over_rule_duplicate','rewrite_as_experience_atom','no_rule_copy_memory_pollution')
      properties=@("decision=$decision","run_id=$runId","frames=$frames","missing_return_to_parent=$missingReturn","memory_recalls=$recalls","direct_active_memory_write=false")
      relations=@('protects:active_compact_memory','uses:DELTA_test','precedes:governed_absorption','supports:self_build_thinking')
      uses=@('Before absorbing any AIMO learning atom, check whether it merely repeats settings/contracts/validators. If so, reject with explanation or rewrite into a local experience atom that records the specific run evidence and repair pattern.')
      proof_requirements=@('gate_decision_present','duplicate_rule_refs_or_delta_report_present','final_atom_differs_from_candidate_when_rewritten','absorption_allowed_only_for_ACCEPT_or_REWRITE')
      negative_case='Reject if the candidate is a raw rule copy with no run-specific observation, repair, contradiction, recall result, or future-use delta.'
      return_to_parent='Return to Builder self-build path by keeping compact memory as active learned experience, not a duplicate law archive.'
      source_basis=@('Owner correction: rules already in validators/settings should not be blindly stored as atoms','AIMO acceptance gate decision','AIMO deep-thinking run context')
      source_missing=$false
      quality_flags=@('delta_backed','explained_gate_decision','anti_rule_duplicate','governed_absorption','return_to_parent')
    }
    $delta.discovered_in_run=$true
    $delta.evidence_backed=$true
    $delta.local_experience=$true
    $delta.transferable=$true
    $delta.actionable_next_cycle=$true
  } else {
    $decision='REJECT_WITH_EXPLANATION'
    $reason='candidate_is_rule_duplicate_without_context_delta'
    $explanation='The candidate repeats an existing rule/policy/validator but no run context was provided to rewrite it as an experience atom.'
    $rejection='Not absorbed: memory atoms require DELTA, not a copied rule.'
  }
}
$absorptionAllowed=($decision -eq 'ACCEPT' -or $decision -eq 'REWRITE_AS_EXPERIENCE_ATOM')
$decisionObj=[ordered]@{
  schema='aimo_memory_atom_acceptance_gate_decision_v1'
  decision=$decision
  reason=$reason
  explanation=$explanation
  candidate_atom_path=$CandidateAtomPath
  final_atom_path=if($absorptionAllowed){$FinalAtomPath}else{$null}
  duplicate_rule_refs=@($duplicateRuleRefs)
  duplicate_memory_refs=@($duplicateMemoryRefs)
  delta=$delta
  final_atom=if($absorptionAllowed){$finalAtom}else{$null}
  rejection_explanation=$rejection
  absorption_allowed=$absorptionAllowed
  policy_snapshot=[ordered]@{ decisions=$gatePolicy.decisions; delta_test=$gatePolicy.delta_test }
}
Write-CleanJson $OutputPath $decisionObj 60
if($absorptionAllowed){ Write-CleanJsonLine $FinalAtomPath $finalAtom }
Write-Host "MEMORY_ATOM_GATE_DECISION=$decision"
Write-Host "ABSORPTION_ALLOWED=$absorptionAllowed"
Write-Host "GATE_DECISION_PATH=$OutputPath"
if($absorptionAllowed){ Write-Host "FINAL_ATOM_PATH=$FinalAtomPath" }
Write-Host "EXPLANATION=$explanation"
if(-not $absorptionAllowed){ exit 2 }
