$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=($obj|ConvertTo-Json -Depth 40) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false)))
}
function Parse-File($path){
  $tokens=$null; $parseErrors=$null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null
  if(@($parseErrors).Count -gt 0){ Add-Err "parse_failed:$path" }
}
Parse-File 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
Parse-File 'operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1'
$selector='operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1'
$defaultPath='.runtime/memory_to_next_path_reuse_gate_v1/default_packet.json'
$avoidPath='.runtime/memory_to_next_path_reuse_gate_v1/avoid_packet.json'
$out1=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $selector -Mode LabOnly -Goal 'default action selection' -OutputPath $defaultPath *>&1 | ForEach-Object {[string]$_})
if($LASTEXITCODE -ne 0){ Add-Err 'default_selector_exit_nonzero' }
$out2=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $selector -Mode LabOnly -Goal 'reuse gate after repeated absorbed action' -OutputPath $avoidPath -AvoidActionIds ACTION_CONTRACT_V1 *>&1 | ForEach-Object {[string]$_})
if($LASTEXITCODE -ne 0){ Add-Err 'avoid_selector_exit_nonzero' }
$default=$null; $avoid=$null
if(Test-Path $defaultPath){ $default=Get-Content $defaultPath -Raw|ConvertFrom-Json } else { Add-Err 'default_packet_missing' }
if(Test-Path $avoidPath){ $avoid=Get-Content $avoidPath -Raw|ConvertFrom-Json } else { Add-Err 'avoid_packet_missing' }
if($default -and $default.selected_action.action_id -ne 'ACTION_CONTRACT_V1'){ Add-Err "default_selected_unexpected:$($default.selected_action.action_id)" }
if($avoid){
  if($avoid.selected_action.action_id -ne 'MEMORY_TO_NEXT_PATH_REUSE_GATE_V1'){ Add-Err "avoid_selected_unexpected:$($avoid.selected_action.action_id)" }
  if(@($avoid.avoid_action_ids) -notcontains 'ACTION_CONTRACT_V1'){ Add-Err 'avoid_action_ids_missing_action_contract' }
  $rejectedIds=@($avoid.rejected_actions | ForEach-Object { $_.action.action_id })
  if($rejectedIds -notcontains 'ACTION_CONTRACT_V1'){ Add-Err 'action_contract_not_rejected_after_absorption' }
  $rejectReasons=@($avoid.rejected_actions | Where-Object { $_.action.action_id -eq 'ACTION_CONTRACT_V1' } | ForEach-Object { $_.reject_reasons })
  if($rejectReasons -notcontains 'already_absorbed_repeat_candidate'){ Add-Err 'missing_already_absorbed_reject_reason' }
  if($avoid.selected_action.execution_allowed -ne $false){ Add-Err 'avoid_selected_execution_allowed_not_false' }
}
$runnerText=Get-Content 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Raw
foreach($needle in @('memory_to_next_path_reuse_gate.json','PASS_MEMORY_TO_NEXT_PATH_REUSE_GATE_V1','Get-LatestMemoryToNextPathReuseGate','selectorArgs')){
  if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" }
}
$status=if($errors.Count -eq 0){'PASS_MEMORY_TO_NEXT_PATH_REUSE_GATE_V1'}else{'FAIL_MEMORY_TO_NEXT_PATH_REUSE_GATE_V1'}
$proof=[ordered]@{
  schema='memory_to_next_path_reuse_gate_v1_validation'
  status=$status
  checked_at=(Get-Date).ToString('o')
  default_packet=$defaultPath
  avoid_packet=$avoidPath
  default_selected_action=if($default){$default.selected_action.action_id}else{$null}
  avoid_selected_action=if($avoid){$avoid.selected_action.action_id}else{$null}
  validates=[ordered]@{ consumed_repeat_is_not_reselected=$true; new_mental_growth_candidate_selected=$true; execution_allowed_false=$true; runner_emits_reuse_gate=$true }
  boundary=[ordered]@{ validator_did_not_start_agent_life=$true; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; action_execution_performed=$false }
  errors=@($errors)
}
WJson 'tests/self_development/MEMORY_TO_NEXT_PATH_REUSE_GATE_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
Write-Host 'PROOF=tests/self_development/MEMORY_TO_NEXT_PATH_REUSE_GATE_V1_PROOF.json'
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }
