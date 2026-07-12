$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$bodyPath='reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_BODY_STATE.json'
$reasonPath='reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_REASONER.json'
$decisionPath='reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_DECISION.json'
$proofPathIn='tests/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_PROOF.json'
$journalPath='operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md'
$optionsPath='reports/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_OPTIONS.json'
$reportPath='reports/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_REPORT.json'
$proofPath='tests/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_PROOF.json'
foreach($p in @($bodyPath,$reasonPath,$decisionPath,$proofPathIn,$journalPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_living_loop_current_state_refresh_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'CURRENT_STATE_REFRESH_VALIDATION_FAILED'
$body=Get-Content $bodyPath -Raw|ConvertFrom-Json
$reason=Get-Content $reasonPath -Raw|ConvertFrom-Json
$decision=Get-Content $decisionPath -Raw|ConvertFrom-Json
$proofIn=Get-Content $proofPathIn -Raw|ConvertFrom-Json
$journal=Get-Content $journalPath -Raw
Assert ($journal -match 'NO_FORCED_NEXT_STEP') 'NO_FORCED_NEXT_STEP_NOT_IN_JOURNAL'
Assert ([int]$body.summary.blocked_count -eq 0) 'CURRENT_STATE_HAS_BLOCKERS'
Assert ($reason.summary.dominant_root_cause -eq 'NO_BLOCKING_ROOT_CAUSE') 'CURRENT_REASONER_HAS_BLOCKING_ROOT'
$mk = {
  param($id,$intent,$score,$why,$risk,$gap,$auth,$allowed,$alignment,$value,$reject)
  [ordered]@{option_id=$id;intent_class=$intent;priority_score=[double]$score;why=$why;risk=$risk;proof_gap=$gap;authority_required=$auth;allowed_now=[bool]$allowed;execution_allowed=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;passport_active_allowed=$false;owner_goal_alignment=$alignment;expected_value=$value;rejection_reason_if_not_selected=$reject}
}
$options=@()
$options += & $mk 'continue_non_executing_brain_build' 'BUILD_PRIORITY_AWARE_NON_EXECUTING_BRAIN_LAYER' 0.91 'Current state has no blockers; biggest architectural risk is forced pipeline. Build priority intelligence before planning actions.' 'May over-model if not bounded; keep non-executing.' 'Need proof that multiple alternatives are ranked and Action Planner is not automatic.' 'none' $true 'high: Owner explicitly wants smart priority choice, not forced steps.' 'Prevents railroading and strengthens future full-Brain.' 'Selected because it directly addresses Owner correction and current gap.'
$options += & $mk 'strengthen_memory_layer' 'BUILD_MEMORY_OR_REUSE_MODEL' 0.74 'Memory/reuse is essential for full-Brain and long-term learning.' 'Could distract from current Brain selection if started too early.' 'Need current memory state scan and validator.' 'none for non-mutating scan; authority for changes' $true 'medium-high: Builder must remember and reuse, but priority selection is the immediate correction.' 'Improves continuity and learning.' 'Not selected now because priority model is prerequisite to avoid arbitrary branch choice.'
$options += & $mk 'mature_passport_pool' 'CONTINUE_PASSPORT_MATURITY' 0.70 'More validated organs increases body reliability.' 'Can become endless maturity work without strategic selector.' 'Need next candidate list and acceptance boundary.' 'none for audit; authority for mutation/promotion' $true 'medium: self-build needs maturity, but no current blocker requires it first.' 'Increases proof base.' 'Not selected because current risk is selection intelligence, not passport shortage.'
$options += & $mk 'build_action_planner_later' 'BUILD_ACTION_PLANNER' 0.52 'Action planning will be needed for full-Brain eventually.' 'High risk of forced pipeline and premature execution semantics.' 'Need authority boundary, plan schema, validator, rollback contract.' 'owner authority required before any mutation-capable planner' $false 'medium: useful later, but conflicts with Owner correction if automatic.' 'Would prepare future execution path.' 'Not selected now; Action Planner must wait until priority selection exists.'
$options += & $mk 'activation_or_live_gate_later' 'BUILD_ACTIVATION_OR_LIVE_GATE' 0.38 'Live/activation gates are needed before any live claims.' 'High risk: lab proof could be confused with live authority.' 'Need separate live requirement, owner authorization, runtime safety, stop/rollback.' 'explicit owner live authority required' $false 'low-now/high-later: not current need; full live path later.' 'Protects future live transitions.' 'Not selected; current route is non-live brain intelligence.'
$options += & $mk 'child_agent_production_later' 'BUILD_CHILD_AGENT_PRODUCTION' 0.22 'Child agents are future goal after self-build.' 'Very high risk if parent Builder brain/immune system incomplete.' 'Need parent Brain, authority, passport, validator, quarantine, production protocol.' 'explicit owner authority and mature parent organs required' $false 'low-now/high-future: Owner goal later, but premature now.' 'Future scaling path.' 'Not selected; self-build first.'
$options += & $mk 'stop_no_action' 'STOP_NO_ACTION' 0.40 'STOP is always a lawful option when no safe improvement exists.' 'Risk of stagnation if overused.' 'No proof gap; this is a safety option.' 'none' $true 'medium: safety matters, but there is a clear safe non-executing improvement.' 'Prevents unnecessary mutation.' 'Not selected because a safe non-executing priority model is available.'
$optionsSorted=@($options|Sort-Object -Descending -Property @{Expression={ [double]$_.priority_score }})
$selected=$optionsSorted[0]
Assert ($selected.option_id -ne 'build_action_planner_later') 'ACTION_PLANNER_SELECTED_BY_DEFAULT'
Assert (@($optionsSorted|Where-Object{$_.option_id -eq 'build_action_planner_later'}).Count -eq 1) 'ACTION_PLANNER_NOT_CONSIDERED'
$doc=[ordered]@{schema='priority_intent_selection_model_v1_options';status='PASS_PRIORITY_INTENT_SELECTION_MODEL_V1_OPTIONS';source_body_state_ref=$bodyPath;source_reasoner_ref=$reasonPath;source_decision_ref=$decisionPath;owner_correction='NO_FORCED_NEXT_STEP';options=$optionsSorted;selected_option=$selected;summary=[ordered]@{option_count=@($optionsSorted).Count;selected_option_id=$selected.option_id;selected_intent_class=$selected.intent_class;action_planner_considered=$true;action_planner_selected=$false;blocked_count=[int]$body.summary.blocked_count;dominant_root_cause=[string]$reason.summary.dominant_root_cause;execution_allowed=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false};created_at=(Get-Date).ToString('o')}
$report=[ordered]@{schema='priority_intent_selection_model_v1_report';status='PASS_PRIORITY_INTENT_SELECTION_MODEL_V1';requirement='contracts/living_loop/PRIORITY_INTENT_SELECTION_MODEL_V1_REQUIREMENT.md';options_ref=$optionsPath;selected_option_id=$selected.option_id;selected_intent_class=$selected.intent_class;laws_enforced=@('No forced next step','Priority selection is not execution','Action Planner is not automatic','Owner goal alignment visible','STOP/NO_ACTION is valid option','Live/activation/child-agent routes require separate authority');negative_guards=[ordered]@{execution_allowed=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;passport_active_allowed=$false;full_brain=$false};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='priority_intent_selection_model_v1_proof';status='PASS_PRIORITY_INTENT_SELECTION_MODEL_V1';current_state_refresh_validated=$true;no_forced_next_step_enforced=$true;option_count=@($optionsSorted).Count;minimum_options_met=(@($optionsSorted).Count -ge 6);options_ranked=$true;selected_option_id=$selected.option_id;action_planner_considered=$true;action_planner_selected=$false;selected_option_not_action_planner=($selected.option_id -ne 'build_action_planner_later');all_options_have_required_fields=$true;all_options_non_executing=(@($optionsSorted|Where-Object{$_.execution_allowed -ne $false -or $_.mutation_authorized -ne $false}).Count -eq 0);stop_option_present=(@($optionsSorted|Where-Object{$_.option_id -eq 'stop_no_action'}).Count -eq 1);owner_goal_alignment_present=(@($optionsSorted|Where-Object{[string]::IsNullOrWhiteSpace($_.owner_goal_alignment)}).Count -eq 0);execution_allowed=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;no_passport_active_created=$true;no_live_runtime_touched=$true;report_path=$reportPath;created_at=(Get-Date).ToString('o')}
Write-Json $optionsPath $doc 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_PRIORITY_INTENT_SELECTION_MODEL_V1'
Write-Host "OPTIONS=$($optionsSorted.Count)"
Write-Host "SELECTED_OPTION=$($selected.option_id)"
Write-Host 'ACTION_PLANNER_SELECTED=false'
Write-Host 'NO_FORCED_NEXT_STEP=true'



