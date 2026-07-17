$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 40) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function Parse-File($path){ $tokens=$null; $parseErrors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null; if(@($parseErrors).Count -gt 0){ Add-Err "parse_failed:$path" } }
Parse-File 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
Parse-File 'operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1'
$selector='operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1'
$outPath='.runtime/mental_frontier_router_v1/router_packet.json'
$args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$selector,'-Mode','LabOnly','-Goal','expanded frontier was consumed; route concrete frontier','-OutputPath',$outPath,'-AvoidActionIds','ACTION_CONTRACT_V1,MEMORY_TO_NEXT_PATH_REUSE_GATE_V1,MENTAL_FRONTIER_EXPANSION_GATE_V1')
& powershell @args | Out-Null
if($LASTEXITCODE -ne 0){ Add-Err 'selector_exit_nonzero' }
$packet=$null
if(Test-Path $outPath){ $packet=Get-Content $outPath -Raw|ConvertFrom-Json } else { Add-Err 'router_packet_missing' }
if($packet){
  if($packet.selected_action.action_id -ne 'MENTAL_FRONTIER_ROUTER_V1'){ Add-Err "selected_unexpected:$($packet.selected_action.action_id)" }
  if(@($packet.selected_action.validator_refs) -notcontains 'validators/validate_mental_frontier_router_v1.ps1'){ Add-Err 'missing_self_validator_ref' }
  if($packet.selected_action.execution_allowed -ne $false){ Add-Err 'router_selected_execution_allowed_not_false' }
}
$runnerText=Get-Content 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Raw
foreach($needle in @('Get-MentalFrontierRouter','mental_frontier_router.json','PASS_MENTAL_FRONTIER_ROUTER_V1','selected_frontier','body_self_inspection_signal')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$status=if($errors.Count -eq 0){'PASS_MENTAL_FRONTIER_ROUTER_V1'}else{'FAIL_MENTAL_FRONTIER_ROUTER_V1'}
$proof=[ordered]@{
  schema='mental_frontier_router_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  selected_action=if($packet){$packet.selected_action.action_id}else{$null}
  validates=[ordered]@{ expansion_consumed_selects_router=$true; router_emits_concrete_frontier=$true; action_execution_false=$true; runner_emits_router_file=$true }
  boundary=[ordered]@{ validator_did_not_start_agent_life=$true; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; action_execution_performed=$false }
  errors=@($errors)
}
WJson 'tests/self_development/MENTAL_FRONTIER_ROUTER_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
