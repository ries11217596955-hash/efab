$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function Clamp01([double]$x){ if($x -lt 0){return 0.0}; if($x -gt 1){return 1.0}; return [math]::Round($x,4)}
$policyPath='contracts/living_loop/PRIORITY_POLICY_CONTRACT_V1.json'
$outPath='reports/self_development/PRIORITY_POLICY_CONTRACT_V1_SCORED_OPTIONS.json'
$reportPath='reports/self_development/PRIORITY_POLICY_CONTRACT_V1_REPORT.json'
$proofPath='tests/self_development/PRIORITY_POLICY_CONTRACT_V1_PROOF.json'
foreach($p in @('contracts/living_loop/PRIORITY_POLICY_CONTRACT_V1.md',$policyPath,$outPath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_priority_intent_selection_model_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'BASE_PRIORITY_MODEL_VALIDATION_FAILED'
$policy=Get-Content $policyPath -Raw|ConvertFrom-Json
$out=Get-Content $outPath -Raw|ConvertFrom-Json
$report=Get-Content $reportPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($out.status -eq 'PASS_PRIORITY_POLICY_CONTRACT_V1_SCORED_OPTIONS') 'SCORED_STATUS_BAD'
Assert ($report.status -eq 'PASS_PRIORITY_POLICY_CONTRACT_V1') 'REPORT_STATUS_BAD'
Assert ($proof.status -eq 'PASS_PRIORITY_POLICY_CONTRACT_V1') 'PROOF_STATUS_BAD'
$positive=@($policy.mandatory_positive_components); $penalty=@($policy.mandatory_penalty_components)
foreach($w in @($positive)){Assert ($policy.positive_weights.PSObject.Properties.Name -contains $w) "POS_WEIGHT_MISSING:$w"}
foreach($w in @($penalty)){Assert ($policy.penalty_weights.PSObject.Properties.Name -contains $w) "PEN_WEIGHT_MISSING:$w"}
$options=@($out.ranked_options)
Assert ($options.Count -ge 7) 'OPTIONS_TOO_FEW'
foreach($mandatory in @($policy.mandatory_options)){Assert (@($options|Where-Object{$_.option_id -eq $mandatory}).Count -eq 1) "MANDATORY_OPTION_MISSING:$mandatory"}
$last=999.0
foreach($opt in $options){
  Assert ([double]$opt.final_score -le $last) "RANKING_NOT_DESC:$($opt.option_id)"; $last=[double]$opt.final_score
  foreach($c in @($positive+$penalty)){Assert ($opt.score_components.PSObject.Properties.Name -contains $c) "COMPONENT_MISSING:$($opt.option_id):${c}"; $val=[double]$opt.score_components.$c; Assert ($val -ge 0 -and $val -le 1) "COMPONENT_OUT_OF_RANGE:$($opt.option_id):${c}:${val}"}
  $pos=0.0; foreach($c in $positive){$pos += [double]$policy.positive_weights.$c * [double]$opt.score_components.$c}
  $pen=0.0; foreach($c in $penalty){$pen += [double]$policy.penalty_weights.$c * [double]$opt.score_components.$c}
  $expected=Clamp01 ($pos - ([double]$policy.penalty_multiplier * $pen) + [double]$policy.baseline)
  Assert ([math]::Abs([double]$opt.positive_score - [math]::Round($pos,4)) -le 0.0001) "POS_SCORE_BAD:$($opt.option_id)"
  Assert ([math]::Abs([double]$opt.penalty_score - [math]::Round($pen,4)) -le 0.0001) "PEN_SCORE_BAD:$($opt.option_id)"
  Assert ([math]::Abs([double]$opt.final_score - $expected) -le 0.0001) "FINAL_SCORE_FORMULA_BAD:$($opt.option_id):expected=$expected actual=$($opt.final_score)"
  Assert ($opt.execution_allowed -eq $false) "EXECUTION_OVERCLAIM:$($opt.option_id)"
  Assert ($opt.mutation_authorized -eq $false) "MUTATION_OVERCLAIM:$($opt.option_id)"
  Assert ($opt.runtime_ready -eq $false) "RUNTIME_OVERCLAIM:$($opt.option_id)"
  Assert ($opt.live_ready -eq $false) "LIVE_OVERCLAIM:$($opt.option_id)"
  Assert ($opt.autonomous_runtime -eq $false) "AUTONOMOUS_OVERCLAIM:$($opt.option_id)"
}
Assert ($out.selected_recommendation.option_id -eq 'continue_non_executing_brain_build') 'SELECTED_OPTION_UNEXPECTED'
Assert ($out.summary.action_planner_scored -eq $true) 'ACTION_PLANNER_NOT_SCORED'
Assert ($out.summary.action_planner_selected -eq $false) 'ACTION_PLANNER_SELECTED'
# Negative fixtures must fail policy checks.
$missing=Get-Content 'tests/self_development/negative_fixtures/PRIORITY_POLICY_MISSING_COMPONENT_NEGATIVE.json' -Raw|ConvertFrom-Json
Assert (-not ($missing.option.score_components.PSObject.Properties.Name -contains 'strategic_value')) 'NEGATIVE_MISSING_COMPONENT_NOT_NEGATIVE'
$forced=Get-Content 'tests/self_development/negative_fixtures/PRIORITY_POLICY_FORCED_ACTION_PLANNER_NEGATIVE.json' -Raw|ConvertFrom-Json
Assert ($forced.selected_option.option_id -eq 'build_action_planner_later' -and [double]$forced.selected_option.score_components.forced_pipeline_penalty -gt 0.35) 'NEGATIVE_FORCED_PLANNER_NOT_NEGATIVE'
$live=Get-Content 'tests/self_development/negative_fixtures/PRIORITY_POLICY_LIVE_WITHOUT_AUTHORITY_NEGATIVE.json' -Raw|ConvertFrom-Json
Assert ($live.selected_option.option_id -eq 'activation_or_live_gate_later' -and $live.selected_option.live_ready -eq $true) 'NEGATIVE_LIVE_NOT_NEGATIVE'
Assert ($proof.formula_weights_present -eq $true) 'PROOF_FORMULA_WEIGHTS_BAD'
Assert ($proof.all_mandatory_components_present -eq $true) 'PROOF_COMPONENTS_BAD'
Assert ($proof.same_formula_applied_to_all_options -eq $true) 'PROOF_SAME_FORMULA_BAD'
Assert ($proof.manual_scores_forbidden -eq $true) 'PROOF_MANUAL_SCORE_BAD'
Assert ($proof.no_forced_next_step_enforced -eq $true) 'PROOF_NO_FORCED_BAD'
Assert ($proof.recommendation_not_command -eq $true) 'PROOF_RECOMMENDATION_BAD'
Write-Host 'VALIDATION_PASS=PASS_PRIORITY_POLICY_CONTRACT_V1'
Write-Host "OPTIONS=$($options.Count)"
Write-Host "SELECTED_OPTION=$($out.selected_recommendation.option_id)"
Write-Host 'FORMULA_VALIDATED=true'
Write-Host 'NEGATIVE_FIXTURES_VALIDATED=true'
Write-Host 'RECOMMENDATION_NOT_COMMAND=true'

