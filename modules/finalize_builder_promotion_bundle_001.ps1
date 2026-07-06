param(
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [switch]$WriteFinalHandoff
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "inspect_builder_quality_decision_index_001.ps1")

function Normalize-Phase160EPromotionFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160EPromotionRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160E_PROMOTION_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160EPromotionFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160EPromotionPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase160EPromotionRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160EPromotionFullPath -Path $RepoRoot
  $full = Normalize-Phase160EPromotionFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160E_PROMOTION_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function Write-Phase160EPromotionJsonFile {
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

function Write-Phase160EPromotionTextFile {
  param([string]$Path, [string]$Text)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  if (-not $Text.EndsWith("`n")) {
    $Text += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Add-Phase160EPromotionJsonLine {
  param([string]$Path, [object]$Object)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $line = $Object | ConvertTo-Json -Depth 100 -Compress
  [System.IO.File]::AppendAllText($Path, "$line`n", [System.Text.UTF8Encoding]::new($false))
}

function Read-Phase160EPromotionJsonSafe {
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

function Get-Phase160EPromotionProperty {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $Default
}

function Get-Phase160EPromotionString {
  param([object]$Object, [string]$Name, [string]$Default = "NONE")
  $value = Get-Phase160EPromotionProperty -Object $Object -Name $Name -Default $Default
  if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
    return $Default
  }
  return [string]$value
}

function Assert-Phase160EPromotionRunIdSafe {
  param([string]$RunId)
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    return
  }
  if ($RunId.IndexOfAny([char[]]@("/", "\")) -ge 0) {
    throw "PHASE160E_PROMOTION_RUN_ID_MUST_BE_LEAF=$RunId"
  }
}

function Invoke-Phase160EPromotionQualityGate {
  param(
    [string]$RepoRoot,
    [string]$CandidateDir,
    [string]$SessionRoot,
    [string]$RunId
  )
  $qualityGateScript = Resolve-Phase160EPromotionPath -RepoRoot $RepoRoot -Path "modules/inspect_builder_candidate_quality_gate_001.ps1"
  if (-not (Test-Path -LiteralPath $qualityGateScript)) {
    throw "PHASE160H_PROMOTION_QUALITY_GATE_MISSING=modules/inspect_builder_candidate_quality_gate_001.ps1"
  }
  $candidateDirRelative = ConvertTo-Phase160EPromotionRelativePath -RepoRoot $RepoRoot -FullPath $CandidateDir
  $output = @(powershell -NoProfile -ExecutionPolicy Bypass -File $qualityGateScript -CandidateDir $candidateDirRelative -SessionRoot $SessionRoot -RunId $RunId 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE160H_PROMOTION_QUALITY_GATE_FAILED candidate=$candidateDirRelative output=$($output -join ' | ')"
  }
  return ($output -join "`n") | ConvertFrom-Json
}

$RepoRoot = Resolve-Phase160EPromotionRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160EPromotionPath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  Assert-Phase160EPromotionRunIdSafe -RunId $RunId
  if (-not [string]::IsNullOrWhiteSpace($RunId) -and [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = "runtime_sessions/live_growth/$RunId"
  }
  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    throw "PHASE160E_PROMOTION_SESSION_ROOT_REQUIRED"
  }

  $SessionRootFull = Resolve-Phase160EPromotionPath -RepoRoot $RepoRoot -Path $SessionRoot
  $SessionRootRelative = ConvertTo-Phase160EPromotionRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull
  $ManifestPath = Join-Path $SessionRootFull "run_manifest.json"
  $RuntimeGuardPath = Join-Path $SessionRootFull "runtime_guard.json"
  $Manifest = Read-Phase160EPromotionJsonSafe -Path $ManifestPath
  $RuntimeGuard = Read-Phase160EPromotionJsonSafe -Path $RuntimeGuardPath
  if ($null -eq $Manifest) {
    throw "PHASE160E_PROMOTION_RUN_MANIFEST_MISSING=$SessionRootRelative/run_manifest.json"
  }

  $CandidateWorkspace = Join-Path $SessionRootFull "candidate_workspace"
  $CandidateBundleRoot = Join-Path $CandidateWorkspace "candidate_bundles"
  $CandidateQueueRoot = Join-Path $CandidateWorkspace "candidate_queue"
  $CandidateQuarantineRoot = Join-Path $CandidateWorkspace "candidate_quarantine"
  $ChangeLedgerPath = Join-Path $CandidateWorkspace "change_ledger.jsonl"
  $PromotionBundleRoot = Join-Path $SessionRootFull "promotion_bundle"
  New-Item -ItemType Directory -Force -Path $CandidateBundleRoot, $CandidateQueueRoot, $CandidateQuarantineRoot, $PromotionBundleRoot | Out-Null

  $CandidateRecords = @()
  $bundleDirectories = @(Get-ChildItem -LiteralPath $CandidateBundleRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
  foreach ($bundleDirectory in $bundleDirectories) {
    $candidateManifest = Read-Phase160EPromotionJsonSafe -Path (Join-Path $bundleDirectory.FullName "candidate_manifest.json")
    if ($null -eq $candidateManifest) {
      continue
    }
    $qualityResult = Invoke-Phase160EPromotionQualityGate -RepoRoot $RepoRoot -CandidateDir $bundleDirectory.FullName -SessionRoot $SessionRootRelative -RunId ([string]$Manifest.run_id)
    $candidateManifest = Read-Phase160EPromotionJsonSafe -Path (Join-Path $bundleDirectory.FullName "candidate_manifest.json")
    $candidateStatus = Read-Phase160EPromotionJsonSafe -Path (Join-Path $bundleDirectory.FullName "candidate_status.json")
    $qualityRecord = Read-Phase160EPromotionJsonSafe -Path (Join-Path $bundleDirectory.FullName "quality_gate/quality_gate_result.json")
    $decision = Get-Phase160EPromotionString -Object $qualityRecord -Name "quality_status" -Default (Get-Phase160EPromotionString -Object $qualityRecord -Name "status" -Default (Get-Phase160EPromotionString -Object $candidateStatus -Name "quality_status" -Default (Get-Phase160EPromotionString -Object $candidateStatus -Name "status" -Default (Get-Phase160EPromotionString -Object $candidateManifest -Name "quality_status" -Default (Get-Phase160EPromotionString -Object $candidateManifest -Name "decision" -Default "UNKNOWN")))))
    $ownerPromotionAllowed = [bool](Get-Phase160EPromotionProperty -Object $qualityRecord -Name "owner_promotion_allowed" -Default (Get-Phase160EPromotionProperty -Object $candidateStatus -Name "owner_promotion_allowed" -Default (Get-Phase160EPromotionProperty -Object $candidateManifest -Name "owner_promotion_allowed" -Default ($decision -eq "CANDIDATE_READY"))))
    $revisionRequestPath = Get-Phase160EPromotionString -Object $qualityRecord -Name "revision_request_path" -Default (Get-Phase160EPromotionString -Object $candidateStatus -Name "revision_request_path" -Default (Get-Phase160EPromotionString -Object $candidateManifest -Name "revision_request_path" -Default "NONE"))
    $CandidateRecords += [pscustomobject][ordered]@{
      candidate_id = Get-Phase160EPromotionString -Object $candidateManifest -Name "candidate_id"
      source = Get-Phase160EPromotionString -Object $candidateManifest -Name "source" -Default "owner_task"
      source_task_id = Get-Phase160EPromotionString -Object $candidateManifest -Name "source_task_id"
      source_plan_item_id = Get-Phase160EPromotionString -Object $candidateManifest -Name "source_plan_item_id"
      source_internal_goal_id = Get-Phase160EPromotionString -Object $candidateManifest -Name "source_internal_goal_id"
      source_internal_goal_name = Get-Phase160EPromotionString -Object $candidateManifest -Name "source_internal_goal_name"
      created_from_run_head = Get-Phase160EPromotionString -Object $candidateManifest -Name "created_from_run_head"
      target_area = Get-Phase160EPromotionString -Object $candidateManifest -Name "target_area"
      proposed_file_paths = @(Get-Phase160EPromotionProperty -Object $candidateManifest -Name "proposed_file_paths" -Default @())
      proposed_validator_paths = @(Get-Phase160EPromotionProperty -Object $candidateManifest -Name "proposed_validator_paths" -Default @())
      acceptance_validator_needed = @(Get-Phase160EPromotionProperty -Object $candidateManifest -Name "acceptance_validator_needed" -Default @())
      decision = $decision
      quality_status = $decision
      owner_promotion_allowed = $ownerPromotionAllowed
      revision_request_path = $revisionRequestPath
      materialization_parse_check_pass = if ($qualityRecord.PSObject.Properties.Name -contains "materialization_parse_check_pass") { [bool]$qualityRecord.materialization_parse_check_pass } else { $false }
      quality_gate_result_path = if ($qualityRecord.PSObject.Properties.Name -contains "candidate_dir") { "$([string]$qualityRecord.candidate_dir)/quality_gate/quality_gate_result.json" } else { "NONE" }
      quality_failed_checks = if ($qualityRecord.PSObject.Properties.Name -contains "failed_checks") { @($qualityRecord.failed_checks) } else { @() }
      quality_failure_reasons = if ($qualityRecord.PSObject.Properties.Name -contains "failure_reasons") { @($qualityRecord.failure_reasons) } else { @() }
      quality_gate_status = if ($null -ne $qualityResult -and $qualityResult.PSObject.Properties.Name -contains "status") { [string]$qualityResult.status } else { $decision }
      bundle_path = ConvertTo-Phase160EPromotionRelativePath -RepoRoot $RepoRoot -FullPath $bundleDirectory.FullName
    }
  }

  $QualityIndex = Get-Phase160KQualityDecisionIndex -RepoRoot $RepoRoot -SessionRootFull $SessionRootFull -RepairMissingQualityResults
  $CandidateRecords = @($QualityIndex.candidate_records)
  $readyCandidates = @($CandidateRecords | Where-Object { $_.quality_status -eq "CANDIDATE_READY" -and $_.owner_promotion_allowed -eq $true })
  $revisionRequiredCandidates = @($CandidateRecords | Where-Object { $_.quality_status -eq "REVISION_REQUIRED" })
  $draftCandidates = @($CandidateRecords | Where-Object { $_.quality_status -eq "CANDIDATE_DRAFT" })
  $quarantinedCandidates = @($CandidateRecords | Where-Object { $_.decision -match "QUARANTINE|QUARANTINED" })
  $blockedCandidates = @($CandidateRecords | Where-Object { $_.decision -match "BLOCKED" })
  $sourceTasks = @($CandidateRecords | ForEach-Object { [string]$_.source_task_id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "NONE" } | Select-Object -Unique)
  $sourcePlanItems = @($CandidateRecords | ForEach-Object { [string]$_.source_plan_item_id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "NONE" } | Select-Object -Unique)
  $sourceInternalGoals = @($CandidateRecords | Where-Object { [string]$_.source_internal_goal_id -ne "NONE" } | ForEach-Object {
    [ordered]@{
      goal_id = [string]$_.source_internal_goal_id
      goal_name = [string]$_.source_internal_goal_name
      candidate_id = [string]$_.candidate_id
    }
  })
  $requiredValidators = @($CandidateRecords | ForEach-Object { @($_.acceptance_validator_needed) + @($_.proposed_validator_paths) } | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
  $proposedFiles = @($CandidateRecords | ForEach-Object { $_.proposed_file_paths } | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
  $RuntimeGuardStatus = Get-Phase160EPromotionString -Object $RuntimeGuard -Name "status" -Default "UNKNOWN"
  $BlockedReasons = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "blocked_reasons") { @($RuntimeGuard.blocked_reasons | ForEach-Object { [string]$_ }) } else { @() }
  $PromotionStatus = "BLOCKED_NO_READY_CANDIDATES"
  if ($CandidateRecords.Count -eq 0) {
    if ($RuntimeGuardStatus -eq "BLOCKED") {
      $PromotionStatus = "BLOCKED_NO_CANDIDATES"
    } else {
      $PromotionStatus = "NO_CANDIDATES"
    }
  } elseif ([string]$QualityIndex.quality_artifact_consistency_status -eq "INCONSISTENT") {
    $PromotionStatus = "BLOCKED_QUALITY_ARTIFACT_INCONSISTENCY"
  } elseif ($readyCandidates.Count -gt 0) {
    $PromotionStatus = "WAITING_OWNER_REVIEW"
  }
  $OwnerReviewRequired = ($PromotionStatus -eq "WAITING_OWNER_REVIEW" -or $PromotionStatus -eq "BLOCKED_NO_CANDIDATES" -or $PromotionStatus -eq "BLOCKED_NO_READY_CANDIDATES")
  $OwnerPromotionGateRequired = $PromotionStatus -eq "WAITING_OWNER_REVIEW"
  $RestartRequiredAfterPromotion = $PromotionStatus -eq "WAITING_OWNER_REVIEW"
  $LastQualityDecision = if ($CandidateRecords.Count -gt 0) { [string]$CandidateRecords[-1].quality_status } else { "NONE" }
  $LastRevisionRequest = if ($CandidateRecords.Count -gt 0) { [string]$CandidateRecords[-1].revision_request_path } else { "NONE" }
  $OwnerPromotionAllowed = ($readyCandidates.Count -gt 0 -and [string]$QualityIndex.quality_artifact_consistency_status -ne "INCONSISTENT")

  $PromotionManifest = [ordered]@{
    status = "PASS"
    promotion_status = $PromotionStatus
    run_id = [string]$Manifest.run_id
    run_head = [string]$Manifest.run_head
    branch = [string]$Manifest.branch
    runtime_guard_status = $RuntimeGuardStatus
    blocked_reasons = @($BlockedReasons)
    candidate_count_total = [int]$QualityIndex.candidate_count_total
    candidate_count = $CandidateRecords.Count
    ready_candidate_count = $readyCandidates.Count
    ready_candidate_count_after_quality = $readyCandidates.Count
    quality_gate_enabled = $true
    quality_result_file_count = [int]$QualityIndex.quality_result_file_count
    quality_decision_count = [int]$QualityIndex.quality_decision_count
    quality_artifact_consistency_status = [string]$QualityIndex.quality_artifact_consistency_status
    missing_quality_result_count = [int]$QualityIndex.missing_quality_result_count
    quality_ready_count = $readyCandidates.Count
    revision_required_count = $revisionRequiredCandidates.Count
    draft_candidate_count = $draftCandidates.Count
    quarantined_candidate_count = $quarantinedCandidates.Count
    blocked_candidate_count = $blockedCandidates.Count
    promotion_ready_candidate_ids = @($QualityIndex.promotion_ready_candidate_ids)
    revision_required_candidate_ids = @($QualityIndex.revision_required_candidate_ids)
    quarantined_candidate_ids = @($QualityIndex.quarantined_candidate_ids)
    blocked_candidate_ids = @($QualityIndex.blocked_candidate_ids)
    last_quality_decision = $LastQualityDecision
    last_revision_request = $LastRevisionRequest
    candidate_ids = @($CandidateRecords | ForEach-Object { [string]$_.candidate_id })
    quality_decisions = @($CandidateRecords | ForEach-Object {
      [ordered]@{
        candidate_id = [string]$_.candidate_id
        quality_status = [string]$_.quality_status
        owner_promotion_allowed = [bool]$_.owner_promotion_allowed
        revision_required = [bool]$_.revision_required
        revision_request_path = [string]$_.revision_request_path
        materialization_parse_check_pass = [bool]$_.materialization_parse_check_pass
        quality_result_path = [string]$_.canonical_quality_result_path
        repair_source = [string]$_.repair_source
      }
    })
    source_tasks = $sourceTasks
    source_plan_items = $sourcePlanItems
    source_internal_goals = $sourceInternalGoals
    proposed_files_summary = $proposedFiles
    required_validators = $requiredValidators
    owner_review_required = $OwnerReviewRequired
    owner_promotion_gate_required = $OwnerPromotionGateRequired
    owner_promotion_allowed = $OwnerPromotionAllowed
    candidate_output_is_not_accepted_code = $true
    accepted_head_after_promotion = "UNKNOWN_UNTIL_OWNER_COMMIT"
    restart_required_after_promotion = $RestartRequiredAfterPromotion
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $false
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  $PromotionManifestPath = Join-Path $PromotionBundleRoot "promotion_manifest.json"
  Write-Phase160EPromotionJsonFile -Path $PromotionManifestPath -Object $PromotionManifest

  $summaryLines = @(
    "# PHASE160G Owner Review Summary",
    "",
    "status: $PromotionStatus",
    "run_id: $($PromotionManifest.run_id)",
    "run_head: $($PromotionManifest.run_head)",
    "candidate_count: $($PromotionManifest.candidate_count)",
    "ready_candidate_count: $($PromotionManifest.ready_candidate_count)",
    "ready_candidate_count_after_quality: $($PromotionManifest.ready_candidate_count_after_quality)",
    "revision_required_count: $($PromotionManifest.revision_required_count)",
    "draft_candidate_count: $($PromotionManifest.draft_candidate_count)",
    "quarantined_candidate_count: $($PromotionManifest.quarantined_candidate_count)",
    "blocked_candidate_count: $($PromotionManifest.blocked_candidate_count)",
    "owner_promotion_allowed: $($PromotionManifest.owner_promotion_allowed)",
    "last_quality_decision: $($PromotionManifest.last_quality_decision)",
    "last_revision_request: $($PromotionManifest.last_revision_request)",
    "runtime_guard_status: $RuntimeGuardStatus",
    "",
    "## Owner Gate",
    "- Candidate output is not accepted code.",
    "- Promotion requires owner stop, check, promotion, commit, and daemon restart only when a quality-ready candidate exists.",
    "- Runtime outputs must not be staged.",
    "- No commit, push, or branch switch was performed by the live daemon.",
    "- WAITING_OWNER_REVIEW is allowed only when ready_candidate_count_after_quality is greater than zero.",
    "",
    "## Quality Decisions"
  )
  if ($CandidateRecords.Count -eq 0) {
    $summaryLines += "- NONE"
  } else {
    foreach ($candidate in $CandidateRecords) {
      $sourceLabel = if ([string]$candidate.source -eq "internal_self_selected_goal") { "internal self-selected goal" } elseif ([string]$candidate.source -eq "plan_item") { "plan item" } else { "owner task" }
      $summaryLines += "- $($candidate.candidate_id) quality=$($candidate.quality_status) owner_promotion_allowed=$($candidate.owner_promotion_allowed) revision_request=$($candidate.revision_request_path) source=$sourceLabel task=$($candidate.source_task_id) plan_item=$($candidate.source_plan_item_id) internal_goal=$($candidate.source_internal_goal_id)"
    }
  }
  if ($CandidateRecords.Count -eq 0) {
    $reason = if ($RuntimeGuardStatus -eq "BLOCKED") { "runtime guard blocked candidate production: $($BlockedReasons -join ', ')" } else { "no active task produced a candidate in this session" }
    $summaryLines += @(
      "",
      "## No Candidate Ready",
      "- No candidate was created.",
      "- Nothing is ready for promotion.",
      "- Reason: $reason.",
      "- Next required action: review the runtime guard, active task, and self-initiated trigger evidence before starting another live run."
    )
  } elseif ($readyCandidates.Count -eq 0) {
    $summaryLines += @(
      "",
      "## No Ready Candidate",
      "- Candidate records exist, but none are ready for owner promotion.",
      "- Nothing is ready for promotion.",
      "- Next required action: inspect revision, draft, blocked, or quarantined candidate records before deciding whether to continue."
    )
  }
  $summaryLines += @(
    "",
    "## Review Notes",
    "- What candidate was created: session-local candidate bundles listed above.",
    "- Source: owner task, plan item, or internal self-selected goal is recorded per candidate.",
    "- Why useful: candidates target autonomy, safety, owner value, and validator-feasible self-growth.",
    "- Not applied to repo: no candidate payload was written to tracked accepted code.",
    "- Validators needed after promotion: $($requiredValidators -join ', ')",
    "- Risks and quarantine notes: incomplete candidates remain review-only and can be quarantined by the owner.",
    "- Restart rule: promotion requires owner stop, check, promotion, commit, and daemon restart only for ready candidates."
  )
  Write-Phase160EPromotionTextFile -Path (Join-Path $PromotionBundleRoot "owner_review_summary.md") -Text ($summaryLines -join "`n")

  $ProofIndex = [ordered]@{
    status = "PASS"
    run_id = [string]$Manifest.run_id
    run_head = [string]$Manifest.run_head
    promotion_status = $PromotionStatus
    proof_entries = @(
      [ordered]@{ proof_type = "run_manifest"; path = "$SessionRootRelative/run_manifest.json"; required = $true },
      [ordered]@{ proof_type = "runtime_identity"; path = "$SessionRootRelative/runtime_identity.json"; required = $true },
      [ordered]@{ proof_type = "runtime_guard"; path = "$SessionRootRelative/runtime_guard.json"; required = $true },
      [ordered]@{ proof_type = "candidate_workspace_ledger"; path = "$SessionRootRelative/candidate_workspace/change_ledger.jsonl"; required = $true },
      [ordered]@{ proof_type = "promotion_manifest"; path = "$SessionRootRelative/promotion_bundle/promotion_manifest.json"; required = $true },
      [ordered]@{ proof_type = "owner_review_summary"; path = "$SessionRootRelative/promotion_bundle/owner_review_summary.md"; required = $true }
    )
    candidate_bundle_paths = @($CandidateRecords | ForEach-Object { [string]$_.bundle_path })
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase160EPromotionJsonFile -Path (Join-Path $PromotionBundleRoot "promotion_proof_index.json") -Object $ProofIndex

  Add-Phase160EPromotionJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
    event_type = "promotion_bundle_updated"
    source = "promotion_finalizer"
    run_id = [string]$Manifest.run_id
    candidate_count = $CandidateRecords.Count
    ready_candidate_count = $readyCandidates.Count
    ready_candidate_count_after_quality = $readyCandidates.Count
    quality_result_file_count = [int]$QualityIndex.quality_result_file_count
    quality_decision_count = [int]$QualityIndex.quality_decision_count
    quality_artifact_consistency_status = [string]$QualityIndex.quality_artifact_consistency_status
    missing_quality_result_count = [int]$QualityIndex.missing_quality_result_count
    quality_gate_enabled = $true
    quality_ready_count = $readyCandidates.Count
    revision_required_count = $revisionRequiredCandidates.Count
    draft_candidate_count = $draftCandidates.Count
    quarantined_candidate_count = $quarantinedCandidates.Count
    blocked_candidate_count = $blockedCandidates.Count
    last_quality_decision = $LastQualityDecision
    last_revision_request = $LastRevisionRequest
    owner_promotion_allowed = $OwnerPromotionAllowed
    promotion_status = $PromotionStatus
    restart_required_after_promotion = $RestartRequiredAfterPromotion
    occurred_at = (Get-Date).ToUniversalTime().ToString("o")
  })

  if ($WriteFinalHandoff) {
    $handoffLines = @(
      "# PHASE160E Final Handoff Summary",
      "",
      "status: $PromotionStatus",
      "run_id: $($PromotionManifest.run_id)",
      "run_head: $($PromotionManifest.run_head)",
      "promotion_status: $($PromotionManifest.promotion_status)",
      "candidate_count: $($PromotionManifest.candidate_count)",
      "ready_candidate_count: $($PromotionManifest.ready_candidate_count)",
      "ready_candidate_count_after_quality: $($PromotionManifest.ready_candidate_count_after_quality)",
      "",
      "## Required Owner Sequence",
      "1. Stop the live runner.",
      "2. Inspect the promotion bundle and candidate bundles.",
      "3. Promote selected candidate work outside the live runtime session only if a quality-ready candidate exists.",
      "4. Run validators and commit accepted tracked code only after owner promotion.",
      "5. Restart a fresh live runner from the accepted head after accepted promotion.",
      "",
      "## Non-Mutation Claims",
      "- commit_performed: False",
      "- push_performed: False",
      "- branch_switch_performed: False",
      "- protected_state_mutated: False",
      "- candidate_output_is_not_accepted_code: True"
    )
    Write-Phase160EPromotionTextFile -Path (Join-Path $SessionRootFull "final_handoff_summary.md") -Text ($handoffLines -join "`n")
  }

  [pscustomobject][ordered]@{
    status = "PASS"
    run_id = [string]$Manifest.run_id
    session_root = $SessionRootRelative
    run_head = [string]$Manifest.run_head
    candidate_count = $CandidateRecords.Count
    ready_candidate_count = $readyCandidates.Count
    ready_candidate_count_after_quality = $readyCandidates.Count
    quality_result_file_count = [int]$QualityIndex.quality_result_file_count
    quality_decision_count = [int]$QualityIndex.quality_decision_count
    quality_artifact_consistency_status = [string]$QualityIndex.quality_artifact_consistency_status
    missing_quality_result_count = [int]$QualityIndex.missing_quality_result_count
    quality_gate_enabled = $true
    quality_ready_count = $readyCandidates.Count
    revision_required_count = $revisionRequiredCandidates.Count
    draft_candidate_count = $draftCandidates.Count
    quarantined_candidate_count = $quarantinedCandidates.Count
    blocked_candidate_count = $blockedCandidates.Count
    last_quality_decision = $LastQualityDecision
    last_revision_request = $LastRevisionRequest
    owner_promotion_allowed = $OwnerPromotionAllowed
    promotion_bundle_status = $PromotionStatus
    owner_review_summary_created = Test-Path -LiteralPath (Join-Path $PromotionBundleRoot "owner_review_summary.md")
    promotion_manifest_created = Test-Path -LiteralPath $PromotionManifestPath
    promotion_proof_index_created = Test-Path -LiteralPath (Join-Path $PromotionBundleRoot "promotion_proof_index.json")
    final_handoff_summary_created = Test-Path -LiteralPath (Join-Path $SessionRootFull "final_handoff_summary.md")
    restart_required_after_promotion = $RestartRequiredAfterPromotion
  } | ConvertTo-Json -Depth 20
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
