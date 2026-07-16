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
  if(@($proof.mind_logic_frame.frame.source_ladder).Count -lt 4){ Add-Err 'mind_logic_source_ladder_too_short' }
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
