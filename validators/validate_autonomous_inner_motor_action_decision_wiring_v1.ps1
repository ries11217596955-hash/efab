param([string]$ProofPath)
$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Read-Json([string]$PathToRead){
  if(-not(Test-Path $PathToRead)){ Add-Err "missing_json:${PathToRead}"; return $null }
  try { return Get-Content $PathToRead -Raw | ConvertFrom-Json } catch { Add-Err "bad_json:${PathToRead}:$($_.Exception.Message)"; return $null }
}
if([string]::IsNullOrWhiteSpace($ProofPath)){
  $latest=Get-ChildItem '.runtime/autonomous_inner_motor' -Filter 'SANDBOX_EXPLORATION_PROOF.json' -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($latest){ $ProofPath=$latest.FullName.Substring((Resolve-Path '.').Path.Length+1).Replace('\','/') }
}
$proof=Read-Json $ProofPath
if($proof){
  if($proof.boundary.action_decision_candidate_generated -ne $true){ Add-Err 'action_decision_candidate_generated_not_true' }
  if($proof.boundary.action_execution_allowed -ne $false){ Add-Err 'action_execution_allowed_not_false' }
  if($proof.boundary.no_action -ne $true){ Add-Err 'boundary_no_action_not_true' }
  if($proof.next_action_candidate.status -ne 'PASS_AGENT_ACTION_DECISION_PACKET_V1'){ Add-Err ('next_action_status_bad:'+ $proof.next_action_candidate.status) }
  if($proof.next_action_candidate.packet.selected_action.action_id -ne 'ACTION_CONTRACT_V1'){ Add-Err 'selected_action_id_bad' }
  if($proof.next_action_candidate.packet.selected_action.execution_allowed -ne $false){ Add-Err 'selected_action_execution_allowed_not_false' }
  if(@($proof.next_action_candidate.packet.selected_action.validator_refs).Count -lt 1){ Add-Err 'selected_action_validator_refs_missing' }
  if([string]::IsNullOrWhiteSpace([string]$proof.next_action_candidate.packet.selected_action.rollback_plan)){ Add-Err 'selected_action_rollback_missing' }
  if($proof.next_action_candidate.packet.safety_boundary.action_execution_allowed -ne $false){ Add-Err 'packet_safety_boundary_allows_execution' }
  if($proof.mutation_audit.codex_launched -ne $false){ Add-Err 'codex_launched_not_false' }
  if($proof.mutation_audit.school_started -ne $false){ Add-Err 'school_started_not_false' }
  if($proof.mutation_audit.background_process_started -ne $false){ Add-Err 'background_process_started_not_false' }
  if($proof.mutation_audit.direct_active_memory_write -ne $false){ Add-Err 'direct_active_memory_write_not_false' }
}
$status=if($errors.Count -eq 0){'PASS_AUTONOMOUS_INNER_MOTOR_ACTION_DECISION_WIRING_V1'}else{'FAIL_AUTONOMOUS_INNER_MOTOR_ACTION_DECISION_WIRING_V1'}
$out=[ordered]@{
  schema='autonomous_inner_motor_action_decision_wiring_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  proof_path=$ProofPath
  selected_action=if($proof){$proof.next_action_candidate.packet.selected_action}else{$null}
  action_execution_allowed=if($proof){$proof.boundary.action_execution_allowed}else{$null}
  action_decision_status=if($proof){$proof.next_action_candidate.status}else{$null}
  boundary=[ordered]@{ validates_candidate_generated=$true; validates_execution_blocked=$true; validates_validator_refs=$true; validates_rollback_required=$true; validates_no_codex_school_background=$true }
  errors=@($errors)
}
$proofOut='tests/self_development/AUTONOMOUS_INNER_MOTOR_ACTION_DECISION_WIRING_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofOut -Parent) | Out-Null
$out | ConvertTo-Json -Depth 50 | Set-Content $proofOut -Encoding UTF8
Write-Host "VALIDATION_STATUS=$status"
Write-Host "PROOF_OUT=$proofOut"
Write-Host "ACTION_EXECUTION_ALLOWED=$($out.action_execution_allowed)"
if($errors.Count -gt 0){ $errors|ForEach-Object{Write-Host "ERROR=$_"}; exit 1 }
