. (Join-Path $PSScriptRoot "normalize_builder_owner_inbox_message_001.ps1")
. (Join-Path $PSScriptRoot "classify_builder_owner_inbox_message_type_001.ps1")
. (Join-Path $PSScriptRoot "quarantine_builder_owner_inbox_message_001.ps1")
. (Join-Path $PSScriptRoot "inspect_builder_owner_inbox_router_state_001.ps1")

function Resolve-Phase161B1RouterPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase161B1RouterRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  if ([string]::IsNullOrWhiteSpace($FullPath)) {
    return "NONE"
  }
  $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  $path = [System.IO.Path]::GetFullPath($FullPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  if ($path -eq $root) {
    return "."
  }
  if (-not $path.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $FullPath
  }
  return ($path.Substring($root.Length + 1) -replace "\\", "/")
}

function Add-Phase161B1RouterJsonLine {
  param([string]$Path, [object]$Object)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $line = $Object | ConvertTo-Json -Depth 100 -Compress
  [System.IO.File]::AppendAllText($Path, "$line`n", [System.Text.UTF8Encoding]::new($false))
}

function ConvertTo-Phase161B1RouterOrderedState {
  param([object]$Object)
  $state = [ordered]@{}
  if ($null -ne $Object) {
    foreach ($property in $Object.PSObject.Properties) {
      $state[$property.Name] = $property.Value
    }
  }
  return $state
}

function Update-Phase161B1RouterCurrentState {
  param(
    [string]$SessionRootFull,
    [object]$RouterState,
    [object]$LearningDecision = $null
  )
  $currentStatePath = Join-Path $SessionRootFull "current_state.json"
  $existing = Read-Phase161B1RouterJsonSafe -Path $currentStatePath
  $state = ConvertTo-Phase161B1RouterOrderedState -Object $existing
  foreach ($property in $RouterState.PSObject.Properties) {
    $state[$property.Name] = $property.Value
  }
  if ($null -ne $LearningDecision) {
    foreach ($name in @("learning_mode", "active_curriculum_id", "active_school_run_id", "school_mode_allowed", "self_mode_allowed", "selected_curriculum_source", "recommended_next_self_gap")) {
      if ($LearningDecision.PSObject.Properties.Name -contains $name) {
        $state[$name] = $LearningDecision.$name
      }
    }
    if ($LearningDecision.PSObject.Properties.Name -contains "decision_reason") {
      $state["learning_mode_decision_reason"] = $LearningDecision.decision_reason
    }
  }
  $state["owner_inbox_router_enabled"] = $true
  $state["accepted_repo_mutation_allowed"] = $false
  $state["protected_state_mutation_allowed"] = $false
  Write-Phase161B1RouterJsonFile -Path $currentStatePath -Object $state
}

function Invoke-Phase161B1JsonScript {
  param(
    [string]$RepoRoot,
    [string]$ScriptRelativePath,
    [string[]]$Arguments
  )
  $scriptPath = Join-Path $RepoRoot $ScriptRelativePath
  $output = @(powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE161B1_ROUTER_SCRIPT_FAILED=$ScriptRelativePath output=$($output -join ' | ')"
  }
  return ($output -join "`n") | ConvertFrom-Json
}

function Invoke-Phase161B1OwnerInboxRouter {
  param(
    [string]$RepoRoot,
    [string]$SessionRootFull,
    [string]$SessionRootRelative = "",
    [string]$DutyId = "NONE",
    [string]$EventLogPath = ""
  )

  $teacherInbox = Join-Path $SessionRootFull "teacher_inbox"
  $teacherConsumed = Join-Path $SessionRootFull "teacher_consumed"
  $routerRoot = Join-Path $SessionRootFull "owner_inbox_router"
  $routeRecordsRoot = Join-Path $routerRoot "route_records"
  $instructionRouted = Join-Path $SessionRootFull "instruction_inbox_routed"
  $learningCurriculumOwner = Join-Path $RepoRoot "runtime_sessions/learning_curricula/owner"
  foreach ($directory in @($teacherInbox, $teacherConsumed, $routeRecordsRoot, $instructionRouted, $learningCurriculumOwner)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $files = @(Get-ChildItem -LiteralPath $teacherInbox -File -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.json" } | Sort-Object FullName)
  $processed = 0
  $curriculumRouted = 0
  $ownerTaskRouted = 0
  $instructionRoutedCount = 0
  $controlRouted = 0
  $quarantined = 0
  $lastRecord = $null
  $lastDecision = $null

  foreach ($file in $files) {
    $processed += 1
    $normalized = ConvertTo-Phase161B1OwnerInboxMessageNormalized -Path $file.FullName
    $classification = Invoke-Phase161B1OwnerInboxMessageClassification -NormalizedMessage $normalized
    $routeRecord = [pscustomobject][ordered]@{
      message_id = [string]$normalized.message_id
      original_file = [string]$normalized.original_file
      message_type = [string]$classification.message_type
      route_decision = [string]$classification.route_decision
      route_target = [string]$classification.route_target
      accepted_by_router = [bool]$classification.accepted_by_router
      quarantine_required = [bool]$classification.quarantine_required
      quarantine_reason = [string]$classification.quarantine_reason
      curriculum_id = [string]$normalized.curriculum_id
      owner_task_id = [string]$normalized.owner_task_id
      instruction_target = [string]$normalized.instruction_target
      created_at = (Get-Date).ToUniversalTime().ToString("o")
      accepted_repo_mutation_allowed = $false
      protected_state_mutation_allowed = $false
    }

    if ([bool]$classification.quarantine_required) {
      $quarantine = Invoke-Phase161B1OwnerInboxMessageQuarantine -SessionRootFull $SessionRootFull -RouteRecord $routeRecord -RawFileFullPath $file.FullName -Reason ([string]$classification.quarantine_reason)
      $routeRecord.route_target = ConvertTo-Phase161B1RouterRelativePath -RepoRoot $RepoRoot -FullPath $quarantine.quarantine_path
      $quarantined += 1
    } elseif ([string]$classification.route_decision -eq "ROUTE_CURRICULUM_PACK") {
      $safeCurriculumId = ConvertTo-Phase161B1InboxSafeLeaf -Value ([string]$normalized.curriculum_id) -MaxLength 80
      $stagedPackPath = Get-Phase161B1UniqueFilePath -Directory $learningCurriculumOwner -Name ("{0}_{1}.json" -f $safeCurriculumId, ([string]$normalized.content_hash).Substring(0, 12))
      Write-Phase161B1RouterJsonFile -Path $stagedPackPath -Object $normalized.payload
      $validation = Invoke-Phase161B1JsonScript -RepoRoot $RepoRoot -ScriptRelativePath "modules/validate_builder_curriculum_pack_schema_001.ps1" -Arguments @("-RepoRoot", $RepoRoot, "-CurriculumPackPath", $stagedPackPath)
      if ([string]$validation.status -ne "PASS") {
        $routeRecord.route_decision = "REJECT_MALFORMED_MESSAGE"
        $routeRecord.accepted_by_router = $false
        $routeRecord.quarantine_required = $true
        $routeRecord.quarantine_reason = "invalid_curriculum_schema"
        $quarantine = Invoke-Phase161B1OwnerInboxMessageQuarantine -SessionRootFull $SessionRootFull -RouteRecord $routeRecord -RawFileFullPath $file.FullName -Reason "invalid_curriculum_schema"
        $routeRecord.route_target = ConvertTo-Phase161B1RouterRelativePath -RepoRoot $RepoRoot -FullPath $quarantine.quarantine_path
        $quarantined += 1
      } else {
        $schoolRunId = "PHASE161B1_ROUTED_{0}_{1}" -f $safeCurriculumId, ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfff"))
        $ingest = Invoke-Phase161B1JsonScript -RepoRoot $RepoRoot -ScriptRelativePath "modules/ingest_builder_curriculum_pack_001.ps1" -Arguments @("-RepoRoot", $RepoRoot, "-CurriculumPackPath", $stagedPackPath, "-SchoolRunId", $schoolRunId)
        Write-Phase161B1RouterJsonFile -Path (Join-Path $SessionRootFull "school_run_pointer.json") -Object ([ordered]@{
          school_run_id = [string]$ingest.school_run_id
          curriculum_id = [string]$normalized.curriculum_id
          source_message_id = [string]$normalized.message_id
          source = "teacher_inbox"
          created_at = (Get-Date).ToUniversalTime().ToString("o")
        })
        $lastDecision = Invoke-Phase161B1JsonScript -RepoRoot $RepoRoot -ScriptRelativePath "modules/decide_builder_learning_mode_001.ps1" -Arguments @("-RepoRoot", $RepoRoot, "-SessionRoot", $SessionRootFull, "-CurriculumPackPath", $stagedPackPath, "-CurriculumSource", "owner", "-SchoolRunId", $schoolRunId, "-DecisionId", ("PHASE161B1_ROUTER_" + [string]$normalized.message_id), "-EmitJson")
        $routeRecord.route_target = [string]$ingest.school_run_root
        $curriculumRouted += 1
        [void](Move-Phase161B1RouterFileUnique -SourcePath $file.FullName -DestinationDirectory $teacherConsumed -Prefix "raw_curriculum_")
      }
    } elseif ([string]$classification.route_decision -eq "ROUTE_INSTRUCTION") {
      $targetPath = Get-Phase161B1UniqueFilePath -Directory $instructionRouted -Name ("instruction_{0}.json" -f ([string]$normalized.message_id))
      Write-Phase161B1RouterJsonFile -Path $targetPath -Object $normalized.parsed_message
      $routeRecord.route_target = ConvertTo-Phase161B1RouterRelativePath -RepoRoot $RepoRoot -FullPath $targetPath
      $instructionRoutedCount += 1
      [void](Move-Phase161B1RouterFileUnique -SourcePath $file.FullName -DestinationDirectory $teacherConsumed -Prefix "raw_instruction_")
    } elseif ([string]$classification.route_decision -eq "ROUTE_CONTROL_STOP") {
      Write-Phase161B1RouterJsonFile -Path (Join-Path $SessionRootFull "stop.flag") -Object ([ordered]@{
        requested_by_message_id = [string]$normalized.message_id
        source = "teacher_inbox"
        accepted_repo_mutation_allowed = $false
        protected_state_mutation_allowed = $false
        created_at = (Get-Date).ToUniversalTime().ToString("o")
      })
      $controlRouted += 1
      [void](Move-Phase161B1RouterFileUnique -SourcePath $file.FullName -DestinationDirectory $teacherConsumed -Prefix "raw_stop_")
    } elseif ([string]$classification.route_decision -eq "ROUTE_CONTROL_PAUSE") {
      Write-Phase161B1RouterJsonFile -Path (Join-Path $SessionRootFull "pause_request.json") -Object ([ordered]@{
        requested_by_message_id = [string]$normalized.message_id
        source = "teacher_inbox"
        accepted_repo_mutation_allowed = $false
        protected_state_mutation_allowed = $false
        created_at = (Get-Date).ToUniversalTime().ToString("o")
      })
      $controlRouted += 1
      [void](Move-Phase161B1RouterFileUnique -SourcePath $file.FullName -DestinationDirectory $teacherConsumed -Prefix "raw_pause_")
    } elseif ([string]$classification.route_decision -eq "ROUTE_OWNER_TASK") {
      $ownerTaskRouted += 1
    }

    $routeRecordPath = Join-Path $routeRecordsRoot ("{0}.json" -f ([string]$routeRecord.message_id))
    Write-Phase161B1RouterJsonFile -Path $routeRecordPath -Object $routeRecord
    Write-Phase161B1RouterJsonFile -Path (Join-Path $routerRoot "last_route.json") -Object $routeRecord
    $lastRecord = $routeRecord
    if (-not [string]::IsNullOrWhiteSpace($EventLogPath)) {
      Add-Phase161B1RouterJsonLine -Path $EventLogPath -Object ([ordered]@{
        event_type = "owner_inbox_router_decision"
        source = "owner_inbox_router"
        duty_id = $DutyId
        message_id = [string]$routeRecord.message_id
        message_type = [string]$routeRecord.message_type
        route_decision = [string]$routeRecord.route_decision
        quarantine_reason = [string]$routeRecord.quarantine_reason
        occurred_at = (Get-Date).ToUniversalTime().ToString("o")
      })
    }
  }

  $routerState = Get-Phase161B1OwnerInboxRouterState -SessionRootFull $SessionRootFull
  Update-Phase161B1RouterCurrentState -SessionRootFull $SessionRootFull -RouterState $routerState -LearningDecision $lastDecision
  return [pscustomobject][ordered]@{
    status = "PASS"
    owner_inbox_router_enabled = $true
    processed_count = $processed
    curriculum_pack_routed_count = $curriculumRouted
    owner_task_routed_count = $ownerTaskRouted
    instruction_routed_count = $instructionRoutedCount
    control_message_routed_count = $controlRouted
    quarantine_count = $quarantined
    last_owner_inbox_message_type = if ($null -ne $lastRecord) { [string]$lastRecord.message_type } else { "NONE" }
    last_owner_inbox_route_decision = if ($null -ne $lastRecord) { [string]$lastRecord.route_decision } else { "NONE" }
    last_owner_inbox_quarantine_reason = if ($null -ne $lastRecord) { [string]$lastRecord.quarantine_reason } else { "NONE" }
    accepted_repo_mutation_allowed = $false
    protected_state_mutation_allowed = $false
  }
}
