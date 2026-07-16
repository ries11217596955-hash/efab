param(
  [Parameter(Mandatory=$true)][string]$DeepSourceAnswerPath,
  [string]$OutputPath = '.runtime/deep_source_answer_assimilation_v1/assimilation_candidate.json'
)
$ErrorActionPreference='Stop'
function WJson($obj,$path){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $obj | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding UTF8
}
function Read-Json($path){ Get-Content $path -Raw | ConvertFrom-Json }

$errors = New-Object System.Collections.Generic.List[string]
if(!(Test-Path $DeepSourceAnswerPath)){ $errors.Add('deep_source_answer_path_missing') }

$source = $null
if($errors.Count -eq 0){ $source = Read-Json $DeepSourceAnswerPath }

$answerCandidate = $null
if($source){
  if($source.answer_candidate){ $answerCandidate = $source.answer_candidate }
  elseif($source.result -and $source.result.answer_candidate){ $answerCandidate = $source.result.answer_candidate }
}

$answerReady = $false
if($source){
  if($null -ne $source.answer_ready){ $answerReady = [bool]$source.answer_ready }
  elseif($source.result -and $null -ne $source.result.answer_ready){ $answerReady = [bool]$source.result.answer_ready }
}

$evidenceItems = @()
if($answerCandidate -and $answerCandidate.evidence_items){ $evidenceItems = @($answerCandidate.evidence_items) }

if($errors.Count -gt 0){
  $out=[ordered]@{
    schema='deep_source_answer_assimilation_v1'
    status='FAIL_DEEP_SOURCE_ANSWER_ASSIMILATION_V1'
    created_at=(Get-Date).ToString('o')
    source_path=$DeepSourceAnswerPath
    answer_ready=$false
    errors=@($errors)
    boundary=[ordered]@{active_memory_mutated=$false; live_process_touched=$false; external_tool_launched=$false; repo_mutated=$false}
  }
  WJson $out $OutputPath
  Write-Host ('ASSIMILATION_STATUS='+$out.status)
  Write-Host ('ASSIMILATION_PATH='+$OutputPath)
  exit 1
}

if(!$answerReady -or !$answerCandidate){
  $out=[ordered]@{
    schema='deep_source_answer_assimilation_v1'
    status='BLOCKED_NO_READY_DEEP_SOURCE_ANSWER_V1'
    created_at=(Get-Date).ToString('o')
    source_path=$DeepSourceAnswerPath
    answer_ready=$answerReady
    reason='deep source request did not produce a ready answer_candidate'
    next_required='obtain a ready answer_candidate through active memory, repo proof, Owner, or governed external source before assimilation'
    mind_delta_candidate=$null
    acceptance_boundary=[ordered]@{accepted_memory_update=$false; requires_validator=$true; requires_reuse_proof=$true; requires_parent_return=$true}
    boundary=[ordered]@{active_memory_mutated=$false; live_process_touched=$false; external_tool_launched=$false; repo_mutated=$false}
    errors=@()
  }
  WJson $out $OutputPath
  Write-Host ('ASSIMILATION_STATUS='+$out.status)
  Write-Host ('ASSIMILATION_PATH='+$OutputPath)
  exit 0
}

$direct = [string]$answerCandidate.direct_answer
$unknown = @()
if($answerCandidate.unknown){ $unknown = @($answerCandidate.unknown | ForEach-Object { [string]$_ }) }
$risks = @()
if($answerCandidate.contradictions_or_risks){ $risks = @($answerCandidate.contradictions_or_risks | ForEach-Object { [string]$_ }) }
$rule = if($answerCandidate.reusable_rule){ [string]$answerCandidate.reusable_rule } else { 'Use ready deep source answer as bounded reasoning input, not accepted memory.' }

$out=[ordered]@{
  schema='deep_source_answer_assimilation_v1'
  status='PASS_DEEP_SOURCE_ANSWER_ASSIMILATION_CANDIDATE_V1'
  created_at=(Get-Date).ToString('o')
  source_path=$DeepSourceAnswerPath
  answer_ready=$true
  evidence_count=$evidenceItems.Count
  direct_answer=$direct
  reusable_rule_candidate=$rule
  mind_delta_candidate=[ordered]@{
    type='reasoning_delta_candidate'
    status='CANDIDATE_NOT_ACCEPTED'
    change='convert ready deep answer into bounded known/unknown update for the current mind logic frame'
    known_additions=@($evidenceItems | ForEach-Object { [ordered]@{source=$_.source; claim=$_.claim; evidence_status='ANSWER_EVIDENCE_CANDIDATE'} })
    unknown_remaining=@($unknown)
    risks=@($risks)
    next_verification_step=[string]$answerCandidate.next_verification_step
  }
  acceptance_boundary=[ordered]@{
    accepted_memory_update=$false
    accepted_atom=$false
    requires_validator=$true
    requires_reuse_proof=$true
    requires_parent_return=$true
    forbidden=@('mutate active memory','claim accepted truth','launch external tool','execute action')
  }
  boundary=[ordered]@{active_memory_mutated=$false; live_process_touched=$false; external_tool_launched=$false; repo_mutated=$false}
  errors=@()
}
WJson $out $OutputPath
Write-Host ('ASSIMILATION_STATUS='+$out.status)
Write-Host ('ASSIMILATION_EVIDENCE_COUNT='+$out.evidence_count)
Write-Host ('ASSIMILATION_PATH='+$OutputPath)
