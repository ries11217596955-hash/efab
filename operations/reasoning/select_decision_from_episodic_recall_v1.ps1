function Get-DecisionField($Object, [string]$Name, $Default = $null) {
  if($null -eq $Object) { return $Default }
  try { $value = $Object[$Name]; if($null -ne $value) { return $value } } catch {}
  if($Object.PSObject -and $Object.PSObject.Properties[$Name]) { return $Object.PSObject.Properties[$Name].Value }
  return $Default
}
function ConvertTo-DecisionText([object[]]$Values) {
  return ((@($Values) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ }) -join ' ')
}
function Get-ReasoningDecisionFromEpisodicRecall {
  param(
    [string]$TaskName,
    [string]$TaskQuery,
    [string]$TaskTarget,
    [string]$SelectorReason,
    [string]$UsefulIntent,
    $EpisodicRecall,
    [int]$MaxHints = 2
  )
  $baseQuery = if($null -ne $TaskQuery) { [string]$TaskQuery } else { '' }
  $recallAvailable = [bool](Get-DecisionField $EpisodicRecall 'available' $false)
  if(-not $recallAvailable) {
    return [ordered]@{
      schema='episodic_recall_decision_v1'
      available=$false
      status='NO_EPISODIC_RECALL_DECISION'
      decision_action='KEEP_TASK'
      decision_reason='No relevant episodic recall was available.'
      task_name=$TaskName
      original_query=$baseQuery
      rewritten_query=$baseQuery
      selected_episode_ids=@()
      reuse_hints_applied=@()
      required_guardrails=@()
      question_to_self='No past episode found; proceed with normal bounded task path.'
      avoid_repeated_failure=$false
    }
  }
  $selected=@(Get-DecisionField $EpisodicRecall 'selected' @())
  $reuseHints=@(Get-DecisionField $EpisodicRecall 'reuse_hints' @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -First ([Math]::Max(1,$MaxHints))
  $episodeIds=@($selected | ForEach-Object { Get-DecisionField $_ 'episode_id' $null } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  $episodeText=ConvertTo-DecisionText (@($selected | ForEach-Object { @((Get-DecisionField $_ 'topic' ''),(Get-DecisionField $_ 'reuse_hint' ''),(Get-DecisionField $_ 'failure_reason' ''),(Get-DecisionField $_ 'correction' ''),(Get-DecisionField $_ 'status' '')) }))
  $taskText=ConvertTo-DecisionText @($TaskName,$TaskQuery,$SelectorReason,$UsefulIntent,$TaskTarget)
  $combined=($taskText+' '+$episodeText).ToLowerInvariant()
  $guardrails=New-Object System.Collections.Generic.List[string]
  $action='APPLY_REUSE_HINT'
  $reason='Relevant episodic recall is available; apply bounded reuse hints before continuing.'
  $question='What did past experience warn about, and how should the current task be guarded before execution?'
  $avoid=$false
  if($combined -match 'validator|ordered payload|live-shaped|payload shape|object shape|selector|memory routing|routing') {
    $action='REQUIRE_VALIDATION_GUARDRAIL'
    $reason='Past episode indicates routing/selector changes can pass lab validation while failing live-shaped payloads.'
    $question='Could this task repeat a prior selector or memory-routing failure because validator fixtures differ from live payload shape?'
    $guardrails.Add('validate live-shaped payload/object shape before accepting selector or routing behavior') | Out-Null
    $guardrails.Add('test PSCustomObject and ordered dictionary input shapes') | Out-Null
    $guardrails.Add('do not treat episodic recall as proof; preserve proof_refs and run validators') | Out-Null
    $avoid=$true
  } elseif(@($reuseHints).Count -gt 0) {
    $guardrails.Add('apply recalled reuse_hint as bounded experience context') | Out-Null
    $guardrails.Add('do not copy raw episodic trace into compact memory') | Out-Null
  } else {
    $action='KEEP_TASK_WITH_RECALL_CONTEXT'
    $reason='Recall exists but contains no concrete reuse hint; keep task and only record recall context.'
    $guardrails.Add('record recall context without changing task behavior') | Out-Null
  }
  $appendParts=New-Object System.Collections.Generic.List[string]
  if(@($reuseHints).Count -gt 0) { $appendParts.Add('episodic_reuse_hint: '+((@($reuseHints)) -join ' | ')) | Out-Null }
  if(@($guardrails.ToArray()).Count -gt 0) { $appendParts.Add('episodic_decision_guardrail: '+((@($guardrails.ToArray()) | Select-Object -First 3) -join ' | ')) | Out-Null }
  $appendParts.Add('episodic_question_to_self: '+$question) | Out-Null
  $rewritten=$baseQuery
  if(@($appendParts.ToArray()).Count -gt 0) { $rewritten = ($baseQuery + '; ' + ((@($appendParts.ToArray())) -join '; ')).Trim(';',' ') }
  return [ordered]@{
    schema='episodic_recall_decision_v1'
    available=$true
    status='EPISODIC_DECISION_AVAILABLE'
    decision_action=$action
    decision_reason=$reason
    task_name=$TaskName
    original_query=$baseQuery
    rewritten_query=$rewritten
    selected_episode_ids=@($episodeIds)
    reuse_hints_applied=@($reuseHints)
    required_guardrails=@($guardrails.ToArray())
    question_to_self=$question
    avoid_repeated_failure=$avoid
  }
}
