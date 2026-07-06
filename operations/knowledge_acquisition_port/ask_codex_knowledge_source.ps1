param(
  [string]$CurrentTask,
  [string]$KnowledgeNeed,
  [string]$AlreadyChecked = 'active_memory,reflex_registry,repo_specs',
  [string]$RunId = $("knowledge_acquisition_" + (Get-Date -Format 'yyyyMMdd_HHmmss')),
  [string]$InputJsonPath,
  [string]$RunRootBase = 'operations/knowledge_acquisition_port/runs',
  [switch]$RetainRawSource
)

$ErrorActionPreference = 'Stop'
if(-not [string]::IsNullOrWhiteSpace($InputJsonPath)) {
  $inputObject = Get-Content -LiteralPath $InputJsonPath -Raw | ConvertFrom-Json
  $CurrentTask = [string]$inputObject.CurrentTask
  $KnowledgeNeed = [string]$inputObject.KnowledgeNeed
  $AlreadyChecked = [string]$inputObject.AlreadyChecked
  if($inputObject.RunId) { $RunId = [string]$inputObject.RunId }
if($inputObject.RunRootBase) { $RunRootBase = [string]$inputObject.RunRootBase }
  if($inputObject.RetainRawSource -eq $true) { $RetainRawSource = $true }
}
if([string]::IsNullOrWhiteSpace($CurrentTask) -or [string]::IsNullOrWhiteSpace($KnowledgeNeed)) {
  throw 'CurrentTask and KnowledgeNeed are required, either as parameters or InputJsonPath fields.'
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $RepoRoot

$RunRoot = Join-Path $RunRootBase $RunId
New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
$LastMessagePath = Join-Path $RunRoot 'codex_last_message.json.txt'
$ProofPath = Join-Path $RunRoot 'KNOWLEDGE_ACQUISITION_PROOF.json'
$DigestPath = Join-Path $RunRoot 'SOURCE_DIGEST_AND_PROMOTION_DECISION.json'
$TemplatePath = 'operations/knowledge_acquisition_port/CODEX_KNOWLEDGE_REQUEST_TEMPLATE.md'
$SchemaPath = 'operations/knowledge_acquisition_port/codex_knowledge_answer_schema.json'
$RetentionPolicyPath = 'operations/knowledge_acquisition_port/SOURCE_DIGEST_RETENTION_POLICY.md'

function Get-GitStatusShort { @(git status --short --untracked-files=all) }
function New-ShaOrNull([string]$Path) { if(Test-Path -LiteralPath $Path){ return (Get-FileHash -Algorithm SHA256 $Path).Hash }; return $null }
function Get-RequiredShapeOk($Parsed) {
  if($null -eq $Parsed) { return $false }
  return (
    $Parsed.answer_status -eq 'CODEX_DRAFT' -and
    $Parsed.source_role -eq 'CODEX_READONLY_SOURCE' -and
    -not [string]::IsNullOrWhiteSpace([string]$Parsed.candidate_knowledge) -and
    @($Parsed.missing_concepts).Count -ge 1 -and
    @($Parsed.suggested_decomposition).Count -ge 1 -and
    @($Parsed.safe_learning_steps).Count -ge 1 -and
    @($Parsed.validation_needed).Count -ge 1 -and
    -not [string]::IsNullOrWhiteSpace([string]$Parsed.return_to_task_hint) -and
    -not [string]::IsNullOrWhiteSpace([string]$Parsed.limits)
  )
}
function New-CompactList($Value,[int]$Max=5) {
  $items=@($Value) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -First $Max
  return @($items | ForEach-Object { [string]$_ })
}

$StatusBefore = Get-GitStatusShort
$PromptTemplate = Get-Content -LiteralPath $TemplatePath -Raw
$Prompt = $PromptTemplate.Replace('{{CURRENT_TASK}}', $CurrentTask).Replace('{{KNOWLEDGE_NEED}}', $KnowledgeNeed).Replace('{{ALREADY_CHECKED}}', $AlreadyChecked)

$Prompt | codex exec --skip-git-repo-check --sandbox read-only --ephemeral --output-last-message $LastMessagePath - | Out-Null
$ExitCode = $LASTEXITCODE
$Raw = if(Test-Path -LiteralPath $LastMessagePath){ Get-Content -LiteralPath $LastMessagePath -Raw } else { '' }
$RawSha = New-ShaOrNull $LastMessagePath
$Parsed = $null
$JsonValid = $false
try {
  $Parsed = $Raw | ConvertFrom-Json
  $JsonValid = $true
} catch { }
$RequiredShapeValid = if($JsonValid){ Get-RequiredShapeOk $Parsed } else { $false }
$Pass = ($ExitCode -eq 0 -and $JsonValid -and $RequiredShapeValid)

$Digest = [ordered]@{
  schema='SOURCE_DIGEST_AND_PROMOTION_DECISION_V1'
  status=$(if($Pass){'COMPACT_DIGEST_CREATED'}else{'DIGEST_INCOMPLETE_SOURCE_QUERY_FAILED'})
  run_id=$RunId
  source='CODEX_READONLY_SOURCE'
  source_answer_status=$(if($JsonValid -and $Parsed.answer_status){$Parsed.answer_status}else{'CODEX_DRAFT'})
  parent_task=$CurrentTask
  knowledge_need=$KnowledgeNeed
  compact_candidate_knowledge=$(if($JsonValid){[string]$Parsed.candidate_knowledge}else{$null})
  compact_missing_concepts=$(if($JsonValid){New-CompactList $Parsed.missing_concepts 8}else{@()})
  compact_safe_learning_steps=$(if($JsonValid){New-CompactList $Parsed.safe_learning_steps 8}else{@()})
  compact_validation_needed=$(if($JsonValid){New-CompactList $Parsed.validation_needed 8}else{@()})
  return_to_task_hint=$(if($JsonValid){[string]$Parsed.return_to_task_hint}else{$null})
  promotion_decision=[ordered]@{
    default_classification='CASE_PATTERN_CANDIDATE'
    raw_retention_decision=$(if($Pass -and -not $RetainRawSource){'DELETE_RAW_CANDIDATE'}elseif($RetainRawSource){'AUDIT_RETENTION_REQUESTED'}else{'RAW_RETAINED_FOR_FAILURE_DEBUG'})
    active_memory_candidate=$false
    atom_candidate=$false
    reflex_candidate=$false
    organ_candidate=$false
    owner_decision_required='only if promotion beyond case pattern is requested'
    reason='One source answer is material only; default is compact reusable case pattern plus validation/return hint.'
  }
  proof_refs=[ordered]@{
    knowledge_acquisition_proof=$ProofPath
    raw_answer_sha256=$RawSha
    raw_answer_retained=$(if(Test-Path -LiteralPath $LastMessagePath){$true}else{$false})
  }
}
$Digest | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $DigestPath -Encoding UTF8

$StatusAfter = Get-GitStatusShort
$Proof = [ordered]@{
  schema='KNOWLEDGE_ACQUISITION_PROOF_V1'
  source='CODEX_READONLY_SOURCE'
  status=$(if($Pass){'PASS_CODEX_DRAFT_RETURNED'}else{'FAIL_CODEX_SOURCE_QUERY'})
  checked_at=(Get-Date).ToString('o')
  run_id=$RunId
  current_task=$CurrentTask
  knowledge_need=$KnowledgeNeed
  already_checked=$AlreadyChecked
  template_path=$TemplatePath
  answer_schema='CODEX_KNOWLEDGE_ANSWER_SCHEMA_V1'
  answer_schema_path=$SchemaPath
  retention_policy_path=$RetentionPolicyPath
  source_digest_path=$DigestPath
  codex_command='codex exec --skip-git-repo-check --sandbox read-only --ephemeral --output-last-message <run_root>/codex_last_message.json.txt -'
  codex_exit_code=$ExitCode
  codex_answer_status=$(if($JsonValid -and $Parsed.answer_status){$Parsed.answer_status}else{'CODEX_DRAFT'})
  codex_answer_json_valid=$JsonValid
  codex_answer_required_shape_valid=$RequiredShapeValid
  codex_answer_sha256=$RawSha
  raw_source_retention=$(if($Pass -and -not $RetainRawSource){'DELETED_AFTER_COMPACT_DIGEST'}elseif($RetainRawSource){'RETAINED_BY_REQUEST'}else{'RETAINED_FOR_FAILURE_DEBUG'})
  source_role=$(if($JsonValid){$Parsed.source_role}else{$null})
  candidate_knowledge=$(if($JsonValid){$Parsed.candidate_knowledge}else{$null})
  missing_concepts=$(if($JsonValid){@($Parsed.missing_concepts)}else{@()})
  suggested_decomposition=$(if($JsonValid){@($Parsed.suggested_decomposition)}else{@()})
  safe_learning_steps=$(if($JsonValid){@($Parsed.safe_learning_steps)}else{@()})
  validation_needed=$(if($JsonValid){@($Parsed.validation_needed)}else{@()})
  return_to_task_hint=$(if($JsonValid){$Parsed.return_to_task_hint}else{$null})
  limits=$(if($JsonValid){$Parsed.limits}else{$Raw.Substring(0,[Math]::Min(500,$Raw.Length))})
  promotion_decision=$Digest.promotion_decision
  mutation_audit=[ordered]@{
    active_memory_mutated=$false
    codex_file_write_requested=$false
    codex_shell_execution_requested=$false
    repo_status_before=@($StatusBefore)
    repo_status_after=@($StatusAfter)
  }
  boundary='CODEX_DRAFT only; agent must validate before acting; compact digest required; raw source not retained by default.'
}
$Proof | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $ProofPath -Encoding UTF8

foreach($f in @($DigestPath,$ProofPath,$LastMessagePath)){
  if(Test-Path -LiteralPath $f){
    $txt=Get-Content -LiteralPath $f -Raw
    $txt=$txt -replace "`r`n","`n"
    [IO.File]::WriteAllText((Resolve-Path $f).Path,$txt,[Text.UTF8Encoding]::new($false))
  }
}
if($Pass -and -not $RetainRawSource) {
  Remove-Item -LiteralPath $LastMessagePath -Force -ErrorAction SilentlyContinue
  # Update proof/digest raw_retained fields after deletion.
  $Proof.raw_source_retention='DELETED_AFTER_COMPACT_DIGEST'
  $Digest.proof_refs.raw_answer_retained=$false
  $Proof | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $ProofPath -Encoding UTF8
  $Digest | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $DigestPath -Encoding UTF8
}
$Proof | ConvertTo-Json -Depth 16
if($Proof.status -notlike 'PASS_*'){ exit 1 }
