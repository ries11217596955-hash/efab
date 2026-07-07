function Convert-ToForkSafeSlug([string]$Value, [int]$MaxLength = 72) {
  if([string]::IsNullOrWhiteSpace($Value)) { return 'unknown_task' }
  $slug = ($Value.ToLowerInvariant() -replace '[^a-z0-9_\-]+','_').Trim('_','-')
  if([string]::IsNullOrWhiteSpace($slug)) { $slug = 'unknown_task' }
  if($slug.Length -gt $MaxLength) { $slug = $slug.Substring(0,$MaxLength).Trim('_','-') }
  return $slug
}
function Limit-ForkText([string]$Value, [int]$MaxLength = 1400) {
  if($null -eq $Value) { return '' }
  $s = [string]$Value
  if($s.Length -le $MaxLength) { return $s }
  return ($s.Substring(0,$MaxLength) + '...TRUNCATED')
}
function Get-ForkField($Object, [string]$Name, $Default = $null) {
  if($null -eq $Object) { return $Default }
  try { $value = $Object[$Name]; if($null -ne $value) { return $value } } catch {}
  if($Object.PSObject -and $Object.PSObject.Properties[$Name]) { return $Object.PSObject.Properties[$Name].Value }
  return $Default
}
function Get-TaskForkFromEpisodicDecision {
  param(
    [string]$TaskName,
    [string]$TaskQuery,
    [string]$TaskTarget,
    $EpisodicDecision
  )
  $decisionAction = [string](Get-ForkField $EpisodicDecision 'decision_action' 'KEEP_TASK')
  $decisionStatus = [string](Get-ForkField $EpisodicDecision 'status' 'NO_DECISION')
  $originalTask = [ordered]@{ name=$TaskName; target=$TaskTarget; query=$TaskQuery }
  if($decisionAction -ne 'REQUIRE_VALIDATION_GUARDRAIL') {
    return [ordered]@{
      schema='episodic_decision_task_fork_v1'
      status='NO_TASK_FORK_REQUIRED'
      fork_available=$false
      fork_action='KEEP_TASK'
      fork_reason='Episodic decision did not require a validation fork.'
      decision_status=$decisionStatus
      decision_action=$decisionAction
      original_task=$originalTask
      forked_task=$null
      continue_original_after_validation=$false
      selected_episode_ids=@(Get-ForkField $EpisodicDecision 'selected_episode_ids' @())
      required_guardrails=@(Get-ForkField $EpisodicDecision 'required_guardrails' @())
    }
  }
  $guardrails=@(Get-ForkField $EpisodicDecision 'required_guardrails' @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
  $episodes=@(Get-ForkField $EpisodicDecision 'selected_episode_ids' @()) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
  $question=[string](Get-ForkField $EpisodicDecision 'question_to_self' 'What validation guardrail is required before continuing?')
  $reason=[string](Get-ForkField $EpisodicDecision 'decision_reason' 'Episodic decision requires validation guardrail before continuing original task.')
  $safeOriginal=Convert-ToForkSafeSlug $TaskName
  $forkName='validate_guardrails_before_' + $safeOriginal
  $guardrailText=Limit-ForkText ((@($guardrails) -join ' | ')) 1000
  $episodeText=Limit-ForkText ((@($episodes) -join ' | ')) 700
  $baseQuery=Limit-ForkText $TaskQuery 1200
  $forkQuery=(
    "Validate episodic decision guardrails before continuing original task. " +
    "original_task=$TaskName; original_query=$baseQuery; " +
    "decision_reason=$reason; required_guardrails=$guardrailText; " +
    "question_to_self=$question; selected_episode_ids=$episodeText; " +
    "proof_needed=validator must cover live-shaped payload/object shapes and preserve proof refs before original task continuation."
  )
  $forked=[ordered]@{
    name=$forkName
    target=$(if([string]::IsNullOrWhiteSpace($TaskTarget)){'validation_guardrail'}else{$TaskTarget})
    query=Limit-ForkText $forkQuery 3200
  }
  return [ordered]@{
    schema='episodic_decision_task_fork_v1'
    status='TASK_FORK_CREATED'
    fork_available=$true
    fork_action='FORK_TO_VALIDATION_TASK'
    fork_reason='Episodic decision required validation guardrail before original task continuation.'
    decision_status=$decisionStatus
    decision_action=$decisionAction
    original_task=$originalTask
    forked_task=$forked
    continue_original_after_validation=$true
    selected_episode_ids=@($episodes)
    required_guardrails=@($guardrails)
  }
}
