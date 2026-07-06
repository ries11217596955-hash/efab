param(
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [string]$DutyId = "NONE",
  [int]$TickNumber = 0
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "inspect_builder_quality_decision_index_001.ps1")

function Normalize-Phase160ECandidateFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160ECandidateRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160E_CANDIDATE_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160ECandidateFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160ECandidatePath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase160ECandidateRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160ECandidateFullPath -Path $RepoRoot
  $full = Normalize-Phase160ECandidateFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160E_CANDIDATE_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function ConvertTo-Phase160ECandidateDotNetFileSystemPath {
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

function Test-Phase160ECandidateDirectoryExists {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $true
  }
  return [System.IO.Directory]::Exists((ConvertTo-Phase160ECandidateDotNetFileSystemPath -Path $Path))
}

function Ensure-Phase160ECandidateParentDirectory {
  param([string]$Path)
  $directory = Split-Path -Path $Path -Parent
  $created = $false
  $existsBefore = $false
  if (-not [string]::IsNullOrWhiteSpace($directory)) {
    $existsBefore = Test-Phase160ECandidateDirectoryExists -Path $directory
    if (-not $existsBefore) {
      [System.IO.Directory]::CreateDirectory((ConvertTo-Phase160ECandidateDotNetFileSystemPath -Path $directory)) | Out-Null
      $created = $true
    }
  }
  $existsAfter = if (-not [string]::IsNullOrWhiteSpace($directory)) { Test-Phase160ECandidateDirectoryExists -Path $directory } else { $true }
  return [pscustomobject][ordered]@{
    parent_directory = if ([string]::IsNullOrWhiteSpace($directory)) { "NONE" } else { $directory }
    parent_directory_exists_before = $existsBefore
    parent_directory_exists = $existsAfter
    parent_directory_created = $created
  }
}

function Write-Phase160ECandidateJsonFile {
  param([string]$Path, [object]$Object, [int]$Depth = 100)
  $null = Ensure-Phase160ECandidateParentDirectory -Path $Path
  $json = ($Object | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText((ConvertTo-Phase160ECandidateDotNetFileSystemPath -Path $Path), $json, [System.Text.UTF8Encoding]::new($false))
}

function Write-Phase160ECandidateTextFile {
  param([string]$Path, [string]$Text)
  $null = Ensure-Phase160ECandidateParentDirectory -Path $Path
  if (-not $Text.EndsWith("`n")) {
    $Text += "`n"
  }
  [System.IO.File]::WriteAllText((ConvertTo-Phase160ECandidateDotNetFileSystemPath -Path $Path), $Text, [System.Text.UTF8Encoding]::new($false))
}

function Write-Phase160ECandidatePayloadWriteBlocker {
  param(
    [string]$RepoRoot,
    [string]$CandidateId,
    [string]$CandidateDir,
    [string]$BlockerQueuePath,
    [string]$FailedPath,
    [string]$Reason,
    [bool]$ParentDirectoryExists,
    [bool]$ParentDirectoryCreated
  )
  $failedPathForRecord = try {
    ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath $FailedPath
  } catch {
    [string]$FailedPath
  }
  $blocker = [ordered]@{
    status = "BLOCKED"
    blocker_id = "PHASE160H1_PAYLOAD_WRITE_FAILED"
    candidate_id = $CandidateId
    failed_path = $failedPathForRecord
    reason = $Reason
    parent_directory_exists = $ParentDirectoryExists
    parent_directory_created = $ParentDirectoryCreated
    next_action = "Create the payload parent directory before writing and retry candidate payload generation."
    owner_promotion_allowed = $false
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $false
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  if (-not [string]::IsNullOrWhiteSpace($CandidateDir)) {
    $payloadWriteBlockerPath = try {
      ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath (Join-Path $CandidateDir "payload_write_blocker.json")
    } catch {
      "payload_write_blocker.json"
    }
    Write-Phase160ECandidateJsonFile -Path (Join-Path $CandidateDir "payload_write_blocker.json") -Object $blocker
    Write-Phase160ECandidateJsonFile -Path (Join-Path $CandidateDir "candidate_status.json") -Object ([ordered]@{
      status = "BLOCKED"
      quality_status = "BLOCKED"
      candidate_id = $CandidateId
      blocker_id = "PHASE160H1_PAYLOAD_WRITE_FAILED"
      payload_write_blocker_path = $payloadWriteBlockerPath
      owner_promotion_allowed = $false
      updated_at = (Get-Date).ToUniversalTime().ToString("o")
    })
  }
  if (-not [string]::IsNullOrWhiteSpace($BlockerQueuePath)) {
    Write-Phase160ECandidateJsonFile -Path (Join-Path $BlockerQueuePath ("blocker_payload_write_{0}.json" -f (ConvertTo-Phase160ECandidateSafeLeaf -Value $CandidateId -MaxLength 60))) -Object $blocker
  }
  return [pscustomobject]$blocker
}

function Write-Phase160ECandidatePayloadTextFile {
  param(
    [string]$RepoRoot,
    [string]$Path,
    [string]$Text,
    [string]$CandidateId,
    [string]$CandidateDir,
    [string]$BlockerQueuePath
  )
  $parentInfo = $null
  try {
    $parentInfo = Ensure-Phase160ECandidateParentDirectory -Path $Path
    if (-not [bool]$parentInfo.parent_directory_exists) {
      throw "PHASE160H1_PAYLOAD_PARENT_DIRECTORY_MISSING_AFTER_CREATE path=$Path"
    }
    if (-not $Text.EndsWith("`n")) {
      $Text += "`n"
    }
    [System.IO.File]::WriteAllText((ConvertTo-Phase160ECandidateDotNetFileSystemPath -Path $Path), $Text, [System.Text.UTF8Encoding]::new($false))
    return [pscustomobject][ordered]@{
      status = "PASS"
      path = $Path
      parent_directory_exists = [bool]$parentInfo.parent_directory_exists
      parent_directory_created = [bool]$parentInfo.parent_directory_created
    }
  } catch {
    $directory = Split-Path -Path $Path -Parent
    $parentExists = if (-not [string]::IsNullOrWhiteSpace($directory)) { Test-Phase160ECandidateDirectoryExists -Path $directory } else { $true }
    $parentCreated = if ($null -ne $parentInfo) { [bool]$parentInfo.parent_directory_created } else { $false }
    $null = Write-Phase160ECandidatePayloadWriteBlocker -RepoRoot $RepoRoot -CandidateId $CandidateId -CandidateDir $CandidateDir -BlockerQueuePath $BlockerQueuePath -FailedPath $Path -Reason $_.Exception.Message -ParentDirectoryExists $parentExists -ParentDirectoryCreated $parentCreated
    throw "PHASE160H1_PAYLOAD_WRITE_FAILED candidate_id=$CandidateId failed_path=$Path reason=$($_.Exception.Message)"
  }
}

function Add-Phase160ECandidateJsonLine {
  param([string]$Path, [object]$Object)
  $null = Ensure-Phase160ECandidateParentDirectory -Path $Path
  $line = $Object | ConvertTo-Json -Depth 100 -Compress
  [System.IO.File]::AppendAllText((ConvertTo-Phase160ECandidateDotNetFileSystemPath -Path $Path), "$line`n", [System.Text.UTF8Encoding]::new($false))
}

function Read-Phase160ECandidateJsonSafe {
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

function Get-Phase160ECandidateProperty {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $Default
}

function Get-Phase160ECandidateString {
  param([object]$Object, [string]$Name, [string]$Default = "NONE")
  $value = Get-Phase160ECandidateProperty -Object $Object -Name $Name -Default $Default
  if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
    return $Default
  }
  return [string]$value
}

function ConvertTo-Phase160ECandidateSafeLeaf {
  param([string]$Value, [int]$MaxLength = 90)
  $leaf = if ([string]::IsNullOrWhiteSpace($Value)) { "NONE" } else { $Value }
  $leaf = $leaf -replace '[^A-Za-z0-9_.-]', '_'
  if ($leaf.Length -gt $MaxLength) {
    $leaf = $leaf.Substring(0, $MaxLength)
  }
  return $leaf
}

function Assert-Phase160ECandidateRunIdSafe {
  param([string]$RunId)
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    return
  }
  if ($RunId.IndexOfAny([char[]]@("/", "\")) -ge 0) {
    throw "PHASE160E_CANDIDATE_RUN_ID_MUST_BE_LEAF=$RunId"
  }
}

function Get-Phase160ECandidatePriorityRank {
  param([string]$Priority)
  switch ($Priority.ToLowerInvariant()) {
    "high" { return 3 }
    "normal" { return 2 }
    "low" { return 1 }
    default { return 0 }
  }
}

function Get-Phase160ECandidateSourceRank {
  param([string]$Source)
  switch ($Source.ToLowerInvariant()) {
    "owner" { return 3 }
    "observer" { return 2 }
    "system" { return 1 }
    default { return 0 }
  }
}

function Get-Phase160ECandidateJsonFileCount {
  param([string]$Directory, [string]$Pattern = "*.json")
  if (-not (Test-Path -LiteralPath $Directory)) {
    return 0
  }
  return @(Get-ChildItem -LiteralPath $Directory -File -Filter $Pattern -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.json" }).Count
}

function Get-Phase160ECandidateBundleCounts {
  param([string]$CandidateBundleRoot)
  $candidateWorkspaceRoot = Split-Path -Path $CandidateBundleRoot -Parent
  $sessionRootForIndex = Split-Path -Path $candidateWorkspaceRoot -Parent
  if (-not [string]::IsNullOrWhiteSpace($sessionRootForIndex) -and -not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    $qualityIndex = Get-Phase160KQualityDecisionIndex -RepoRoot $RepoRoot -SessionRootFull $sessionRootForIndex -RepairMissingQualityResults
    return [pscustomobject][ordered]@{
      candidate_count = [int]$qualityIndex.candidate_count_total
      ready_candidate_count = [int]$qualityIndex.ready_candidate_count_after_quality
      revision_required_count = [int]$qualityIndex.revision_required_count
      draft_candidate_count = [int]$qualityIndex.draft_candidate_count
      quarantined_candidate_count = [int]$qualityIndex.quarantined_candidate_count
      blocked_candidate_count = [int]$qualityIndex.blocked_candidate_count
      last_candidate_id = if (@($qualityIndex.candidate_records).Count -gt 0) { [string]$qualityIndex.candidate_records[-1].candidate_id } else { "NONE" }
      last_quality_decision = [string]$qualityIndex.last_quality_decision
      last_revision_request = [string]$qualityIndex.last_revision_request
      owner_promotion_allowed = [bool]$qualityIndex.owner_promotion_allowed
      quality_result_file_count = [int]$qualityIndex.quality_result_file_count
      quality_decision_count = [int]$qualityIndex.quality_decision_count
      quality_artifact_consistency_status = [string]$qualityIndex.quality_artifact_consistency_status
      missing_quality_result_count = [int]$qualityIndex.missing_quality_result_count
    }
  }
  $candidateCount = 0
  $readyCount = 0
  $revisionCount = 0
  $draftCount = 0
  $quarantineCount = 0
  $blockedCount = 0
  $lastCandidateId = "NONE"
  $lastQualityDecision = "NONE"
  $lastRevisionRequest = "NONE"
  $ownerPromotionAllowed = $false
  $bundleDirs = @(Get-ChildItem -LiteralPath $CandidateBundleRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc, Name)
  foreach ($bundleDir in $bundleDirs) {
    $manifest = Read-Phase160ECandidateJsonSafe -Path (Join-Path $bundleDir.FullName "candidate_manifest.json")
    $status = Read-Phase160ECandidateJsonSafe -Path (Join-Path $bundleDir.FullName "candidate_status.json")
    $quality = Read-Phase160ECandidateJsonSafe -Path (Join-Path $bundleDir.FullName "quality_gate/quality_gate_result.json")
    if ($null -eq $manifest) {
      continue
    }
    $candidateCount += 1
    $decision = Get-Phase160ECandidateString -Object $quality -Name "quality_status" -Default (Get-Phase160ECandidateString -Object $quality -Name "status" -Default (Get-Phase160ECandidateString -Object $status -Name "quality_status" -Default (Get-Phase160ECandidateString -Object $status -Name "status" -Default (Get-Phase160ECandidateString -Object $manifest -Name "quality_status" -Default (Get-Phase160ECandidateString -Object $manifest -Name "decision" -Default "UNKNOWN")))))
    $candidateOwnerPromotionAllowed = [bool](Get-Phase160ECandidateProperty -Object $quality -Name "owner_promotion_allowed" -Default (Get-Phase160ECandidateProperty -Object $status -Name "owner_promotion_allowed" -Default (Get-Phase160ECandidateProperty -Object $manifest -Name "owner_promotion_allowed" -Default ($decision -eq "CANDIDATE_READY"))))
    if ($decision -eq "CANDIDATE_READY" -and $candidateOwnerPromotionAllowed) {
      $readyCount += 1
    }
    if ($decision -eq "REVISION_REQUIRED") {
      $revisionCount += 1
    }
    if ($decision -eq "CANDIDATE_DRAFT") {
      $draftCount += 1
    }
    if ($decision -match "QUARANTINE|QUARANTINED") {
      $quarantineCount += 1
    }
    if ($decision -match "BLOCKED") {
      $blockedCount += 1
    }
    $lastCandidateId = Get-Phase160ECandidateString -Object $manifest -Name "candidate_id" -Default $bundleDir.Name
    $lastQualityDecision = $decision
    $lastRevisionRequest = Get-Phase160ECandidateString -Object $quality -Name "revision_request_path" -Default (Get-Phase160ECandidateString -Object $status -Name "revision_request_path" -Default (Get-Phase160ECandidateString -Object $manifest -Name "revision_request_path" -Default "NONE"))
    if ($candidateOwnerPromotionAllowed) {
      $ownerPromotionAllowed = $true
    }
  }
  return [pscustomobject][ordered]@{
    candidate_count = $candidateCount
    ready_candidate_count = $readyCount
    revision_required_count = $revisionCount
    draft_candidate_count = $draftCount
    quarantined_candidate_count = $quarantineCount
    blocked_candidate_count = $blockedCount
    last_candidate_id = $lastCandidateId
    last_quality_decision = $lastQualityDecision
    last_revision_request = $lastRevisionRequest
    owner_promotion_allowed = $ownerPromotionAllowed
  }
}

function Get-Phase160ECandidateDecision {
  param([object]$Candidate)
  return Get-Phase160ECandidateString -Object $Candidate -Name "quality_status" -Default (Get-Phase160ECandidateString -Object $Candidate -Name "decision" -Default (Get-Phase160ECandidateString -Object $Candidate -Name "status" -Default "UNKNOWN"))
}

function Get-Phase160ECandidateOwnerPromotionAllowed {
  param([object]$Candidate)
  $decision = Get-Phase160ECandidateDecision -Candidate $Candidate
  return [bool](Get-Phase160ECandidateProperty -Object $Candidate -Name "owner_promotion_allowed" -Default ($decision -eq "CANDIDATE_READY"))
}

function Invoke-Phase160ECandidateQualityGate {
  param(
    [string]$RepoRoot,
    [string]$CandidateDir,
    [string]$SessionRoot,
    [string]$RunId
  )
  $qualityGateScript = Resolve-Phase160ECandidatePath -RepoRoot $RepoRoot -Path "modules/inspect_builder_candidate_quality_gate_001.ps1"
  if (-not (Test-Path -LiteralPath $qualityGateScript)) {
    throw "PHASE160H_CANDIDATE_QUALITY_GATE_MISSING=modules/inspect_builder_candidate_quality_gate_001.ps1"
  }
  $candidateDirRelative = ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath $CandidateDir
  $output = @(powershell -NoProfile -ExecutionPolicy Bypass -File $qualityGateScript -CandidateDir $candidateDirRelative -SessionRoot $SessionRoot -RunId $RunId 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE160H_CANDIDATE_QUALITY_GATE_FAILED candidate=$candidateDirRelative output=$($output -join ' | ')"
  }
  return ($output -join "`n") | ConvertFrom-Json
}

function Get-Phase160ECandidateRetryContext {
  param(
    [string]$CandidateBundleRoot,
    [string]$BaseCandidateId,
    [int]$MaxRetryLimit
  )
  $matchingDirs = @(Get-ChildItem -LiteralPath $CandidateBundleRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -eq $BaseCandidateId -or $_.Name -like "$BaseCandidateId`_retry_*"
  } | Sort-Object LastWriteTimeUtc, Name)
  if ($matchingDirs.Count -lt 1) {
    return [pscustomobject][ordered]@{
      candidate_id = $BaseCandidateId
      retry_number = 0
      previous_candidate_dir = "NONE"
      previous_revision_request = $null
      existing_manifest = $null
      retry_allowed = $true
    }
  }
  $latestDir = $matchingDirs[-1]
  $latestManifest = Read-Phase160ECandidateJsonSafe -Path (Join-Path $latestDir.FullName "candidate_manifest.json")
  $latestStatus = Read-Phase160ECandidateJsonSafe -Path (Join-Path $latestDir.FullName "candidate_status.json")
  $latestRevision = Read-Phase160ECandidateJsonSafe -Path (Join-Path $latestDir.FullName "revision_request.json")
  $decision = Get-Phase160ECandidateString -Object $latestManifest -Name "quality_status" -Default (Get-Phase160ECandidateString -Object $latestStatus -Name "quality_status" -Default (Get-Phase160ECandidateString -Object $latestStatus -Name "status" -Default (Get-Phase160ECandidateString -Object $latestManifest -Name "decision" -Default "UNKNOWN")))
  $ownerPromotionAllowed = [bool](Get-Phase160ECandidateProperty -Object $latestManifest -Name "owner_promotion_allowed" -Default (Get-Phase160ECandidateProperty -Object $latestStatus -Name "owner_promotion_allowed" -Default ($decision -eq "CANDIDATE_READY")))
  $latestRetryNumber = if ($null -ne $latestRevision -and $latestRevision.PSObject.Properties.Name -contains "retry_number") { [int]$latestRevision.retry_number } elseif ($null -ne $latestManifest -and $latestManifest.PSObject.Properties.Name -contains "revision_retry_number") { [int]$latestManifest.revision_retry_number } else { 0 }
  if (($decision -eq "CANDIDATE_READY" -and $ownerPromotionAllowed) -or $decision -match "QUARANTINED|BLOCKED") {
    return [pscustomobject][ordered]@{
      candidate_id = if ($null -ne $latestManifest) { Get-Phase160ECandidateString -Object $latestManifest -Name "candidate_id" -Default $latestDir.Name } else { $latestDir.Name }
      retry_number = $latestRetryNumber
      previous_candidate_dir = $latestDir.FullName
      previous_revision_request = $latestRevision
      existing_manifest = $latestManifest
      retry_allowed = $false
    }
  }
  if ($latestRetryNumber -ge $MaxRetryLimit) {
    return [pscustomobject][ordered]@{
      candidate_id = if ($null -ne $latestManifest) { Get-Phase160ECandidateString -Object $latestManifest -Name "candidate_id" -Default $latestDir.Name } else { $latestDir.Name }
      retry_number = $latestRetryNumber
      previous_candidate_dir = $latestDir.FullName
      previous_revision_request = $latestRevision
      existing_manifest = $latestManifest
      retry_allowed = $false
    }
  }
  $nextRetryNumber = $latestRetryNumber + 1
  return [pscustomobject][ordered]@{
    candidate_id = ("{0}_retry_{1:d2}" -f $BaseCandidateId, $nextRetryNumber)
    retry_number = $nextRetryNumber
    previous_candidate_dir = $latestDir.FullName
    previous_revision_request = $latestRevision
    existing_manifest = $null
    retry_allowed = $true
  }
}

function ConvertTo-Phase160ECandidateSingleQuotedLiteral {
  param([string]$Value)
  return "'{0}'" -f (([string]$Value) -replace "'", "''")
}

function New-Phase160ECandidateModulePayloadText {
  param(
    [string]$CandidateId,
    [string]$TaskId,
    [string]$PlanItemId,
    [string]$OwnerGoal,
    [string]$DesiredGap
  )
  $lines = @(
    'param(',
    '  [string]$CandidateSpecPath = "",',
    '  [string]$OutputPath = ""',
    ')',
    '',
    '$ErrorActionPreference = "Stop"',
    '',
    'function Read-CandidateSpecJson {',
    '  param([string]$Path)',
    '  if ([string]::IsNullOrWhiteSpace($Path)) {',
    '    return [pscustomobject][ordered]@{}',
    '  }',
    '  if (-not (Test-Path -LiteralPath $Path)) {',
    '    throw "CANDIDATE_SPEC_MISSING=$Path"',
    '  }',
    '  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json',
    '}',
    '',
    'function Invoke-CandidatePayload {',
    '  param([object]$Spec)',
    '  $signals = @(',
    '    "real_module_payload_executed",',
    '    "validator_payload_required",',
    '    "owner_promotion_gate_preserved",',
    '    "runtime_session_only"',
    '  )',
    '  return [pscustomobject][ordered]@{',
    '    status = "PASS"',
    ('    candidate_id = ' + (ConvertTo-Phase160ECandidateSingleQuotedLiteral -Value $CandidateId)),
    ('    source_task_id = ' + (ConvertTo-Phase160ECandidateSingleQuotedLiteral -Value $TaskId)),
    ('    source_plan_item_id = ' + (ConvertTo-Phase160ECandidateSingleQuotedLiteral -Value $PlanItemId)),
    ('    owner_goal = ' + (ConvertTo-Phase160ECandidateSingleQuotedLiteral -Value $OwnerGoal)),
    ('    desired_next_gap = ' + (ConvertTo-Phase160ECandidateSingleQuotedLiteral -Value $DesiredGap)),
    '    execution_signals = $signals',
    '    spec_property_count = if ($null -ne $Spec) { $Spec.PSObject.Properties.Count } else { 0 }',
    '    accepted_code_written = $false',
    '    repo_mutation_performed = $false',
    '    commit_performed = $false',
    '    push_performed = $false',
    '    branch_switch_performed = $false',
    '    protected_state_mutated = $false',
    '    executed_at = (Get-Date).ToUniversalTime().ToString("o")',
    '  }',
    '}',
    '',
    '$spec = Read-CandidateSpecJson -Path $CandidateSpecPath',
    '$result = Invoke-CandidatePayload -Spec $spec',
    'if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {',
    '  $directory = Split-Path -Path $OutputPath -Parent',
    '  if ($directory -and -not (Test-Path -LiteralPath $directory)) {',
    '    New-Item -ItemType Directory -Force -Path $directory | Out-Null',
    '  }',
    '  $json = ($result | ConvertTo-Json -Depth 20) -replace "`r`n", "`n"',
    '  if (-not $json.EndsWith("`n")) { $json += "`n" }',
    '  [System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))',
    '}',
    '$result | ConvertTo-Json -Depth 20'
  )
  return ($lines -join "`n")
}

function New-Phase160ECandidateValidatorPayloadText {
  param(
    [string]$CandidateId,
    [string]$ProposedModuleTarget
  )
  $lines = @(
    'param(',
    '  [string]$PayloadRoot = "."',
    ')',
    '',
    '$ErrorActionPreference = "Stop"',
    '',
    'function Assert-CandidateValidatorTrue {',
    '  param([object]$Actual, [string]$Name)',
    '  if ($Actual -ne $true) {',
    '    throw "CANDIDATE_VALIDATOR_ASSERT_TRUE_FAILED=$Name actual=$Actual"',
    '  }',
    '}',
    '',
    'function Test-CandidatePowerShellParse {',
    '  param([string]$Path)',
    '  $tokens = $null',
    '  $parseErrors = $null',
    '  [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors) | Out-Null',
    '  if ($parseErrors.Count -gt 0) {',
    '    throw "CANDIDATE_VALIDATOR_PARSE_FAILED=$Path message=$($parseErrors[0].Message)"',
    '  }',
    '}',
    '',
    ('$modulePath = Join-Path $PayloadRoot ' + (ConvertTo-Phase160ECandidateSingleQuotedLiteral -Value $ProposedModuleTarget)),
    'Assert-CandidateValidatorTrue -Actual (Test-Path -LiteralPath $modulePath) -Name "module_payload_exists"',
    'Test-CandidatePowerShellParse -Path $modulePath',
    '$text = Get-Content -LiteralPath $modulePath -Raw',
    'Assert-CandidateValidatorTrue -Actual ($text -match "real_module_payload_executed") -Name "module_execution_signal"',
    'Assert-CandidateValidatorTrue -Actual ($text -match "owner_promotion_gate_preserved") -Name "owner_gate_signal"',
    '[pscustomobject][ordered]@{',
    '  status = "PASS"',
    ('  candidate_id = ' + (ConvertTo-Phase160ECandidateSingleQuotedLiteral -Value $CandidateId)),
    '  module_payload_exists = $true',
    '  module_payload_parse_pass = $true',
    '  owner_promotion_gate_preserved = $true',
    '  accepted_code_written = $false',
    '  commit_performed = $false',
    '  push_performed = $false',
    '  branch_switch_performed = $false',
    '  protected_state_mutated = $false',
    '  validated_at = (Get-Date).ToUniversalTime().ToString("o")',
    '} | ConvertTo-Json -Depth 20'
  )
  return ($lines -join "`n")
}

function Get-Phase160ECandidateActivePlanFile {
  param([string]$SessionRootFull, [object]$PlanItem)
  if ($null -eq $PlanItem) {
    return $null
  }
  $parentTaskId = Get-Phase160ECandidateString -Object $PlanItem -Name "parent_task_id"
  $itemId = Get-Phase160ECandidateString -Object $PlanItem -Name "item_id"
  if ($parentTaskId -eq "NONE" -or $itemId -eq "NONE") {
    return $null
  }
  $safeParent = ConvertTo-Phase160ECandidateSafeLeaf -Value $parentTaskId
  $candidate = Join-Path $SessionRootFull ("plan_items/{0}/{1}.json" -f $safeParent, $itemId)
  if (Test-Path -LiteralPath $candidate) {
    return $candidate
  }
  return $null
}

function Select-Phase160ECandidateNextPlanItem {
  param(
    [string]$SessionRootFull,
    [string]$RepoRoot,
    [object]$ActiveTask,
    [string]$ChangeLedgerPath,
    [string]$PlanAdvancementLogPath
  )
  if ($null -eq $ActiveTask) {
    return $null
  }
  $taskId = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
  if ($taskId -eq "NONE") {
    return $null
  }
  $safeTaskId = ConvertTo-Phase160ECandidateSafeLeaf -Value $taskId
  $taskPlanDir = Join-Path $SessionRootFull "plan_items/$safeTaskId"
  if (-not (Test-Path -LiteralPath $taskPlanDir)) {
    return $null
  }
  $planFiles = @(Get-ChildItem -LiteralPath $taskPlanDir -File -Filter "*_plan_item_*.json" -ErrorAction SilentlyContinue | Sort-Object Name)
  foreach ($planFile in $planFiles) {
    $planItem = Read-Phase160ECandidateJsonSafe -Path $planFile.FullName
    if ($null -eq $planItem) {
      continue
    }
    $status = Get-Phase160ECandidateString -Object $planItem -Name "status"
    if ($status -ne "PENDING") {
      continue
    }
    $planItem.status = "ACTIVE"
    $planItem | Add-Member -MemberType NoteProperty -Name "activated_at" -Value (Get-Date).ToUniversalTime().ToString("o") -Force
    Write-Phase160ECandidateJsonFile -Path $planFile.FullName -Object $planItem
    Write-Phase160ECandidateJsonFile -Path (Join-Path $SessionRootFull "active_task/active_plan_item.json") -Object $planItem
    Write-Phase160ECandidateJsonFile -Path (Join-Path $SessionRootFull "plan_items/active_plan_item.json") -Object $planItem
    $relativePlanPath = ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath $planFile.FullName
    Add-Phase160ECandidateJsonLine -Path $PlanAdvancementLogPath -Object ([ordered]@{
      event_type = "plan_item_advanced"
      source = "candidate_workspace_step"
      task_id = $taskId
      plan_item_id = Get-Phase160ECandidateString -Object $planItem -Name "item_id"
      status = "ACTIVE"
      plan_item_path = $relativePlanPath
      occurred_at = (Get-Date).ToUniversalTime().ToString("o")
    })
    Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
      event_type = "plan_item_advanced"
      source = "candidate_workspace_step"
      task_id = $taskId
      plan_item_id = Get-Phase160ECandidateString -Object $planItem -Name "item_id"
      occurred_at = (Get-Date).ToUniversalTime().ToString("o")
    })
    return $planItem
  }
  return $null
}

function New-Phase160ECandidateBundle {
  param(
    [string]$RepoRoot,
    [string]$SessionRootFull,
    [object]$RunManifest,
    [object]$ActiveTask,
    [object]$ActivePlanItem,
    [string]$DutyId,
    [int]$TickNumber,
    [string]$CandidateBundleRoot,
    [string]$CandidateQueueRoot,
    [string]$ChangeLedgerPath
  )

  if ($null -eq $ActiveTask) {
    return $null
  }
  $taskId = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
  if ($taskId -eq "NONE") {
    return $null
  }
  $planItemId = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
  $safeTask = ConvertTo-Phase160ECandidateSafeLeaf -Value $taskId -MaxLength 28
  $safePlan = ConvertTo-Phase160ECandidateSafeLeaf -Value $planItemId -MaxLength 18
  $baseCandidateId = if ($planItemId -eq "NONE") { "cand_$safeTask" } else { "cand_{0}_{1}" -f $safeTask, $safePlan }
  $baseCandidateId = ConvertTo-Phase160ECandidateSafeLeaf -Value $baseCandidateId -MaxLength 60
  $existingCandidateDirs = @(Get-ChildItem -LiteralPath $CandidateBundleRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -eq $baseCandidateId -or $_.Name -like "$baseCandidateId`_retry_*"
  } | Sort-Object LastWriteTimeUtc, Name)
  if ($existingCandidateDirs.Count -gt 0) {
    $latestExistingDir = $existingCandidateDirs[-1]
    if (Test-Path -LiteralPath (Join-Path $latestExistingDir.FullName "candidate_manifest.json")) {
      $null = Invoke-Phase160ECandidateQualityGate -RepoRoot $RepoRoot -CandidateDir $latestExistingDir.FullName -SessionRoot (ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull) -RunId ([string]$RunManifest.run_id)
    }
  }
  $maxRetryLimit = 2
  $retryContext = Get-Phase160ECandidateRetryContext -CandidateBundleRoot $CandidateBundleRoot -BaseCandidateId $baseCandidateId -MaxRetryLimit $maxRetryLimit
  if ($null -ne $retryContext.existing_manifest) {
    return $retryContext.existing_manifest
  }
  $candidateId = ConvertTo-Phase160ECandidateSafeLeaf -Value ([string]$retryContext.candidate_id) -MaxLength 80
  $candidateDir = Join-Path $CandidateBundleRoot $candidateId
  $candidateManifestPath = Join-Path $candidateDir "candidate_manifest.json"
  if (Test-Path -LiteralPath $candidateManifestPath) {
    $null = Invoke-Phase160ECandidateQualityGate -RepoRoot $RepoRoot -CandidateDir $candidateDir -SessionRoot (ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull) -RunId ([string]$RunManifest.run_id)
    return Read-Phase160ECandidateJsonSafe -Path $candidateManifestPath
  }

  New-Item -ItemType Directory -Force -Path $candidateDir | Out-Null
  $ownerGoal = Get-Phase160ECandidateString -Object $ActiveTask -Name "owner_goal"
  $desiredGap = Get-Phase160ECandidateString -Object $ActiveTask -Name "desired_next_gap"
  $taskSource = Get-Phase160ECandidateString -Object $ActiveTask -Name "source" -Default "owner"
  $candidateSource = if ($taskSource -eq "internal_self_selected_goal") { "internal_self_selected_goal" } elseif ($planItemId -ne "NONE") { "plan_item" } else { "owner_task" }
  $sourceInternalGoalId = Get-Phase160ECandidateString -Object $ActiveTask -Name "internal_goal_id" -Default "NONE"
  $sourceInternalGoalName = Get-Phase160ECandidateString -Object $ActiveTask -Name "internal_goal_name" -Default "NONE"
  $targetArea = if ($candidateSource -eq "internal_self_selected_goal") { "self_initiated_useful_goal_selection" } elseif ($planItemId -ne "NONE") { "active_plan_item_candidate" } else { "active_task_candidate" }
  $payloadLeaf = ConvertTo-Phase160ECandidateSafeLeaf -Value $candidateId -MaxLength 64
  $proposedModulePath = "modules/invoke_builder_candidate_{0}_001.ps1" -f $payloadLeaf
  $proposedValidatorPath = "validators/validate_builder_candidate_{0}_v1.ps1" -f $payloadLeaf
  $modulePayloadPath = "proposed_patch_or_file_payloads/modules/{0}" -f (Split-Path -Path $proposedModulePath -Leaf)
  $validatorPayloadPath = "proposed_patch_or_file_payloads/validators/{0}" -f (Split-Path -Path $proposedValidatorPath -Leaf)
  $validatorNeeded = @($proposedValidatorPath)
  $expectedCapabilities = @(Get-Phase160ECandidateProperty -Object $ActiveTask -Name "expected_candidate_capabilities" -Default @())
  if ($expectedCapabilities.Count -lt 1 -or $desiredGap -match "SELF_INITIATED_USEFUL_GOAL_SELECTION|SELF_SELECTED_USEFUL_CANDIDATE_PRODUCTION" -or $ownerGoal -match "self-initiated|useful goal|candidate|organ|module|validator") {
    $expectedCapabilities = @(
      "SELF_INITIATED_USEFUL_GOAL_SELECTION",
      "self_gap_inventory",
      "usefulness_scoring",
      "internal_active_task",
      "internal_active_task_creation",
      "no_teacher_inbox",
      "no_teacher_inbox_required",
      "candidate_bundle_creation",
      "promotion_bundle_update",
      "runtime_guard_required"
    )
  }
  $candidateCreatedAt = (Get-Date).ToUniversalTime().ToString("o")
  $previousRevision = $retryContext.previous_revision_request
  $revisionFeedbackReasons = if ($null -ne $previousRevision -and $previousRevision.PSObject.Properties.Name -contains "why_it_failed") { @($previousRevision.why_it_failed | ForEach-Object { [string]$_ }) } else { @() }
  $revisionFeedbackChecks = if ($null -ne $previousRevision -and $previousRevision.PSObject.Properties.Name -contains "what_failed") { @($previousRevision.what_failed | ForEach-Object { [string]$_ }) } else { @() }
  $modulePayloadText = New-Phase160ECandidateModulePayloadText -CandidateId $candidateId -TaskId $taskId -PlanItemId $planItemId -OwnerGoal $ownerGoal -DesiredGap $desiredGap
  $validatorPayloadText = New-Phase160ECandidateValidatorPayloadText -CandidateId $candidateId -ProposedModuleTarget $proposedModulePath
  $modulePayloadWrite = Write-Phase160ECandidatePayloadTextFile -RepoRoot $RepoRoot -Path (Join-Path $candidateDir $modulePayloadPath) -Text $modulePayloadText -CandidateId $candidateId -CandidateDir $candidateDir -BlockerQueuePath (Join-Path $SessionRootFull "blocker_queue")
  $validatorPayloadWrite = Write-Phase160ECandidatePayloadTextFile -RepoRoot $RepoRoot -Path (Join-Path $candidateDir $validatorPayloadPath) -Text $validatorPayloadText -CandidateId $candidateId -CandidateDir $candidateDir -BlockerQueuePath (Join-Path $SessionRootFull "blocker_queue")
  $manifest = [ordered]@{
    status = "PASS"
    candidate_id = $candidateId
    base_candidate_id = $baseCandidateId
    revision_retry_number = [int]$retryContext.retry_number
    max_retry_limit = $maxRetryLimit
    revision_feedback_considered = ($revisionFeedbackReasons.Count -gt 0 -or $revisionFeedbackChecks.Count -gt 0)
    consumed_revision_feedback = [ordered]@{
      previous_candidate_dir = if ([string]$retryContext.previous_candidate_dir -eq "NONE") { "NONE" } else { ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath ([string]$retryContext.previous_candidate_dir) }
      what_failed = @($revisionFeedbackChecks)
      why_it_failed = @($revisionFeedbackReasons)
    }
    source_task_id = $taskId
    source = $candidateSource
    source_plan_item_id = $planItemId
    source_internal_goal_id = $sourceInternalGoalId
    source_internal_goal_name = $sourceInternalGoalName
    created_from_run_head = [string]$RunManifest.run_head
    run_id = [string]$RunManifest.run_id
    target_area = $targetArea
    owner_goal = $ownerGoal
    desired_next_gap = $desiredGap
    proposed_file_paths = @($proposedModulePath)
    proposed_validator_paths = $validatorNeeded
    acceptance_validator_needed = $validatorNeeded
    proposed_payload_paths = @($modulePayloadPath, $validatorPayloadPath)
    proposed_module_payload_path = $modulePayloadPath
    proposed_validator_payload_path = $validatorPayloadPath
    payload_parent_directories_created = ([bool]$modulePayloadWrite.parent_directory_created -or [bool]$validatorPayloadWrite.parent_directory_created)
    module_payload_parent_directory_exists = [bool]$modulePayloadWrite.parent_directory_exists
    validator_payload_parent_directory_exists = [bool]$validatorPayloadWrite.parent_directory_exists
    expected_candidate_capabilities = $expectedCapabilities
    owner_approval_required = $true
    owner_promotion_gate_required = $true
    candidate_output_is_not_accepted_code = $true
    repo_mutation_performed = $false
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $false
    decision = "CANDIDATE_DRAFT"
    quality_gate_enabled = $true
    owner_promotion_allowed = $false
    duty_id = $DutyId
    tick_number = $TickNumber
    created_at = $candidateCreatedAt
  }
  Write-Phase160ECandidateJsonFile -Path $candidateManifestPath -Object $manifest
  Write-Phase160ECandidateJsonFile -Path (Join-Path $candidateDir "proposed_files.json") -Object ([ordered]@{
    status = "PASS"
    candidate_id = $candidateId
    proposed_file_paths = @($proposedModulePath)
    proposed_validator_paths = $validatorNeeded
    proposed_payloads = @(
      [ordered]@{
        kind = "module"
        role = "proposed_module_payload"
        target_path = $proposedModulePath
        payload_path = $modulePayloadPath
        parse_required = $true
        required = $true
      },
      [ordered]@{
        kind = "validator"
        role = "proposed_validator_payload"
        target_path = $proposedValidatorPath
        payload_path = $validatorPayloadPath
        parse_required = $true
        required = $true
      }
    )
    proposed_module_payload_path = $modulePayloadPath
    proposed_validator_payload_path = $validatorPayloadPath
    source = $candidateSource
    proposed_only = $true
    accepted_code_written = $false
  })
  Write-Phase160ECandidateJsonFile -Path (Join-Path $candidateDir "proposed_patch_or_file_payloads/payload.json") -Object ([ordered]@{
    status = "PASS"
    candidate_id = $candidateId
    source = $candidateSource
    payload_type = "session_local_candidate_payload"
    proposed_file_path = $proposedModulePath
    proposed_validator_path = $proposedValidatorPath
    proposed_module_payload_path = $modulePayloadPath
    proposed_validator_payload_path = $validatorPayloadPath
    payload_note = "Candidate payload is data for owner review only. The live daemon did not write accepted code."
    required_payload_markers = @(
      "SELF_INITIATED_USEFUL_GOAL_SELECTION",
      "self_gap_inventory",
      "usefulness_scoring",
      "internal_active_task",
      "internal_active_task_creation",
      "no_teacher_inbox",
      "no_teacher_inbox_required",
      "candidate_bundle_creation",
      "promotion_bundle_update",
      "runtime_guard_required"
    )
    proposed_execution_contract = @(
      "Read run manifest and runtime guard.",
      "Build SELF_INITIATED_USEFUL_GOAL_SELECTION support from self_gap_inventory evidence.",
      "Use usefulness_scoring to rank at least five goals.",
      "Create internal_active_task without no_teacher_inbox dependency.",
      "Write candidate_bundle_creation payloads and promotion_bundle_update evidence.",
      "Respect owner promotion gate and runtime_guard_required before future activation.",
      "Write proof before any future accepted-code promotion."
    )
    proposed_module_payload = [ordered]@{
      self_gap_inventory = $true
      usefulness_scoring = $true
      internal_active_task_creation = $true
      no_teacher_inbox_required = $true
      candidate_bundle_creation = $true
      promotion_bundle_update = $true
      runtime_guard_required = $true
    }
    proposed_validator_payload = [ordered]@{
      validator_paths = $validatorNeeded
      validator_payload_path = $validatorPayloadPath
      proves_no_teacher_inbox_required = $true
      proves_owner_review_required = $true
      proves_runtime_guard_required = $true
    }
    repo_mutation_performed = $false
  })
  Write-Phase160ECandidateTextFile -Path (Join-Path $candidateDir "candidate_rationale.md") -Text (@(
    "# Candidate Rationale",
    "",
    "candidate_id: $candidateId",
    "source: $candidateSource",
    "source_task_id: $taskId",
    "source_plan_item_id: $planItemId",
    "source_internal_goal_id: $sourceInternalGoalId",
    "",
    "This candidate captures a session-local proposal from the live runner. It is intentionally not accepted code and requires owner promotion."
  ) -join "`n")
  Write-Phase160ECandidateJsonFile -Path (Join-Path $candidateDir "candidate_validation_plan.json") -Object ([ordered]@{
    status = "PASS"
    candidate_id = $candidateId
    validators_required_before_acceptance = $validatorNeeded
    proposed_validator_paths = $validatorNeeded
    proposed_module_payload_path = $modulePayloadPath
    proposed_validator_payload_path = $validatorPayloadPath
    materialization_parse_check_required = $true
    owner_review_required = $true
    runtime_guard_required = $true
    promotion_requires_fresh_commit_after_owner_review = $true
  })
  Write-Phase160ECandidateJsonFile -Path (Join-Path $candidateDir "candidate_risk_review.json") -Object ([ordered]@{
    status = "PASS"
    candidate_id = $candidateId
    risks = @(
      "Candidate may be incomplete until owner promotion.",
      "Live runtime outputs must never be staged as accepted code."
    )
    mitigations = @(
      "Owner promotion gate is required.",
      "Fresh validators and restart are required after accepted promotion."
    )
    accepted_state_mutated = $false
    repo_mutation_performed = $false
  })
  Write-Phase160ECandidateJsonFile -Path (Join-Path $candidateDir "candidate_status.json") -Object ([ordered]@{
    status = "CANDIDATE_DRAFT"
    quality_status = "CANDIDATE_DRAFT"
    candidate_id = $candidateId
    source = $candidateSource
    source_task_id = $taskId
    source_plan_item_id = $planItemId
    source_internal_goal_id = $sourceInternalGoalId
    owner_review_required = $true
    owner_promotion_allowed = $false
    promotion_status = "CANDIDATE_DRAFT"
    quality_gate_enabled = $true
    created_at = $candidateCreatedAt
  })
  Write-Phase160ECandidateJsonFile -Path (Join-Path $CandidateQueueRoot "$candidateId.json") -Object ([ordered]@{
    status = "CANDIDATE_DRAFT"
    quality_status = "CANDIDATE_DRAFT"
    candidate_id = $candidateId
    source = $candidateSource
    source_task_id = $taskId
    source_plan_item_id = $planItemId
    candidate_manifest_path = ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath $candidateManifestPath
    owner_promotion_allowed = $false
    queued_at = $candidateCreatedAt
  })

  Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
    event_type = "candidate_created"
    source = "candidate_workspace_step"
    candidate_id = $candidateId
    source_task_id = $taskId
    source_plan_item_id = $planItemId
    run_head = [string]$RunManifest.run_head
    occurred_at = $candidateCreatedAt
  })
  Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
    event_type = "candidate_validation_plan_written"
    source = "candidate_workspace_step"
    candidate_id = $candidateId
    occurred_at = (Get-Date).ToUniversalTime().ToString("o")
  })
  $qualityResult = Invoke-Phase160ECandidateQualityGate -RepoRoot $RepoRoot -CandidateDir $candidateDir -SessionRoot (ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull) -RunId ([string]$RunManifest.run_id)
  Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
    event_type = "candidate_quality_gate_completed"
    source = "candidate_workspace_step"
    candidate_id = $candidateId
    quality_status = [string]$qualityResult.quality_status
    owner_promotion_allowed = [bool]$qualityResult.owner_promotion_allowed
    revision_request_path = if ($qualityResult.PSObject.Properties.Name -contains "revision_request_path") { [string]$qualityResult.revision_request_path } else { "NONE" }
    occurred_at = (Get-Date).ToUniversalTime().ToString("o")
  })
  if ([string]$qualityResult.quality_status -eq "CANDIDATE_READY" -and [bool]$qualityResult.owner_promotion_allowed) {
    Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
      event_type = "candidate_ready_for_owner_review"
      source = "candidate_workspace_step"
      candidate_id = $candidateId
      promotion_status = "WAITING_OWNER_REVIEW"
      occurred_at = (Get-Date).ToUniversalTime().ToString("o")
    })
  }

  return Read-Phase160ECandidateJsonSafe -Path $candidateManifestPath
}

function Set-Phase160ECandidatePlanItemWaiting {
  param([string]$SessionRootFull, [object]$PlanItem, [string]$CandidateId)
  if ($null -eq $PlanItem) {
    return
  }
  $PlanItem.status = "WAITING_OWNER_PROMOTION"
  $PlanItem | Add-Member -MemberType NoteProperty -Name "candidate_id" -Value $CandidateId -Force
  $PlanItem | Add-Member -MemberType NoteProperty -Name "waiting_owner_promotion_at" -Value (Get-Date).ToUniversalTime().ToString("o") -Force
  $planFile = Get-Phase160ECandidateActivePlanFile -SessionRootFull $SessionRootFull -PlanItem $PlanItem
  if ($null -ne $planFile) {
    Write-Phase160ECandidateJsonFile -Path $planFile -Object $PlanItem
  }
  Write-Phase160ECandidateJsonFile -Path (Join-Path $SessionRootFull "active_task/active_plan_item.json") -Object $PlanItem
  Write-Phase160ECandidateJsonFile -Path (Join-Path $SessionRootFull "plan_items/active_plan_item.json") -Object $PlanItem
}

$RepoRoot = Resolve-Phase160ECandidateRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160ECandidatePath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  Assert-Phase160ECandidateRunIdSafe -RunId $RunId
  if (-not [string]::IsNullOrWhiteSpace($RunId) -and [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = "runtime_sessions/live_growth/$RunId"
  }
  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    throw "PHASE160E_CANDIDATE_SESSION_ROOT_REQUIRED"
  }

  $SessionRootFull = Resolve-Phase160ECandidatePath -RepoRoot $RepoRoot -Path $SessionRoot
  $SessionRootRelative = ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull
  $RunManifestPath = Join-Path $SessionRootFull "run_manifest.json"
  $RuntimeGuardPath = Join-Path $SessionRootFull "runtime_guard.json"
  $RunManifest = Read-Phase160ECandidateJsonSafe -Path $RunManifestPath
  $RuntimeGuard = Read-Phase160ECandidateJsonSafe -Path $RuntimeGuardPath
  if ($null -eq $RunManifest) {
    throw "PHASE160E_CANDIDATE_RUN_MANIFEST_MISSING=$SessionRootRelative/run_manifest.json"
  }
  if ($null -eq $RuntimeGuard) {
    throw "PHASE160E_CANDIDATE_RUNTIME_GUARD_MISSING=$SessionRootRelative/runtime_guard.json"
  }

  $CandidateWorkspace = Join-Path $SessionRootFull "candidate_workspace"
  $CandidateBundleRoot = Join-Path $CandidateWorkspace "candidate_bundles"
  $CandidateQueueRoot = Join-Path $CandidateWorkspace "candidate_queue"
  $CandidateQuarantineRoot = Join-Path $CandidateWorkspace "candidate_quarantine"
  $ChangeLedgerPath = Join-Path $CandidateWorkspace "change_ledger.jsonl"
  $TaskLifecycleRoot = Join-Path $SessionRootFull "task_lifecycle"
  $TaskCompletionReceiptRoot = Join-Path $TaskLifecycleRoot "task_completion_receipts"
  $BacklogAdvancementLogPath = Join-Path $TaskLifecycleRoot "backlog_advancement_log.jsonl"
  $PlanAdvancementLogPath = Join-Path $TaskLifecycleRoot "plan_item_advancement_log.jsonl"
  $ActiveTaskStatePath = Join-Path $TaskLifecycleRoot "active_task_state.json"
  $BlockerQueuePath = Join-Path $SessionRootFull "blocker_queue"
  foreach ($directory in @(
    $CandidateWorkspace,
    $CandidateBundleRoot,
    $CandidateQueueRoot,
    $CandidateQuarantineRoot,
    $TaskLifecycleRoot,
    $TaskCompletionReceiptRoot,
    $BlockerQueuePath,
    (Join-Path $SessionRootFull "promotion_bundle"),
    (Join-Path $SessionRootFull "active_task"),
    (Join-Path $SessionRootFull "task_backlog"),
    (Join-Path $SessionRootFull "plan_items")
  )) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  if ([string]$RuntimeGuard.status -ne "PASS" -or [bool]$RuntimeGuard.candidate_production_enabled -ne $true) {
    $BlockedReasons = if ($RuntimeGuard.PSObject.Properties.Name -contains "blocked_reasons") { @($RuntimeGuard.blocked_reasons | ForEach-Object { [string]$_ }) } else { @("runtime_guard_blocked") }
    if ($BlockedReasons.Count -lt 1) {
      $BlockedReasons = @("runtime_guard_blocked")
    }
    Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
      event_type = "candidate_workspace_step_blocked"
      source = "candidate_workspace_step"
      duty_id = $DutyId
      runtime_guard_status = [string]$RuntimeGuard.status
      candidate_production_enabled = [bool]$RuntimeGuard.candidate_production_enabled
      blocked_reasons = @($BlockedReasons)
      occurred_at = (Get-Date).ToUniversalTime().ToString("o")
    })
    Write-Phase160ECandidateJsonFile -Path (Join-Path $BlockerQueuePath ("blocker_candidate_workspace_runtime_guard_{0}.json" -f (ConvertTo-Phase160ECandidateSafeLeaf -Value $DutyId -MaxLength 40))) -Object ([ordered]@{
      status = "BLOCKED"
      blocker_id = "PHASE160G_CANDIDATE_WORKSPACE_RUNTIME_GUARD_BLOCKED"
      source = "candidate_workspace_step"
      duty_id = $DutyId
      runtime_guard_status = [string]$RuntimeGuard.status
      candidate_production_enabled = [bool]$RuntimeGuard.candidate_production_enabled
      blocked_reasons = @($BlockedReasons)
      blocked_reasons_source = "$SessionRootRelative/runtime_guard.json"
      candidate_created = $false
      promotion_ready_claim_created = $false
      created_at = (Get-Date).ToUniversalTime().ToString("o")
    })
    [pscustomobject][ordered]@{
      status = "BLOCKED"
      run_id = [string]$RunManifest.run_id
      session_root = $SessionRootRelative
      runtime_guard_status = [string]$RuntimeGuard.status
      candidate_production_enabled = $false
      blocked_reasons = @($BlockedReasons)
      candidate_count = (Get-Phase160ECandidateBundleCounts -CandidateBundleRoot $CandidateBundleRoot).candidate_count
    } | ConvertTo-Json -Depth 20
    return
  }

  $ActiveTaskPath = Join-Path $SessionRootFull "active_task/active_task.json"
  $ActivePlanItemPath = Join-Path $SessionRootFull "active_task/active_plan_item.json"
  $ActiveTask = Read-Phase160ECandidateJsonSafe -Path $ActiveTaskPath
  $ActivePlanItem = Read-Phase160ECandidateJsonSafe -Path $ActivePlanItemPath
  $ActiveTaskState = Read-Phase160ECandidateJsonSafe -Path $ActiveTaskStatePath
  $CandidateCreated = $false
  $BacklogAdvanced = $false
  $PlanItemAdvanced = $false
  $ActiveTaskMovedToWaitingPromotion = $false
  $LastCandidateId = "NONE"

  if ($null -ne $ActiveTask -and $null -eq $ActiveTaskState) {
    Write-Phase160ECandidateJsonFile -Path $ActiveTaskStatePath -Object ([ordered]@{
      status = "ACTIVE"
      active_task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
      active_plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
      run_id = [string]$RunManifest.run_id
      run_head = [string]$RunManifest.run_head
      updated_at = (Get-Date).ToUniversalTime().ToString("o")
    })
    $ActiveTaskState = Read-Phase160ECandidateJsonSafe -Path $ActiveTaskStatePath
  }

  $CurrentStateStatus = if ($null -ne $ActiveTaskState) { Get-Phase160ECandidateString -Object $ActiveTaskState -Name "status" } else { "NONE" }
  if ($null -ne $ActiveTask -and $CurrentStateStatus -ne "WAITING_OWNER_PROMOTION") {
    $candidate = New-Phase160ECandidateBundle -RepoRoot $RepoRoot -SessionRootFull $SessionRootFull -RunManifest $RunManifest -ActiveTask $ActiveTask -ActivePlanItem $ActivePlanItem -DutyId $DutyId -TickNumber $TickNumber -CandidateBundleRoot $CandidateBundleRoot -CandidateQueueRoot $CandidateQueueRoot -ChangeLedgerPath $ChangeLedgerPath
    if ($null -ne $candidate) {
      $CandidateCreated = $true
      $LastCandidateId = Get-Phase160ECandidateString -Object $candidate -Name "candidate_id"
      $candidateSourceForState = Get-Phase160ECandidateString -Object $candidate -Name "source" -Default "owner_task"
      $candidateDecision = Get-Phase160ECandidateDecision -Candidate $candidate
      $candidateOwnerPromotionAllowed = Get-Phase160ECandidateOwnerPromotionAllowed -Candidate $candidate
      $candidateRevisionRequestPath = Get-Phase160ECandidateString -Object $candidate -Name "revision_request_path" -Default "NONE"
      if ($candidateDecision -eq "CANDIDATE_READY" -and $candidateOwnerPromotionAllowed) {
        Set-Phase160ECandidatePlanItemWaiting -SessionRootFull $SessionRootFull -PlanItem $ActivePlanItem -CandidateId $LastCandidateId
        Write-Phase160ECandidateJsonFile -Path $ActiveTaskStatePath -Object ([ordered]@{
          status = "WAITING_OWNER_PROMOTION"
          source = $candidateSourceForState
          active_task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          active_plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          desired_next_gap = Get-Phase160ECandidateString -Object $ActiveTask -Name "desired_next_gap"
          run_id = [string]$RunManifest.run_id
          run_head = [string]$RunManifest.run_head
          owner_approval_required = $true
          owner_review_required = $true
          owner_promotion_allowed = $true
          restart_required_after_promotion = $true
          updated_at = (Get-Date).ToUniversalTime().ToString("o")
        })
        $receiptPath = Join-Path $TaskCompletionReceiptRoot ("receipt_{0}_{1}.json" -f (ConvertTo-Phase160ECandidateSafeLeaf -Value (Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id") -MaxLength 70), $LastCandidateId)
        Write-Phase160ECandidateJsonFile -Path $receiptPath -Object ([ordered]@{
          status = "WAITING_OWNER_PROMOTION"
          source = $candidateSourceForState
          task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          promotion_gate_required = $true
          completed_session_local = $true
          accepted_code_written = $false
          created_at = (Get-Date).ToUniversalTime().ToString("o")
        })
        $ActiveTaskMovedToWaitingPromotion = $true
        Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
          event_type = "active_task_moved_to_waiting_owner_promotion"
          source = "candidate_workspace_step"
          task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          occurred_at = (Get-Date).ToUniversalTime().ToString("o")
        })
      } else {
        Write-Phase160ECandidateJsonFile -Path $ActiveTaskStatePath -Object ([ordered]@{
          status = $candidateDecision
          source = $candidateSourceForState
          active_task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          active_plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          revision_request_path = $candidateRevisionRequestPath
          return_to_candidate_generation = $true
          owner_promotion_allowed = $false
          run_id = [string]$RunManifest.run_id
          run_head = [string]$RunManifest.run_head
          updated_at = (Get-Date).ToUniversalTime().ToString("o")
        })
        Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
          event_type = "active_task_candidate_not_ready_for_owner_promotion"
          source = "candidate_workspace_step"
          task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          revision_request_path = $candidateRevisionRequestPath
          owner_promotion_allowed = $false
          occurred_at = (Get-Date).ToUniversalTime().ToString("o")
        })
      }
    }
  }

  $BacklogFiles = @(Get-ChildItem -LiteralPath (Join-Path $SessionRootFull "task_backlog") -File -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.json" } | Sort-Object `
    @{ Expression = { -(Get-Phase160ECandidatePriorityRank -Priority (Get-Phase160ECandidateString -Object (Read-Phase160ECandidateJsonSafe -Path $_.FullName) -Name "priority")) } }, `
    @{ Expression = { -(Get-Phase160ECandidateSourceRank -Source (Get-Phase160ECandidateString -Object (Read-Phase160ECandidateJsonSafe -Path $_.FullName) -Name "source")) } }, `
    @{ Expression = { [string](Get-Phase160ECandidateString -Object (Read-Phase160ECandidateJsonSafe -Path $_.FullName) -Name "created_at") } }, `
    Name)

  $StateAfterCandidate = Read-Phase160ECandidateJsonSafe -Path $ActiveTaskStatePath
  $CanAdvanceBacklog = ($null -ne $StateAfterCandidate -and (Get-Phase160ECandidateString -Object $StateAfterCandidate -Name "status") -eq "WAITING_OWNER_PROMOTION" -and $BacklogFiles.Count -gt 0)
  if ($CanAdvanceBacklog) {
    $SelectedBacklogFile = $BacklogFiles[0]
    $SelectedBacklog = Read-Phase160ECandidateJsonSafe -Path $SelectedBacklogFile.FullName
    if ($null -ne $SelectedBacklog) {
      $selectedBacklogSource = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "source" -Default "unknown"
      $selectedBacklogStatus = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "backlog_status" -Default "BACKLOG"
      $selectedActivationConditions = @(Get-Phase160ECandidateProperty -Object $SelectedBacklog -Name "activation_conditions" -Default @() | ForEach-Object { [string]$_ })
      if ($selectedBacklogSource -eq "owner" -and $selectedBacklogStatus -eq "BACKLOG_WAITING_ACTIVE_SLOT" -and @($selectedActivationConditions | Where-Object { $_ -eq "owner_promotion_or_restart_gate_required" }).Count -gt 0) {
        Add-Phase160ECandidateJsonLine -Path $BacklogAdvancementLogPath -Object ([ordered]@{
          event_type = "owner_backlog_activation_deferred"
          source = "candidate_workspace_step"
          active_task_id = Get-Phase160ECandidateString -Object $StateAfterCandidate -Name "active_task_id"
          backlog_task_id = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "task_id"
          backlog_status = $selectedBacklogStatus
          reason = "owner_promotion_or_restart_gate_required"
          occurred_at = (Get-Date).ToUniversalTime().ToString("o")
        })
        Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
          event_type = "owner_backlog_activation_deferred"
          source = "candidate_workspace_step"
          active_task_id = Get-Phase160ECandidateString -Object $StateAfterCandidate -Name "active_task_id"
          backlog_task_id = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "task_id"
          reason = "owner_promotion_or_restart_gate_required"
          occurred_at = (Get-Date).ToUniversalTime().ToString("o")
        })
      } else {
      $previousTaskId = Get-Phase160ECandidateString -Object $StateAfterCandidate -Name "active_task_id"
      $newTaskId = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "task_id"
      Write-Phase160ECandidateJsonFile -Path $ActiveTaskPath -Object ([ordered]@{
        status = "ACTIVE"
        duty_id = $DutyId
        task_id = $newTaskId
        source = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "source" -Default "owner"
        priority = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "priority" -Default "normal"
        owner_goal = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "owner_goal"
        desired_next_gap = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "desired_next_gap"
        teacher_digest_path = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "teacher_digest_path"
        content_hash = Get-Phase160ECandidateString -Object $SelectedBacklog -Name "content_hash"
        active_plan_item_id = "NONE"
        active_plan_item_path = "NONE"
        plan_step_count = [int](Get-Phase160ECandidateProperty -Object $SelectedBacklog -Name "plan_step_count" -Default 0)
        selected_for_candidate_workspace = $true
        selected_at = (Get-Date).ToUniversalTime().ToString("o")
      })
      Remove-Item -LiteralPath $SelectedBacklogFile.FullName -Force
      $ActiveTask = Read-Phase160ECandidateJsonSafe -Path $ActiveTaskPath
      $ActivePlanItem = Select-Phase160ECandidateNextPlanItem -SessionRootFull $SessionRootFull -RepoRoot $RepoRoot -ActiveTask $ActiveTask -ChangeLedgerPath $ChangeLedgerPath -PlanAdvancementLogPath $PlanAdvancementLogPath
      if ($null -ne $ActivePlanItem) {
        $PlanItemAdvanced = $true
        $ActiveTask.active_plan_item_id = Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id"
        $ActiveTask.active_plan_item_path = ConvertTo-Phase160ECandidateRelativePath -RepoRoot $RepoRoot -FullPath (Get-Phase160ECandidateActivePlanFile -SessionRootFull $SessionRootFull -PlanItem $ActivePlanItem)
        Write-Phase160ECandidateJsonFile -Path $ActiveTaskPath -Object $ActiveTask
      }
      Write-Phase160ECandidateJsonFile -Path $ActiveTaskStatePath -Object ([ordered]@{
        status = "ACTIVE"
        active_task_id = $newTaskId
        active_plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
        previous_task_id = $previousTaskId
        run_id = [string]$RunManifest.run_id
        run_head = [string]$RunManifest.run_head
        updated_at = (Get-Date).ToUniversalTime().ToString("o")
      })
      $BacklogAdvanced = $true
      Add-Phase160ECandidateJsonLine -Path $BacklogAdvancementLogPath -Object ([ordered]@{
        event_type = "backlog_advanced"
        source = "candidate_workspace_step"
        previous_task_id = $previousTaskId
        active_task_id = $newTaskId
        selected_backlog_file = $SelectedBacklogFile.Name
        active_plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
        occurred_at = (Get-Date).ToUniversalTime().ToString("o")
      })
      Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
        event_type = "backlog_advanced"
        source = "candidate_workspace_step"
        previous_task_id = $previousTaskId
        active_task_id = $newTaskId
        occurred_at = (Get-Date).ToUniversalTime().ToString("o")
      })
      }
    }
  }

  $ActiveTask = Read-Phase160ECandidateJsonSafe -Path $ActiveTaskPath
  $ActivePlanItem = Read-Phase160ECandidateJsonSafe -Path $ActivePlanItemPath
  $StateBeforeSecondCandidate = Read-Phase160ECandidateJsonSafe -Path $ActiveTaskStatePath
  $stateTaskId = if ($null -ne $StateBeforeSecondCandidate) { Get-Phase160ECandidateString -Object $StateBeforeSecondCandidate -Name "active_task_id" } else { "NONE" }
  $stateStatus = if ($null -ne $StateBeforeSecondCandidate) { Get-Phase160ECandidateString -Object $StateBeforeSecondCandidate -Name "status" } else { "NONE" }
  if ($null -ne $ActiveTask -and $stateStatus -eq "ACTIVE" -and $stateTaskId -eq (Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id")) {
    $candidate = New-Phase160ECandidateBundle -RepoRoot $RepoRoot -SessionRootFull $SessionRootFull -RunManifest $RunManifest -ActiveTask $ActiveTask -ActivePlanItem $ActivePlanItem -DutyId $DutyId -TickNumber $TickNumber -CandidateBundleRoot $CandidateBundleRoot -CandidateQueueRoot $CandidateQueueRoot -ChangeLedgerPath $ChangeLedgerPath
    if ($null -ne $candidate) {
      $CandidateCreated = $true
      $LastCandidateId = Get-Phase160ECandidateString -Object $candidate -Name "candidate_id"
      $candidateSourceForState = Get-Phase160ECandidateString -Object $candidate -Name "source" -Default "owner_task"
      $candidateDecision = Get-Phase160ECandidateDecision -Candidate $candidate
      $candidateOwnerPromotionAllowed = Get-Phase160ECandidateOwnerPromotionAllowed -Candidate $candidate
      $candidateRevisionRequestPath = Get-Phase160ECandidateString -Object $candidate -Name "revision_request_path" -Default "NONE"
      if ($candidateDecision -eq "CANDIDATE_READY" -and $candidateOwnerPromotionAllowed) {
        Set-Phase160ECandidatePlanItemWaiting -SessionRootFull $SessionRootFull -PlanItem $ActivePlanItem -CandidateId $LastCandidateId
        Write-Phase160ECandidateJsonFile -Path $ActiveTaskStatePath -Object ([ordered]@{
          status = "WAITING_OWNER_PROMOTION"
          source = $candidateSourceForState
          active_task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          active_plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          desired_next_gap = Get-Phase160ECandidateString -Object $ActiveTask -Name "desired_next_gap"
          run_id = [string]$RunManifest.run_id
          run_head = [string]$RunManifest.run_head
          owner_approval_required = $true
          owner_review_required = $true
          owner_promotion_allowed = $true
          restart_required_after_promotion = $true
          updated_at = (Get-Date).ToUniversalTime().ToString("o")
        })
        Write-Phase160ECandidateJsonFile -Path (Join-Path $TaskCompletionReceiptRoot ("receipt_{0}_{1}.json" -f (ConvertTo-Phase160ECandidateSafeLeaf -Value (Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id") -MaxLength 70), $LastCandidateId)) -Object ([ordered]@{
          status = "WAITING_OWNER_PROMOTION"
          source = $candidateSourceForState
          task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          promotion_gate_required = $true
          completed_session_local = $true
          accepted_code_written = $false
          created_at = (Get-Date).ToUniversalTime().ToString("o")
        })
        $ActiveTaskMovedToWaitingPromotion = $true
        Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
          event_type = "active_task_moved_to_waiting_owner_promotion"
          source = "candidate_workspace_step"
          task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          occurred_at = (Get-Date).ToUniversalTime().ToString("o")
        })
      } else {
        Write-Phase160ECandidateJsonFile -Path $ActiveTaskStatePath -Object ([ordered]@{
          status = $candidateDecision
          source = $candidateSourceForState
          active_task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          active_plan_item_id = if ($null -ne $ActivePlanItem) { Get-Phase160ECandidateString -Object $ActivePlanItem -Name "item_id" } else { "NONE" }
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          revision_request_path = $candidateRevisionRequestPath
          return_to_candidate_generation = $true
          owner_promotion_allowed = $false
          run_id = [string]$RunManifest.run_id
          run_head = [string]$RunManifest.run_head
          updated_at = (Get-Date).ToUniversalTime().ToString("o")
        })
        Add-Phase160ECandidateJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
          event_type = "active_task_candidate_not_ready_for_owner_promotion"
          source = "candidate_workspace_step"
          task_id = Get-Phase160ECandidateString -Object $ActiveTask -Name "task_id"
          candidate_id = $LastCandidateId
          quality_status = $candidateDecision
          revision_request_path = $candidateRevisionRequestPath
          owner_promotion_allowed = $false
          occurred_at = (Get-Date).ToUniversalTime().ToString("o")
        })
      }
    }
  }

  $FinalizeScript = Resolve-Phase160ECandidatePath -RepoRoot $RepoRoot -Path "modules/finalize_builder_promotion_bundle_001.ps1"
  $FinalizeOutput = @(powershell -NoProfile -ExecutionPolicy Bypass -File $FinalizeScript -SessionRoot $SessionRootRelative -RunId ([string]$RunManifest.run_id) 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE160E_CANDIDATE_PROMOTION_FINALIZE_FAILED exit=$LASTEXITCODE output=$($FinalizeOutput -join ' | ')"
  }
  $FinalizeResult = ($FinalizeOutput -join "`n") | ConvertFrom-Json
  $Counts = Get-Phase160ECandidateBundleCounts -CandidateBundleRoot $CandidateBundleRoot
  if ($LastCandidateId -eq "NONE") {
    $LastCandidateId = [string]$Counts.last_candidate_id
  }
  $FinalTaskState = Read-Phase160ECandidateJsonSafe -Path $ActiveTaskStatePath

  [pscustomobject][ordered]@{
    status = "PASS"
    run_id = [string]$RunManifest.run_id
    session_root = $SessionRootRelative
    duty_id = $DutyId
    tick_number = $TickNumber
    run_head = [string]$RunManifest.run_head
    candidate_workspace_created = Test-Path -LiteralPath $CandidateWorkspace
    candidate_bundle_created = [int]$Counts.candidate_count -gt 0
    candidate_created_this_step = $CandidateCreated
    candidate_count = [int]$Counts.candidate_count
    ready_candidate_count = [int]$Counts.ready_candidate_count
    quality_gate_enabled = $true
    quality_ready_count = [int]$Counts.ready_candidate_count
    quality_result_file_count = if ($Counts.PSObject.Properties.Name -contains "quality_result_file_count") { [int]$Counts.quality_result_file_count } else { 0 }
    quality_decision_count = if ($Counts.PSObject.Properties.Name -contains "quality_decision_count") { [int]$Counts.quality_decision_count } else { [int]$Counts.candidate_count }
    quality_artifact_consistency_status = if ($Counts.PSObject.Properties.Name -contains "quality_artifact_consistency_status") { [string]$Counts.quality_artifact_consistency_status } else { "UNKNOWN" }
    missing_quality_result_count = if ($Counts.PSObject.Properties.Name -contains "missing_quality_result_count") { [int]$Counts.missing_quality_result_count } else { 0 }
    revision_required_count = [int]$Counts.revision_required_count
    draft_candidate_count = [int]$Counts.draft_candidate_count
    quarantined_candidate_count = [int]$Counts.quarantined_candidate_count
    blocked_candidate_count = [int]$Counts.blocked_candidate_count
    last_quality_decision = [string]$Counts.last_quality_decision
    last_revision_request = [string]$Counts.last_revision_request
    owner_promotion_allowed = [bool]$Counts.owner_promotion_allowed
    promotion_bundle_created = [bool]$FinalizeResult.promotion_manifest_created
    promotion_bundle_status = [string]$FinalizeResult.promotion_bundle_status
    owner_review_summary_created = [bool]$FinalizeResult.owner_review_summary_created
    active_task_moved_to_waiting_promotion = $ActiveTaskMovedToWaitingPromotion
    active_task_status = if ($null -ne $FinalTaskState) { Get-Phase160ECandidateString -Object $FinalTaskState -Name "status" } else { "NONE" }
    backlog_advanced = $BacklogAdvanced
    plan_item_advanced = $PlanItemAdvanced
    last_candidate_id = $LastCandidateId
    restart_required_after_promotion = $true
    repo_mutation_performed = $false
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $false
  } | ConvertTo-Json -Depth 20
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
