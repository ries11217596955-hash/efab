function Normalize-Phase160KQualityPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160KQualityPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-Phase160KQualityRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160KQualityPath -Path $RepoRoot
  $full = Normalize-Phase160KQualityPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160K_QUALITY_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function Read-Phase160KQualityJsonSafe {
  param([string]$Path)
  try {
    if (-not (Test-Path -LiteralPath $Path)) {
      return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Write-Phase160KQualityJsonFile {
  param([string]$Path, [object]$Object, [int]$Depth = 100)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-Phase160KQualityProperty {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $Default
}

function Get-Phase160KQualityString {
  param([object]$Object, [string]$Name, [string]$Default = "NONE")
  $value = Get-Phase160KQualityProperty -Object $Object -Name $Name -Default $Default
  if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
    return $Default
  }
  return [string]$value
}

function Get-Phase160KQualityBool {
  param([object]$Object, [string]$Name, [bool]$Default = $false)
  $value = Get-Phase160KQualityProperty -Object $Object -Name $Name -Default $Default
  try {
    return [bool]$value
  } catch {
    return $Default
  }
}

function Get-Phase160KQualityInt {
  param([object]$Object, [string]$Name, [int]$Default = 0)
  $value = Get-Phase160KQualityProperty -Object $Object -Name $Name -Default $Default
  try {
    return [int]$value
  } catch {
    return $Default
  }
}

function Set-Phase160KQualityProperty {
  param([object]$Object, [string]$Name, [object]$Value)
  if ($null -eq $Object) {
    return
  }
  $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
}

function Get-Phase160KQualityCanonicalPath {
  param([string]$CandidateDirFull)
  return (Join-Path $CandidateDirFull "candidate_quality/quality_result.json")
}

function Get-Phase160KQualityLegacyPath {
  param([string]$CandidateDirFull)
  return (Join-Path $CandidateDirFull "quality_gate/quality_gate_result.json")
}

function ConvertTo-Phase160KCanonicalQualityResult {
  param(
    [string]$RepoRoot,
    [string]$CandidateDirFull,
    [object]$QualityRecord,
    [object]$CandidateManifest,
    [object]$CandidateStatus,
    [string]$RepairSource = "quality_gate_evaluation"
  )

  $candidateId = Get-Phase160KQualityString -Object $QualityRecord -Name "candidate_id" -Default (Get-Phase160KQualityString -Object $CandidateManifest -Name "candidate_id" -Default (Split-Path -Path $CandidateDirFull -Leaf))
  $sourceTaskId = Get-Phase160KQualityString -Object $QualityRecord -Name "source_task_id" -Default (Get-Phase160KQualityString -Object $CandidateManifest -Name "source_task_id" -Default (Get-Phase160KQualityString -Object $CandidateStatus -Name "source_task_id" -Default "NONE"))
  $qualityStatus = Get-Phase160KQualityString -Object $QualityRecord -Name "quality_status" -Default (Get-Phase160KQualityString -Object $QualityRecord -Name "status" -Default (Get-Phase160KQualityString -Object $CandidateStatus -Name "quality_status" -Default (Get-Phase160KQualityString -Object $CandidateManifest -Name "quality_status" -Default (Get-Phase160KQualityString -Object $CandidateManifest -Name "decision" -Default "UNKNOWN"))))
  $ownerPromotionAllowed = Get-Phase160KQualityBool -Object $QualityRecord -Name "owner_promotion_allowed" -Default (Get-Phase160KQualityBool -Object $CandidateStatus -Name "owner_promotion_allowed" -Default (Get-Phase160KQualityBool -Object $CandidateManifest -Name "owner_promotion_allowed" -Default ($qualityStatus -eq "CANDIDATE_READY")))
  $revisionRequired = $qualityStatus -eq "REVISION_REQUIRED"
  $failedChecks = @(Get-Phase160KQualityProperty -Object $QualityRecord -Name "failed_checks" -Default @() | ForEach-Object { [string]$_ })
  $failureReasons = @(Get-Phase160KQualityProperty -Object $QualityRecord -Name "failure_reasons" -Default @() | ForEach-Object { [string]$_ })
  $blockedReasons = @(Get-Phase160KQualityProperty -Object $QualityRecord -Name "blocked_reasons" -Default @() | ForEach-Object { [string]$_ })
  $unsafeReasons = @(Get-Phase160KQualityProperty -Object $QualityRecord -Name "unsafe_reasons" -Default @() | ForEach-Object { [string]$_ })
  $allReasons = @($failureReasons + $blockedReasons + $unsafeReasons | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  $payloadRoot = Join-Path $CandidateDirFull "proposed_patch_or_file_payloads"
  $payloadFileCount = if (Test-Path -LiteralPath $payloadRoot) { @(Get-ChildItem -LiteralPath $payloadRoot -File -Recurse -ErrorAction SilentlyContinue).Count } else { 0 }
  $placeholderDetected = (@($failedChecks | Where-Object { [string]$_ -match "(?i)placeholder|stub|outline" }).Count -gt 0)
  $outlineOnlyDetected = (@($failedChecks | Where-Object { [string]$_ -match "(?i)outline" }).Count -gt 0)
  $materializationStatus = Get-Phase160KQualityString -Object $QualityRecord -Name "materialization_status" -Default "NONE"
  $parsePassed = Get-Phase160KQualityBool -Object $QualityRecord -Name "materialization_parse_check_pass" -Default (Get-Phase160KQualityBool -Object $QualityRecord -Name "parse_check_passed" -Default $false)
  $revisionRequestPath = Get-Phase160KQualityString -Object $QualityRecord -Name "revision_request_path" -Default (Get-Phase160KQualityString -Object $CandidateStatus -Name "revision_request_path" -Default (Get-Phase160KQualityString -Object $CandidateManifest -Name "revision_request_path" -Default "NONE"))
  $score = switch ($qualityStatus) {
    "CANDIDATE_READY" { 100 }
    "REVISION_REQUIRED" { 50 }
    "CANDIDATE_DRAFT" { 10 }
    default { 0 }
  }

  return [ordered]@{
    candidate_id = $candidateId
    source_task_id = $sourceTaskId
    quality_status = $qualityStatus
    quality_score_total = $score
    real_module_payload_present = (Get-Phase160KQualityInt -Object $QualityRecord -Name "module_payload_count" -Default 0) -gt 0
    real_validator_payload_present = (Get-Phase160KQualityInt -Object $QualityRecord -Name "validator_payload_count" -Default 0) -gt 0
    proposed_payload_dir_exists = Test-Path -LiteralPath $payloadRoot
    payload_file_count = $payloadFileCount
    placeholder_detected = $placeholderDetected
    outline_only_detected = $outlineOnlyDetected
    materialization_attempted = $materializationStatus -ne "NONE"
    materialization_passed = $materializationStatus -eq "PASS"
    parse_check_attempted = $materializationStatus -ne "NONE"
    parse_check_passed = $parsePassed
    validation_plan_present = Test-Path -LiteralPath (Join-Path $CandidateDirFull "candidate_validation_plan.json")
    risk_review_present = Test-Path -LiteralPath (Join-Path $CandidateDirFull "candidate_risk_review.json")
    repo_mutation_performed = Get-Phase160KQualityBool -Object $QualityRecord -Name "repo_mutation_performed" -Default $false
    commit_performed = Get-Phase160KQualityBool -Object $QualityRecord -Name "commit_performed" -Default $false
    push_performed = Get-Phase160KQualityBool -Object $QualityRecord -Name "push_performed" -Default $false
    branch_switch_performed = Get-Phase160KQualityBool -Object $QualityRecord -Name "branch_switch_performed" -Default $false
    protected_state_mutated = Get-Phase160KQualityBool -Object $QualityRecord -Name "protected_state_mutated" -Default $false
    decision_reason = if ($allReasons.Count -gt 0) { $allReasons -join "; " } elseif ($qualityStatus -eq "CANDIDATE_READY") { "quality_gate_passed" } else { "quality_gate_evaluated" }
    revision_required = $revisionRequired
    revision_request_path = $revisionRequestPath
    owner_promotion_allowed = $ownerPromotionAllowed
    candidate_dir = ConvertTo-Phase160KQualityRelativePath -RepoRoot $RepoRoot -FullPath $CandidateDirFull
    canonical_quality_result_path = ConvertTo-Phase160KQualityRelativePath -RepoRoot $RepoRoot -FullPath (Get-Phase160KQualityCanonicalPath -CandidateDirFull $CandidateDirFull)
    legacy_quality_gate_result_path = ConvertTo-Phase160KQualityRelativePath -RepoRoot $RepoRoot -FullPath (Get-Phase160KQualityLegacyPath -CandidateDirFull $CandidateDirFull)
    repair_source = $RepairSource
    created_at = Get-Phase160KQualityString -Object $QualityRecord -Name "checked_at" -Default (Get-Phase160KQualityString -Object $QualityRecord -Name "created_at" -Default ((Get-Date).ToUniversalTime().ToString("o")))
  }
}

function Repair-Phase160KCandidateQualityArtifacts {
  param(
    [string]$RepoRoot,
    [string]$CandidateDirFull,
    [switch]$RepairMissingQualityResult
  )

  $manifestPath = Join-Path $CandidateDirFull "candidate_manifest.json"
  $statusPath = Join-Path $CandidateDirFull "candidate_status.json"
  $canonicalPath = Get-Phase160KQualityCanonicalPath -CandidateDirFull $CandidateDirFull
  $legacyPath = Get-Phase160KQualityLegacyPath -CandidateDirFull $CandidateDirFull
  $manifest = Read-Phase160KQualityJsonSafe -Path $manifestPath
  $status = Read-Phase160KQualityJsonSafe -Path $statusPath
  $canonical = Read-Phase160KQualityJsonSafe -Path $canonicalPath
  $legacy = Read-Phase160KQualityJsonSafe -Path $legacyPath
  $missingBeforeRepair = $null -eq $canonical
  $repairPerformed = $false
  $repairSource = "NONE"

  if ($null -eq $canonical -and $null -ne $legacy -and $RepairMissingQualityResult) {
    $canonical = [pscustomobject](ConvertTo-Phase160KCanonicalQualityResult -RepoRoot $RepoRoot -CandidateDirFull $CandidateDirFull -QualityRecord $legacy -CandidateManifest $manifest -CandidateStatus $status -RepairSource "legacy_quality_gate_result_backfill")
    Write-Phase160KQualityJsonFile -Path $canonicalPath -Object $canonical
    $repairPerformed = $true
    $repairSource = "legacy_quality_gate_result_backfill"
  }

  $mismatchedFields = @()
  if ($null -ne $canonical) {
    $canonicalCandidateId = Get-Phase160KQualityString -Object $canonical -Name "candidate_id"
    $canonicalStatus = Get-Phase160KQualityString -Object $canonical -Name "quality_status"
    $canonicalRevisionRequired = Get-Phase160KQualityBool -Object $canonical -Name "revision_required" -Default ($canonicalStatus -eq "REVISION_REQUIRED")
    $canonicalOwnerAllowed = Get-Phase160KQualityBool -Object $canonical -Name "owner_promotion_allowed" -Default ($canonicalStatus -eq "CANDIDATE_READY")
    $canonicalSourceTask = Get-Phase160KQualityString -Object $canonical -Name "source_task_id"

    foreach ($side in @(
      [ordered]@{ name = "candidate_manifest"; value = $manifest },
      [ordered]@{ name = "candidate_status"; value = $status }
    )) {
      $record = $side.value
      if ($null -eq $record) {
        continue
      }
      if ((Get-Phase160KQualityString -Object $record -Name "candidate_id" -Default $canonicalCandidateId) -ne $canonicalCandidateId) {
        $mismatchedFields += "$($side.name).candidate_id"
      }
      $sideStatus = Get-Phase160KQualityString -Object $record -Name "quality_status" -Default (Get-Phase160KQualityString -Object $record -Name "decision" -Default $canonicalStatus)
      if ($sideStatus -ne $canonicalStatus) {
        $mismatchedFields += "$($side.name).quality_status"
      }
      $sideRevision = Get-Phase160KQualityBool -Object $record -Name "revision_required" -Default ($sideStatus -eq "REVISION_REQUIRED")
      if ($sideRevision -ne $canonicalRevisionRequired) {
        $mismatchedFields += "$($side.name).revision_required"
      }
      $sideOwnerAllowed = Get-Phase160KQualityBool -Object $record -Name "owner_promotion_allowed" -Default ($sideStatus -eq "CANDIDATE_READY")
      if ($sideOwnerAllowed -ne $canonicalOwnerAllowed) {
        $mismatchedFields += "$($side.name).owner_promotion_allowed"
      }
      $sideSourceTask = Get-Phase160KQualityString -Object $record -Name "source_task_id" -Default $canonicalSourceTask
      if ($sideSourceTask -ne $canonicalSourceTask) {
        $mismatchedFields += "$($side.name).source_task_id"
      }
    }
  }

  return [pscustomobject][ordered]@{
    status = if ($null -eq $canonical) { "MISSING_QUALITY_RESULT" } elseif ($mismatchedFields.Count -gt 0) { "MISMATCH" } elseif ($repairPerformed) { "REPAIRED_WITH_CANONICAL_BACKFILL" } else { "PASS" }
    candidate_id = if ($null -ne $canonical) { Get-Phase160KQualityString -Object $canonical -Name "candidate_id" } elseif ($null -ne $manifest) { Get-Phase160KQualityString -Object $manifest -Name "candidate_id" -Default (Split-Path -Path $CandidateDirFull -Leaf) } else { Split-Path -Path $CandidateDirFull -Leaf }
    candidate_dir = ConvertTo-Phase160KQualityRelativePath -RepoRoot $RepoRoot -FullPath $CandidateDirFull
    canonical_quality_result_path = ConvertTo-Phase160KQualityRelativePath -RepoRoot $RepoRoot -FullPath $canonicalPath
    quality_result_exists = $null -ne $canonical
    missing_before_repair = $missingBeforeRepair
    repair_performed = $repairPerformed
    repair_source = $repairSource
    mismatch_detected = $mismatchedFields.Count -gt 0
    mismatched_fields = @($mismatchedFields | Select-Object -Unique)
    canonical_source = "candidate_quality/quality_result.json"
    recommended_repair = if ($null -eq $canonical) { "run quality gate or backfill only from legacy evaluated quality_gate result" } elseif ($mismatchedFields.Count -gt 0) { "align candidate_manifest.json and candidate_status.json to canonical quality_result.json" } else { "NONE" }
    quality_result = $canonical
    manifest = $manifest
    status_record = $status
  }
}
