param(
  [Parameter(Mandatory=$true)][string]$AcceptanceDecisionPath,
  [string]$OutputPath = '.runtime/source_authority_router_v1/source_route_decision.json'
)
$ErrorActionPreference='Stop'
function WJson($obj,$path){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $obj | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding UTF8
}
function Read-Json($path){ Get-Content $path -Raw | ConvertFrom-Json }
$errors=New-Object System.Collections.Generic.List[string]
if(!(Test-Path $AcceptanceDecisionPath)){ $errors.Add('acceptance_decision_path_missing') }
$acc=$null
if($errors.Count -eq 0){ $acc=Read-Json $AcceptanceDecisionPath }
if($acc -and $acc.status -ne 'PASS_MIND_DELTA_ACCEPTANCE_DECISION_V1'){
  $errors.Add('acceptance_decision_not_ready:'+[string]$acc.status)
}
$decision=if($acc){[string]$acc.decision}else{'REQUEST_MORE_PROOF'}
$evidenceCount=if($acc -and $null -ne $acc.evidence_count){[int]$acc.evidence_count}else{0}
$unknownCount=if($acc -and $null -ne $acc.unknown_count){[int]$acc.unknown_count}else{0}
$riskCount=if($acc -and $null -ne $acc.risk_count){[int]$acc.risk_count}else{0}
$route='BLOCKED_OWNER_OR_OPERATOR_REVIEW'
$reason='no valid acceptance decision'
$allowedNow=@()
$blockedNow=@('codex','web_external','accepted_memory_write','accepted_core_write','action_execution')
if($errors.Count -eq 0){
  switch($decision){
    'ACCEPT_AS_KNOWN_CANDIDATE' {
      $route='LOCAL_ACCEPTANCE_PIPELINE_REQUIRED'
      $reason='candidate may be routed to local accepted-core/D2B pipeline only after reuse proof and accepted pipeline; this router does not write memory'
      $allowedNow=@('local_validation','reuse_proof','accepted_pipeline_request_packet')
    }
    'KEEP_AS_ASSUMPTION' {
      if($riskCount -gt 0){
        $route='OWNER_OR_REPO_PROOF_FIRST'
        $reason='unresolved risk markers require bounded Owner/repo proof before external expansion'
        $allowedNow=@('repo_proof_lookup','owner_clarification_request')
      } elseif($unknownCount -gt 0){
        $route='LOCAL_MEMORY_THEN_REPO_PROOF'
        $reason='assumption has unknowns; first use local memory and repo proof before asking external sources'
        $allowedNow=@('local_memory_lookup','repo_proof_lookup','owner_clarification_request')
      } else {
        $route='REPO_PROOF_LOOKUP'
        $reason='assumption has limited evidence; seek repo/proof confirmation before acceptance'
        $allowedNow=@('repo_proof_lookup','owner_clarification_request')
      }
    }
    'REQUEST_MORE_PROOF' {
      if($evidenceCount -eq 0){
        $route='SOURCE_LADDER_START_LOCAL'
        $reason='no evidence; begin with local memory/repo proof, then Owner; Codex/web only as gated future escalation'
        $allowedNow=@('local_memory_lookup','repo_proof_lookup','owner_clarification_request')
      } else {
        $route='SOURCE_LADDER_EXPAND_LOCAL_FIRST'
        $reason='some evidence but insufficient; expand through local/repo/Owner before governed external scout'
        $allowedNow=@('local_memory_lookup','repo_proof_lookup','owner_clarification_request')
      }
    }
    default {
      $route='BLOCKED_UNKNOWN_ACCEPTANCE_DECISION'
      $reason='acceptance decision is unknown to router'
      $allowedNow=@('owner_clarification_request')
    }
  }
}
$out=[ordered]@{
  schema='source_authority_router_v1'
  status=if($errors.Count -eq 0){'PASS_SOURCE_AUTHORITY_ROUTE_DECISION_V1'}else{'BLOCKED_SOURCE_AUTHORITY_ROUTE_DECISION_V1'}
  created_at=(Get-Date).ToString('o')
  acceptance_decision_path=$AcceptanceDecisionPath
  acceptance_decision=$decision
  route=$route
  reason=$reason
  allowed_now=@($allowedNow)
  blocked_now=@($blockedNow)
  source_ladder=[ordered]@{
    first='local_memory_lookup'
    second='repo_proof_lookup'
    third='owner_clarification_request'
    fourth='codex_request_packet_only_when_authorized'
    fifth='web_external_scout_only_when_authorized'
  }
  escalation_packet=[ordered]@{
    codex_allowed_now=$false
    web_allowed_now=$false
    codex_future_condition='bounded file/task contract, validators, proof report, no protected mutation before PREFLIGHT_PASS'
    web_future_condition='current public fact gap, source contract, citations/provenance, no accepted memory write'
  }
  boundary=[ordered]@{
    active_memory_mutated=$false
    accepted_core_mutated=$false
    live_process_touched=$false
    codex_launched=$false
    web_launched=$false
    external_tool_launched=$false
    action_executed=$false
  }
  forbidden=@('launch Codex','browse web','write accepted memory','mutate accepted-core','execute action from route decision')
  errors=@($errors)
}
WJson $out $OutputPath
Write-Host ('SOURCE_ROUTER_STATUS='+$out.status)
Write-Host ('SOURCE_ROUTER_ROUTE='+$out.route)
Write-Host ('SOURCE_ROUTER_PATH='+$OutputPath)
if($errors.Count -gt 0){ exit 1 }
