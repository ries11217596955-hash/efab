function Get-Phase161B1ClassifierObjectProperty {
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

function ConvertTo-Phase161B1ClassifierBoolean {
  param([object]$Value, [bool]$Default = $false)
  if ($null -eq $Value) {
    return $Default
  }
  if ($Value -is [bool]) {
    return [bool]$Value
  }
  $text = ([string]$Value).Trim().ToLowerInvariant()
  if ($text -eq "true") {
    return $true
  }
  if ($text -eq "false") {
    return $false
  }
  return $Default
}

function Get-Phase161B1ClassifierFlag {
  param([object]$Message, [string[]]$Names)
  $rules = Get-Phase161B1ClassifierObjectProperty -Object $Message -Names @("safety_rules") -Default $null
  if ($null -ne $rules) {
    foreach ($name in $Names) {
      if ($rules -is [System.Collections.IDictionary] -and $rules.Contains($name)) {
        return ConvertTo-Phase161B1ClassifierBoolean -Value $rules[$name] -Default $false
      }
      if ($rules.PSObject.Properties.Name -contains $name) {
        return ConvertTo-Phase161B1ClassifierBoolean -Value $rules.$name -Default $false
      }
    }
  }
  foreach ($name in $Names) {
    if ($null -ne $Message -and $Message -is [System.Collections.IDictionary] -and $Message.Contains($name)) {
      return ConvertTo-Phase161B1ClassifierBoolean -Value $Message[$name] -Default $false
    }
    if ($null -ne $Message -and $Message.PSObject.Properties.Name -contains $name) {
      return ConvertTo-Phase161B1ClassifierBoolean -Value $Message.$name -Default $false
    }
  }
  return $false
}

function Get-Phase161B1UnsafeReason {
  param([object]$Message)
  if (Get-Phase161B1ClassifierFlag -Message $Message -Names @("repo_commit_allowed", "commit_allowed")) {
    return "unsafe_commit_allowed"
  }
  if (Get-Phase161B1ClassifierFlag -Message $Message -Names @("repo_push_allowed", "push_allowed")) {
    return "unsafe_push_allowed"
  }
  if (Get-Phase161B1ClassifierFlag -Message $Message -Names @("branch_switch_allowed", "git_checkout_allowed")) {
    return "unsafe_branch_switch_allowed"
  }
  if (Get-Phase161B1ClassifierFlag -Message $Message -Names @("protected_state_mutation_allowed", "accepted_state_mutation_allowed", "accepted_memory_mutation_allowed", "accepted_self_model_mutation_allowed")) {
    return "unsafe_protected_state_mutation_allowed"
  }
  if (Get-Phase161B1ClassifierFlag -Message $Message -Names @("accepted_repo_mutation_allowed", "accepted_code_mutation_allowed", "accepted_repo_file_mutation_allowed", "live_repo_file_mutation_allowed", "repo_file_mutation_allowed")) {
    return "unsafe_accepted_repo_mutation_allowed"
  }
  return "NONE"
}

function Test-Phase161B1HasProperty {
  param([object]$Object, [string]$Name)
  return ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name)
}

function Invoke-Phase161B1OwnerInboxMessageClassification {
  param(
    [Parameter(Mandatory = $true)]
    [object]$NormalizedMessage
  )

  $messageType = [string]$NormalizedMessage.inferred_message_type
  $payload = $NormalizedMessage.payload
  $message = $NormalizedMessage.parsed_message

  if (-not [string]::IsNullOrWhiteSpace([string]$NormalizedMessage.parse_error)) {
    return [pscustomobject][ordered]@{
      message_type = "unknown"
      route_decision = "REJECT_MALFORMED_MESSAGE"
      route_target = "teacher_quarantine"
      accepted_by_router = $false
      quarantine_required = $true
      quarantine_reason = "malformed_json"
    }
  }

  if (@("owner_task", "curriculum_pack", "instruction", "stop", "pause") -notcontains $messageType) {
    return [pscustomobject][ordered]@{
      message_type = $messageType
      route_decision = "QUARANTINE_UNKNOWN_MESSAGE_TYPE"
      route_target = "teacher_quarantine"
      accepted_by_router = $false
      quarantine_required = $true
      quarantine_reason = "unknown_message_type"
    }
  }

  $unsafeReason = Get-Phase161B1UnsafeReason -Message $(if ($messageType -eq "curriculum_pack") { $payload } else { $message })
  if ($unsafeReason -ne "NONE") {
    return [pscustomobject][ordered]@{
      message_type = $messageType
      route_decision = "QUARANTINE_UNSAFE_MESSAGE"
      route_target = "teacher_quarantine"
      accepted_by_router = $false
      quarantine_required = $true
      quarantine_reason = $unsafeReason
    }
  }

  switch ($messageType) {
    "owner_task" {
      $ownerGoal = Get-Phase161B1ClassifierObjectProperty -Object $message -Names @("owner_goal") -Default ""
      if ([string]::IsNullOrWhiteSpace([string]$ownerGoal)) {
        return [pscustomobject][ordered]@{
          message_type = "owner_task"
          route_decision = "REJECT_MALFORMED_MESSAGE"
          route_target = "teacher_quarantine"
          accepted_by_router = $false
          quarantine_required = $true
          quarantine_reason = "missing_goal"
        }
      }
      return [pscustomobject][ordered]@{
        message_type = "owner_task"
        route_decision = "ROUTE_OWNER_TASK"
        route_target = "PHASE160J_OWNER_TASK_INTAKE"
        accepted_by_router = $true
        quarantine_required = $false
        quarantine_reason = "NONE"
      }
    }
    "curriculum_pack" {
      $lessons = @()
      if (Test-Phase161B1HasProperty -Object $payload -Name "lessons") {
        $lessons = @($payload.lessons)
      }
      if ([string]::IsNullOrWhiteSpace([string](Get-Phase161B1ClassifierObjectProperty -Object $payload -Names @("curriculum_id") -Default "")) -or $lessons.Count -lt 1) {
        return [pscustomobject][ordered]@{
          message_type = "curriculum_pack"
          route_decision = "REJECT_MALFORMED_MESSAGE"
          route_target = "teacher_quarantine"
          accepted_by_router = $false
          quarantine_required = $true
          quarantine_reason = "invalid_curriculum_schema"
        }
      }
      return [pscustomobject][ordered]@{
        message_type = "curriculum_pack"
        route_decision = "ROUTE_CURRICULUM_PACK"
        route_target = "SCHOOL_MODE"
        accepted_by_router = $true
        quarantine_required = $false
        quarantine_reason = "NONE"
      }
    }
    "instruction" {
      $target = [string](Get-Phase161B1ClassifierObjectProperty -Object $message -Names @("target") -Default "general")
      if (@("active_task", "active_school_run", "latest_candidate", "general") -notcontains $target) {
        return [pscustomobject][ordered]@{
          message_type = "instruction"
          route_decision = "QUARANTINE_UNSAFE_MESSAGE"
          route_target = "teacher_quarantine"
          accepted_by_router = $false
          quarantine_required = $true
          quarantine_reason = "unsafe_instruction_target"
        }
      }
      return [pscustomobject][ordered]@{
        message_type = "instruction"
        route_decision = "ROUTE_INSTRUCTION"
        route_target = "instruction_inbox_routed"
        accepted_by_router = $true
        quarantine_required = $false
        quarantine_reason = "NONE"
      }
    }
    "stop" {
      return [pscustomobject][ordered]@{
        message_type = "stop"
        route_decision = "ROUTE_CONTROL_STOP"
        route_target = "stop.flag"
        accepted_by_router = $true
        quarantine_required = $false
        quarantine_reason = "NONE"
      }
    }
    "pause" {
      return [pscustomobject][ordered]@{
        message_type = "pause"
        route_decision = "ROUTE_CONTROL_PAUSE"
        route_target = "pause_request.json"
        accepted_by_router = $true
        quarantine_required = $false
        quarantine_reason = "NONE"
      }
    }
  }
}
