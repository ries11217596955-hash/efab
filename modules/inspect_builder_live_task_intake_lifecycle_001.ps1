param(
  [string]$RepoRoot = ".",
  [string]$OutputDir = "reports/self_development",
  [string]$RuntimeRoot = "runtime_sessions/live_growth/PHASE160I_LONG_RUN_LIFECYCLE_AUDIT_INTAKE_001"
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160IIntakePath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160IIntakeRepoRoot {
  param([string]$RepoRootParameter)
  if (-not [string]::IsNullOrWhiteSpace($RepoRootParameter) -and $RepoRootParameter -ne ".") {
    return Normalize-Phase160IIntakePath -Path $RepoRootParameter
  }
  $scriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    throw "PHASE160I_INTAKE_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160IIntakePath -Path (Join-Path $scriptRoot "..")
}

function Resolve-Phase160IIntakePath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-Phase160IIntakeRelativePath {
  param([string]$Root, [string]$FullPath)
  $rootFull = Normalize-Phase160IIntakePath -Path $Root
  $pathFull = Normalize-Phase160IIntakePath -Path $FullPath
  if ($pathFull -eq $rootFull) {
    return "."
  }
  if (-not $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160I_INTAKE_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($pathFull.Substring($rootFull.Length + 1) -replace "\\", "/")
}

function Write-Phase160IIntakeJsonFile {
  param([string]$Path, [object]$Object)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-Phase160IIntakeProperty {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $Default
}

function Get-Phase160IIntakeString {
  param([object]$Object, [string]$Name, [string]$Default = "")
  $value = Get-Phase160IIntakeProperty -Object $Object -Name $Name -Default $Default
  if ($null -eq $value) {
    return $Default
  }
  return [string]$value
}

function Get-Phase160IIntakeSafetyFlag {
  param([object]$Task, [string]$Name)
  $rules = Get-Phase160IIntakeProperty -Object $Task -Name "safety_rules" -Default $null
  if ($null -ne $rules -and $rules.PSObject.Properties.Name -contains $Name) {
    return $rules.$Name
  }
  if ($null -ne $Task -and $Task.PSObject.Properties.Name -contains $Name) {
    return $Task.$Name
  }
  return $null
}

function Test-Phase160IIntakeEnvelope {
  param([object]$Task)
  $missing = @()
  if ((Get-Phase160IIntakeString -Object $Task -Name "event_type") -ne "owner_live_task_injection") {
    $missing += "event_type=owner_live_task_injection"
  }
  foreach ($required in @("task_id", "source", "priority", "owner_goal", "desired_next_gap")) {
    if ([string]::IsNullOrWhiteSpace((Get-Phase160IIntakeString -Object $Task -Name $required))) {
      $missing += $required
    }
  }
  return [pscustomobject][ordered]@{
    valid = $missing.Count -eq 0
    missing_or_invalid_fields = @($missing)
  }
}

function Test-Phase160IIntakeSafety {
  param([object]$Task)
  $missing = @()
  $wrong = @()
  foreach ($flag in @("accepted_state_mutation_allowed", "accepted_memory_mutation_allowed", "accepted_self_model_mutation_allowed", "repo_commit_allowed")) {
    $value = Get-Phase160IIntakeSafetyFlag -Task $Task -Name $flag
    if ($null -eq $value) {
      $missing += "safety_rules.$flag"
    } elseif ([bool]$value -ne $false) {
      $wrong += "safety_rules.$flag"
    }
  }
  $runtimeOnly = Get-Phase160IIntakeSafetyFlag -Task $Task -Name "runtime_session_only"
  if ($null -eq $runtimeOnly) {
    $missing += "safety_rules.runtime_session_only"
  } elseif ([bool]$runtimeOnly -ne $true) {
    $wrong += "safety_rules.runtime_session_only"
  }
  return [pscustomobject][ordered]@{
    valid = ($missing.Count -eq 0 -and $wrong.Count -eq 0)
    missing_fields = @($missing)
    wrong_value_fields = @($wrong)
  }
}

function New-Phase160IIntakeSyntheticTasks {
  $canonicalSafety = [ordered]@{
    accepted_state_mutation_allowed = $false
    accepted_memory_mutation_allowed = $false
    accepted_self_model_mutation_allowed = $false
    repo_commit_allowed = $false
    runtime_session_only = $true
  }
  return @(
    [ordered]@{
      fixture_id = "task_with_owner_goal_only"
      safe_intent = $true
      task = [ordered]@{
        owner_goal = "Audit whether an owner goal without the live-task envelope is handled honestly."
      }
    },
    [ordered]@{
      fixture_id = "task_with_safety_rules"
      safe_intent = $true
      task = [ordered]@{
        event_type = "owner_live_task_injection"
        task_id = "PHASE160I_SAFE_INTENT_ALTERNATE_SAFETY_RULES_001"
        source = "owner"
        priority = "high"
        owner_goal = "Run a safe owner training task without accepted state mutation."
        desired_next_gap = "LONG_RUN_LIFECYCLE_VISIBILITY_AND_BATCH_READINESS_GAP"
        safety_rules = [ordered]@{
          no_accepted_state_mutation = $true
          no_repo_commit = $true
          runtime_session_only = $true
        }
      }
    },
    [ordered]@{
      fixture_id = "task_with_expected_outputs"
      safe_intent = $true
      task = [ordered]@{
        event_type = "owner_live_task_injection"
        task_id = "PHASE160I_EXPECTED_OUTPUTS_SAFE_001"
        source = "owner"
        priority = "normal"
        owner_goal = "Create an audit-only expected output without accepted code mutation."
        desired_next_gap = "LONG_RUN_LIFECYCLE_VISIBILITY_AND_BATCH_READINESS_GAP"
        expected_outputs = @("stage audit JSON", "repair map")
        safety_rules = $canonicalSafety
      }
    },
    [ordered]@{
      fixture_id = "task_with_multiple_plan_items"
      safe_intent = $true
      task = [ordered]@{
        event_type = "owner_live_task_injection"
        task_id = "PHASE160I_MULTI_PLAN_SAFE_001"
        source = "owner"
        priority = "normal"
        owner_goal = "Split a safe owner training request into several session-local plan items."
        desired_next_gap = "LONG_RUN_LIFECYCLE_VISIBILITY_AND_BATCH_READINESS_GAP"
        plan_steps = @(
          "Inspect live task intake.",
          "Inspect active task backlog transition.",
          "Inspect quality artifacts."
        )
        safety_rules = $canonicalSafety
      }
    }
  )
}

$resolvedRoot = Resolve-Phase160IIntakeRepoRoot -RepoRootParameter $RepoRoot
$pushed = $false

try {
  Push-Location $resolvedRoot
  $pushed = $true
  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160IIntakePath -Root $resolvedRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  $outputRootFull = Resolve-Phase160IIntakePath -Root $resolvedRoot -Path $OutputDir
  $runtimeRootFull = Resolve-Phase160IIntakePath -Root $resolvedRoot -Path $RuntimeRoot
  $teacherInboxFull = Join-Path $runtimeRootFull "teacher_inbox"
  New-Item -ItemType Directory -Force -Path $teacherInboxFull | Out-Null

  $existingActive = $false
  $results = @()
  foreach ($fixture in New-Phase160IIntakeSyntheticTasks) {
    $task = [pscustomobject]$fixture.task
    $taskPath = Join-Path $teacherInboxFull ("{0}.json" -f [string]$fixture.fixture_id)
    Write-Phase160IIntakeJsonFile -Path $taskPath -Object $fixture.task
    $envelope = Test-Phase160IIntakeEnvelope -Task $task
    $safety = Test-Phase160IIntakeSafety -Task $task
    $classification = "ACCEPTABLE"
    $reason = "accepted_by_live_task_envelope_and_safety_rules"
    if (-not [bool]$envelope.valid) {
      $classification = "QUARANTINED"
      $reason = "invalid_live_task_envelope"
    } elseif (-not [bool]$safety.valid) {
      $classification = "QUARANTINED"
      $reason = "unsafe_live_task_safety_rules"
    } elseif (-not $existingActive) {
      $classification = "ACTIVE"
      $existingActive = $true
    } else {
      $classification = "BACKLOG"
      $reason = "existing_active_task_retained"
    }
    $results += [ordered]@{
      fixture_id = [string]$fixture.fixture_id
      task_id = Get-Phase160IIntakeString -Object $task -Name "task_id" -Default "NONE"
      safe_intent = [bool]$fixture.safe_intent
      classification = $classification
      reason = $reason
      envelope_valid = [bool]$envelope.valid
      missing_or_invalid_envelope_fields = @($envelope.missing_or_invalid_fields)
      safety_valid = [bool]$safety.valid
      missing_required_safety_fields = @($safety.missing_fields)
      wrong_value_safety_fields = @($safety.wrong_value_fields)
      synthetic_task_path = ConvertTo-Phase160IIntakeRelativePath -Root $resolvedRoot -FullPath $taskPath
    }
  }

  $unsafeRecord = @($results | Where-Object { $_.reason -eq "unsafe_live_task_safety_rules" } | Select-Object -First 1)
  $audit = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage = "STAGE 1 - OWNER LIVE TASK INTAKE"
    stage_id = "stage_01_owner_task_intake_audit"
    synthetic_runtime_root = ConvertTo-Phase160IIntakeRelativePath -Root $resolvedRoot -FullPath $runtimeRootFull
    synthetic_task_count = $results.Count
    classifications = @($results)
    unsafe_live_task_safety_rules = [ordered]@{
      detected = $null -ne $unsafeRecord
      reason = "unsafe_live_task_safety_rules"
      exact_triggering_fields = if ($null -ne $unsafeRecord) { @($unsafeRecord.missing_required_safety_fields) + @($unsafeRecord.wrong_value_safety_fields) } else { @() }
      root_cause = "Live intake accepts only exact safety flag names accepted_state_mutation_allowed=false, accepted_memory_mutation_allowed=false, accepted_self_model_mutation_allowed=false, repo_commit_allowed=false, and runtime_session_only=true. Safe-intent alternate rule names are quarantined."
      safety_rules_schema_assessment = "TOO_STRICT_AND_BADLY_NAMED_FOR_SAFE_OWNER_TRAINING_TASKS"
      safe_owner_training_task_falsely_quarantined = ($null -ne $unsafeRecord -and [bool]$unsafeRecord.safe_intent)
    }
    expected_outputs_field_effect = "expected_outputs is accepted when canonical envelope and canonical safety flags are present."
    multiple_plan_items_effect = "plan_steps are acceptable and become backlog when another valid task already owns active_task."
    observed_recent_run_alignment = [ordered]@{
      owner_reported_quarantine_reason = "unsafe_live_task_safety_rules"
      audit_reproduces_root_cause_class = $null -ne $unsafeRecord
    }
    blocks_phase161 = $true
    repair_package = "TASK_INTAKE_SCHEMA_AND_SAFETY_RULES_REPAIR"
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  $stagePath = Join-Path $outputRootFull "stage_01_owner_task_intake_audit.json"
  Write-Phase160IIntakeJsonFile -Path $stagePath -Object $audit
  $audit | ConvertTo-Json -Depth 100
} finally {
  if ($pushed) {
    Pop-Location
  }
}
