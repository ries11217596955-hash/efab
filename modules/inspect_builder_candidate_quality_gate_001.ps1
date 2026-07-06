param(
  [string]$CandidateDir = "",
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [int]$MaxRetryLimit = 2
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "normalize_builder_candidate_quality_artifacts_001.ps1")

function Normalize-Phase160HQualityFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160HQualityRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160H_QUALITY_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160HQualityFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160HQualityPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Assert-Phase160HQualityPathInside {
  param([string]$Root, [string]$FullPath, [string]$Label)
  $root = Normalize-Phase160HQualityFullPath -Path $Root
  $full = Normalize-Phase160HQualityFullPath -Path $FullPath
  if (-not ($full -eq $root -or $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "PHASE160H_QUALITY_PATH_OUTSIDE_$Label=$FullPath"
  }
  return $full
}

function ConvertTo-Phase160HQualityRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160HQualityFullPath -Path $RepoRoot
  $full = Normalize-Phase160HQualityFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160H_QUALITY_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function ConvertTo-Phase160HQualityDotNetFileSystemPath {
  param([string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  if ([System.IO.Path]::DirectorySeparatorChar -ne '\') {
    return $full
  }
  if ($full.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
    return $full
  }
  if ($full.StartsWith('\\', [System.StringComparison]::Ordinal)) {
    return '\\?\UNC\' + $full.Substring(2)
  }
  return '\\?\' + $full
}

function Test-Phase160HQualityFileExists {
  param([string]$Path)
  return [System.IO.File]::Exists((ConvertTo-Phase160HQualityDotNetFileSystemPath -Path $Path))
}

function Test-Phase160HQualityDirectoryExists {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $true
  }
  return [System.IO.Directory]::Exists((ConvertTo-Phase160HQualityDotNetFileSystemPath -Path $Path))
}

function New-Phase160HQualityDirectory {
  param([string]$Path)
  if (-not [string]::IsNullOrWhiteSpace($Path)) {
    [System.IO.Directory]::CreateDirectory((ConvertTo-Phase160HQualityDotNetFileSystemPath -Path $Path)) | Out-Null
  }
}

function Read-Phase160HQualityTextFile {
  param([string]$Path)
  return [System.IO.File]::ReadAllText((ConvertTo-Phase160HQualityDotNetFileSystemPath -Path $Path), [System.Text.UTF8Encoding]::new($false))
}

function Write-Phase160HQualityTextFile {
  param([string]$Path, [string]$Text)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Phase160HQualityDirectoryExists -Path $directory)) {
    New-Phase160HQualityDirectory -Path $directory
  }
  [System.IO.File]::WriteAllText((ConvertTo-Phase160HQualityDotNetFileSystemPath -Path $Path), $Text, [System.Text.UTF8Encoding]::new($false))
}

function Write-Phase160HQualityJsonFile {
  param([string]$Path, [object]$Object, [int]$Depth = 100)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Phase160HQualityDirectoryExists -Path $directory)) {
    New-Phase160HQualityDirectory -Path $directory
  }
  $json = ($Object | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  Write-Phase160HQualityTextFile -Path $Path -Text $json
}

function Read-Phase160HQualityJsonSafe {
  param([string]$Path)
  try {
    if (-not (Test-Phase160HQualityFileExists -Path $Path)) {
      return $null
    }
    return Read-Phase160HQualityTextFile -Path $Path | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-Phase160HQualityProperty {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $Default
}

function Set-Phase160HQualityProperty {
  param([object]$Object, [string]$Name, [object]$Value)
  if ($null -eq $Object) {
    return
  }
  $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
}

function Test-Phase160HQualityRelativePathSafe {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $false
  }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $false
  }
  $parts = @($Path -split "[\\/]+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  return (@($parts | Where-Object { $_ -eq ".." }).Count -eq 0)
}

function Test-Phase160HQualityProtectedTargetPath {
  param([string]$Path)
  $normalized = ([string]$Path) -replace "\\", "/"
  $protectedPaths = @(
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
  )
  return @($protectedPaths | Where-Object { $normalized -ieq $_ }).Count -gt 0
}

function Test-Phase160HQualityUnsafePayloadText {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $false
  }
  $unsafePatterns = @(
    "(?i)\bgit\s+commit\b",
    "(?i)\bgit\s+push\b",
    "(?i)\bgit\s+checkout\b",
    "(?i)\bgit\s+switch\b",
    "(?i)\bgit\s+reset\b",
    "(?i)\bgit\s+merge\b",
    "(?i)\bgit\s+rebase\b",
    "(?i)Start-Process\s+git",
    "(?i)\bSet-Content\b.*\b(TASK_QUEUE|GENESIS_STATE|CAPABILITY_ROADMAP|packs[/\\]registry|orchestrator[/\\]run\.ps1)\b",
    "(?i)\[System\.IO\.File\]::WriteAllText\(.*\b(TASK_QUEUE|GENESIS_STATE|CAPABILITY_ROADMAP|packs[/\\]registry|orchestrator[/\\]run\.ps1)\b",
    '(?i)commit_performed\s*=\s*\$true',
    '(?i)push_performed\s*=\s*\$true',
    '(?i)branch_switch_performed\s*=\s*\$true',
    '(?i)protected_state_mutated\s*=\s*\$true'
  )
  foreach ($pattern in $unsafePatterns) {
    if ($Text -match $pattern) {
      return $true
    }
  }
  return $false
}

function Test-Phase160HQualityStubPayloadText {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $true
  }
  if ($Text.Trim().Length -lt 120) {
    return $true
  }
  $stubPatterns = @(
    "(?i)\bTODO\b",
    "(?i)\bFIXME\b",
    "(?i)IMPLEMENT_ME",
    "(?i)not implemented",
    "(?i)outline-only",
    "(?i)\bplaceholder\b",
    "(?i)\bstub\b"
  )
  foreach ($pattern in $stubPatterns) {
    if ($Text -match $pattern) {
      return $true
    }
  }
  return $false
}

function Invoke-Phase160HQualityMaterialization {
  param([string]$RepoRoot, [string]$CandidateDirRelative, [string]$SessionRoot, [string]$RunId)
  $materializerScript = Resolve-Phase160HQualityPath -RepoRoot $RepoRoot -Path "modules/test_builder_candidate_payload_materialization_001.ps1"
  if (-not (Test-Path -LiteralPath $materializerScript)) {
    throw "PHASE160H_QUALITY_MATERIALIZER_MISSING=modules/test_builder_candidate_payload_materialization_001.ps1"
  }
  $output = @(powershell -NoProfile -ExecutionPolicy Bypass -File $materializerScript -CandidateDir $CandidateDirRelative -SessionRoot $SessionRoot -RunId $RunId 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject][ordered]@{
      status = "FAIL"
      parser_checks_pass = $false
      failures = @("materializer invocation failed: $($output -join ' | ')")
    }
  }
  return ($output -join "`n") | ConvertFrom-Json
}

function Invoke-Phase160HQualityRevisionRequest {
  param(
    [string]$RepoRoot,
    [string]$CandidateDirRelative,
    [string]$CandidateId,
    [string]$QualityStatus,
    [string[]]$FailedChecks,
    [string[]]$FailureReasons,
    [string[]]$RequiredPayloadImprovements,
    [int]$RetryNumber,
    [int]$MaxRetryLimit
  )
  $revisionScript = Resolve-Phase160HQualityPath -RepoRoot $RepoRoot -Path "modules/invoke_builder_candidate_revision_request_001.ps1"
  if (-not (Test-Path -LiteralPath $revisionScript)) {
    throw "PHASE160H_QUALITY_REVISION_SCRIPT_MISSING=modules/invoke_builder_candidate_revision_request_001.ps1"
  }
  $output = @(powershell -NoProfile -ExecutionPolicy Bypass -File $revisionScript `
    -CandidateDir $CandidateDirRelative `
    -CandidateId $CandidateId `
    -QualityStatus $QualityStatus `
    -FailedChecks $FailedChecks `
    -FailureReasons $FailureReasons `
    -RequiredPayloadImprovements $RequiredPayloadImprovements `
    -RetryNumber $RetryNumber `
    -MaxRetryLimit $MaxRetryLimit 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE160H_QUALITY_REVISION_REQUEST_FAILED output=$($output -join ' | ')"
  }
  return ($output -join "`n") | ConvertFrom-Json
}

$RepoRoot = Resolve-Phase160HQualityRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160HQualityPath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  if ([string]::IsNullOrWhiteSpace($CandidateDir)) {
    throw "PHASE160H_QUALITY_CANDIDATE_DIR_REQUIRED"
  }
  if ($MaxRetryLimit -lt 0) {
    $MaxRetryLimit = 0
  }

  $CandidateDirFull = Resolve-Phase160HQualityPath -RepoRoot $RepoRoot -Path $CandidateDir
  $CandidateDirFull = Assert-Phase160HQualityPathInside -Root $RepoRoot -FullPath $CandidateDirFull -Label "REPO"
  if (-not (Test-Path -LiteralPath $CandidateDirFull)) {
    throw "PHASE160H_QUALITY_CANDIDATE_DIR_MISSING=$CandidateDir"
  }
  $CandidateDirRelative = ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $CandidateDirFull

  $manifestPath = Join-Path $CandidateDirFull "candidate_manifest.json"
  $proposedFilesPath = Join-Path $CandidateDirFull "proposed_files.json"
  $validationPlanPath = Join-Path $CandidateDirFull "candidate_validation_plan.json"
  $riskReviewPath = Join-Path $CandidateDirFull "candidate_risk_review.json"
  $candidateStatusPath = Join-Path $CandidateDirFull "candidate_status.json"
  $payloadRoot = Join-Path $CandidateDirFull "proposed_patch_or_file_payloads"

  $manifest = Read-Phase160HQualityJsonSafe -Path $manifestPath
  $proposedFiles = Read-Phase160HQualityJsonSafe -Path $proposedFilesPath
  $validationPlan = Read-Phase160HQualityJsonSafe -Path $validationPlanPath
  $riskReview = Read-Phase160HQualityJsonSafe -Path $riskReviewPath
  $candidateStatus = Read-Phase160HQualityJsonSafe -Path $candidateStatusPath
  $existingRevision = Read-Phase160HQualityJsonSafe -Path (Join-Path $CandidateDirFull "revision_request.json")
  $candidateId = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "candidate_id") { [string]$manifest.candidate_id } else { Split-Path -Path $CandidateDirFull -Leaf }
  $retryNumber = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "revision_retry_number") { [int]$manifest.revision_retry_number } elseif ($null -ne $existingRevision -and $existingRevision.PSObject.Properties.Name -contains "retry_number") { [int]$existingRevision.retry_number } else { 0 }

  $failedChecks = @()
  $failureReasons = @()
  $requiredImprovements = @()
  $blockedReasons = @()
  $unsafeReasons = @()

  $requiredJsonFiles = @(
    [ordered]@{ name = "candidate_manifest.json"; value = $manifest },
    [ordered]@{ name = "proposed_files.json"; value = $proposedFiles },
    [ordered]@{ name = "candidate_validation_plan.json"; value = $validationPlan },
    [ordered]@{ name = "candidate_risk_review.json"; value = $riskReview },
    [ordered]@{ name = "candidate_status.json"; value = $candidateStatus }
  )
  foreach ($requiredJsonFile in $requiredJsonFiles) {
    if ($null -eq $requiredJsonFile.value) {
      $failedChecks += "missing_or_unreadable_$($requiredJsonFile.name)"
      $failureReasons += "$($requiredJsonFile.name) is required before a candidate can be ready."
    }
  }

  if (-not (Test-Phase160HQualityDirectoryExists -Path $payloadRoot)) {
    $failedChecks += "missing_proposed_patch_or_file_payloads"
    $failureReasons += "proposed_patch_or_file_payloads directory is missing."
  }

  $payloads = if ($null -ne $proposedFiles) { @(Get-Phase160HQualityProperty -Object $proposedFiles -Name "proposed_payloads" -Default @()) } else { @() }
  if ($payloads.Count -lt 1) {
    $failedChecks += "missing_proposed_payloads"
    $failureReasons += "proposed_files.json does not list real proposed payload files."
    $requiredImprovements += "Add proposed_payloads entries for one module payload and one validator payload."
  }

  $modulePayloads = @()
  $validatorPayloads = @()
  $payloadTexts = @()
  $payloadTargets = @()
  foreach ($payload in $payloads) {
    $kind = [string](Get-Phase160HQualityProperty -Object $payload -Name "kind" -Default "unknown")
    $targetPath = [string](Get-Phase160HQualityProperty -Object $payload -Name "target_path" -Default "")
    $payloadPath = [string](Get-Phase160HQualityProperty -Object $payload -Name "payload_path" -Default "")
    $payloadTargets += $targetPath
    if ($targetPath -match "(?i)placeholder|accepted_candidate_placeholder") {
      $failedChecks += "placeholder_target_path"
      $failureReasons += "Proposed target path is a placeholder: $targetPath"
    }
    if (Test-Phase160HQualityProtectedTargetPath -Path $targetPath) {
      $blockedReasons += "protected target path requested: $targetPath"
    }
    if (-not (Test-Phase160HQualityRelativePathSafe -Path $payloadPath)) {
      $failedChecks += "unsafe_or_missing_payload_path"
      $failureReasons += "Payload path is missing or unsafe for target $targetPath."
      continue
    }
    $payloadFullPath = [System.IO.Path]::GetFullPath((Join-Path $CandidateDirFull $payloadPath))
    $payloadFullPath = Assert-Phase160HQualityPathInside -Root $CandidateDirFull -FullPath $payloadFullPath -Label "CANDIDATE"
    if (-not (Test-Phase160HQualityFileExists -Path $payloadFullPath)) {
      $failedChecks += "payload_file_missing"
      $failureReasons += "Payload file is missing: $payloadPath"
      continue
    }
    $payloadText = Read-Phase160HQualityTextFile -Path $payloadFullPath
    $payloadTexts += $payloadText
    if (Test-Phase160HQualityStubPayloadText -Text $payloadText) {
      $failedChecks += "placeholder_empty_outline_or_stub_payload"
      $failureReasons += "Payload file is empty, placeholder, outline-only, or stub-like: $payloadPath"
    }
    if (Test-Phase160HQualityUnsafePayloadText -Text $payloadText) {
      $unsafeReasons += "unsafe mutation or git operation requested in payload $payloadPath"
    }
    if ($kind -eq "module" -or $targetPath -match "^modules[/\\].+\.ps1$") {
      $modulePayloads += $payload
    }
    if ($kind -eq "validator" -or $targetPath -match "^validators[/\\].+\.ps1$") {
      $validatorPayloads += $payload
    }
  }

  $manifestProposedFilePaths = if ($null -ne $manifest) { @(Get-Phase160HQualityProperty -Object $manifest -Name "proposed_file_paths" -Default @()) } else { @() }
  foreach ($manifestPathEntry in $manifestProposedFilePaths) {
    if ([string]$manifestPathEntry -match "(?i)placeholder|accepted_candidate_placeholder") {
      $failedChecks += "placeholder_manifest_path"
      $failureReasons += "candidate_manifest.json proposed_file_paths contains placeholder path: $manifestPathEntry"
    }
  }

  if ($modulePayloads.Count -lt 1) {
    $failedChecks += "missing_module_payload"
    $failureReasons += "Candidate does not include a real proposed module payload."
    $requiredImprovements += "Add a parseable module .ps1 payload under proposed_patch_or_file_payloads."
  }
  if ($validatorPayloads.Count -lt 1) {
    $failedChecks += "missing_validator_payload"
    $failureReasons += "Candidate does not include a real proposed validator payload."
    $requiredImprovements += "Add a parseable validator .ps1 payload under proposed_patch_or_file_payloads."
  }

  $materialization = Invoke-Phase160HQualityMaterialization -RepoRoot $RepoRoot -CandidateDirRelative $CandidateDirRelative -SessionRoot $SessionRoot -RunId $RunId
  if ([string]$materialization.status -ne "PASS") {
    $failedChecks += "payload_materialization_failed"
    foreach ($materializationFailure in @($materialization.failures)) {
      if (-not [string]::IsNullOrWhiteSpace([string]$materializationFailure)) {
        $failureReasons += [string]$materializationFailure
      }
    }
  }
  if ($materialization.PSObject.Properties.Name -contains "parser_checks_pass" -and -not [bool]$materialization.parser_checks_pass) {
    $failedChecks += "materialized_powershell_parser_failed"
    $failureReasons += "Materialized PowerShell payload did not parse."
  }

  $qualityStatus = "CANDIDATE_READY"
  if ($blockedReasons.Count -gt 0) {
    $qualityStatus = "BLOCKED"
  } elseif ($unsafeReasons.Count -gt 0) {
    $qualityStatus = "QUARANTINED"
  } elseif ($failedChecks.Count -gt 0) {
    $qualityStatus = "REVISION_REQUIRED"
  }
  $ownerPromotionAllowed = $qualityStatus -eq "CANDIDATE_READY"
  $promotionStatus = if ($ownerPromotionAllowed) { "WAITING_OWNER_REVIEW" } else { $qualityStatus }

  $revisionResult = $null
  if (-not $ownerPromotionAllowed) {
    $allFailedChecks = @($failedChecks + $blockedReasons + $unsafeReasons | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $allFailureReasons = @($failureReasons + $blockedReasons + $unsafeReasons | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    if ($requiredImprovements.Count -lt 1) {
      $requiredImprovements = @(
        "Replace weak payload with real module and validator payload files.",
        "Keep candidate payloads session-local under proposed_patch_or_file_payloads.",
        "Remove commit, push, branch-switch, and protected-state mutation requests."
      )
    }
    $revisionResult = Invoke-Phase160HQualityRevisionRequest -RepoRoot $RepoRoot -CandidateDirRelative $CandidateDirRelative -CandidateId $candidateId -QualityStatus $qualityStatus -FailedChecks $allFailedChecks -FailureReasons $allFailureReasons -RequiredPayloadImprovements $requiredImprovements -RetryNumber $retryNumber -MaxRetryLimit $MaxRetryLimit
  }

  $revisionRequestPath = if ($null -ne $revisionResult -and $revisionResult.PSObject.Properties.Name -contains "revision_request_path") { [string]$revisionResult.revision_request_path } else { "NONE" }
  $checkedAt = (Get-Date).ToUniversalTime().ToString("o")
  $qualityResultPath = Join-Path $CandidateDirFull "quality_gate/quality_gate_result.json"
  $qualityResult = [ordered]@{
    status = $qualityStatus
    quality_status = $qualityStatus
    candidate_id = $candidateId
    source_task_id = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "source_task_id") { [string]$manifest.source_task_id } else { "NONE" }
    candidate_dir = $CandidateDirRelative
    quality_gate_enabled = $true
    owner_promotion_allowed = $ownerPromotionAllowed
    promotion_status = $promotionStatus
    proposed_payload_count = $payloads.Count
    module_payload_count = $modulePayloads.Count
    validator_payload_count = $validatorPayloads.Count
    materialization_status = [string]$materialization.status
    materialization_parse_check_pass = if ($materialization.PSObject.Properties.Name -contains "parser_checks_pass") { [bool]$materialization.parser_checks_pass } else { $false }
    failed_checks = @($failedChecks | Select-Object -Unique)
    failure_reasons = @($failureReasons | Select-Object -Unique)
    blocked_reasons = @($blockedReasons | Select-Object -Unique)
    unsafe_reasons = @($unsafeReasons | Select-Object -Unique)
    revision_request_path = $revisionRequestPath
    revision_required = ($qualityStatus -eq "REVISION_REQUIRED")
    retry_number = $retryNumber
    max_retry_limit = $MaxRetryLimit
    accepted_code_written = $false
    repo_mutation_performed = $false
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $false
    checked_at = $checkedAt
  }
  Write-Phase160HQualityJsonFile -Path $qualityResultPath -Object $qualityResult
  $canonicalQualityResult = ConvertTo-Phase160KCanonicalQualityResult -RepoRoot $RepoRoot -CandidateDirFull $CandidateDirFull -QualityRecord ([pscustomobject]$qualityResult) -CandidateManifest $manifest -CandidateStatus $candidateStatus -RepairSource "quality_gate_evaluation"
  $canonicalQualityResultPath = Get-Phase160KQualityCanonicalPath -CandidateDirFull $CandidateDirFull
  Write-Phase160KQualityJsonFile -Path $canonicalQualityResultPath -Object $canonicalQualityResult

  if ($null -ne $manifest) {
    Set-Phase160HQualityProperty -Object $manifest -Name "decision" -Value $qualityStatus
    Set-Phase160HQualityProperty -Object $manifest -Name "quality_status" -Value $qualityStatus
    Set-Phase160HQualityProperty -Object $manifest -Name "quality_gate_enabled" -Value $true
    Set-Phase160HQualityProperty -Object $manifest -Name "quality_gate_result_path" -Value (ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $qualityResultPath)
    Set-Phase160HQualityProperty -Object $manifest -Name "quality_result_path" -Value (ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $canonicalQualityResultPath)
    Set-Phase160HQualityProperty -Object $manifest -Name "revision_request_path" -Value $revisionRequestPath
    Set-Phase160HQualityProperty -Object $manifest -Name "revision_required" -Value ($qualityStatus -eq "REVISION_REQUIRED")
    Set-Phase160HQualityProperty -Object $manifest -Name "owner_promotion_allowed" -Value $ownerPromotionAllowed
    Set-Phase160HQualityProperty -Object $manifest -Name "materialization_parse_check_pass" -Value ([bool]$qualityResult.materialization_parse_check_pass)
    Set-Phase160HQualityProperty -Object $manifest -Name "quality_gate_failure_reasons" -Value @($qualityResult.failure_reasons + $qualityResult.blocked_reasons + $qualityResult.unsafe_reasons)
    Set-Phase160HQualityProperty -Object $manifest -Name "quality_checked_at" -Value $checkedAt
    Write-Phase160HQualityJsonFile -Path $manifestPath -Object $manifest
  }

  if ($null -eq $candidateStatus) {
    $candidateStatus = [pscustomobject][ordered]@{
      candidate_id = $candidateId
    }
  }
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "status" -Value $qualityStatus
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "quality_status" -Value $qualityStatus
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "quality_gate_enabled" -Value $true
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "owner_promotion_allowed" -Value $ownerPromotionAllowed
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "promotion_status" -Value $promotionStatus
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "revision_request_path" -Value $revisionRequestPath
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "revision_required" -Value ($qualityStatus -eq "REVISION_REQUIRED")
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "source_task_id" -Value ([string]$qualityResult.source_task_id)
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "quality_result_path" -Value (ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $canonicalQualityResultPath)
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "materialization_parse_check_pass" -Value ([bool]$qualityResult.materialization_parse_check_pass)
  Set-Phase160HQualityProperty -Object $candidateStatus -Name "updated_at" -Value $checkedAt
  Write-Phase160HQualityJsonFile -Path $candidateStatusPath -Object $candidateStatus

  if ($null -ne $proposedFiles) {
    Set-Phase160HQualityProperty -Object $proposedFiles -Name "quality_status" -Value $qualityStatus
    Set-Phase160HQualityProperty -Object $proposedFiles -Name "quality_gate_result_path" -Value (ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $qualityResultPath)
    Set-Phase160HQualityProperty -Object $proposedFiles -Name "quality_result_path" -Value (ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $canonicalQualityResultPath)
    Set-Phase160HQualityProperty -Object $proposedFiles -Name "owner_promotion_allowed" -Value $ownerPromotionAllowed
    Write-Phase160HQualityJsonFile -Path $proposedFilesPath -Object $proposedFiles
  }

  $candidateBundlesRoot = Split-Path -Path $CandidateDirFull -Parent
  if ((Split-Path -Path $candidateBundlesRoot -Leaf) -eq "candidate_bundles") {
    $candidateWorkspaceRoot = Split-Path -Path $candidateBundlesRoot -Parent
    $candidateQueueRoot = Join-Path $candidateWorkspaceRoot "candidate_queue"
    New-Phase160HQualityDirectory -Path $candidateQueueRoot
    Write-Phase160HQualityJsonFile -Path (Join-Path $candidateQueueRoot "$candidateId.json") -Object ([ordered]@{
      status = $promotionStatus
      quality_status = $qualityStatus
      candidate_id = $candidateId
      candidate_manifest_path = ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $manifestPath
      quality_gate_result_path = ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $qualityResultPath
      quality_result_path = ConvertTo-Phase160HQualityRelativePath -RepoRoot $RepoRoot -FullPath $canonicalQualityResultPath
      revision_request_path = $revisionRequestPath
      revision_required = ($qualityStatus -eq "REVISION_REQUIRED")
      owner_promotion_allowed = $ownerPromotionAllowed
      updated_at = $checkedAt
    })
  }

  [pscustomobject]$qualityResult | ConvertTo-Json -Depth 100
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
