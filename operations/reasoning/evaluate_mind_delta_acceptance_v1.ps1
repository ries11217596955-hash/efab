param(
  [Parameter(Mandatory=$true)][string]$AssimilationPath,
  [string]$OutputPath = '.runtime/mind_delta_acceptance_gate_v1/acceptance_decision.json'
)
$ErrorActionPreference='Stop'
function WJson($obj,$path){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $obj | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding UTF8
}
function Read-Json($path){ Get-Content $path -Raw | ConvertFrom-Json }
$errors=New-Object System.Collections.Generic.List[string]
if(!(Test-Path $AssimilationPath)){ $errors.Add('assimilation_path_missing') }
$assim=$null
if($errors.Count -eq 0){ $assim=Read-Json $AssimilationPath }
if($assim -and $assim.status -ne 'PASS_DEEP_SOURCE_ANSWER_ASSIMILATION_CANDIDATE_V1'){
  $errors.Add('assimilation_not_ready:'+[string]$assim.status)
}
$decision='REQUEST_MORE_PROOF'
$reason='no valid assimilation candidate'
$mindDelta=$null
$evidenceCount=0
$unknownCount=0
$riskCount=0
if($assim -and $assim.mind_delta_candidate){
  $mindDelta=$assim.mind_delta_candidate
  $evidenceCount=[int]$assim.evidence_count
  $unknownCount=@($mindDelta.unknown_remaining).Count
  $riskCount=@($mindDelta.risks).Count
  if($riskCount -gt 0){
    $decision='KEEP_AS_ASSUMPTION'
    $reason='candidate has unresolved risk markers'
  } elseif($unknownCount -gt 0){
    $decision='KEEP_AS_ASSUMPTION'
    $reason='candidate has unknown_remaining items'
  } elseif($evidenceCount -ge 2){
    $decision='ACCEPT_AS_KNOWN_CANDIDATE'
    $reason='candidate has multiple evidence items and no unresolved unknown/risk markers'
  } elseif($evidenceCount -ge 1){
    $decision='KEEP_AS_ASSUMPTION'
    $reason='candidate has limited evidence only'
  } else {
    $decision='REQUEST_MORE_PROOF'
    $reason='candidate has no evidence items'
  }
}
if($errors.Count -gt 0){
  $decision='REQUEST_MORE_PROOF'
  $reason=($errors -join ';')
}
$out=[ordered]@{
  schema='mind_delta_acceptance_gate_v1'
  status=if($errors.Count -eq 0){'PASS_MIND_DELTA_ACCEPTANCE_DECISION_V1'}else{'BLOCKED_MIND_DELTA_ACCEPTANCE_DECISION_V1'}
  created_at=(Get-Date).ToString('o')
  assimilation_path=$AssimilationPath
  decision=$decision
  reason=$reason
  evidence_count=$evidenceCount
  unknown_count=$unknownCount
  risk_count=$riskCount
  accepted_memory_update=$false
  accepted_atom=$false
  next_required=if($decision -eq 'ACCEPT_AS_KNOWN_CANDIDATE'){'route to accepted-core/D2B pipeline or reuse proof; do not write accepted memory here'}elseif($decision -eq 'KEEP_AS_ASSUMPTION'){'preserve as assumption candidate and request targeted verification before acceptance'}else{'obtain more proof before using as known'}
  mind_delta_candidate_status=if($mindDelta){$mindDelta.status}else{$null}
  boundary=[ordered]@{
    active_memory_mutated=$false
    live_process_touched=$false
    external_tool_launched=$false
    codex_launched=$false
    repo_mutated=$false
    accepted_core_mutated=$false
  }
  forbidden=@('write accepted memory','claim accepted atom','execute action from candidate','launch Codex/web without authority')
  errors=@($errors)
}
WJson $out $OutputPath
Write-Host ('ACCEPTANCE_GATE_STATUS='+$out.status)
Write-Host ('ACCEPTANCE_GATE_DECISION='+$out.decision)
Write-Host ('ACCEPTANCE_GATE_PATH='+$OutputPath)
if($errors.Count -gt 0){ exit 1 }
