$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$req='contracts/living_loop/PRIORITY_INTENT_SELECTION_MODEL_V1_REQUIREMENT.md'
$optionsPath='reports/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_OPTIONS.json'
$reportPath='reports/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_REPORT.json'
$proofPath='tests/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_PROOF.json'
foreach($p in @($req,$optionsPath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_living_loop_current_state_refresh_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'CURRENT_STATE_REFRESH_VALIDATION_FAILED'
$o=Get-Content $optionsPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($o.status -eq 'PASS_PRIORITY_INTENT_SELECTION_MODEL_V1_OPTIONS') 'OPTIONS_STATUS_BAD'
Assert ($r.status -eq 'PASS_PRIORITY_INTENT_SELECTION_MODEL_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_PRIORITY_INTENT_SELECTION_MODEL_V1') 'PROOF_STATUS_BAD'
$options=@($o.options)
Assert ($options.Count -ge 6) 'OPTIONS_TOO_FEW'
$last=999.0
foreach($opt in $options){Assert ([double]$opt.priority_score -le $last) 'OPTIONS_NOT_SORTED_DESC'; $last=[double]$opt.priority_score; foreach($f in @('option_id','intent_class','priority_score','why','risk','proof_gap','authority_required','allowed_now','execution_allowed','mutation_authorized','owner_goal_alignment','expected_value','rejection_reason_if_not_selected')){Assert ($opt.PSObject.Properties.Name -contains $f) "OPTION_FIELD_MISSING:$f"}; Assert ($opt.execution_allowed -eq $false) "OPTION_EXECUTION_OVERCLAIM:$($opt.option_id)"; Assert ($opt.mutation_authorized -eq $false) "OPTION_MUTATION_OVERCLAIM:$($opt.option_id)"; Assert ($opt.runtime_ready -eq $false) "OPTION_RUNTIME_OVERCLAIM:$($opt.option_id)"; Assert ($opt.live_ready -eq $false) "OPTION_LIVE_OVERCLAIM:$($opt.option_id)"; Assert ($opt.autonomous_runtime -eq $false) "OPTION_AUTONOMOUS_OVERCLAIM:$($opt.option_id)"}
Assert (@($options|Where-Object{$_.option_id -eq 'build_action_planner_later'}).Count -eq 1) 'ACTION_PLANNER_NOT_CONSIDERED'
Assert ($o.selected_option.option_id -ne 'build_action_planner_later') 'ACTION_PLANNER_SELECTED_BY_DEFAULT'
Assert (@($options|Where-Object{$_.option_id -eq 'stop_no_action'}).Count -eq 1) 'STOP_OPTION_MISSING'
Assert ($p.no_forced_next_step_enforced -eq $true) 'NO_FORCED_NEXT_STEP_NOT_ENFORCED'
Assert ($p.action_planner_considered -eq $true) 'ACTION_PLANNER_CONSIDERED_PROOF_BAD'
Assert ($p.action_planner_selected -eq $false) 'ACTION_PLANNER_SELECTED_PROOF_BAD'
Assert ($p.all_options_non_executing -eq $true) 'OPTIONS_NON_EXECUTING_PROOF_BAD'
Assert ($p.owner_goal_alignment_present -eq $true) 'OWNER_ALIGNMENT_PROOF_BAD'
Write-Host 'VALIDATION_PASS=PASS_PRIORITY_INTENT_SELECTION_MODEL_V1'
Write-Host "OPTIONS=$($options.Count)"
Write-Host "SELECTED_OPTION=$($o.selected_option.option_id)"
Write-Host 'ACTION_PLANNER_SELECTED=false'
Write-Host 'NO_FORCED_NEXT_STEP=true'
