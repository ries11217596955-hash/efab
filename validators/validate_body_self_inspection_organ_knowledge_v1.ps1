$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 50) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$card='operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json'
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
if(-not(Test-Path $card)){ Add-Err 'missing_body_self_inspection_knowledge_card' }
if(-not(Test-Path $runner)){ Add-Err 'missing_aimo_runner' }
$c=$null
if(Test-Path $card){ $c=Get-Content $card -Raw|ConvertFrom-Json }
if($c){
  if($c.status -ne 'KNOWN_ORGAN_AVAILABLE_NOT_WIRED'){ Add-Err "knowledge_status_wrong:$($c.status)" }
  if($c.organ_id -ne 'BODY_SELF_INSPECTION_CIRCUIT_V1'){ Add-Err 'organ_id_wrong' }
  if($c.router_frontier_id -ne 'body_self_inspection_signal'){ Add-Err 'router_frontier_wrong' }
  foreach($p in @($c.invocation_entrypoint,$c.signal_entrypoint,$c.validator,$c.proof,$c.integration_plan,$c.canonical_launch_quarantine)){ if(-not(Test-Path $p)){ Add-Err "knowledge_ref_missing:$p" } }
  if($c.boundary.knowledge_only -ne $true){ Add-Err 'knowledge_only_boundary_missing' }
  if($c.boundary.body_inspection_invoked -ne $false){ Add-Err 'body_invoked_boundary_should_be_false' }
  if(@($c.forbidden_use) -notcontains 'run_every_cycle'){ Add-Err 'forbidden_use_run_every_cycle_missing' }
}
$runnerText=''
if(Test-Path $runner){ $runnerText=Get-Content $runner -Raw }
foreach($needle in @('Get-BodySelfInspectionOrganKnowledge','BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json','known_organs','known_body_self_inspection_organ_available_not_wired','body_self_inspection_circuit_v1')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$status=if($errors.Count -eq 0){'PASS_BODY_SELF_INSPECTION_ORGAN_KNOWLEDGE_V1'}else{'FAIL_BODY_SELF_INSPECTION_ORGAN_KNOWLEDGE_V1'}
$proof=[ordered]@{
  schema='body_self_inspection_organ_knowledge_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  knowledge_card=$card
  runner=$runner
  errors=@($errors)
  boundary=[ordered]@{ validator_did_not_start_agent_life=$true; body_inspection_invoked=$false; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; repair_executed=$false }
}
WJson 'tests/self_development/BODY_SELF_INSPECTION_ORGAN_KNOWLEDGE_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
