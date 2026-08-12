function Select-AutonomousWakeFrontier {
  param(
    [bool]$RepoClean=$true,
    [bool]$ActiveMemoryReady=$true,
    [bool]$BodyMapAvailable=$true,
    [bool]$SchoolActive=$false,
    [bool]$SelfBuildCandidateAvailable=$true,
    [bool]$FreshSelfBuildGap=$false,
    [string]$FreshSelfBuildGapText='',
    [string[]]$AvoidFrontiers=@()
  )
  $candidates=New-Object System.Collections.Generic.List[object]
  function Add-Candidate([string]$id,[double]$score,[string]$reason,[string]$goal,[bool]$freshSignal){
    $penalty=if($AvoidFrontiers -contains $id){35}else{0}
    $candidates.Add([pscustomobject][ordered]@{frontier=$id;base_score=$score;avoid_penalty=$penalty;score=($score-$penalty);reason=$reason;goal=$goal;fresh_signal=$freshSignal})|Out-Null
  }
  if(-not $RepoClean){ Add-Candidate 'recovery_control_gap' 100 'fresh_repo_dirty_signal_has_priority_over_exploration' 'Understand the current repository/control inconsistency and determine the smallest safe recovery step before exploration.' $true }
  if($SchoolActive){ Add-Candidate 'school_runtime_observation' 95 'active_school_is_current_runtime_signal' 'Observe the active School run and determine whether any bounded learning/recovery decision is required without starting duplicate work.' $true }
  if(-not $ActiveMemoryReady){ Add-Candidate 'active_memory_recovery' 90 'protected_memory_required_files_are_not_ready' 'Understand why protected active memory is unavailable or incomplete and what proof is required to restore safe read access.' $true }
  if(-not $BodyMapAvailable){ Add-Candidate 'body_map_recovery' 80 'current_body_map_missing' 'Understand the current body-knowledge gap before relying on self-model claims.' $true }
  if($FreshSelfBuildGap){
    $g=if([string]::IsNullOrWhiteSpace($FreshSelfBuildGapText)){'Reason about the freshly proven Builder capability gap and identify the smallest bounded learning or repair step.'}else{('Reason about the freshly proven Builder capability gap: '+$FreshSelfBuildGapText)}
    Add-Candidate 'self_build_gap' 72 'fresh_explicit_self_build_gap' $g $true
  } elseif($SelfBuildCandidateAvailable){
    Add-Candidate 'self_build_gap' 25 'self_build_material_exists_but_freshness_is_not_proven' 'Re-evaluate a Builder capability gap only after fresh proof shows it is still current.' $false
  }
  Add-Candidate 'knowledge_source_gap' 60 'healthy_autonomous_default_seeks_new_reusable_knowledge' 'Identify one high-value knowledge gap not already resolved by current memory, then determine the smallest trustworthy evidence needed to learn it.' $true
  if($ActiveMemoryReady){ Add-Candidate 'memory_quality_frontier' 42 'memory_exists_and_can_be_examined_for_quality_or_coverage_without_forcing_topic' 'Examine whether current memory has a quality or coverage weakness worth learning about, without forcing the next topic to repeat old memory.' $false }
  Add-Candidate 'bounded_exploration' 38 'bounded_novel_exploration_remains_available' 'Explore one novel useful question with potential cross-domain reuse, while avoiding recently saturated frontiers.' $false
  $ordered=@($candidates | Sort-Object @{Expression='score';Descending=$true},@{Expression='frontier';Descending=$false})
  $selected=$ordered | Select-Object -First 1
  return [ordered]@{
    schema='autonomous_wake_frontier_selector_v1'
    status=if($selected){'PASS_AUTONOMOUS_WAKE_FRONTIER_SELECTOR_V1'}else{'BLOCKED_AUTONOMOUS_WAKE_FRONTIER_NO_CANDIDATES'}
    owner_task_required=$false
    selection_rule='fresh control/recovery signals > fresh explicit capability gap > healthy knowledge seeking > non-fresh maintenance/exploration candidates; avoid penalty prevents fixation'
    candidates=@($ordered)
    selected_frontier=if($selected){$selected.frontier}else{$null}
    selected_reason=if($selected){$selected.reason}else{$null}
    selected_goal=if($selected){$selected.goal}else{$null}
    boundary=[ordered]@{ selector_only=$true; action_execution_allowed=$false; active_memory_mutated=$false; no_web_research=$true; no_codex_launch=$true; no_school_launch=$true }
  }
}
