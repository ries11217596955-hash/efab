function Test-Phase160JBacklogActivationReady {
  param([object]$ExistingActiveTask, [string]$ExistingActiveStatus = "NONE")
  $activeTaskId = if ($null -ne $ExistingActiveTask -and $ExistingActiveTask.PSObject.Properties.Name -contains "task_id") { [string]$ExistingActiveTask.task_id } else { "NONE" }
  return ([string]::IsNullOrWhiteSpace($activeTaskId) -or $activeTaskId -eq "NONE" -or $ExistingActiveStatus -eq "NONE")
}

function ConvertTo-Phase160JActiveTaskFromBacklog {
  param([object]$BacklogRecord, [string]$DutyId = "NONE")
  $taskId = if ($BacklogRecord.PSObject.Properties.Name -contains "task_id") { [string]$BacklogRecord.task_id } else { [string]$BacklogRecord.normalized_task_id }
  return [ordered]@{
    status = "ACTIVE"
    duty_id = $DutyId
    task_id = $taskId
    normalized_task_id = if ($BacklogRecord.PSObject.Properties.Name -contains "normalized_task_id") { [string]$BacklogRecord.normalized_task_id } else { $taskId }
    source = "owner"
    priority = if ($BacklogRecord.PSObject.Properties.Name -contains "priority") { [string]$BacklogRecord.priority } else { "normal" }
    owner_goal = if ($BacklogRecord.PSObject.Properties.Name -contains "owner_goal") { [string]$BacklogRecord.owner_goal } else { "" }
    desired_next_gap = if ($BacklogRecord.PSObject.Properties.Name -contains "desired_next_gap") { [string]$BacklogRecord.desired_next_gap } else { "OWNER_TASK_LIFECYCLE_GAP" }
    teacher_digest_path = if ($BacklogRecord.PSObject.Properties.Name -contains "teacher_digest_path") { [string]$BacklogRecord.teacher_digest_path } else { "NONE" }
    content_hash = if ($BacklogRecord.PSObject.Properties.Name -contains "content_hash") { [string]$BacklogRecord.content_hash } else { "" }
    active_plan_item_id = "NONE"
    active_plan_item_path = "NONE"
    plan_step_count = if ($BacklogRecord.PSObject.Properties.Name -contains "plan_step_count") { [int]$BacklogRecord.plan_step_count } else { 0 }
    selected_for_candidate_workspace = $true
    active_owner_task = $true
    selected_at = (Get-Date).ToUniversalTime().ToString("o")
  }
}
