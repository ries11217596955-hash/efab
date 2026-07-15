param(
  [string]$ProofPath='operations/autonomous_inner_motor/proofs/AUTONOMOUS_INNER_MOTOR_SELF_DIRECTED_THINKING_PROOF_20260715.json'
)
$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message){ $script:errors.Add($Message) | Out-Null }
function Read-Json([string]$Path){
  if(-not(Test-Path $Path)){ Add-Err "missing:$Path"; return $null }
  try { return (Get-Content $Path -Raw | ConvertFrom-Json) }
  catch { Add-Err "bad_json:$($Path):$($_.Exception.Message)"; return $null }
}
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=20){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth $Depth
  $lines=@($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
  while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){$lines=@();break}; $lines=@($lines[0..($lines.Count-2)]) }
  $clean=($lines -join "`n") + "`n"
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $full=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($full,$clean,$utf8NoBom)
}
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$policyPath='operations/autonomous_inner_motor/motor_policy.json'
$specPath='operations/autonomous_inner_motor/AUTONOMOUS_INNER_MOTOR_ORGAN_SPEC.md'
$proof=Read-Json $ProofPath
$policy=Read-Json $policyPath
$runnerText=if(Test-Path $runner){ Get-Content $runner -Raw } else { Add-Err "missing:$runner"; '' }
$specText=if(Test-Path $specPath){ Get-Content $specPath -Raw } else { Add-Err "missing:$specPath"; '' }
if($runnerText -notlike "*[string]`$Question=''*" -and $runnerText -notlike "*`$Question=''*"){ Add-Err 'runner_question_default_not_empty' }
if($runnerText -notlike '*SeedSource*SelfBuild*'){ Add-Err 'runner_seed_source_selfbuild_missing' }
if($runnerText -notlike '*Get-SelfBuildState*'){ Add-Err 'runner_self_build_state_reader_missing' }
if($runnerText -notlike '*New-InternalSelfGoal*'){ Add-Err 'runner_internal_goal_builder_missing' }
if($runnerText -notlike '*does_not_wait_for_owner_query*'){ Add-Err 'runner_owner_wait_law_missing' }
if($specText -notlike '*Self-directed thinking law*'){ Add-Err 'spec_self_directed_law_missing' }
if($null -ne $policy){
  if($policy.owner_query_required -ne $false){ Add-Err 'policy_owner_query_required_not_false' }
  if($policy.self_directed_thinking.enabled -ne $true){ Add-Err 'policy_self_directed_thinking_not_enabled' }
  if($policy.self_directed_thinking.does_not_wait_for_owner_query -ne $true){ Add-Err 'policy_waits_for_owner_query' }
  if(-not(@($policy.self_directed_thinking.stage_order) -contains 'child_agent_production')){ Add-Err 'policy_child_agent_stage_missing' }
}
if($null -ne $proof){
  if($proof.owner_query_required -ne $false){ Add-Err 'proof_owner_query_required_not_false' }
  if($proof.internal_goal.source -ne 'SELF_BUILD_INTERNAL_SEED'){ Add-Err "proof_internal_goal_source_bad:$($proof.internal_goal.source)" }
  if($proof.internal_goal.goal -notlike '*thinking capacity*'){ Add-Err 'proof_internal_goal_not_thinking_capacity' }
  if($proof.internal_goal.second_stage -notlike '*self_build*' -and $proof.internal_goal.second_stage -notlike '*self-build*'){ Add-Err 'proof_second_stage_self_build_missing' }
  if($proof.internal_goal.third_stage -notlike '*child_agent*' -and $proof.internal_goal.third_stage -notlike '*child-agent*'){ Add-Err 'proof_third_stage_child_agent_missing' }
  if($proof.selected_next_path.path -ne 'build_self_directed_thinking_cycle_and_gap_selector_wiring_v1'){ Add-Err "proof_selected_path_bad:$($proof.selected_next_path.path)" }
  if($proof.memory_state.unchanged -ne $true){ Add-Err 'proof_memory_not_unchanged' }
  if($proof.mutation_audit.codex_launched -ne $false){ Add-Err 'proof_codex_launched' }
  if($proof.mutation_audit.web_research_performed -ne $false){ Add-Err 'proof_web_research_performed' }
  if($proof.stop_reason -ne 'PROTECTIVE_CHECKPOINT_THINKING_ONLY'){ Add-Err "proof_stop_reason_bad:$($proof.stop_reason)" }
  if(@($proof.cycles).Count -lt 7){ Add-Err 'proof_cycles_less_than_7' }
}
$status=if($errors.Count -eq 0){'PASS_AUTONOMOUS_INNER_MOTOR_SELF_DIRECTED_THINKING_V1'}else{'FAIL_AUTONOMOUS_INNER_MOTOR_SELF_DIRECTED_THINKING_V1'}
$out=[ordered]@{
  schema='autonomous_inner_motor_self_directed_thinking_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  proof_path=$ProofPath
  boundary=[ordered]@{
    validates_no_owner_query_wait=$true
    validates_self_build_direction=$true
    validates_future_child_agent_direction=$true
    runs_agent_actions=$false
    mutates_active_memory=$false
  }
  errors=@($errors)
}
$proofOut='tests/self_development/AUTONOMOUS_INNER_MOTOR_SELF_DIRECTED_THINKING_V1_PROOF.json'
Write-CleanJson $proofOut $out 20
Write-Host "STATUS=$status"
Write-Host "PROOF_OUT=$proofOut"
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }
