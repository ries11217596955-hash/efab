param(
  [string]$Problem='agent mind logic memory recall hypothesis contradiction next step',
  [string]$Need='deep answer needed for next logical step',
  [ValidateSet('Auto','MemoryOnly','RequestOnly')][string]$Mode='Auto',
  [string]$OutputPath='.runtime/deep_source_answer_request_v1/source_answer_request.json'
)
$ErrorActionPreference='Stop'
function WJson($o,$p){ New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null; $o|ConvertTo-Json -Depth 100|Set-Content -Path $p -Encoding UTF8 }
function Terms([string]$s){ if([string]::IsNullOrWhiteSpace($s)){ return @() }; return @($s.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 3 } | Select-Object -Unique) }
$question="What is the deepest evidence-backed answer needed for: $Need ? Context: $Problem"
$answerContract=[ordered]@{
  required_format='json_object'
  fields=@('direct_answer','evidence_items','confidence','known','unknown','assumptions','contradictions_or_risks','next_verification_step','reusable_rule')
  depth_requirements=@('answer the exact need, not a generic topic','separate known from unknown','cite memory/source evidence by label/path when available','include missing evidence if answer is not enough','return no_evidence_no_claim when unsupported')
  stop_conditions=@('no accepted evidence','ambiguous need','source unavailable','answer would require unauthorized external/Codex execution')
}
$memoryResult=[ordered]@{status='NOT_RUN'; result_path=$null; accepted_count=0; accepted_matches=@(); answer_candidate=$null}
$filterScript='operations/reasoning/filter_memory_recall_relevance_v1.ps1'
$filterPath=Join-Path (Split-Path $OutputPath -Parent) 'memory_filter_for_answer.json'
if($Mode -ne 'RequestOnly' -and (Test-Path $filterScript)){
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $filterScript -Query ($Problem + ' ' + $Need) -Top 8 -AcceptTop 3 -OutputPath $filterPath *>&1 | ForEach-Object { [string]$_ })
  $memoryResult.stdout=@($out | Where-Object { $_ -match '^(RECALL_FILTER_STATUS|RECALL_FILTER_ACCEPTED_COUNT|RECALL_FILTER_TOP_LABEL)=' })
  $memoryResult.exit_code=$LASTEXITCODE
  $memoryResult.result_path=$filterPath
  if((Test-Path $filterPath) -and $LASTEXITCODE -eq 0){
    $fr=Get-Content $filterPath -Raw|ConvertFrom-Json
    $memoryResult.status=$fr.status
    $memoryResult.accepted_count=[int]$fr.accepted_count
    $memoryResult.accepted_matches=@($fr.accepted_matches | Select-Object -First 3 | ForEach-Object { [ordered]@{label=$_.label; summary=$_.summary; relevance_score=$_.relevance_score; relevance_class=$_.relevance_class; decision=$_.decision} })
    if($memoryResult.accepted_count -gt 0){
      $top=@($fr.accepted_matches | Select-Object -First 3)
      $memoryResult.answer_candidate=[ordered]@{
        direct_answer='Memory contains relevant prior material; use it as evidence, not final truth.'
        evidence_items=@($top | ForEach-Object { [ordered]@{label=$_.label; summary=$_.summary; relevance_score=$_.relevance_score} })
        confidence='MEMORY_SUPPORTED_CANDIDATE'
        known=@($top | ForEach-Object { $_.summary })
        unknown=@('whether memory evidence is sufficient for the current task without repo/source verification')
        assumptions=@('accepted memory labels are relevant because they passed relevance filter')
        contradictions_or_risks=@('memory can be stale or curriculum-like; do not treat as live fact')
        next_verification_step='cross-check accepted memory evidence with repo proof or ask external source if factual/live claim is needed'
        reusable_rule='Use filtered memory as evidence candidate; if insufficient, request a deeper source answer in the exact contract format.'
      }
    }
  } elseif(Test-Path $filterPath){
    $fr=Get-Content $filterPath -Raw|ConvertFrom-Json
    $memoryResult.status='FILTER_NONZERO_WITH_RESULT'
    $memoryResult.accepted_count=[int]$fr.accepted_count
    $memoryResult.accepted_matches=@($fr.accepted_matches | Select-Object -First 3 | ForEach-Object { [ordered]@{label=$_.label; summary=$_.summary; relevance_score=$_.relevance_score; relevance_class=$_.relevance_class; decision=$_.decision} })
  } else {
    $memoryResult.status='MEMORY_FILTER_FAILED_NO_RESULT'
  }
} elseif($Mode -eq 'RequestOnly') {
  $memoryResult.status='SKIPPED_REQUEST_ONLY'
} else {
  $memoryResult.status='FILTER_SCRIPT_MISSING'
}
$requestPacket=[ordered]@{
  schema='deep_source_answer_request_packet_v1'
  question=$question
  need=$Need
  context=$Problem
  answer_contract=$answerContract
  preferred_source_ladder=@(
    [ordered]@{rank=1; source='active_memory_filtered'; allowed_now=$true; reason='read-only local evidence'},
    [ordered]@{rank=2; source='repo_proof'; allowed_now=$true; reason='read-only local proof'},
    [ordered]@{rank=3; source='Owner'; allowed_now=$true; reason='Owner intent/unknown clarification'},
    [ordered]@{rank=4; source='Codex'; allowed_now=$false; reason='requires bounded task and explicit authority'},
    [ordered]@{rank=5; source='web_or_external_source'; allowed_now=$false; reason='requires web/tool authority and citations'}
  )
  required_answer_shape=[ordered]@{
    direct_answer='<one precise answer>'
    evidence_items=@('<source label/path + what it proves>')
    confidence='<PROVEN_LAB|PROVEN_LIVE|MEMORY_SUPPORTED|UNKNOWN>'
    known=@('<known facts>')
    unknown=@('<remaining unknowns>')
    assumptions=@('<assumptions>')
    contradictions_or_risks=@('<risks>')
    next_verification_step='<single check that would raise confidence>'
    reusable_rule='<compact reusable rule if any>'
  }
}
$status=if($memoryResult.answer_candidate){'PASS_DEEP_SOURCE_ANSWER_REQUEST_WITH_MEMORY_CANDIDATE_V1'}else{'PASS_DEEP_SOURCE_ANSWER_REQUEST_PACKET_V1'}
$result=[ordered]@{
  schema='deep_source_answer_request_result_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  mode=$Mode
  problem=$Problem
  need=$Need
  exact_question=$question
  answer_contract=$answerContract
  memory_result=$memoryResult
  request_packet=$requestPacket
  answer_ready=($null -ne $memoryResult.answer_candidate)
  answer_candidate=$memoryResult.answer_candidate
  boundary=[ordered]@{reasoning_only=$true; memory_read_only=$true; active_memory_mutated=$false; codex_launched=$false; web_launched=$false; school_started=$false; action_executed=$false}
}
WJson $result $OutputPath
Write-Host ('DEEP_SOURCE_ANSWER_STATUS='+$result.status)
Write-Host ('DEEP_SOURCE_ANSWER_READY='+$result.answer_ready)
Write-Host ('DEEP_SOURCE_ANSWER_PATH='+$OutputPath)
if($result.answer_ready){ Write-Host ('DEEP_SOURCE_ANSWER_EVIDENCE_COUNT='+@($memoryResult.answer_candidate.evidence_items).Count) }
