$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$reportPath='operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_B_STATE_MEMORY_LAYERS_V1.json'
if(-not(Test-Path $reportPath)){ Add-Err "missing:$reportPath" }
$r=$null
if(Test-Path $reportPath){ $r=Get-Content $reportPath -Raw | ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_RAM_LIFE_AUDIT_B_STATE_MEMORY_LAYERS_V1'){ Add-Err "status_mismatch:$($r.status)" }
  $requiredLayers=@('immutable_life_orientation_card','active_compact_memory','ram_state','cycle_scratch','proof','checkpoint','archive','raw_debug')
  $layerNames=@($r.memory_layers.PSObject.Properties.Name)
  foreach($layer in $requiredLayers){ if($layerNames -notcontains $layer){ Add-Err "missing_layer:$layer" } }
  if($r.memory_layers.immutable_life_orientation_card.mutability -ne 'read_only_during_life'){ Add-Err 'orientation_card_not_read_only' }
  if($r.memory_layers.immutable_life_orientation_card.update_authority -notlike '*operator*'){ Add-Err 'orientation_update_authority_not_operator' }
  if($r.memory_layers.active_compact_memory.mutability -notlike '*governed acceptance*'){ Add-Err 'compact_memory_not_gated' }
  if($r.memory_layers.ram_state.max_size_policy -notlike '*budget*'){ Add-Err 'ram_state_budget_missing' }
  if($r.memory_layers.cycle_scratch.retention -notlike '*discard*'){ Add-Err 'cycle_scratch_not_discard' }
  if($r.memory_layers.proof.policy -ne 'compact proof, not memory layer'){ Add-Err 'proof_policy_mismatch' }
  if($r.memory_layers.raw_debug.retention -notlike '*off by default*'){ Add-Err 'raw_debug_not_off_by_default' }
  foreach($anti in @('life orientation card as diary','proof files as memory','raw debug as context','loading all compact memory into every cycle','unbounded RAM state','auto-updating orientation card without operator acceptance')){ if(@($r.anti_patterns) -notcontains $anti){ Add-Err "missing_antipattern:$anti" } }
  foreach($flag in @('orientation_card_read_only_during_life','compact_memory_grows_only_through_gates','cycle_scratch_discarded_by_default','proof_is_not_memory','raw_debug_off_by_default','ram_state_budget_required','no_layer_allowed_to_become_diary')){ if($r.acceptance.$flag -ne $true){ Add-Err "acceptance_false:$flag" } }
  if($r.boundary.audit_only -ne $true){ Add-Err 'audit_only_not_true' }
  if($r.boundary.continuous_runtime_launched -ne $false){ Add-Err 'continuous_runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
  if($r.boundary.runtime_deleted -ne $false){ Add-Err 'runtime_deleted_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '\s-Command\s' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node.*codex|school|continuous' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_RAM_LIFE_AUDIT_B_STATE_MEMORY_LAYERS_V1'}else{'FAIL_RAM_LIFE_AUDIT_B_STATE_MEMORY_LAYERS_V1'}
$proof=[ordered]@{
  schema='ram_life_audit_b_state_memory_layers_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$reportPath
  required_layers=@('immutable_life_orientation_card','active_compact_memory','ram_state','cycle_scratch','proof','checkpoint','archive','raw_debug')
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{ audit_only=$true; continuous_runtime_launched=$false; active_memory_mutated=$false; runtime_deleted=$false; codex_launched=$false; web_launched=$false; school_launched=$false }
}
WJson 'tests/self_development/RAM_LIFE_AUDIT_B_STATE_MEMORY_LAYERS_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
