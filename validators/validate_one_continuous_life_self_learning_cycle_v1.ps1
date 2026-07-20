$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$nb='AGENT_BUILDER_SELF_NOTEBOOK.md'
$report='operations/autonomous_inner_motor/reports/ONE_CONTINUOUS_LIFE_SELF_LEARNING_CYCLE_V1.json'
foreach($p in @($nb,$report)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$nbText=if(Test-Path $nb){Get-Content $nb -Raw}else{''}
foreach($needle in @('ONE_CONTINUOUS_LIFE_SELF_LEARNING_CYCLE','one continuous life','decompose unknown X','live atom candidate','atom-candidate-before-accepted-atom','SHORT_TERM_MIND_STATE_V1 must be designed as RAM-ready living state')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$r=$null
if(Test-Path $report){$r=Get-Content $report -Raw|ConvertFrom-Json}
if($r){
  if($r.status -ne 'PASS_ONE_CONTINUOUS_LIFE_SELF_LEARNING_CYCLE_V1'){ Add-Err "status_mismatch:$($r.status)" }
  foreach($step in @('wake/self-orientation','decompose_X_into_X1_to_Xn','create_live_atom_candidate_in_short_term_mind_state','use_candidate_in_next_decision_immediately','promote_to_compact_memory_only_after_validation')){ if(@($r.strengthened_architecture) -notcontains $step){ Add-Err "architecture_missing:$step" } }
  foreach($layer in @('ram_life','short_term_mind_state','compact_memory','files')){ if(-not $r.memory_layers.PSObject.Properties[$layer]){ Add-Err "layer_missing:$layer" } }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
  if($r.boundary.ram_migrated -ne $false){ Add-Err 'ram_migrated_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_one_continuous_life_self_learning_cycle_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|school|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_ONE_CONTINUOUS_LIFE_SELF_LEARNING_CYCLE_V1'}else{'FAIL_ONE_CONTINUOUS_LIFE_SELF_LEARNING_CYCLE_V1'}
$proof=[ordered]@{
  schema='one_continuous_life_self_learning_cycle_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  notebook=$nb
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{architecture_note_only=$true; runtime_launched=$false; active_memory_mutated=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false; ram_migrated=$false}
}
WJson 'tests/self_development/ONE_CONTINUOUS_LIFE_SELF_LEARNING_CYCLE_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
