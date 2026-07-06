param(
  [string]$CurrentTask,
  [string]$KnowledgeNeed,
  [string]$AlreadyChecked = 'active_memory,reflex_registry,repo_specs',
  [string]$PartsJson,
  [string]$RunId = $("batch_knowledge_acquisition_" + (Get-Date -Format 'yyyyMMdd_HHmmss')),
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
  $PartsJson = ($inputObject.DecomposedParts | ConvertTo-Json -Depth 10 -Compress)
  if($inputObject.RunId) { $RunId = [string]$inputObject.RunId }
if($inputObject.RunRootBase) { $RunRootBase = [string]$inputObject.RunRootBase }
  if($inputObject.RetainRawSource -eq $true) { $RetainRawSource = $true }
}
if([string]::IsNullOrWhiteSpace($CurrentTask) -or [string]::IsNullOrWhiteSpace($KnowledgeNeed) -or [string]::IsNullOrWhiteSpace($PartsJson)) {
  throw 'CurrentTask, KnowledgeNeed, and PartsJson/DecomposedParts are required.'
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $RepoRoot

$RunRoot = Join-Path $RunRootBase $RunId
New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
$LastMessagePath = Join-Path $RunRoot 'codex_batch_last_message.json.txt'
$ProofPath = Join-Path $RunRoot 'BATCH_KNOWLEDGE_ACQUISITION_PROOF.json'
$DigestPath = Join-Path $RunRoot 'BATCH_SOURCE_DIGEST_AND_PROMOTION_DECISION.json'
$TemplatePath = 'operations/knowledge_acquisition_port/CODEX_BATCH_KNOWLEDGE_REQUEST_TEMPLATE.md'
$SchemaPath = 'operations/knowledge_acquisition_port/codex_batch_knowledge_answer_schema.json'
$RetentionPolicyPath = 'operations/knowledge_acquisition_port/SOURCE_DIGEST_RETENTION_POLICY.md'

function Get-GitStatusShort { @(git status --short --untracked-files=all) }
function New-ShaOrNull([string]$Path) { if(Test-Path -LiteralPath $Path){ return (Get-FileHash -Algorithm SHA256 $Path).Hash }; return $null }
function New-CompactList($Value,[int]$Max=5) { @(@($Value) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -First $Max | ForEach-Object { [string]$_ }) }
function Get-RequiredShapeOk($Parsed,$ExpectedIds) {
  if($null -eq $Parsed) { return $false }
  if($Parsed.answer_status -ne 'CODEX_DRAFT') { return $false }
  if($Parsed.source_role -ne 'CODEX_BATCH_READONLY_SOURCE') { return $false }
  if([string]::IsNullOrWhiteSpace([string]$Parsed.parent_task)) { return $false }
  if(@($Parsed.parts).Count -lt 1) { return $false }
  foreach($id in $ExpectedIds) {
    $part=@($Parsed.parts | Where-Object { [string]$_.id -eq [string]$id }) | Select-Object -First 1
    if($null -eq $part) { return $false }
    if([string]::IsNullOrWhiteSpace([string]$part.name)) { return $false }
    if([string]::IsNullOrWhiteSpace([string]$part.meaning)) { return $false }
    if([string]::IsNullOrWhiteSpace([string]$part.role_in_parent_task)) { return $false }
    if(@($part.missing_knowledge).Count -lt 1) { return $false }
    if(@($part.safe_learning_steps).Count -lt 1) { return $false }
    if(@($part.validation_needed).Count -lt 1) { return $false }
    if([string]::IsNullOrWhiteSpace([string]$part.return_to_parent_hint)) { return $false }
  }
  if($null -eq $Parsed.cross_part_map) { return $false }
  if(@($Parsed.cross_part_map.priority_order).Count -lt 1) { return $false }
  if($null -eq $Parsed.parent_return_plan) { return $false }
  if([string]::IsNullOrWhiteSpace([string]$Parsed.parent_return_plan.how_to_rebuild_x)) { return $false }
  if([string]::IsNullOrWhiteSpace([string]$Parsed.parent_return_plan.next_small_action)) { return $false }
  if(@($Parsed.parent_return_plan.proof_needed).Count -lt 1) { return $false }
  if([string]::IsNullOrWhiteSpace([string]$Parsed.limits)) { return $false }
  return $true
}

$Parts = $PartsJson | ConvertFrom-Json
$ExpectedIds = @($Parts | ForEach-Object { [string]$_.id })
if($ExpectedIds.Count -gt 10) { throw 'Batch parts limit exceeded: max 10.' }
if($ExpectedIds.Count -lt 1) { throw 'At least one part required.' }
$StatusBefore = Get-GitStatusShort
$PromptTemplate = Get-Content -LiteralPath $TemplatePath -Raw
$Prompt = $PromptTemplate.Replace('{{CURRENT_TASK}}', $CurrentTask).Replace('{{KNOWLEDGE_NEED}}', $KnowledgeNeed).Replace('{{ALREADY_CHECKED}}', $AlreadyChecked).Replace('{{DECOMPOSED_PARTS_JSON}}', ($Parts | ConvertTo-Json -Depth 10 -Compress))

$Prompt | codex exec --skip-git-repo-check --sandbox read-only --ephemeral --output-last-message $LastMessagePath - | Out-Null
$ExitCode = $LASTEXITCODE
$Raw = if(Test-Path -LiteralPath $LastMessagePath){ Get-Content -LiteralPath $LastMessagePath -Raw } else { '' }
$RawSha = New-ShaOrNull $LastMessagePath
$Parsed = $null
$JsonValid = $false
try { $Parsed = $Raw | ConvertFrom-Json; $JsonValid = $true } catch { }
$RequiredShapeValid = if($JsonValid){ Get-RequiredShapeOk $Parsed $ExpectedIds } else { $false }
$Pass = ($ExitCode -eq 0 -and $JsonValid -and $RequiredShapeValid)

$PartDigests=@()
if($JsonValid) {
  foreach($p in @($Parsed.parts)) {
    $PartDigests += [ordered]@{
      id=[string]$p.id
      name=[string]$p.name
      meaning=[string]$p.meaning
      role_in_parent_task=[string]$p.role_in_parent_task
      compact_missing_knowledge=New-CompactList $p.missing_knowledge 5
      compact_safe_learning_steps=New-CompactList $p.safe_learning_steps 5
      compact_validation_needed=New-CompactList $p.validation_needed 5
      return_to_parent_hint=[string]$p.return_to_parent_hint
    }
  }
}
$Digest=[ordered]@{
  schema='BATCH_SOURCE_DIGEST_AND_PROMOTION_DECISION_V1'
  status=$(if($Pass){'COMPACT_BATCH_DIGEST_CREATED'}else{'BATCH_DIGEST_INCOMPLETE_SOURCE_QUERY_FAILED'})
  run_id=$RunId
  source='CODEX_BATCH_READONLY_SOURCE'
  source_answer_status=$(if($JsonValid -and $Parsed.answer_status){$Parsed.answer_status}else{'CODEX_DRAFT'})
  parent_task=$CurrentTask
  knowledge_need=$KnowledgeNeed
  part_count=$ExpectedIds.Count
  part_digests=$PartDigests
  cross_part_map=$(if($JsonValid){$Parsed.cross_part_map}else{$null})
  parent_return_plan=$(if($JsonValid){$Parsed.parent_return_plan}else{$null})
  promotion_decision=[ordered]@{
    default_classification='CASE_PATTERN_CANDIDATE'
    raw_retention_decision=$(if($Pass -and -not $RetainRawSource){'DELETE_RAW_CANDIDATE'}elseif($RetainRawSource){'AUDIT_RETENTION_REQUESTED'}else{'RAW_RETAINED_FOR_FAILURE_DEBUG'})
    active_memory_candidate=$false
    atom_candidate=$false
    reflex_candidate=$false
    organ_candidate=$false
    owner_decision_required='only if promotion beyond case pattern is requested'
    reason='Batch source answer is material only; default is compact case pattern with part map and parent return plan.'
  }
  proof_refs=[ordered]@{
    batch_knowledge_acquisition_proof=$ProofPath
    raw_answer_sha256=$RawSha
    raw_answer_retained=$(if(Test-Path -LiteralPath $LastMessagePath){$true}else{$false})
  }
}
$Digest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $DigestPath -Encoding UTF8
$StatusAfter = Get-GitStatusShort
$Proof=[ordered]@{
  schema='BATCH_KNOWLEDGE_ACQUISITION_PROOF_V1'
  source='CODEX_BATCH_READONLY_SOURCE'
  status=$(if($Pass){'PASS_CODEX_BATCH_DRAFT_RETURNED'}else{'FAIL_CODEX_BATCH_SOURCE_QUERY'})
  checked_at=(Get-Date).ToString('o')
  run_id=$RunId
  current_task=$CurrentTask
  knowledge_need=$KnowledgeNeed
  already_checked=$AlreadyChecked
  part_ids=$ExpectedIds
  part_count=$ExpectedIds.Count
  template_path=$TemplatePath
  answer_schema='CODEX_BATCH_KNOWLEDGE_ANSWER_SCHEMA_V1'
  answer_schema_path=$SchemaPath
  retention_policy_path=$RetentionPolicyPath
  source_digest_path=$DigestPath
  codex_exit_code=$ExitCode
  codex_answer_status=$(if($JsonValid -and $Parsed.answer_status){$Parsed.answer_status}else{'CODEX_DRAFT'})
  codex_answer_json_valid=$JsonValid
  codex_answer_required_shape_valid=$RequiredShapeValid
  codex_answer_sha256=$RawSha
  raw_source_retention=$(if($Pass -and -not $RetainRawSource){'DELETED_AFTER_COMPACT_DIGEST'}elseif($RetainRawSource){'RETAINED_BY_REQUEST'}else{'RETAINED_FOR_FAILURE_DEBUG'})
  parent_return_plan=$(if($JsonValid){$Parsed.parent_return_plan}else{$null})
  promotion_decision=$Digest.promotion_decision
  mutation_audit=[ordered]@{
    active_memory_mutated=$false
    codex_file_write_requested=$false
    codex_shell_execution_requested=$false
    repo_status_before=@($StatusBefore)
    repo_status_after=@($StatusAfter)
  }
  boundary='CODEX_DRAFT only; batch answer is compact source material; raw source not retained by default.'
}
$Proof | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $ProofPath -Encoding UTF8
foreach($f in @($DigestPath,$ProofPath,$LastMessagePath)){
  if(Test-Path -LiteralPath $f){
    $txt=Get-Content -LiteralPath $f -Raw
    $txt=$txt -replace "`r`n","`n"
    [IO.File]::WriteAllText((Resolve-Path $f).Path,$txt,[Text.UTF8Encoding]::new($false))
  }
}
if($Pass -and -not $RetainRawSource) {
  Remove-Item -LiteralPath $LastMessagePath -Force -ErrorAction SilentlyContinue
  $Proof.raw_source_retention='DELETED_AFTER_COMPACT_DIGEST'
  $Digest.proof_refs.raw_answer_retained=$false
  $Proof | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $ProofPath -Encoding UTF8
  $Digest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $DigestPath -Encoding UTF8
}
$Proof | ConvertTo-Json -Depth 30
if($Proof.status -notlike 'PASS_*'){ exit 1 }
