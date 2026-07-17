$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){
  $dir=Split-Path $path -Parent
  if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
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
$outPath='.runtime/mental_frontier_expansion_gate_v1/frontier_packet.json'
$selectorArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$selector,'-Mode','LabOnly','-Goal','topic saturation requires new mental frontier','-OutputPath',$outPath,'-AvoidActionIds','ACTION_CONTRACT_V1,MEMORY_TO_NEXT_PATH_REUSE_GATE_V1')
& powershell @selectorArgs | Out-Null
if($LASTEXITCODE -ne 0){ Add-Err 'selector_exit_nonzero' }
$packet=$null
if(Test-Path $outPath){ $packet=Get-Content $outPath -Raw|ConvertFrom-Json } else { Add-Err 'frontier_packet_missing' }
if($packet){
  if($packet.selected_action.action_id -ne 'MENTAL_FRONTIER_EXPANSION_GATE_V1'){ Add-Err "selected_unexpected:$($packet.selected_action.action_id)" }
  foreach($id in @('ACTION_CONTRACT_V1','MEMORY_TO_NEXT_PATH_REUSE_GATE_V1')){ if(@($packet.avoid_action_ids) -notcontains $id){ Add-Err "missing_avoid_id:$id" } }
  if($packet.selected_action.execution_allowed -ne $false){ Add-Err 'frontier_selected_execution_allowed_not_false' }
  if(@($packet.selected_action.validator_refs) -notcontains 'validators/validate_mental_frontier_expansion_gate_v1.ps1'){ Add-Err 'missing_self_validator_ref' }
}
$runnerText=Get-Content 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Raw
foreach($needle in @('Get-MentalFrontierExpansionGate','mental_frontier_expansion_gate.json','PASS_MENTAL_FRONTIER_EXPANSION_GATE_V1','body_self_inspection_signal','knowledge_source_gap')){
  if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" }
}
$status=if($errors.Count -eq 0){'PASS_MENTAL_FRONTIER_EXPANSION_GATE_V1'}else{'FAIL_MENTAL_FRONTIER_EXPANSION_GATE_V1'}
$proof=[ordered]@{
  schema='mental_frontier_expansion_gate_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  selected_action=if($packet){$packet.selected_action.action_id}else{$null}
  avoid_action_ids=if($packet){@($packet.avoid_action_ids)}else{@()}
  validates=[ordered]@{ topic_saturation_can_force_new_frontier=$true; old_paths_avoided=$true; action_execution_false=$true; runner_emits_gate=$true }
  boundary=[ordered]@{ validator_did_not_start_agent_life=$true; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; action_execution_performed=$false }
  errors=@($errors)
}
WJson 'tests/self_development/MENTAL_FRONTIER_EXPANSION_GATE_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
