param()
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$root=Join-Path '.runtime/self_development' ('school_knowledge_normalizer_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $root|Out-Null
$normalizer='operations/school/codex/validate_and_normalize_codex_school_patch_candidates_v1.ps1'
$required=@('schema','candidate_id','topic_key','topic_label','depth_level','prerequisite_depth','target_depth','source_basis','source_missing','claim','knowledge_kind','evidence_statement','expected_behavior','failure_contrast','validator','proof_requirements','negative_case','return_to_parent','digest_hint','quality_flags')
$task=[ordered]@{required_candidate_fields=$required;topic_key='memory_admission';start_depth=1;target_depth=3;candidate_limit=1}
$taskPath=Join-Path $root 'task.json';$task|ConvertTo-Json -Depth 20|Set-Content $taskPath -Encoding UTF8
$producerFiles=@(
  'operations/school/codex/build_codex_school_patch_task_v1.ps1',
  'operations/school/warehouse/build_codex_warehouse_macro_task_v1.ps1',
  'operations/school/warehouse/build_codex_warehouse_request_macro_task_v1.ps1',
  'operations/school/run_agent_school.ps1'
)
foreach($producerFile in $producerFiles){
  $producerText=Get-Content $producerFile -Raw
  if($producerText -match 'codex_school_patch_candidate_v1'){throw ('OLD_PATCH_SCHEMA_REMAINS:'+ $producerFile)}
  foreach($requiredText in @('codex_school_knowledge_candidate_v1','knowledge_kind','evidence_statement')){if($producerText -notmatch [regex]::Escape($requiredText)){throw ('KNOWLEDGE_PRODUCER_CONTRACT_MISSING:'+ $producerFile+':'+$requiredText)}}
}
foreach($producerFile in @('operations/school/warehouse/build_codex_warehouse_macro_task_v1.ps1','operations/school/warehouse/build_codex_warehouse_request_macro_task_v1.ps1','operations/school/run_agent_school.ps1')){
  $producerText=Get-Content $producerFile -Raw
  if($producerText -notmatch 'INSUFFICIENT_EVIDENCE_FOR_EXACT_COUNT'){throw ('INSUFFICIENT_EVIDENCE_FAIL_RULE_MISSING:'+ $producerFile)}
}
$selectorText=Get-Content 'operations/school/memory/select_dynamic_theme_cell_v1.ps1' -Raw
if($selectorText -notmatch "@\('AUTO','DEFAULT'\)"){throw 'DEFAULT_IS_NOT_AUTO_GUARD_MISSING'}
$schoolRunnerText=Get-Content 'operations/school/run_agent_school.ps1' -Raw
foreach($requiredText in @('SCHOOL_KNOWLEDGE_NORMALIZATION_BLOCKED','AGENTS.md is an execution contract','source formatting, line numbers, token/character counts')){if($schoolRunnerText -notmatch [regex]::Escape($requiredText)){throw ('SCHOOL_PRE_DIGEST_QUALITY_GUARD_MISSING:'+ $requiredText)}}
function New-Candidate([string]$Claim,[string]$Kind,[string]$Evidence,[bool]$SourceMissing=$false){
  [ordered]@{schema='codex_school_knowledge_candidate_v1';candidate_id='cand_1';topic_key='memory_admission';topic_label='Memory admission';depth_level=1;prerequisite_depth=0;target_depth=3;source_basis=if($SourceMissing){@()}else{@($normalizer)};source_missing=$SourceMissing;claim=$Claim;knowledge_kind=$Kind;evidence_statement=$Evidence;expected_behavior='Future reasoning may use this knowledge when relevant.';failure_contrast='Unsupported material must not be admitted.';validator='Check semantic normalizer behavior.';proof_requirements='Behavioral validator proof.';negative_case='Task-like or source-less material is rejected.';return_to_parent='Improves memory admission correctness.';digest_hint='Store only the declarative knowledge claim.';quality_flags=@('grounded','semantic_regression')}
}
function Run-Case([string]$Name,$Candidate,[bool]$ExpectPass){
  $in=Join-Path $root ($Name+'.jsonl');$out=Join-Path $root ($Name+'_atoms.jsonl');$report=Join-Path $root ($Name+'_report.json');$stdout=Join-Path $root ($Name+'_stdout.txt');$stderr=Join-Path $root ($Name+'_stderr.txt')
  ($Candidate|ConvertTo-Json -Depth 40 -Compress)|Set-Content $in -Encoding UTF8
  $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$normalizer,'-TaskJsonPath',$taskPath,'-CandidatesJsonlPath',$in,'-OutputAtomsJsonlPath',$out,'-ReportPath',$report)
  $p=Start-Process powershell.exe -ArgumentList $args -PassThru -Wait -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  if($ExpectPass -and $p.ExitCode-ne0){throw "CASE_EXPECTED_PASS:$Name"}
  if(-not$ExpectPass -and $p.ExitCode-eq0){throw "CASE_EXPECTED_REJECT:$Name"}
  if(-not$ExpectPass -and (Test-Path $out)){throw "REJECT_CASE_EMITTED_ATOM:$Name"}
  if($ExpectPass){return (Get-Content $out -Raw|ConvertFrom-Json)}
  return $null
}
function Run-BatchRejectCase([string]$Name,[object[]]$Candidates,[string]$Topic='memory_admission'){
  $taskBatch=[ordered]@{required_candidate_fields=$required;topic_key=$Topic;start_depth=1;target_depth=3;candidate_limit=$Candidates.Count}
  $taskBatchPath=Join-Path $root ($Name+'_task.json');$taskBatch|ConvertTo-Json -Depth 20|Set-Content $taskBatchPath -Encoding UTF8
  $in=Join-Path $root ($Name+'.jsonl');$out=Join-Path $root ($Name+'_atoms.jsonl');$report=Join-Path $root ($Name+'_report.json');$stdout=Join-Path $root ($Name+'_stdout.txt');$stderr=Join-Path $root ($Name+'_stderr.txt')
  ($Candidates|ForEach-Object{$_|ConvertTo-Json -Depth 40 -Compress}) -join "`n" | Set-Content $in -Encoding UTF8
  $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$normalizer,'-TaskJsonPath',$taskBatchPath,'-CandidatesJsonlPath',$in,'-OutputAtomsJsonlPath',$out,'-ReportPath',$report)
  $p=Start-Process powershell.exe -ArgumentList $args -PassThru -Wait -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  if($p.ExitCode-eq0){throw "BATCH_EXPECTED_REJECT:$Name"}
  if(Test-Path $out){throw "BATCH_REJECT_EMITTED_ATOMS:$Name"}
  if(-not(Test-Path $report)){throw "BATCH_REJECT_REPORT_MISSING:$Name"}
  return (Get-Content $report -Raw|ConvertFrom-Json)
}
try{
  $null=Run-Case 'task_like' (New-Candidate 'Add a guard to reject unsupported memory candidates.' 'rule' 'The cited source describes the normalizer admission logic.') $false
  $null=Run-Case 'source_missing' (New-Candidate 'The normalizer rejects unsupported memory candidates.' 'constraint' 'No grounded source is available.' $true) $false
  $vague=New-Candidate 'The School normalizer requires resolvable provenance before knowledge admission.' 'constraint' 'A vague source label is not sufficient.'
  $vague.source_basis=@('Selection and School Request files')
  $null=Run-Case 'vague_source' $vague $false
  $agents=New-Candidate 'The School runner checks normalization status before digestion.' 'constraint' 'The execution contract is not admissible as School knowledge evidence.'
  $agents.source_basis=@('AGENTS.md')
  $null=Run-Case 'agents_source' $agents $false
  $trivia=New-Candidate 'The normalizer source line 42 has 12 parsed word tokens and 91 non-newline characters.' 'observation' 'The cited file can be counted structurally.'
  $null=Run-Case 'source_document_trivia' $trivia $false
  $templateRows=New-Object System.Collections.Generic.List[object]
  for($n=1;$n-le20;$n++){
    $c=New-Candidate ("The memory source grounding constraint number {0} requires resolvable evidence before admission." -f $n) 'constraint' 'The normalizer enforces resolvable source evidence before admission.'
    $c.candidate_id=('template_'+$n)
    [void]$templateRows.Add($c)
  }
  $templateReport=Run-BatchRejectCase 'template_collapse' @($templateRows.ToArray())
  if([string]$templateReport.status -ne 'FAIL_CODEX_SCHOOL_KNOWLEDGE_CANDIDATE_NORMALIZATION_V1'){throw 'TEMPLATE_BATCH_STATUS_NOT_FAIL'}
  if(@($templateReport.batch_failures).Count -lt1){throw 'TEMPLATE_BATCH_FAILURE_REASON_MISSING'}
  $mustClaim='A knowledge candidate must have a resolvable source_basis before admission.'
  $mustAtom=Run-Case 'declarative_must_constraint' (New-Candidate $mustClaim 'constraint' 'The normalizer source resolves every source_basis entry before admission.') $true
  if([string]$mustAtom.summary-ne$mustClaim){throw 'DECLARATIVE_MUST_CONSTRAINT_REJECTED_OR_CHANGED'}
  $claim='The School normalizer requires a non-empty source_basis before a knowledge candidate can be admitted.'
  $atom=Run-Case 'grounded' (New-Candidate $claim 'constraint' 'The normalizer source checks source_basis and rejects candidates without grounded source evidence.') $true
  if([string]$atom.summary-ne$claim -or [string]$atom.definition-ne$claim){throw 'SUMMARY_OR_DEFINITION_POLLUTED'}
  if([string]$atom.concept_key-eq'memory_admission'){throw 'CONCEPT_KEY_TOPIC_ONLY'}
  if([string]$atom.source_mode-ne'codex_school_knowledge'){throw 'SOURCE_MODE_BAD'}
  if([bool]$atom.source_missing){throw 'SOURCE_MISSING_TRUE_ON_ACCEPTED'}
  if([string]$atom.kind-ne'constraint'){throw 'KNOWLEDGE_KIND_LOST'}
  Write-Host 'VALIDATION_PASS=PASS_CODEX_SCHOOL_KNOWLEDGE_CANDIDATE_NORMALIZATION_V1'
  Write-Host ('CONCEPT_KEY='+[string]$atom.concept_key)
  Write-Host 'TASK_LIKE_REJECT=PASS'
  Write-Host 'SOURCE_MISSING_REJECT=PASS'
  Write-Host 'VAGUE_SOURCE_REJECT=PASS'
  Write-Host 'AGENTS_SOURCE_REJECT=PASS'
  Write-Host 'SOURCE_DOCUMENT_TRIVIA_REJECT=PASS'
  Write-Host 'TEMPLATE_COLLAPSE_BATCH_REJECT=PASS'
  Write-Host 'DEFAULT_AUTO_AND_PRE_DIGEST_STATIC_GUARD=PASS'
  Write-Host 'DECLARATIVE_MUST_CONSTRAINT_ACCEPT=PASS'
  Write-Host 'GROUNDED_KNOWLEDGE_ACCEPT=PASS'
  Write-Host 'PRODUCER_CONTRACT_STATIC_GUARD=PASS'
}finally{
  if(Test-Path $root){Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue}
}
if(Test-Path $root){throw 'VALIDATOR_SCRATCH_LEFTOVER'}
