$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$script='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
foreach($name in @('Get-SelectorField','Convert-ToTaskSafeSlug','Normalize-GrowthSignalTopicForTask','Select-GrowthDirectedDevelopmentTask')){
  $func=@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))[0]
  Assert ($null -ne $func) "FUNCTION_MISSING:$name"
  Invoke-Expression $func.Extent.Text
}
$tasks=@(
  [ordered]@{ name='choose_next_safe_growth_step'; query='baseline growth'; target='policy.json' },
  [ordered]@{ name='understand_own_policy_limits'; query='policy limits'; target='policy.json' },
  [ordered]@{ name='use_memory_before_repeating'; query='memory use'; target='manifest.json' }
)
$prev=[pscustomobject]@{ available=$true; run_id='old_run'; cells_sha256='OLD_HASH' }
$curr=[pscustomobject]@{ available=$true; run_id='new_run'; cells_sha256='NEW_HASH' }
$noGrowth=[pscustomobject]@{ available=$false; topics=@(); focus_boosts=@() }
$delta=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $noGrowth -CurrentMemoryState $curr -PreviousMemoryState $prev
Assert ($delta.reason -eq 'ACTIVE_MEMORY_DELTA_FROM_SCHOOL') 'MEMORY_DELTA_REASON_NOT_SELECTED'
Assert ($delta.task.name -eq 'inspect_school_memory_delta') 'MEMORY_DELTA_TASK_NAME_BAD'
Assert ($delta.overrides_static_rotation -eq $true) 'MEMORY_DELTA_DID_NOT_OVERRIDE_ROTATION'
Assert ($delta.task.query -match 'old_run' -and $delta.task.query -match 'new_run') 'MEMORY_DELTA_QUERY_MISSING_RUN_IDS'
$same=[pscustomobject]@{ available=$true; run_id='new_run'; cells_sha256='NEW_HASH' }
$growth=[pscustomobject]@{ available=$true; source_kind='School'; packet_id='packet_1'; topics=@('route_new_school_atoms_to_growth_action'); focus_boosts=@('school_memory_delta','next_action') }
$signal=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 2 -GrowthSignal $growth -CurrentMemoryState $same -PreviousMemoryState $curr
Assert ($signal.reason -eq 'ACTIVE_GROWTH_SIGNAL_TOPIC') 'GROWTH_SIGNAL_REASON_NOT_SELECTED'
Assert ($signal.task.name -eq 'follow_growth_signal_route_new_school_atoms_to_growth_action') 'GROWTH_SIGNAL_TASK_NAME_BAD'
Assert ($signal.overrides_static_rotation -eq $true) 'GROWTH_SIGNAL_DID_NOT_OVERRIDE_ROTATION'
Assert ($signal.task.target -eq '.runtime/compact_memory_growth_signal_v1/ACTIVE_GROWTH_SIGNAL.json') 'GROWTH_SIGNAL_TARGET_BAD'
$growthOrdered=[ordered]@{ available=$true; source_kind='School'; packet_id='packet_ordered'; topics=@('ordered_growth_signal_topic'); focus_boosts=@('ordered_boost') }
$signalOrdered=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 3 -GrowthSignal $growthOrdered -CurrentMemoryState $same -PreviousMemoryState $curr
Assert ($signalOrdered.reason -eq 'ACTIVE_GROWTH_SIGNAL_TOPIC') 'ORDERED_GROWTH_SIGNAL_REASON_NOT_SELECTED'
Assert ($signalOrdered.task.name -eq 'follow_growth_signal_ordered_growth_signal_topic') 'ORDERED_GROWTH_SIGNAL_TASK_NAME_BAD'
Assert ($signalOrdered.signal_packet_id -eq 'packet_ordered') 'ORDERED_GROWTH_SIGNAL_PACKET_BAD'
$repeatedGrowth=[ordered]@{ available=$true; source_kind='AgentLife'; packet_id='packet_repeated'; topics=@('follow_growth_signal_follow_growth_signal_follow_growth_signal_understand_own_policy'); focus_boosts=@('follow_growth_signal_follow_growth_signal_follow_growth_signal_understand_own_policy') }
$normalizedSignal=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 4 -GrowthSignal $repeatedGrowth -CurrentMemoryState $same -PreviousMemoryState $curr
Assert ($normalizedSignal.reason -eq 'ACTIVE_GROWTH_SIGNAL_TOPIC') 'REPEATED_PREFIX_GROWTH_SIGNAL_REASON_BAD'
Assert ($normalizedSignal.raw_topic -eq 'follow_growth_signal_follow_growth_signal_follow_growth_signal_understand_own_policy') 'REPEATED_PREFIX_RAW_TOPIC_BAD'
Assert ($normalizedSignal.normalized_topic -eq 'understand_own_policy') 'REPEATED_PREFIX_NORMALIZED_TOPIC_BAD'
Assert ($normalizedSignal.topic_was_normalized -eq $true) 'REPEATED_PREFIX_NORMALIZATION_FLAG_BAD'
Assert ($normalizedSignal.task.name -eq 'follow_growth_signal_understand_own_policy') 'REPEATED_PREFIX_TASK_NAME_NOT_NORMALIZED'
Assert ($normalizedSignal.task.name -notmatch 'follow_growth_signal_follow_growth_signal') 'REPEATED_PREFIX_TASK_NAME_STILL_RECURSIVE'
Assert ($normalizedSignal.task.query -match 'growth signal topic understand_own_policy') 'REPEATED_PREFIX_QUERY_NOT_NORMALIZED'
$truncatedResidueGrowth=[ordered]@{ available=$true; source_kind='AgentLife'; packet_id='packet_truncated_residue'; topics=@('validate_guardrails_before_follow_growth_signal_follow_growth_signal_follow_growth_signal_follow_gr'); focus_boosts=@('validate_guardrails_before_follow_growth_signal_follow_growth_signal_follow_growth_signal_follow_gr') }
$truncatedResidueSignal=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 5 -GrowthSignal $truncatedResidueGrowth -CurrentMemoryState $same -PreviousMemoryState $curr
Assert ($truncatedResidueSignal.normalized_topic -eq 'active_growth_signal') 'TRUNCATED_SERVICE_RESIDUE_NORMALIZED_TOPIC_BAD'
Assert ($truncatedResidueSignal.task.name -eq 'follow_growth_signal_active_growth_signal') 'TRUNCATED_SERVICE_RESIDUE_TASK_NAME_BAD'
Assert ($truncatedResidueSignal.task.name -notmatch 'follow_growth_signal_follow_growth_signal') 'TRUNCATED_SERVICE_RESIDUE_STILL_RECURSIVE'
$actionableContractGrowth=[ordered]@{
  available=$true
  source_kind='School'
  packet_id='packet_actionable_contract'
  topics=@('selector_validator_missing_live_payload_shape')
  focus_boosts=@('selector','payload_shape')
  specific_gap='selector_validator_missing_live_payload_shape'
  next_action_candidate='add_ordered_payload_negative_case_to_selector_validator'
  validator_hint='validate ordered dictionary and PSCustomObject selector inputs'
  proof_needed=@('selector validator PASS','ordered payload regression proof')
}
$actionableContractSignal=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 6 -GrowthSignal $actionableContractGrowth -CurrentMemoryState $same -PreviousMemoryState $curr
Assert ($actionableContractSignal.normalized_topic -eq 'selector_validator_missing_live_payload_shape') 'ACTIONABLE_CONTRACT_NORMALIZED_TOPIC_BAD'
Assert ($actionableContractSignal.specific_gap -eq 'selector_validator_missing_live_payload_shape') 'ACTIONABLE_CONTRACT_SPECIFIC_GAP_BAD'
Assert ($actionableContractSignal.next_action_candidate -eq 'add_ordered_payload_negative_case_to_selector_validator') 'ACTIONABLE_CONTRACT_NEXT_ACTION_BAD'
Assert ($actionableContractSignal.validator_hint -like '*ordered dictionary*') 'ACTIONABLE_CONTRACT_VALIDATOR_HINT_BAD'
Assert ($actionableContractSignal.task.query -like '*specific_gap selector_validator_missing_live_payload_shape*') 'ACTIONABLE_CONTRACT_QUERY_MISSING_SPECIFIC_GAP'
Assert ($actionableContractSignal.task.query -like '*next_action_candidate add_ordered_payload_negative_case_to_selector_validator*') 'ACTIONABLE_CONTRACT_QUERY_MISSING_NEXT_ACTION'
Assert ($actionableContractSignal.task.query -like '*validator_hint validate ordered dictionary*') 'ACTIONABLE_CONTRACT_QUERY_MISSING_VALIDATOR_HINT'
Assert ($actionableContractSignal.task.query -like '*proof_needed selector validator PASS*') 'ACTIONABLE_CONTRACT_QUERY_MISSING_PROOF_NEEDED'
$fallback=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 2 -GrowthSignal $noGrowth -CurrentMemoryState $same -PreviousMemoryState $curr
Assert ($fallback.reason -eq 'NO_FRESH_GROWTH_SIGNAL_OR_MEMORY_DELTA') 'FALLBACK_REASON_BAD'
Assert ($fallback.task.name -eq 'understand_own_policy_limits') 'FALLBACK_ROTATION_BAD'
Assert ($fallback.overrides_static_rotation -eq $false) 'FALLBACK_SHOULD_NOT_OVERRIDE'
$aimoText=Get-Content $script -Raw
Assert ($aimoText -match 'specific_gap=\$s\.specific_gap') 'BRIDGE_CONTRACT_FIELD_SPECIFIC_GAP_MISSING'
Assert ($aimoText -match 'next_action_candidate=\$s\.next_action_candidate') 'BRIDGE_CONTRACT_FIELD_NEXT_ACTION_MISSING'
Assert ($aimoText -match 'proof_needed=@\(\$s\.proof_needed\)') 'BRIDGE_CONTRACT_FIELD_PROOF_NEEDED_MISSING'
Assert ($aimoText -match 'validator_hint=\$s\.validator_hint') 'BRIDGE_CONTRACT_FIELD_VALIDATOR_HINT_MISSING'
Assert ($aimoText -match 'signal_quality=\$s\.signal_quality') 'BRIDGE_CONTRACT_FIELD_SIGNAL_QUALITY_MISSING'
Assert ($aimoText -match 'actionable_contract=\$s\.actionable_contract') 'BRIDGE_CONTRACT_FIELD_ACTIONABLE_CONTRACT_MISSING'
$out=[ordered]@{
  schema='growth_directed_task_selection_validation_v1'
  status='PASS_GROWTH_DIRECTED_TASK_SELECTION_V1'
  script=$script
  tests=@(
    [ordered]@{name='memory_delta_overrides_static_rotation'; status='PASS'; selected_task=$delta.task.name; reason=$delta.reason},
    [ordered]@{name='growth_signal_topic_overrides_static_rotation'; status='PASS'; selected_task=$signal.task.name; reason=$signal.reason},
    [ordered]@{name='growth_signal_repeated_prefix_is_normalized'; status='PASS'; selected_task=$normalizedSignal.task.name; raw_topic=$normalizedSignal.raw_topic; normalized_topic=$normalizedSignal.normalized_topic; reason=$normalizedSignal.reason},
    [ordered]@{name='growth_signal_truncated_service_residue_falls_back'; status='PASS'; selected_task=$truncatedResidueSignal.task.name; raw_topic=$truncatedResidueSignal.raw_topic; normalized_topic=$truncatedResidueSignal.normalized_topic; reason=$truncatedResidueSignal.reason},
    [ordered]@{name='growth_signal_actionable_contract_drives_query'; status='PASS'; selected_task=$actionableContractSignal.task.name; normalized_topic=$actionableContractSignal.normalized_topic; next_action_candidate=$actionableContractSignal.next_action_candidate; reason=$actionableContractSignal.reason},
    [ordered]@{name='growth_signal_bridge_passes_actionable_contract_fields'; status='PASS'},
    [ordered]@{name='no_signal_falls_back_to_static_rotation'; status='PASS'; selected_task=$fallback.task.name; reason=$fallback.reason}
  )
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proof='tests/autonomous_inner_motor/GROWTH_DIRECTED_TASK_SELECTION_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proof -Parent) | Out-Null
$out | ConvertTo-Json -Depth 30 | Set-Content -Path $proof -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_GROWTH_DIRECTED_TASK_SELECTION_V1'
Write-Host "PROOF_PATH=$proof"
Write-Host 'LIVE_PROCESS_TOUCHED=false'