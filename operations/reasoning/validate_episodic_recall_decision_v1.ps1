$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$decision='operations/reasoning/select_decision_from_episodic_recall_v1.ps1'
Assert (Test-Path $decision) 'DECISION_HELPER_MISSING'
. (Resolve-Path $decision)
$noRecall=[ordered]@{ available=$false; status='NO_RELEVANT_EPISODIC_MEMORY'; selected=@(); reuse_hints=@() }
$d0=Get-ReasoningDecisionFromEpisodicRecall -TaskName 'ordinary_task' -TaskQuery 'inspect ordinary state' -SelectorReason 'NO_SIGNAL' -UsefulIntent 'baseline' -EpisodicRecall $noRecall
Assert ($d0.status -eq 'NO_EPISODIC_RECALL_DECISION') 'NO_RECALL_STATUS_BAD'
Assert ($d0.decision_action -eq 'KEEP_TASK') 'NO_RECALL_ACTION_BAD'
Assert ($d0.rewritten_query -eq 'inspect ordinary state') 'NO_RECALL_SHOULD_NOT_REWRITE_QUERY'
$genericRecall=[ordered]@{ available=$true; status='EPISODIC_RECALL_AVAILABLE'; selected=@([ordered]@{ episode_id='generic_lesson'; topic='bounded proof lesson'; status='REUSABLE_LESSON'; reuse_hint='Keep proof refs attached to claims.'; failure_reason=''; correction=''}); reuse_hints=@('Keep proof refs attached to claims.') }
$d1=Get-ReasoningDecisionFromEpisodicRecall -TaskName 'proof_summary' -TaskQuery 'summarize proof boundary' -SelectorReason 'ACTIVE_GROWTH_SIGNAL_TOPIC' -UsefulIntent 'use memory' -EpisodicRecall $genericRecall
Assert ($d1.status -eq 'EPISODIC_DECISION_AVAILABLE') 'GENERIC_STATUS_BAD'
Assert ($d1.decision_action -eq 'APPLY_REUSE_HINT') 'GENERIC_ACTION_BAD'
Assert ($d1.rewritten_query -like '*episodic_reuse_hint*') 'GENERIC_REWRITE_MISSING_HINT'
Assert ($d1.avoid_repeated_failure -eq $false) 'GENERIC_SHOULD_NOT_AVOID'
$selectorRecall=[ordered]@{ available=$true; status='EPISODIC_RECALL_AVAILABLE'; selected=@([ordered]@{ episode_id='aimo_growth_selector_ordered_payload_failure_v1'; topic='aimo selector ordered payload validator lesson'; status='REUSABLE_LESSON'; reuse_hint='Before editing selector or memory routing, test PSCustomObject and ordered payload shapes.'; failure_reason='Validator did not model the live-shaped ordered payload.'; correction='Add live-shaped payload fixtures before accepting routing code.'}); reuse_hints=@('Before editing selector or memory routing, test PSCustomObject and ordered payload shapes.') }
$d2=Get-ReasoningDecisionFromEpisodicRecall -TaskName 'follow_growth_signal_understand_own_policy_limits' -TaskQuery 'growth signal topic selector memory routing' -SelectorReason 'ACTIVE_GROWTH_SIGNAL_TOPIC' -UsefulIntent 'turn growth signal into one bounded next action candidate' -EpisodicRecall $selectorRecall
Assert ($d2.decision_action -eq 'REQUIRE_VALIDATION_GUARDRAIL') 'SELECTOR_ACTION_BAD'
Assert ($d2.avoid_repeated_failure -eq $true) 'SELECTOR_AVOID_FLAG_BAD'
Assert (($d2.required_guardrails -join ' ') -like '*live-shaped payload*') 'SELECTOR_GUARDRAIL_MISSING_LIVE_SHAPE'
Assert (($d2.required_guardrails -join ' ') -like '*ordered dictionary*') 'SELECTOR_GUARDRAIL_MISSING_ORDERED_DICTIONARY'
Assert ($d2.rewritten_query -like '*episodic_decision_guardrail*') 'SELECTOR_REWRITE_MISSING_GUARDRAIL'
Assert ($d2.rewritten_query -like '*episodic_question_to_self*') 'SELECTOR_REWRITE_MISSING_QUESTION'
# AIMO static wiring check.
$aimo='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$aimoText=Get-Content $aimo -Raw
Assert ($aimoText -match 'select_decision_from_episodic_recall_v1') 'AIMO_DECISION_DOTSOURCE_MISSING'
Assert ($aimoText -match 'Get-ReasoningDecisionFromEpisodicRecall') 'AIMO_DECISION_CALL_MISSING'
Assert ($aimoText -match 'episodic_decision_trace') 'AIMO_DECISION_TRACE_MISSING'
Assert ($aimoText -match 'episodic_decision_action') 'AIMO_EVENT_DECISION_ACTION_MISSING'
$proof=[ordered]@{
  schema='episodic_recall_decision_validation_v1'
  status='PASS_EPISODIC_RECALL_DECISION_V1'
  tests=@(
    [ordered]@{name='no_recall_keeps_task';status='PASS';action=$d0.decision_action},
    [ordered]@{name='generic_recall_applies_reuse_hint';status='PASS';action=$d1.decision_action},
    [ordered]@{name='selector_payload_recall_requires_validation_guardrail';status='PASS';action=$d2.decision_action;guardrails=@($d2.required_guardrails)},
    [ordered]@{name='aimo_decision_wiring_static_check';status='PASS'}
  )
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/reasoning/EPISODIC_RECALL_DECISION_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 40 | Set-Content -Path $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_EPISODIC_RECALL_DECISION_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
