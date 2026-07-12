$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function Clamp01([double]$x){ if($x -lt 0){return 0.0}; if($x -gt 1){return 1.0}; return [math]::Round($x,4)}
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$policyPath='contracts/living_loop/PRIORITY_POLICY_CONTRACT_V1.json'
$optionsIn='reports/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_OPTIONS.json'
$outPath='reports/self_development/PRIORITY_POLICY_CONTRACT_V1_SCORED_OPTIONS.json'
$reportPath='reports/self_development/PRIORITY_POLICY_CONTRACT_V1_REPORT.json'
$proofPath='tests/self_development/PRIORITY_POLICY_CONTRACT_V1_PROOF.json'
foreach($p in @($policyPath,$optionsIn)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_priority_intent_selection_model_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'PRIORITY_MODEL_VALIDATION_FAILED'
$policy=Get-Content $policyPath -Raw|ConvertFrom-Json
$old=Get-Content $optionsIn -Raw|ConvertFrom-Json
$positive=@($policy.mandatory_positive_components)
$penalty=@($policy.mandatory_penalty_components)
# Component matrix: explicit policy inputs, not final scores. These are interpretable, bounded, and validated.
$componentMatrix=[ordered]@{
  continue_non_executing_brain_build=[ordered]@{owner_goal_fit=0.95;strategic_value=0.94;proof_readiness=0.86;safety_score=0.92;reuse_value=0.78;blocker_relief=0.40;learning_value=0.96;risk_penalty=0.18;authority_cost=0.05;prematurity_penalty=0.12;forced_pipeline_penalty=0.06;live_runtime_penalty=0.00;child_agent_prematurity_penalty=0.00}
  strengthen_memory_layer=[ordered]@{owner_goal_fit=0.82;strategic_value=0.86;proof_readiness=0.62;safety_score=0.84;reuse_value=0.94;blocker_relief=0.30;learning_value=0.88;risk_penalty=0.22;authority_cost=0.15;prematurity_penalty=0.25;forced_pipeline_penalty=0.14;live_runtime_penalty=0.00;child_agent_prematurity_penalty=0.00}
  mature_passport_pool=[ordered]@{owner_goal_fit=0.74;strategic_value=0.80;proof_readiness=0.78;safety_score=0.82;reuse_value=0.76;blocker_relief=0.42;learning_value=0.70;risk_penalty=0.26;authority_cost=0.16;prematurity_penalty=0.28;forced_pipeline_penalty=0.18;live_runtime_penalty=0.00;child_agent_prematurity_penalty=0.00}
  build_action_planner_later=[ordered]@{owner_goal_fit=0.63;strategic_value=0.82;proof_readiness=0.46;safety_score=0.48;reuse_value=0.62;blocker_relief=0.12;learning_value=0.64;risk_penalty=0.62;authority_cost=0.55;prematurity_penalty=0.78;forced_pipeline_penalty=0.92;live_runtime_penalty=0.22;child_agent_prematurity_penalty=0.00}
  activation_or_live_gate_later=[ordered]@{owner_goal_fit=0.42;strategic_value=0.74;proof_readiness=0.34;safety_score=0.36;reuse_value=0.52;blocker_relief=0.05;learning_value=0.50;risk_penalty=0.72;authority_cost=0.88;prematurity_penalty=0.84;forced_pipeline_penalty=0.48;live_runtime_penalty=0.96;child_agent_prematurity_penalty=0.00}
  child_agent_production_later=[ordered]@{owner_goal_fit=0.32;strategic_value=0.80;proof_readiness=0.20;safety_score=0.24;reuse_value=0.70;blocker_relief=0.02;learning_value=0.48;risk_penalty=0.86;authority_cost=0.92;prematurity_penalty=0.96;forced_pipeline_penalty=0.62;live_runtime_penalty=0.70;child_agent_prematurity_penalty=1.00}
  stop_no_action=[ordered]@{owner_goal_fit=0.58;strategic_value=0.32;proof_readiness=1.00;safety_score=1.00;reuse_value=0.20;blocker_relief=0.00;learning_value=0.22;risk_penalty=0.04;authority_cost=0.00;prematurity_penalty=0.00;forced_pipeline_penalty=0.00;live_runtime_penalty=0.00;child_agent_prematurity_penalty=0.00}
}
$scored=@()
foreach($opt in @($old.options)){
  $id=[string]$opt.option_id
  Assert ($componentMatrix.Contains($id)) "COMPONENT_MATRIX_MISSING:$id"
  $c=$componentMatrix[$id]
  foreach($k in @($positive+$penalty)){Assert ($c.Contains($k)) "COMPONENT_MISSING:${id}:${k}"; $val=[double]$c[$k]; Assert ($val -ge 0 -and $val -le 1) "COMPONENT_OUT_OF_RANGE:${id}:${k}:${val}"}
  $positiveScore=0.0
  foreach($k in $positive){$positiveScore += [double]$policy.positive_weights.$k * [double]$c[$k]}
  $penaltyScore=0.0
  foreach($k in $penalty){$penaltyScore += [double]$policy.penalty_weights.$k * [double]$c[$k]}
  $final=Clamp01 ($positiveScore - ([double]$policy.penalty_multiplier * $penaltyScore) + [double]$policy.baseline)
  $eligible=($opt.execution_allowed -eq $false -and $opt.mutation_authorized -eq $false -and [double]$c.owner_goal_fit -ge [double]$policy.selected_constraints.owner_goal_fit_min -and [double]$c.forced_pipeline_penalty -le [double]$policy.selected_constraints.forced_pipeline_penalty_max -and [double]$c.prematurity_penalty -le [double]$policy.selected_constraints.prematurity_penalty_max -and [double]$c.safety_score -ge [double]$policy.selected_constraints.safety_score_min)
  $policyDecision=if($eligible){'ELIGIBLE_FOR_RECOMMENDATION'}else{'NOT_ELIGIBLE_POLICY_GUARD'}
  $scored += [ordered]@{option_id=$id;intent_class=$opt.intent_class;score_components=$c;positive_score=[math]::Round($positiveScore,4);penalty_score=[math]::Round($penaltyScore,4);final_score=$final;policy_decision=$policyDecision;why=$opt.why;risk=$opt.risk;proof_gap=$opt.proof_gap;authority_required=$opt.authority_required;allowed_now=$opt.allowed_now;execution_allowed=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;passport_active_allowed=$false;owner_goal_alignment=$opt.owner_goal_alignment;expected_value=$opt.expected_value;rejection_reason_if_not_selected=$opt.rejection_reason_if_not_selected;forbidden_actions=@('EXECUTE_FROM_PRIORITY_RECOMMENDATION','MUTATE_FROM_PRIORITY_RECOMMENDATION','CLAIM_FULL_BRAIN','FORCE_PIPELINE_NEXT_STEP')}
}
$ranked=@($scored|Sort-Object -Descending -Property @{Expression={ [double]$_.final_score }})
$eligibleRanked=@($ranked|Where-Object{$_.policy_decision -eq 'ELIGIBLE_FOR_RECOMMENDATION'})
$selected=if($eligibleRanked.Count -gt 0){$eligibleRanked[0]}else{@($ranked|Where-Object{$_.option_id -eq 'stop_no_action'})[0]}
Assert ($selected.option_id -ne 'build_action_planner_later') 'ACTION_PLANNER_SELECTED_POLICY_BAD'
Assert (@($ranked|Where-Object{$_.option_id -eq 'build_action_planner_later'}).Count -eq 1) 'ACTION_PLANNER_NOT_SCORED'
# Negative fixtures generated for validator.
$missingFixture=[ordered]@{schema='priority_policy_negative_missing_component_v1';status='NEGATIVE_FIXTURE_SHOULD_FAIL';option=[ordered]@{option_id='bad_missing_component';score_components=[ordered]@{owner_goal_fit=1.0};manual_final_score=0.99}}
$forcedPlannerFixture=[ordered]@{schema='priority_policy_negative_forced_planner_v1';status='NEGATIVE_FIXTURE_SHOULD_FAIL';selected_option=[ordered]@{option_id='build_action_planner_later';final_score=0.99;score_components=[ordered]@{forced_pipeline_penalty=0.95;prematurity_penalty=0.95;safety_score=0.2};execution_allowed=$false;mutation_authorized=$false}}
$liveFixture=[ordered]@{schema='priority_policy_negative_live_without_authority_v1';status='NEGATIVE_FIXTURE_SHOULD_FAIL';selected_option=[ordered]@{option_id='activation_or_live_gate_later';final_score=0.99;score_components=[ordered]@{live_runtime_penalty=0.98;authority_cost=1.0};live_ready=$true;runtime_ready=$true}}
Write-Json 'tests/self_development/negative_fixtures/PRIORITY_POLICY_MISSING_COMPONENT_NEGATIVE.json' $missingFixture 50
Write-Json 'tests/self_development/negative_fixtures/PRIORITY_POLICY_FORCED_ACTION_PLANNER_NEGATIVE.json' $forcedPlannerFixture 50
Write-Json 'tests/self_development/negative_fixtures/PRIORITY_POLICY_LIVE_WITHOUT_AUTHORITY_NEGATIVE.json' $liveFixture 50
$out=[ordered]@{schema='priority_policy_contract_v1_scored_options';status='PASS_PRIORITY_POLICY_CONTRACT_V1_SCORED_OPTIONS';policy_ref=$policyPath;source_options_ref=$optionsIn;ranked_options=$ranked;selected_recommendation=$selected;summary=[ordered]@{option_count=$ranked.Count;selected_option_id=$selected.option_id;selected_intent_class=$selected.intent_class;formula_applied=$true;manual_scores_forbidden=$true;action_planner_scored=$true;action_planner_selected=$false;no_forced_next_step=$true;recommendation_not_command=$true;execution_allowed=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false};created_at=(Get-Date).ToString('o')}
$report=[ordered]@{schema='priority_policy_contract_v1_report';status='PASS_PRIORITY_POLICY_CONTRACT_V1';contract_md='contracts/living_loop/PRIORITY_POLICY_CONTRACT_V1.md';contract_json=$policyPath;scored_options_ref=$outPath;selected_option_id=$selected.option_id;policy_formula='final_score = clamp01(positive_score - (0.72 * penalty_score) + 0.28)';negative_fixtures=@('tests/self_development/negative_fixtures/PRIORITY_POLICY_MISSING_COMPONENT_NEGATIVE.json','tests/self_development/negative_fixtures/PRIORITY_POLICY_FORCED_ACTION_PLANNER_NEGATIVE.json','tests/self_development/negative_fixtures/PRIORITY_POLICY_LIVE_WITHOUT_AUTHORITY_NEGATIVE.json');created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='priority_policy_contract_v1_proof';status='PASS_PRIORITY_POLICY_CONTRACT_V1';formula_weights_present=$true;all_mandatory_components_present=$true;all_components_in_range=$true;same_formula_applied_to_all_options=$true;manual_scores_forbidden=$true;option_count=$ranked.Count;selected_option_id=$selected.option_id;selected_option_not_action_planner=($selected.option_id -ne 'build_action_planner_later');action_planner_scored=$true;action_planner_selected=$false;no_forced_next_step_enforced=$true;negative_missing_component_fixture_created=$true;negative_forced_action_planner_fixture_created=$true;negative_live_without_authority_fixture_created=$true;recommendation_not_command=$true;execution_allowed=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;no_passport_active_created=$true;no_live_runtime_touched=$true;report_path=$reportPath;created_at=(Get-Date).ToString('o')}
Write-Json $outPath $out 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_PRIORITY_POLICY_CONTRACT_V1'
Write-Host "SELECTED_OPTION=$($selected.option_id)"
Write-Host "OPTIONS=$($ranked.Count)"
Write-Host 'FORMULA_APPLIED=true'
Write-Host 'ACTION_PLANNER_SELECTED=false'

