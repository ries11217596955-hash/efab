param(
  [Parameter(Mandatory=$true)][int]$TargetAccepted,
  [Parameter(Mandatory=$true)][string]$RunId,
  [Parameter(Mandatory=$true)][string]$TopicsPlan,
  [string]$RunRootBase = '.runtime/school_source_ports/codex'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
if(-not (Test-Path $TopicsPlan)){ throw "TOPICS_PLAN_MISSING:$TopicsPlan" }
$topics=Get-Content $TopicsPlan -Raw|ConvertFrom-Json
$groups=@()
if($topics.topic_groups){ $groups=@($topics.topic_groups) } elseif($topics.groups){ $groups=@($topics.groups) } else { $groups=@($topics) }
$topicNames=@()
$idx=0
foreach($g in $groups | Select-Object -First 8){
  $idx++
  $topicNames += if($g.key){[string]$g.key}elseif($g.name){[string]$g.name}elseif($g.topic){[string]$g.topic}else{"topic_$idx"}
}
if($topicNames.Count -lt 1){ $topicNames=@('school_candidate_material') }
$parts=@([ordered]@{ id='school_codex_draft_material'; name='school_codex_draft_material'; requested_candidate_hint=('Produce one bounded CODEX_DRAFT material map across these school topics: ' + ($topicNames -join ', ')) })
$inputRoot=Join-Path $RunRootBase $RunId
EnsureDir $inputRoot
$inputPath=Join-Path $inputRoot 'SCHOOL_CODEX_SOURCE_REQUEST.json'
$input=[ordered]@{
  CurrentTask="School Source Router needs draft curriculum material for $TargetAccepted candidates."
  KnowledgeNeed='Suggest missing concepts, decomposition, safe learning steps, validation hints, and limits for school candidate material. Do not write files or decide route.'
  AlreadyChecked='active_compact_memory,school_topics_plan,existing_internal_factory_contract'
  DecomposedParts=@($parts)
  RunId=$RunId
  RunRootBase=$RunRootBase
  RetainRawSource=$false
}
WriteJson $inputPath $input 50
$stdoutPath=Join-Path $inputRoot 'codex_source_stdout.log'
$stderrPath=Join-Path $inputRoot 'codex_source_stderr.log'
$child=Start-Process -FilePath 'powershell' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/knowledge_acquisition_port/ask_codex_batch_knowledge_source.ps1','-InputJsonPath',$inputPath) -WorkingDirectory (Get-Location).Path -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
$child.WaitForExit()
$out=@()
if(Test-Path $stdoutPath){ $out += @(Get-Content $stdoutPath | ForEach-Object{[string]$_}) }
if(Test-Path $stderrPath){ $out += @(Get-Content $stderrPath | ForEach-Object{[string]$_}) }
$runRoot=Join-Path $RunRootBase $RunId
$proofPath=Join-Path $runRoot 'BATCH_KNOWLEDGE_ACQUISITION_PROOF.json'
$digestPath=Join-Path $runRoot 'BATCH_SOURCE_DIGEST_AND_PROMOTION_DECISION.json'
if(-not (Test-Path $proofPath)){ throw "CODEX_BATCH_PROOF_MISSING:$proofPath" }
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
$pass=($proof.status -eq 'PASS_CODEX_BATCH_DRAFT_RETURNED' -and $proof.codex_answer_status -eq 'CODEX_DRAFT' -and $proof.codex_answer_required_shape_valid -eq $true)
$status=if($pass){'PASS_SCHOOL_CODEX_SOURCE_PORT_V1'}else{'FAIL_SCHOOL_CODEX_SOURCE_PORT_V1'}
$portProof=[ordered]@{
  schema='school_codex_source_port_proof_v1'
  status=$status
  run_id=$RunId
  source='CodexSourcePort'
  target_accepted=$TargetAccepted
  topics_plan=$TopicsPlan
  request_path=$inputPath
  codex_batch_proof=$proofPath
  source_digest_path=$digestPath
  stdout_path=$stdoutPath
  stderr_path=$stderrPath
  child_exit_code=$child.ExitCode
  codex_status=$proof.status
  codex_answer_status=$proof.codex_answer_status
  required_shape_valid=$proof.codex_answer_required_shape_valid
  codex_file_write_requested=$proof.mutation_audit.codex_file_write_requested
  codex_shell_execution_requested=$proof.mutation_audit.codex_shell_execution_requested
  active_memory_mutated=$proof.mutation_audit.active_memory_mutated
  material_status='CODEX_DRAFT_ONLY'
  boundary='CodexSourcePort is readonly draft material supplier only; it cannot write compact memory, cannot decide route, and cannot bypass school validators.'
  output=@($out)
  created_at=(Get-Date).ToString('o')
}
$portProofPath=Join-Path $runRoot 'SCHOOL_CODEX_SOURCE_PORT_PROOF.json'
WriteJson $portProofPath $portProof 100
Write-Host "SCHOOL_CODEX_SOURCE_PORT_STATUS=$status"
Write-Host "SCHOOL_CODEX_SOURCE_PORT_PROOF=$portProofPath"
Write-Host "SCHOOL_CODEX_SOURCE_MATERIAL_STATUS=CODEX_DRAFT_ONLY"
if($status -ne 'PASS_SCHOOL_CODEX_SOURCE_PORT_V1'){ exit 1 }