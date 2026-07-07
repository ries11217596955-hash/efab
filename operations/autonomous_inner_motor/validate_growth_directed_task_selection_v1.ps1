$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$script='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
foreach($name in @('Convert-ToTaskSafeSlug','Select-GrowthDirectedDevelopmentTask')){
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
$fallback=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 2 -GrowthSignal $noGrowth -CurrentMemoryState $same -PreviousMemoryState $curr
Assert ($fallback.reason -eq 'NO_FRESH_GROWTH_SIGNAL_OR_MEMORY_DELTA') 'FALLBACK_REASON_BAD'
Assert ($fallback.task.name -eq 'understand_own_policy_limits') 'FALLBACK_ROTATION_BAD'
Assert ($fallback.overrides_static_rotation -eq $false) 'FALLBACK_SHOULD_NOT_OVERRIDE'
$out=[ordered]@{
  schema='growth_directed_task_selection_validation_v1'
  status='PASS_GROWTH_DIRECTED_TASK_SELECTION_V1'
  script=$script
  tests=@(
    [ordered]@{name='memory_delta_overrides_static_rotation'; status='PASS'; selected_task=$delta.task.name; reason=$delta.reason},
    [ordered]@{name='growth_signal_topic_overrides_static_rotation'; status='PASS'; selected_task=$signal.task.name; reason=$signal.reason},
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