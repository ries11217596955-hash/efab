param([string]$ProofPath)
$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Read-Json([string]$PathToRead){ if(-not(Test-Path $PathToRead)){ Add-Err "missing_json:${PathToRead}"; return $null }; try { return Get-Content $PathToRead -Raw | ConvertFrom-Json } catch { Add-Err "bad_json:${PathToRead}:$($_.Exception.Message)"; return $null } }
if([string]::IsNullOrWhiteSpace($ProofPath)){
  $latest=Get-ChildItem '.runtime/autonomous_inner_motor' -Filter 'SANDBOX_EXPLORATION_PROOF.json' -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($latest){ $ProofPath=$latest.FullName.Substring((Resolve-Path '.').Path.Length+1).Replace('\','/') }
}
$proof=Read-Json $ProofPath
if($proof){
  if($proof.boundary.mind_logic_frame_generated -ne $true){ Add-Err 'mind_logic_frame_generated_not_true' }
  if($proof.mind_logic_frame.status -ne 'PASS_AGENT_MIND_LOGIC_FRAME_V1'){ Add-Err ('mind_logic_status_bad:'+ $proof.mind_logic_frame.status) }
  if(-not $proof.mind_logic_frame.frame){ Add-Err 'mind_logic_frame_missing' }
  if(@($proof.mind_logic_frame.frame.known).Count -lt 3){ Add-Err 'mind_logic_known_too_few' }
  if(@($proof.mind_logic_frame.frame.unknown).Count -lt 3){ Add-Err 'mind_logic_unknown_too_few' }
  if(@($proof.mind_logic_frame.frame.hypotheses).Count -lt 3){ Add-Err 'mind_logic_hypotheses_too_few' }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'hypothesis_test_result'){ Add-Err 'mind_logic_hypothesis_test_missing' }
  if($proof.mind_logic_frame.frame.hypothesis_test_result.status -ne 'PASS_HYPOTHESIS_TESTER_V1'){ Add-Err ('mind_logic_hypothesis_test_status_bad:'+ $proof.mind_logic_frame.frame.hypothesis_test_result.status) }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'contradiction_resolution'){ Add-Err 'mind_logic_contradiction_resolution_missing' }
  if($proof.mind_logic_frame.frame.contradiction_resolution.status -ne 'PASS_CONTRADICTION_RESOLUTION_V1'){ Add-Err ('mind_logic_contradiction_resolution_status_bad:'+ $proof.mind_logic_frame.frame.contradiction_resolution.status) }
  if(@($proof.mind_logic_frame.frame.source_ladder).Count -lt 4){ Add-Err 'mind_logic_source_ladder_too_short' }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'deep_source_answer_request'){ Add-Err 'mind_logic_deep_source_answer_missing' }
  if($proof.mind_logic_frame.frame.deep_source_answer_request.status -notin @('PASS_DEEP_SOURCE_ANSWER_REQUEST_WITH_MEMORY_CANDIDATE_V1','PASS_DEEP_SOURCE_ANSWER_REQUEST_PACKET_V1')){ Add-Err ('mind_logic_deep_source_answer_status_bad:'+ $proof.mind_logic_frame.frame.deep_source_answer_request.status) }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'deep_source_answer_assimilation'){ Add-Err 'mind_logic_deep_source_answer_assimilation_missing' }
  if($proof.mind_logic_frame.frame.deep_source_answer_assimilation.status -notin @('PASS_DEEP_SOURCE_ANSWER_ASSIMILATION_CANDIDATE_V1','BLOCKED_NO_READY_DEEP_SOURCE_ANSWER_V1')){ Add-Err ('mind_logic_deep_source_answer_assimilation_status_bad:'+ $proof.mind_logic_frame.frame.deep_source_answer_assimilation.status) }
  if($proof.mind_logic_frame.frame.deep_source_answer_assimilation.status -eq 'PASS_DEEP_SOURCE_ANSWER_ASSIMILATION_CANDIDATE_V1' -and $proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'mind_delta_candidate'){ Add-Err 'mind_delta_candidate_missing_after_assimilation' }
  if($proof.mind_logic_frame.frame.mind_delta_candidate -and $proof.mind_logic_frame.frame.mind_delta_candidate.status -ne 'CANDIDATE_NOT_ACCEPTED'){ Add-Err ('mind_delta_candidate_status_bad:'+ $proof.mind_logic_frame.frame.mind_delta_candidate.status) }
  if($proof.mind_logic_frame.frame.deep_source_answer_assimilation.result -and $proof.mind_logic_frame.frame.deep_source_answer_assimilation.result.boundary.active_memory_mutated -ne $false){ Add-Err 'assimilation_active_memory_mutated' }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'mind_delta_acceptance_decision'){ Add-Err 'mind_delta_acceptance_decision_missing' }
  if($proof.mind_logic_frame.frame.mind_delta_acceptance_decision.status -ne 'PASS_MIND_DELTA_ACCEPTANCE_DECISION_V1'){ Add-Err ('mind_delta_acceptance_decision_status_bad:'+ $proof.mind_logic_frame.frame.mind_delta_acceptance_decision.status) }
  if($proof.mind_logic_frame.frame.mind_delta_acceptance_decision.result.decision -notin @('ACCEPT_AS_KNOWN_CANDIDATE','KEEP_AS_ASSUMPTION','REQUEST_MORE_PROOF')){ Add-Err ('mind_delta_acceptance_decision_bad:'+ $proof.mind_logic_frame.frame.mind_delta_acceptance_decision.result.decision) }
  if($proof.mind_logic_frame.frame.mind_delta_acceptance_decision.result.accepted_memory_update -ne $false){ Add-Err 'acceptance_gate_mutated_accepted_memory' }
  if($proof.mind_logic_frame.frame.mind_delta_acceptance_decision.result.boundary.accepted_core_mutated -ne $false){ Add-Err 'acceptance_gate_mutated_accepted_core' }
  if($proof.mind_logic_frame.frame.mind_delta_acceptance_decision.result.boundary.codex_launched -ne $false){ Add-Err 'acceptance_gate_launched_codex' }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'source_authority_route'){ Add-Err 'source_authority_route_missing' }
  if($proof.mind_logic_frame.frame.source_authority_route.status -ne 'PASS_SOURCE_AUTHORITY_ROUTE_DECISION_V1'){ Add-Err ('source_authority_route_status_bad:'+ $proof.mind_logic_frame.frame.source_authority_route.status) }
  if($proof.mind_logic_frame.frame.source_authority_route.result.route -notin @('LOCAL_ACCEPTANCE_PIPELINE_REQUIRED','LOCAL_MEMORY_THEN_REPO_PROOF','REPO_PROOF_LOOKUP','OWNER_OR_REPO_PROOF_FIRST','SOURCE_LADDER_START_LOCAL','SOURCE_LADDER_EXPAND_LOCAL_FIRST','BLOCKED_UNKNOWN_ACCEPTANCE_DECISION')){ Add-Err ('source_authority_route_bad:'+ $proof.mind_logic_frame.frame.source_authority_route.result.route) }
  if($proof.mind_logic_frame.frame.source_authority_route.result.boundary.codex_launched -ne $false){ Add-Err 'source_router_launched_codex' }
  if($proof.mind_logic_frame.frame.source_authority_route.result.boundary.web_launched -ne $false){ Add-Err 'source_router_launched_web' }
  if($proof.mind_logic_frame.frame.source_authority_route.result.boundary.action_executed -ne $false){ Add-Err 'source_router_executed_action' }
  if($proof.mind_logic_frame.frame.source_authority_route.result.blocked_now -notcontains 'codex'){ Add-Err 'source_router_codex_not_blocked_now' }
  if($proof.mind_logic_frame.frame.source_authority_route.result.blocked_now -notcontains 'web_external'){ Add-Err 'source_router_web_not_blocked_now' }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'route_request_packet'){ Add-Err 'route_request_packet_missing' }
  if($proof.mind_logic_frame.frame.route_request_packet.status -ne 'PASS_ROUTE_REQUEST_PACKET_V1'){ Add-Err ('route_request_packet_status_bad:'+ $proof.mind_logic_frame.frame.route_request_packet.status) }
  if($proof.mind_logic_frame.frame.route_request_packet.result.request_type -notin @('accepted_pipeline_request_packet','local_memory_then_repo_proof_packet','repo_proof_lookup_packet','repo_or_owner_proof_request_packet','source_ladder_local_start_packet','source_ladder_expand_local_first_packet','blocked_unknown_route_packet')){ Add-Err ('route_request_packet_type_bad:'+ $proof.mind_logic_frame.frame.route_request_packet.result.request_type) }
  if($proof.mind_logic_frame.frame.route_request_packet.result.boundary.codex_launched -ne $false){ Add-Err 'route_packet_launched_codex' }
  if($proof.mind_logic_frame.frame.route_request_packet.result.boundary.web_launched -ne $false){ Add-Err 'route_packet_launched_web' }
  if($proof.mind_logic_frame.frame.route_request_packet.result.boundary.action_executed -ne $false){ Add-Err 'route_packet_executed_action' }
  if($proof.mind_logic_frame.frame.route_request_packet.result.codex_request_packet.allowed_now -ne $false){ Add-Err 'route_packet_codex_allowed_now' }
  if($proof.mind_logic_frame.frame.route_request_packet.result.web_scout_request_packet.allowed_now -ne $false){ Add-Err 'route_packet_web_allowed_now' }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'memory_recall'){ Add-Err 'mind_logic_memory_recall_missing' }
  if($proof.mind_logic_frame.frame.PSObject.Properties.Name -notcontains 'memory_recall_filter'){ Add-Err 'mind_logic_memory_recall_filter_missing' }
  if($proof.mind_logic_frame.frame.memory_recall.status -notin @('PASS_COMPACT_MEMORY_RECALL_V1','BLOCKED_NO_RELEVANT_MEMORY_CELLS_V1')){ Add-Err ('mind_logic_memory_recall_status_bad:'+ $proof.mind_logic_frame.frame.memory_recall.status) }
  if($proof.mind_logic_frame.frame.memory_recall_filter.status -notin @('PASS_MEMORY_RECALL_RELEVANCE_FILTER_V1','BLOCKED_NO_RELEVANT_MEMORY_AFTER_FILTER_V1','DISABLED_BY_CALLER','FILTER_SCRIPT_MISSING')){ Add-Err ('mind_logic_memory_recall_filter_status_bad:'+ $proof.mind_logic_frame.frame.memory_recall_filter.status) }
  if($proof.mind_logic_frame.frame.memory_recall_filter.status -eq 'PASS_MEMORY_RECALL_RELEVANCE_FILTER_V1' -and $proof.mind_logic_frame.frame.memory_recall_filter.accepted_count -lt 1){ Add-Err 'mind_logic_filter_pass_without_accepted' }
  if($proof.mind_logic_frame.frame.memory_recall.status -eq 'PASS_COMPACT_MEMORY_RECALL_V1' -and @($proof.mind_logic_frame.frame.memory_recall.matches).Count -lt 1){ Add-Err 'mind_logic_memory_recall_pass_without_matches' }

  if([string]::IsNullOrWhiteSpace([string]$proof.mind_logic_frame.frame.selected_next_logical_step.step_id)){ Add-Err 'mind_logic_next_step_missing' }
  $steps=@($proof.decision_trace | ForEach-Object { $_.step })
  $mindIndex=[array]::IndexOf($steps,'mind_logic_frame')
  $actionIndex=[array]::IndexOf($steps,'action_candidate_contract')
  if($mindIndex -lt 0){ Add-Err 'decision_trace_missing_mind_logic_frame' }
  if($actionIndex -lt 0){ Add-Err 'decision_trace_missing_action_candidate_contract' }
  if($mindIndex -ge 0 -and $actionIndex -ge 0 -and $mindIndex -gt $actionIndex){ Add-Err 'mind_logic_must_precede_action_candidate' }
  if($proof.next_action_candidate.status -ne 'PASS_AGENT_ACTION_DECISION_PACKET_V1'){ Add-Err ('action_decision_status_bad:'+ $proof.next_action_candidate.status) }
  if($proof.boundary.action_execution_allowed -ne $false){ Add-Err 'action_execution_allowed_not_false' }
  if($proof.boundary.no_action -ne $true){ Add-Err 'no_action_not_true' }
  if($proof.mutation_audit.codex_launched -ne $false){ Add-Err 'codex_launched_not_false' }
  if($proof.mutation_audit.school_started -ne $false){ Add-Err 'school_started_not_false' }
  if($proof.mutation_audit.background_process_started -ne $false){ Add-Err 'background_process_started_not_false' }
  if($proof.mutation_audit.direct_active_memory_write -ne $false){ Add-Err 'direct_active_memory_write_not_false' }
}
$status=if($errors.Count -eq 0){'PASS_AUTONOMOUS_INNER_MOTOR_MIND_LOGIC_WIRING_V1'}else{'FAIL_AUTONOMOUS_INNER_MOTOR_MIND_LOGIC_WIRING_V1'}
$out=[ordered]@{
  schema='autonomous_inner_motor_mind_logic_wiring_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  proof_path=$ProofPath
  mind_logic_status=if($proof){$proof.mind_logic_frame.status}else{$null}
  mind_logic_classification=if($proof){$proof.mind_logic_frame.frame.classification}else{$null}
  mind_logic_next_step=if($proof){$proof.mind_logic_frame.frame.selected_next_logical_step}else{$null}
  mind_logic_deep_source_answer_status=if($proof){$proof.mind_logic_frame.frame.deep_source_answer_request.status}else{$null}
  mind_logic_deep_source_answer_ready=if($proof){$proof.mind_logic_frame.frame.deep_source_answer_request.result.answer_ready}else{$null}
  mind_logic_deep_source_answer_evidence_count=if($proof -and $proof.mind_logic_frame.frame.deep_source_answer_request.result.answer_candidate){@($proof.mind_logic_frame.frame.deep_source_answer_request.result.answer_candidate.evidence_items).Count}else{0}
  mind_logic_deep_source_answer_assimilation_status=if($proof){$proof.mind_logic_frame.frame.deep_source_answer_assimilation.status}else{$null}
  mind_logic_delta_candidate_status=if($proof -and $proof.mind_logic_frame.frame.mind_delta_candidate){$proof.mind_logic_frame.frame.mind_delta_candidate.status}else{$null}
  mind_logic_delta_acceptance_decision=if($proof -and $proof.mind_logic_frame.frame.mind_delta_acceptance_decision.result){$proof.mind_logic_frame.frame.mind_delta_acceptance_decision.result.decision}else{$null}
  source_authority_route=if($proof -and $proof.mind_logic_frame.frame.source_authority_route.result){$proof.mind_logic_frame.frame.source_authority_route.result.route}else{$null}
  route_request_packet_type=if($proof -and $proof.mind_logic_frame.frame.route_request_packet.result){$proof.mind_logic_frame.frame.route_request_packet.result.request_type}else{$null}
  mind_logic_hypothesis_test_status=if($proof){$proof.mind_logic_frame.frame.hypothesis_test_result.status}else{$null}
  mind_logic_strongest_hypothesis=if($proof){$proof.mind_logic_frame.frame.hypothesis_test_result.result.strongest_hypothesis}else{$null}
  mind_logic_contradiction_resolution_status=if($proof){$proof.mind_logic_frame.frame.contradiction_resolution.status}else{$null}
  mind_logic_contradiction_resolution_decision=if($proof){$proof.mind_logic_frame.frame.contradiction_resolution.result.decision}else{$null}
  mind_logic_contradiction_resolution_step=if($proof){$proof.mind_logic_frame.frame.contradiction_resolution.result.selected_resolution_step.step_id}else{$null}
  mind_logic_memory_recall_status=if($proof){$proof.mind_logic_frame.frame.memory_recall.status}else{$null}
  mind_logic_memory_recall_match_count=if($proof){@($proof.mind_logic_frame.frame.memory_recall.matches).Count}else{$null}
  mind_logic_memory_recall_filter_status=if($proof){$proof.mind_logic_frame.frame.memory_recall_filter.status}else{$null}
  mind_logic_memory_recall_filter_accepted_count=if($proof){$proof.mind_logic_frame.frame.memory_recall_filter.accepted_count}else{$null}
  action_decision_status=if($proof){$proof.next_action_candidate.status}else{$null}
  action_execution_allowed=if($proof){$proof.boundary.action_execution_allowed}else{$null}
  validates_order='mind_logic_frame_before_action_candidate'
  errors=@($errors)
}
$proofOut='tests/self_development/AUTONOMOUS_INNER_MOTOR_MIND_LOGIC_WIRING_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofOut -Parent) | Out-Null
$out | ConvertTo-Json -Depth 80 | Set-Content $proofOut -Encoding UTF8
Write-Host "VALIDATION_STATUS=$status"
Write-Host "PROOF_OUT=$proofOut"
Write-Host "MIND_LOGIC_STATUS=$($out.mind_logic_status)"
Write-Host "ACTION_EXECUTION_ALLOWED=$($out.action_execution_allowed)"
if($errors.Count -gt 0){ $errors|ForEach-Object{Write-Host "ERROR=$_"}; exit 1 }
