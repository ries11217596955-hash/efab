function Get-Phase160JObjectProperty {
  param([object]$Object, [string[]]$Names, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  foreach ($name in $Names) {
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($name)) {
      return $Object[$name]
    }
    if ($Object.PSObject.Properties.Name -contains $name) {
      return $Object.$name
    }
  }
  return $Default
}

function Get-Phase160JStringProperty {
  param([object]$Object, [string[]]$Names, [string]$Default = "")
  $value = Get-Phase160JObjectProperty -Object $Object -Names $Names -Default $Default
  if ($null -eq $value) {
    return $Default
  }
  return [string]$value
}

function ConvertTo-Phase160JSafeLeaf {
  param([string]$Value, [int]$MaxLength = 80)
  $leaf = if ([string]::IsNullOrWhiteSpace($Value)) { "UNKNOWN" } else { $Value }
  $leaf = $leaf -replace '[^A-Za-z0-9_.-]', '_'
  if ($leaf.Length -gt $MaxLength) {
    $leaf = $leaf.Substring(0, $MaxLength)
  }
  return $leaf
}

function ConvertTo-Phase160JBoolean {
  param([object]$Value, [bool]$Default)
  if ($null -eq $Value) {
    return $Default
  }
  if ($Value -is [bool]) {
    return [bool]$Value
  }
  $text = ([string]$Value).Trim()
  if ($text -eq "true") {
    return $true
  }
  if ($text -eq "false") {
    return $false
  }
  return $Default
}

function Get-Phase160JTaskSafetyFlag {
  param([object]$Task, [string[]]$Names, [bool]$Default)
  $rules = Get-Phase160JObjectProperty -Object $Task -Names @("safety_rules") -Default $null
  if ($null -ne $rules) {
    foreach ($name in $Names) {
      if ($rules -is [System.Collections.IDictionary] -and $rules.Contains($name)) {
        return ConvertTo-Phase160JBoolean -Value $rules[$name] -Default $Default
      }
      if ($rules.PSObject.Properties.Name -contains $name) {
        return ConvertTo-Phase160JBoolean -Value $rules.$name -Default $Default
      }
    }
  }
  foreach ($name in $Names) {
    if ($null -ne $Task -and $Task -is [System.Collections.IDictionary] -and $Task.Contains($name)) {
      return ConvertTo-Phase160JBoolean -Value $Task[$name] -Default $Default
    }
    if ($null -ne $Task -and $Task.PSObject.Properties.Name -contains $name) {
      return ConvertTo-Phase160JBoolean -Value $Task.$name -Default $Default
    }
  }
  return $Default
}

function Get-Phase160JOwnerGoal {
  param([object]$Task)
  $ownerGoal = Get-Phase160JStringProperty -Object $Task -Names @("owner_goal", "program_goal", "curriculum_goal", "goal", "title", "name") -Default ""
  if (-not [string]::IsNullOrWhiteSpace($ownerGoal)) {
    return $ownerGoal
  }
  $program = Get-Phase160JObjectProperty -Object $Task -Names @("program", "curriculum") -Default $null
  if ($null -ne $program) {
    return Get-Phase160JStringProperty -Object $program -Names @("owner_goal", "program_goal", "curriculum_goal", "goal", "title", "name") -Default ""
  }
  return ""
}

function ConvertTo-Phase160JPlanItems {
  param([object]$Task)
  $raw = Get-Phase160JObjectProperty -Object $Task -Names @("plan_items", "plan_steps", "lessons") -Default $null
  $sourceShape = "NONE"
  if ($null -eq $raw) {
    $program = Get-Phase160JObjectProperty -Object $Task -Names @("program", "curriculum") -Default $null
    if ($null -ne $program) {
      $raw = Get-Phase160JObjectProperty -Object $program -Names @("plan_items", "plan_steps", "lessons") -Default $null
      $sourceShape = "program"
    }
  } else {
    $sourceShape = "task"
  }

  $items = @()
  if ($null -eq $raw) {
    return @($items)
  }

  $rawItems = if ($raw -is [System.Array]) { @($raw) } else { @($raw) }
  for ($i = 0; $i -lt $rawItems.Count; $i += 1) {
    $rawItem = $rawItems[$i]
    $description = ""
    $itemId = "plan_item_{0:d3}" -f ($i + 1)
    if ($rawItem -is [string]) {
      $description = [string]$rawItem
    } elseif ($null -ne $rawItem) {
      $description = Get-Phase160JStringProperty -Object $rawItem -Names @("description", "owner_goal", "goal", "title", "name", "lesson", "task") -Default ""
      $candidateItemId = Get-Phase160JStringProperty -Object $rawItem -Names @("item_id", "lesson_id", "id") -Default ""
      if (-not [string]::IsNullOrWhiteSpace($candidateItemId)) {
        $itemId = ConvertTo-Phase160JSafeLeaf -Value $candidateItemId -MaxLength 70
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($description)) {
      $items += [pscustomobject][ordered]@{
        item_id = $itemId
        description = $description
        source_shape = $sourceShape
      }
    }
  }
  return @($items)
}

function ConvertTo-Phase160JOwnerLiveTaskNormalized {
  param(
    [object]$Task,
    [string]$ContentHash = "",
    [string]$RawFileName = "NONE",
    [string]$CreatedAtUtc = ""
  )

  $hashFragment = if (-not [string]::IsNullOrWhiteSpace($ContentHash) -and $ContentHash.Length -ge 12) { $ContentHash.Substring(0, 12) } else { "nohash" }
  $originalTaskId = Get-Phase160JStringProperty -Object $Task -Names @("task_id", "id", "taskId") -Default ""
  $normalizedTaskId = if ([string]::IsNullOrWhiteSpace($originalTaskId)) { "OWNER_TASK_$hashFragment" } else { ConvertTo-Phase160JSafeLeaf -Value $originalTaskId -MaxLength 90 }
  $ownerGoal = Get-Phase160JOwnerGoal -Task $Task
  $planItems = @(ConvertTo-Phase160JPlanItems -Task $Task)
  $source = Get-Phase160JStringProperty -Object $Task -Names @("source") -Default "owner"
  if ([string]::IsNullOrWhiteSpace($source)) {
    $source = "owner"
  }
  $priority = Get-Phase160JStringProperty -Object $Task -Names @("priority") -Default "normal"
  if ([string]::IsNullOrWhiteSpace($priority)) {
    $priority = "normal"
  }
  $desiredNextGap = Get-Phase160JStringProperty -Object $Task -Names @("desired_next_gap", "next_gap", "target_gap") -Default "OWNER_TASK_LIFECYCLE_GAP"
  if ([string]::IsNullOrWhiteSpace($desiredNextGap)) {
    $desiredNextGap = "OWNER_TASK_LIFECYCLE_GAP"
  }
  $expectedOutputs = @(Get-Phase160JObjectProperty -Object $Task -Names @("expected_outputs") -Default @())
  $safetyRules = Get-Phase160JObjectProperty -Object $Task -Names @("safety_rules") -Default $null

  $shape = "owner_goal_only"
  if ($planItems.Count -gt 0) {
    $shape = "owner_goal_plan_items"
  }
  if ($null -ne $safetyRules) {
    $shape = "owner_goal_safety_rules"
  }
  if ($expectedOutputs.Count -gt 0) {
    $shape = "owner_goal_expected_outputs"
  }
  if ($planItems.Count -gt 1 -and (Get-Phase160JObjectProperty -Object $Task -Names @("program", "curriculum", "lessons") -Default $null)) {
    $shape = "curriculum_program"
  }

  $createdAt = if ([string]::IsNullOrWhiteSpace($CreatedAtUtc)) { (Get-Date).ToUniversalTime().ToString("o") } else { $CreatedAtUtc }
  $hasPlanContainer = $null -ne (Get-Phase160JObjectProperty -Object $Task -Names @("plan_items", "plan_steps", "lessons", "program", "curriculum") -Default $null)
  $unsupportedTaskShape = ($hasPlanContainer -and $planItems.Count -lt 1 -and [string]::IsNullOrWhiteSpace($ownerGoal))

  return [pscustomobject][ordered]@{
    normalized_task_id = $normalizedTaskId
    original_task_id = if ([string]::IsNullOrWhiteSpace($originalTaskId)) { "NONE" } else { $originalTaskId }
    source = $source
    owner_goal = $ownerGoal
    plan_items = @($planItems)
    safety_profile = [ordered]@{
      repo_commit_allowed = Get-Phase160JTaskSafetyFlag -Task $Task -Names @("repo_commit_allowed", "commit_allowed") -Default $false
      repo_push_allowed = Get-Phase160JTaskSafetyFlag -Task $Task -Names @("repo_push_allowed", "push_allowed") -Default $false
      branch_switch_allowed = Get-Phase160JTaskSafetyFlag -Task $Task -Names @("branch_switch_allowed", "git_checkout_allowed") -Default $false
      live_repo_file_mutation_allowed = Get-Phase160JTaskSafetyFlag -Task $Task -Names @("live_repo_file_mutation_allowed", "accepted_repo_file_mutation_allowed", "repo_file_mutation_allowed") -Default $false
      protected_state_mutation_allowed = Get-Phase160JTaskSafetyFlag -Task $Task -Names @("protected_state_mutation_allowed", "accepted_state_mutation_allowed", "accepted_memory_mutation_allowed", "accepted_self_model_mutation_allowed") -Default $false
      accepted_repo_mutation_allowed = Get-Phase160JTaskSafetyFlag -Task $Task -Names @("accepted_repo_mutation_allowed", "accepted_code_mutation_allowed", "accepted_repo_file_mutation_allowed") -Default $false
      runtime_session_only = Get-Phase160JTaskSafetyFlag -Task $Task -Names @("runtime_session_only") -Default $true
      owner_promotion_required = Get-Phase160JTaskSafetyFlag -Task $Task -Names @("owner_promotion_required", "owner_approval_required") -Default $true
    }
    accepted_by_intake = $false
    quarantine_required = $false
    quarantine_reason = "NONE"
    backlog_allowed = $true
    active_allowed = $true
    created_at = $createdAt
    priority = $priority
    desired_next_gap = $desiredNextGap
    expected_outputs = @($expectedOutputs)
    task_shape = $shape
    missing_goal = [string]::IsNullOrWhiteSpace($ownerGoal)
    unsupported_task_shape = $unsupportedTaskShape
    raw_file_name = $RawFileName
    content_hash = $ContentHash
  }
}
