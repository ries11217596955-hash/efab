$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$fork='operations/reasoning/select_task_fork_from_episodic_decision_v1.ps1'
Assert (Test-Path $fork) 'FORK_HELPER_MISSING'
. (Resolve-Path $fork)
$keepDecision=[ordered]@{ status='NO_EPISODIC_RECALL_DECISION'; decision_action='KEEP_TASK'; selected_episode_ids=@(); required_guardrails=@(); question_to_self='none' }
$f0=Get-TaskForkFromEpisodicDecision -TaskName 'ordinary_task' -TaskQuery 'inspect ordinary state' -TaskTarget 'runtime' -EpisodicDecision $keepDecision
Assert ($f0.status -eq 'NO_TASK_FORK_REQUIRED') 'KEEP_STATUS_BAD'
Assert ($f0.fork_available -eq $false) 'KEEP_SHOULD_NOT_FORK'
Assert ($f0.fork_action -eq 'KEEP_TASK') 'KEEP_ACTION_BAD'
Assert ($null -eq $f0.forked_task) 'KEEP_FORKED_TASK_SHOULD_BE_NULL'
$genericDecision=[ordered]@{ status='EPISODIC_DECISION_AVAILABLE'; decision_action='APPLY_REUSE_HINT'; selected_episode_ids=@('generic_lesson'); required_guardrails=@('apply recalled reuse_hint as bounded experience context'); question_to_self='what hint applies?' }
$f1=Get-TaskForkFromEpisodicDecision -TaskName 'proof_summary' -TaskQuery 'summarize proof boundary' -TaskTarget 'reports' -EpisodicDecision $genericDecision
Assert ($f1.status -eq 'NO_TASK_FORK_REQUIRED') 'GENERIC_STATUS_BAD'
Assert ($f1.fork_available -eq $false) 'GENERIC_SHOULD_NOT_FORK'
$selectorDecision=[ordered]@{
  status='EPISODIC_DECISION_AVAILABLE'
  decision_action='REQUIRE_VALIDATION_GUARDRAIL'
  decision_reason='Past episode indicates routing/selector changes can pass lab validation while failing live-shaped payloads.'
  selected_episode_ids=@('aimo_growth_selector_ordered_payload_failure_v1')
  required_guardrails=@('validate live-shaped payload/object shape before accepting selector or routing behavior','test PSCustomObject and ordered dictionary input shapes','do not treat episodic recall as proof; preserve proof_refs and run validators')
  question_to_self='Could this task repeat a prior selector or memory-routing failure because validator fixtures differ from live payload shape?'
}
$f2=Get-TaskForkFromEpisodicDecision -TaskName 'follow_growth_signal_understand_own_policy_limits' -TaskQuery 'growth signal topic selector memory routing' -TaskTarget '.runtime/compact_memory_growth_signal_v1/ACTIVE_GROWTH_SIGNAL.json' -EpisodicDecision $selectorDecision
Assert ($f2.status -eq 'TASK_FORK_CREATED') 'FORK_STATUS_BAD'
Assert ($f2.fork_available -eq $true) 'FORK_NOT_AVAILABLE'
Assert ($f2.fork_action -eq 'FORK_TO_VALIDATION_TASK') 'FORK_ACTION_BAD'
Assert ($f2.continue_original_after_validation -eq $true) 'FORK_CONTINUE_FLAG_BAD'
Assert ($f2.forked_task.name -like 'validate_guardrails_before_follow_growth_signal*') 'FORK_NAME_BAD'
Assert ($f2.forked_task.query -like '*live-shaped payload*') 'FORK_QUERY_MISSING_LIVE_SHAPE'
Assert ($f2.forked_task.query -like '*ordered dictionary*') 'FORK_QUERY_MISSING_ORDERED_DICTIONARY'
Assert ($f2.forked_task.query -like '*original_task=follow_growth_signal_understand_own_policy_limits*') 'FORK_QUERY_MISSING_ORIGINAL_TASK'
Assert ($f2.forked_task.query -like '*proof_needed=*') 'FORK_QUERY_MISSING_PROOF_NEEDED'
Assert (($f2.selected_episode_ids -join ' ') -like '*aimo_growth_selector_ordered_payload_failure_v1*') 'FORK_SELECTED_EPISODE_MISSING'
Assert ($f2.forked_task.query -notlike '*stdout_preview*') 'FORK_QUERY_CONTAINS_RAW_LOG_MARKER'
# AIMO static wiring check.
$aimo='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$aimoText=Get-Content $aimo -Raw
Assert ($aimoText -match 'select_task_fork_from_episodic_decision_v1') 'AIMO_FORK_DOTSOURCE_MISSING'
Assert ($aimoText -match 'Get-TaskForkFromEpisodicDecision') 'AIMO_FORK_CALL_MISSING'
Assert ($aimoText -match 'episodic_fork_trace') 'AIMO_FORK_TRACE_MISSING'
Assert ($aimoText -match 'episodic_fork_action') 'AIMO_EVENT_FORK_ACTION_MISSING'
$proof=[ordered]@{
  schema='episodic_decision_task_fork_validation_v1'
  status='PASS_EPISODIC_DECISION_TASK_FORK_V1'
  tests=@(
    [ordered]@{name='keep_task_when_no_recall_decision';status='PASS';action=$f0.fork_action},
    [ordered]@{name='generic_recall_does_not_fork';status='PASS';action=$f1.fork_action},
    [ordered]@{name='validation_guardrail_decision_forks_task';status='PASS';action=$f2.fork_action;forked_task=$f2.forked_task.name},
    [ordered]@{name='fork_query_preserves_original_and_proof_need';status='PASS'},
    [ordered]@{name='aimo_fork_wiring_static_check';status='PASS'}
  )
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/reasoning/EPISODIC_DECISION_TASK_FORK_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 40 | Set-Content -Path $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_EPISODIC_DECISION_TASK_FORK_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
