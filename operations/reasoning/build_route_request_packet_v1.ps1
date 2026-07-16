param(
  [Parameter(Mandatory=$true)][string]$SourceAuthorityRoutePath,
  [string]$OutputPath = '.runtime/route_request_packet_v1/route_request_packet.json'
)
$ErrorActionPreference='Stop'
function WJson($obj,$path){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $obj | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding UTF8
}
function Read-Json($path){ Get-Content $path -Raw | ConvertFrom-Json }
$errors=New-Object System.Collections.Generic.List[string]
if(!(Test-Path $SourceAuthorityRoutePath)){ $errors.Add('source_authority_route_path_missing') }
$routeObj=$null
if($errors.Count -eq 0){ $routeObj=Read-Json $SourceAuthorityRoutePath }
if($routeObj -and $routeObj.status -ne 'PASS_SOURCE_AUTHORITY_ROUTE_DECISION_V1'){
  $errors.Add('source_authority_route_not_ready:'+[string]$routeObj.status)
}
$route=if($routeObj){[string]$routeObj.route}else{'BLOCKED_UNKNOWN_ACCEPTANCE_DECISION'}
$acceptanceDecision=if($routeObj){[string]$routeObj.acceptance_decision}else{'UNKNOWN'}
$requestType='BLOCKED_OPERATOR_REVIEW_PACKET'
$packet=[ordered]@{}
$blockedFuture=@('codex_request_packet','web_scout_request_packet','accepted_memory_write','accepted_core_write','action_execution')
$allowedNow=@()
$reason='no ready source route'
if($errors.Count -eq 0){
  switch($route){
    'LOCAL_ACCEPTANCE_PIPELINE_REQUIRED' {
      $requestType='accepted_pipeline_request_packet'
      $reason='candidate is not accepted here; prepare local validation/reuse request for accepted pipeline'
      $allowedNow=@('local_validation','reuse_proof','accepted_pipeline_request_packet')
      $packet=[ordered]@{
        request_type=$requestType
        target='local_accepted_pipeline'
        required_inputs=@('mind_delta_candidate','acceptance_decision','reuse_proof','validator_proof')
        required_outputs=@('accepted_or_rejected_decision','visibility_proof','reuse_guard_update_candidate')
        forbidden=@('write accepted memory directly','skip accepted pipeline','treat candidate as accepted atom')
      }
    }
    'LOCAL_MEMORY_THEN_REPO_PROOF' {
      $requestType='local_memory_then_repo_proof_packet'
      $reason='assumption needs local memory lookup first, then repo proof if memory is insufficient'
      $allowedNow=@('local_memory_lookup_packet','repo_proof_lookup_packet','owner_clarification_request_packet')
      $packet=[ordered]@{
        request_type=$requestType
        step_order=@('local_memory_lookup','repo_proof_lookup','owner_clarification_request')
        local_memory_lookup_packet=[ordered]@{
          query_goal='find accepted/reusable memory that confirms, refutes, or narrows the assumption'
          required_outputs=@('matched_memory_refs','evidence_status','reuse_applicability','remaining_unknowns')
          forbidden=@('mutate active memory','accept raw memory snapshot as proof')
        }
        repo_proof_lookup_packet=[ordered]@{
          query_goal='find repo proof, validator output, commit, or report that confirms/refutes the assumption'
          required_outputs=@('file_refs','validator_or_commit_refs','proof_status','remaining_unknowns')
          forbidden=@('edit repo','run destructive commands','claim live proof from lab proof')
        }
        owner_clarification_request_packet=[ordered]@{
          question_goal='ask Owner only for missing decision or context after local/repo scan'
          required_outputs=@('owner_decision_or_clarification','proof_boundary')
        }
      }
    }
    'REPO_PROOF_LOOKUP' {
      $requestType='repo_proof_lookup_packet'
      $reason='route selected direct repo proof lookup'
      $allowedNow=@('repo_proof_lookup_packet','owner_clarification_request_packet')
      $packet=[ordered]@{
        request_type=$requestType
        query_goal='find repo proof, validator output, commit, report, or file diff for the candidate'
        required_outputs=@('file_refs','proof_refs','commit_or_validator_refs','proof_status','gap_if_not_found')
        forbidden=@('edit repo','launch live runtime','claim absence from weak keyword scan')
      }
    }
    'OWNER_OR_REPO_PROOF_FIRST' {
      $requestType='repo_or_owner_proof_request_packet'
      $reason='risk markers require repo proof and/or Owner clarification before external expansion'
      $allowedNow=@('repo_proof_lookup_packet','owner_clarification_request_packet')
      $packet=[ordered]@{
        request_type=$requestType
        step_order=@('repo_proof_lookup','owner_clarification_request')
        repo_proof_lookup_packet=[ordered]@{
          query_goal='locate proof or contradiction in repo before asking external systems'
          required_outputs=@('proof_refs','contradiction_refs','risk_status','next_safe_route')
          forbidden=@('mutate protected state','run Codex','browse web')
        }
        owner_clarification_request_packet=[ordered]@{
          question_goal='ask Owner for missing requirement, authority, or proof boundary only if repo proof is insufficient'
          required_outputs=@('owner_decision_required_or_not','clarified_boundary','next_safe_route')
        }
      }
    }
    'SOURCE_LADDER_START_LOCAL' {
      $requestType='source_ladder_local_start_packet'
      $reason='no evidence; start local-first source ladder'
      $allowedNow=@('local_memory_lookup_packet','repo_proof_lookup_packet','owner_clarification_request_packet')
      $packet=[ordered]@{
        request_type=$requestType
        step_order=@('local_memory_lookup','repo_proof_lookup','owner_clarification_request')
        required_stop_condition='stop before Codex/web unless local/repo/Owner prove an external gap and authority exists'
        forbidden=@('start external scout','launch Codex','write accepted memory')
      }
    }
    'SOURCE_LADDER_EXPAND_LOCAL_FIRST' {
      $requestType='source_ladder_expand_local_first_packet'
      $reason='some evidence exists but insufficient; expand local/repo/Owner before external'
      $allowedNow=@('local_memory_lookup_packet','repo_proof_lookup_packet','owner_clarification_request_packet')
      $packet=[ordered]@{
        request_type=$requestType
        step_order=@('local_memory_lookup','repo_proof_lookup','owner_clarification_request')
        external_escalation_preconditions=@('source_gap_proven','scope_bounded','authority_granted','validator_defined')
        forbidden=@('external first','Codex broad task','web without source contract')
      }
    }
    default {
      $requestType='blocked_unknown_route_packet'
      $reason='unknown route; ask Owner/operator or repair router before action'
      $allowedNow=@('owner_clarification_request_packet')
      $packet=[ordered]@{
        request_type=$requestType
        required_outputs=@('route_repair_or_owner_decision')
        forbidden=@('guess route','launch tools')
      }
    }
  }
}
$out=[ordered]@{
  schema='route_request_packet_v1'
  status=if($errors.Count -eq 0){'PASS_ROUTE_REQUEST_PACKET_V1'}else{'BLOCKED_ROUTE_REQUEST_PACKET_V1'}
  created_at=(Get-Date).ToString('o')
  source_authority_route_path=$SourceAuthorityRoutePath
  acceptance_decision=$acceptanceDecision
  source_route=$route
  request_type=$requestType
  reason=$reason
  allowed_now=@($allowedNow)
  blocked_future=@($blockedFuture)
  packet=$packet
  codex_request_packet=[ordered]@{
    status='FUTURE_BLOCKED_NOT_BUILT_NOW'
    allowed_now=$false
    reason='Codex bridge requires bounded task contract, validators, proof report, and no writes before PREFLIGHT_PASS'
  }
  web_scout_request_packet=[ordered]@{
    status='FUTURE_BLOCKED_NOT_BUILT_NOW'
    allowed_now=$false
    reason='Web scout requires current public fact/source gap, source contract, citations/provenance, and no memory write'
  }
  boundary=[ordered]@{
    active_memory_mutated=$false
    accepted_core_mutated=$false
    live_process_touched=$false
    codex_launched=$false
    web_launched=$false
    external_tool_launched=$false
    action_executed=$false
    repo_mutated=$false
  }
  errors=@($errors)
}
WJson $out $OutputPath
Write-Host ('ROUTE_REQUEST_PACKET_STATUS='+$out.status)
Write-Host ('ROUTE_REQUEST_PACKET_TYPE='+$out.request_type)
Write-Host ('ROUTE_REQUEST_PACKET_PATH='+$OutputPath)
if($errors.Count -gt 0){ exit 1 }
