param(
  [Parameter(Mandatory=$true)][string]$TaskJsonPath,
  [Parameter(Mandatory=$true)][string]$CandidatesJsonlPath,
  [Parameter(Mandatory=$true)][string]$OutputAtomsJsonlPath,
  [string]$ReportPath = ''
)
$ErrorActionPreference='Stop'
$repoRoot=(Resolve-Path ((git rev-parse --show-toplevel).Trim())).Path; Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function GetProp($obj,$name){ if($obj.PSObject.Properties[$name]){ return $obj.PSObject.Properties[$name].Value }; return $null }
function Sha256Text([string]$Text){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{ $bytes=[Text.Encoding]::UTF8.GetBytes([string]$Text); return (($sha.ComputeHash($bytes)|ForEach-Object{$_.ToString('x2')}) -join '') } finally { $sha.Dispose() }
}
function NormalizeKnowledgeClaim([string]$Text){ return ((([string]$Text).ToLowerInvariant() -replace '\s+',' ').Trim()) }
function NormalizeKnowledgeTemplate([string]$Text){
  $x=NormalizeKnowledgeClaim $Text
  $x=[regex]::Replace($x,'`[^`]+`','`X`')
  $x=[regex]::Replace($x,'"[^"]+"','"X"')
  $x=[regex]::Replace($x,"'[^']+'","'X'")
  $x=[regex]::Replace($x,'\b[0-9]+\b','#')
  $x=[regex]::Replace($x,'\b[a-f0-9]{8,64}\b','HASH')
  return $x
}
function IsSourceDocumentTrivia([string]$Claim){
  $x=NormalizeKnowledgeClaim $Claim
  if($x -match '\bline #?\d*\b' -and $x -match '\b(word tokens|characters|starts with token|ends with token|classified as|heading depth|bullet entry|ordered-list entry|fenced-code delimiter|belongs to .* section)\b'){ return $true }
  if($x -match '\b(parsed word tokens|non-newline characters|heading depth|code-fence content|paragraph content|lead-in content|bullet content|numbered-list content)\b'){ return $true }
  return $false
}
function Test-KnowledgeSourceRef([string]$Ref){
  $x=([string]$Ref).Trim()
  if([string]::IsNullOrWhiteSpace($x)){ return $false }
  if($x -match '^https://[^\s]+$'){ return $true }
  try{
    $candidate=if([IO.Path]::IsPathRooted($x)){$x}else{Join-Path $repoRoot $x}
    if(-not(Test-Path -LiteralPath $candidate -PathType Leaf)){ return $false }
    $resolved=(Resolve-Path -LiteralPath $candidate).Path
    return $resolved.StartsWith($repoRoot,[StringComparison]::OrdinalIgnoreCase)
  }catch{ return $false }
}
if(-not (Test-Path $TaskJsonPath)){ throw "TASK_JSON_MISSING:$TaskJsonPath" }
if(-not (Test-Path $CandidatesJsonlPath)){ throw "CANDIDATES_JSONL_MISSING:$CandidatesJsonlPath" }
$task=Get-Content $TaskJsonPath -Raw | ConvertFrom-Json
$required=@($task.required_candidate_fields)
if($required.Count -lt 10){ throw 'TASK_REQUIRED_FIELDS_TOO_THIN' }
$topic=[string]$task.topic_key
if(([string]$topic).Trim().ToLowerInvariant() -in @('default','generic','placeholder','unknown_topic')){ throw ('GENERIC_TOPIC_NOT_ADMISSIBLE:'+ $topic) }
$targetDepth=[int]$task.target_depth
$startDepth=[int]$task.start_depth
$expectedCount=[int]$task.candidate_limit
$accepted=New-Object System.Collections.ArrayList
$rejected=New-Object System.Collections.ArrayList
$lineNo=0
$seen=@{}
$seenClaims=@{}
foreach($line in Get-Content $CandidatesJsonlPath){
  if([string]::IsNullOrWhiteSpace($line)){ continue }
  $lineNo++
  $fail=New-Object System.Collections.ArrayList
  try{ $obj=$line | ConvertFrom-Json }catch{ [void]$rejected.Add([pscustomobject]@{line=$lineNo; reason='invalid_json'; error=$_.Exception.Message}); continue }
  foreach($f in $required){
    $v=GetProp $obj $f
    if($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)){ [void]$fail.Add("missing_or_empty:$f") }
  }
  if([string](GetProp $obj 'topic_key') -ne $topic){ [void]$fail.Add('topic_key_mismatch') }
  $depth=0
  [void][int]::TryParse([string](GetProp $obj 'depth_level'),[ref]$depth)
  if($depth -lt $startDepth -or $depth -gt $targetDepth){ [void]$fail.Add('depth_out_of_range') }
  $cid=[string](GetProp $obj 'candidate_id')
  if([string]::IsNullOrWhiteSpace($cid)){ $cid="line_$lineNo" }
  if($seen.ContainsKey($cid)){ [void]$fail.Add('duplicate_candidate_id') } else { $seen[$cid]=$true }
  $sourceBasis=GetProp $obj 'source_basis'
  $sourceMissing=GetProp $obj 'source_missing'
  $sourceRefs=@($sourceBasis)
  $hasSource=($sourceRefs.Count -gt 0 -and @($sourceRefs|Where-Object{-not[string]::IsNullOrWhiteSpace([string]$_)}).Count -gt 0)
  $sourceMissingBool=(([string]$sourceMissing).ToLowerInvariant() -eq 'true')
  if(-not $hasSource){ [void]$fail.Add('grounded_source_basis_required') }
  elseif(@($sourceRefs|Where-Object{-not(Test-KnowledgeSourceRef ([string]$_))}).Count -gt 0){ [void]$fail.Add('unresolvable_source_basis') }
  if(@($sourceRefs|Where-Object{ ([IO.Path]::GetFileName(([string]$_).Trim())).ToLowerInvariant() -eq 'agents.md' }).Count -gt 0){ [void]$fail.Add('execution_contract_not_school_knowledge_source') }
  if($sourceMissingBool){ [void]$fail.Add('source_missing_not_admissible_for_knowledge') }
  $schema=[string](GetProp $obj 'schema')
  if($schema -ne 'codex_school_knowledge_candidate_v1'){ [void]$fail.Add('knowledge_schema_required') }
  $knowledgeKind=([string](GetProp $obj 'knowledge_kind')).ToLowerInvariant()
  if($knowledgeKind -notin @('fact','observation','relation','mechanism','constraint','rule')){ [void]$fail.Add('knowledge_kind_not_allowed') }
  $claim=[string](GetProp $obj 'claim')
  $evidenceStatement=[string](GetProp $obj 'evidence_statement')
  if([string]::IsNullOrWhiteSpace($claim)){ [void]$fail.Add('knowledge_claim_empty') }
  if([string]::IsNullOrWhiteSpace($evidenceStatement)){ [void]$fail.Add('evidence_statement_empty') }
  $claimNorm=NormalizeKnowledgeClaim $claim
  if(IsSourceDocumentTrivia $claim){ [void]$fail.Add('source_document_metadata_not_knowledge') }
  $imperativePattern='^(add|tighten|verify|enforce|ensure|require|prevent|preserve|reject|validate|bound|route|keep|make|limit|guard|detect|prove|create|implement|update|change|fix|write|investigate|collect|gather|decide|choose|assess|compare|identify|determine|find)\b'
  $ambiguousImperativePattern='^(use|test|run|record|build)\s+(the|a|an|this|that|these|those|one|each|all|new|current|existing)\b'
  $instructionPattern='\b(next step|task is to|goal is to|patch proposal|action proposal|we should|you should|we need to|you need to)\b'
  if($claimNorm -match $imperativePattern -or $claimNorm -match $ambiguousImperativePattern -or $claimNorm -match $instructionPattern){ [void]$fail.Add('claim_is_task_or_instruction_not_knowledge') }
  if($seenClaims.ContainsKey($claimNorm)){ [void]$fail.Add('duplicate_knowledge_claim') }
  foreach($f in @('expected_behavior','validator','proof_requirements','negative_case','return_to_parent','digest_hint')){
    if([string]::IsNullOrWhiteSpace([string](GetProp $obj $f))){ [void]$fail.Add("quality_field_empty:$f") }
  }
  if($fail.Count -gt 0){
    [void]$rejected.Add([pscustomobject]@{line=$lineNo; candidate_id=$cid; failures=@($fail)})
    continue
  }
  if(-not [string]::IsNullOrWhiteSpace($claimNorm)){ $seenClaims[$claimNorm]=$true }
  $claimHash=Sha256Text $claimNorm
  $conceptKey=((($topic -replace '[^A-Za-z0-9_\-]','_').ToLowerInvariant()) + '-' + $claimHash.Substring(0,16))
  $labelText=([string](GetProp $obj 'topic_label')).Trim()
  if($claim.Length -le 120){ $labelText=($labelText+': '+$claim) }
  $properties=New-Object System.Collections.Generic.List[string]
  [void]$properties.Add('knowledge_kind='+$knowledgeKind)
  [void]$properties.Add('evidence_statement='+$evidenceStatement)
  foreach($src in @($sourceBasis)){ if(-not [string]::IsNullOrWhiteSpace([string]$src)){ [void]$properties.Add('source_basis='+[string]$src) } }
  $atom=[pscustomobject]@{
    atom_id=('codex.school.knowledge.atom.'+$claimHash.Substring(0,24)+'.v1')
    candidate_id=$cid
    topic=$topic
    concept_key=$conceptKey
    label=$labelText
    kind=$knowledgeKind
    level=$depth
    source_mode='codex_school_knowledge'
    source_basis=$sourceBasis
    source_missing=$false
    objective=$claim
    definition=$claim
    summary=$claim
    properties=@($properties.ToArray())
    relations=@()
    uses=@()
    evidence_statement=$evidenceStatement
    expected_behavior=[string](GetProp $obj 'expected_behavior')
    validator_hint=[string](GetProp $obj 'validator')
    proof_requirements=[string](GetProp $obj 'proof_requirements')
    negative_trap=[string](GetProp $obj 'negative_case')
    failure_contrast=[string](GetProp $obj 'failure_contrast')
    return_to_parent=[string](GetProp $obj 'return_to_parent')
    digest_hint=[string](GetProp $obj 'digest_hint')
    duplicate_key=($topic+'|'+$claimHash)
    theme_key=$topic
    learning_key=($topic+'.knowledge.'+$claimHash.Substring(0,16))
    prerequisite_key=($topic+'.depth.'+[Math]::Max(0,$depth-1))
    behavior_use_proof_target=[string](GetProp $obj 'proof_requirements')
  }
  [void]$accepted.Add($atom)
}
if([string]::IsNullOrWhiteSpace($ReportPath)){ $ReportPath=(Join-Path (Split-Path -Parent $OutputAtomsJsonlPath) 'codex_candidate_normalization_report.json') }
$batchFailures=New-Object System.Collections.Generic.List[string]
$templateCounts=@{}
foreach($a in @($accepted)){
  $template=NormalizeKnowledgeTemplate ([string]$a.summary)
  if(-not $templateCounts.ContainsKey($template)){ $templateCounts[$template]=0 }
  $templateCounts[$template]=[int]$templateCounts[$template]+1
}
$templateUnique=$templateCounts.Count
$templateMaxRepeat=if($templateCounts.Count -gt 0){ [int](($templateCounts.Values|Measure-Object -Maximum).Maximum) }else{0}
$templateUniqueRatio=if($accepted.Count -gt 0){ [math]::Round(($templateUnique/[double]$accepted.Count),4) }else{0}
if($accepted.Count -ge 20){
  if($templateUniqueRatio -lt 0.25){ [void]$batchFailures.Add(('template_diversity_ratio_too_low:{0}' -f $templateUniqueRatio)) }
  if($templateMaxRepeat -gt [math]::Max(10,[math]::Ceiling($accepted.Count*0.10))){ [void]$batchFailures.Add(('template_repeat_too_high:{0}' -f $templateMaxRepeat)) }
}
$normalizationPassed=($accepted.Count -eq $expectedCount -and $accepted.Count -gt 0 -and $batchFailures.Count -eq 0)
$report=[ordered]@{
  schema='codex_school_knowledge_candidate_normalization_v1'
  status=if($normalizationPassed){'PASS_CODEX_SCHOOL_KNOWLEDGE_CANDIDATE_NORMALIZATION_V1'}else{'FAIL_CODEX_SCHOOL_KNOWLEDGE_CANDIDATE_NORMALIZATION_V1'}
  created_at=(Get-Date).ToString('o')
  task_json=$TaskJsonPath
  candidates_jsonl=$CandidatesJsonlPath
  output_atoms_jsonl=$OutputAtomsJsonlPath
  topic_key=$topic
  expected_candidate_count=$expectedCount
  accepted_count=$accepted.Count
  rejected_count=$rejected.Count
  rejected=@($rejected | Select-Object -First 20)
  batch_failures=@($batchFailures)
  template_unique_count=$templateUnique
  template_unique_ratio=$templateUniqueRatio
  template_max_repeat=$templateMaxRepeat
  memory_mutated=$false
}
WriteJson $ReportPath $report 80
Write-Host "CODEX_CANDIDATE_NORMALIZATION_STATUS=$($report.status)"
Write-Host "CODEX_CANDIDATE_NORMALIZATION_REPORT=$ReportPath"
Write-Host "CODEX_CANDIDATE_ACCEPTED_COUNT=$($accepted.Count)"
Write-Host "CODEX_CANDIDATE_REJECTED_COUNT=$($rejected.Count)"
if($accepted.Count -lt 1){ throw 'NO_ACCEPTED_CODEX_CANDIDATES' }
if($accepted.Count -ne $expectedCount){ throw "ACCEPTED_COUNT_MISMATCH:$($accepted.Count)/$expectedCount" }
if($batchFailures.Count -gt 0){ throw ('BATCH_SEMANTIC_QUALITY_FAILED:'+(@($batchFailures)-join',')) }
EnsureDir (Split-Path -Parent $OutputAtomsJsonlPath)
($accepted | ForEach-Object { $_|ConvertTo-Json -Depth 50 -Compress }) -join "`n" | Set-Content -LiteralPath $OutputAtomsJsonlPath -Encoding UTF8
Write-Host "CODEX_CANDIDATE_NORMALIZED_ATOMS=$OutputAtomsJsonlPath"
