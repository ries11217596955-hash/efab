. (Join-Path $PSScriptRoot "normalize_builder_candidate_quality_artifacts_001.ps1")

function Get-Phase160KQualityDecisionIndex {
  param(
    [string]$RepoRoot,
    [string]$SessionRootFull,
    [switch]$RepairMissingQualityResults
  )

  $candidateBundleRoot = Join-Path $SessionRootFull "candidate_workspace/candidate_bundles"
  $promotionManifestPath = Join-Path $SessionRootFull "promotion_bundle/promotion_manifest.json"
  $promotionManifest = Read-Phase160KQualityJsonSafe -Path $promotionManifestPath
  $candidateRecords = @()
  $alignmentRecords = @()
  $repairCount = 0
  $missingQualityResultCount = 0
  $mismatchCount = 0

  if (Test-Path -LiteralPath $candidateBundleRoot) {
    $bundleDirs = @(Get-ChildItem -LiteralPath $candidateBundleRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
    foreach ($bundleDir in $bundleDirs) {
      $alignment = Repair-Phase160KCandidateQualityArtifacts -RepoRoot $RepoRoot -CandidateDirFull $bundleDir.FullName -RepairMissingQualityResult:$RepairMissingQualityResults
      $alignmentRecords += $alignment
      if ([bool]$alignment.repair_performed) {
        $repairCount += 1
      }
      if (-not [bool]$alignment.quality_result_exists) {
        $missingQualityResultCount += 1
      }
      if ([bool]$alignment.mismatch_detected) {
        $mismatchCount += 1
      }

      $manifest = $alignment.manifest
      $quality = $alignment.quality_result
      $status = $alignment.status_record
      $candidateId = [string]$alignment.candidate_id
      $qualityStatus = Get-Phase160KQualityString -Object $quality -Name "quality_status" -Default (Get-Phase160KQualityString -Object $status -Name "quality_status" -Default (Get-Phase160KQualityString -Object $manifest -Name "quality_status" -Default (Get-Phase160KQualityString -Object $manifest -Name "decision" -Default "UNKNOWN")))
      $ownerPromotionAllowed = Get-Phase160KQualityBool -Object $quality -Name "owner_promotion_allowed" -Default (Get-Phase160KQualityBool -Object $status -Name "owner_promotion_allowed" -Default (Get-Phase160KQualityBool -Object $manifest -Name "owner_promotion_allowed" -Default ($qualityStatus -eq "CANDIDATE_READY")))
      $revisionRequestPath = Get-Phase160KQualityString -Object $quality -Name "revision_request_path" -Default (Get-Phase160KQualityString -Object $status -Name "revision_request_path" -Default (Get-Phase160KQualityString -Object $manifest -Name "revision_request_path" -Default "NONE"))
      $candidateRecords += [pscustomobject][ordered]@{
        candidate_id = $candidateId
        source = Get-Phase160KQualityString -Object $manifest -Name "source" -Default "owner_task"
        source_task_id = Get-Phase160KQualityString -Object $quality -Name "source_task_id" -Default (Get-Phase160KQualityString -Object $manifest -Name "source_task_id")
        source_plan_item_id = Get-Phase160KQualityString -Object $manifest -Name "source_plan_item_id"
        source_internal_goal_id = Get-Phase160KQualityString -Object $manifest -Name "source_internal_goal_id"
        source_internal_goal_name = Get-Phase160KQualityString -Object $manifest -Name "source_internal_goal_name"
        created_from_run_head = Get-Phase160KQualityString -Object $manifest -Name "created_from_run_head"
        target_area = Get-Phase160KQualityString -Object $manifest -Name "target_area"
        proposed_file_paths = @(Get-Phase160KQualityProperty -Object $manifest -Name "proposed_file_paths" -Default @())
        proposed_validator_paths = @(Get-Phase160KQualityProperty -Object $manifest -Name "proposed_validator_paths" -Default @())
        acceptance_validator_needed = @(Get-Phase160KQualityProperty -Object $manifest -Name "acceptance_validator_needed" -Default @())
        decision = $qualityStatus
        quality_status = $qualityStatus
        owner_promotion_allowed = $ownerPromotionAllowed
        revision_required = Get-Phase160KQualityBool -Object $quality -Name "revision_required" -Default ($qualityStatus -eq "REVISION_REQUIRED")
        revision_request_path = $revisionRequestPath
        materialization_parse_check_pass = Get-Phase160KQualityBool -Object $quality -Name "parse_check_passed" -Default (Get-Phase160KQualityBool -Object $quality -Name "materialization_parse_check_pass" -Default $false)
        placeholder_detected = Get-Phase160KQualityBool -Object $quality -Name "placeholder_detected" -Default $false
        repo_mutation_performed = Get-Phase160KQualityBool -Object $quality -Name "repo_mutation_performed" -Default $false
        commit_performed = Get-Phase160KQualityBool -Object $quality -Name "commit_performed" -Default $false
        push_performed = Get-Phase160KQualityBool -Object $quality -Name "push_performed" -Default $false
        branch_switch_performed = Get-Phase160KQualityBool -Object $quality -Name "branch_switch_performed" -Default $false
        protected_state_mutated = Get-Phase160KQualityBool -Object $quality -Name "protected_state_mutated" -Default $false
        quality_gate_result_path = Get-Phase160KQualityString -Object $quality -Name "canonical_quality_result_path" -Default ([string]$alignment.canonical_quality_result_path)
        canonical_quality_result_path = [string]$alignment.canonical_quality_result_path
        quality_result_exists = [bool]$alignment.quality_result_exists
        repair_source = [string]$alignment.repair_source
        mismatch_detected = [bool]$alignment.mismatch_detected
        mismatched_fields = @($alignment.mismatched_fields)
        bundle_path = [string]$alignment.candidate_dir
      }
    }
  }

  $promotionDecisionIds = @()
  if ($null -ne $promotionManifest -and $promotionManifest.PSObject.Properties.Name -contains "quality_decisions") {
    foreach ($decision in @($promotionManifest.quality_decisions)) {
      $candidateId = Get-Phase160KQualityString -Object $decision -Name "candidate_id"
      if (-not [string]::IsNullOrWhiteSpace($candidateId) -and $candidateId -ne "NONE") {
        $promotionDecisionIds += $candidateId
        if (@($candidateRecords | Where-Object { [string]$_.candidate_id -eq $candidateId -and [bool]$_.quality_result_exists }).Count -lt 1) {
          $missingQualityResultCount += 1
        }
      }
    }
  }

  $readyCandidates = @($candidateRecords | Where-Object { $_.quality_status -eq "CANDIDATE_READY" -and $_.owner_promotion_allowed -eq $true -and $_.quality_result_exists -eq $true })
  $revisionRequiredCandidates = @($candidateRecords | Where-Object { $_.quality_status -eq "REVISION_REQUIRED" })
  $draftCandidates = @($candidateRecords | Where-Object { $_.quality_status -eq "CANDIDATE_DRAFT" })
  $quarantinedCandidates = @($candidateRecords | Where-Object { $_.quality_status -match "QUARANTINE|QUARANTINED" })
  $blockedCandidates = @($candidateRecords | Where-Object { $_.quality_status -match "BLOCKED" })
  $readyWithoutQualityResult = @($candidateRecords | Where-Object { $_.quality_status -eq "CANDIDATE_READY" -and $_.owner_promotion_allowed -eq $true -and $_.quality_result_exists -ne $true })
  $qualityResultFileCount = @($candidateRecords | Where-Object { $_.quality_result_exists -eq $true }).Count
  $qualityDecisionCount = if ($promotionDecisionIds.Count -gt $candidateRecords.Count) { $promotionDecisionIds.Count } else { $candidateRecords.Count }
  $inconsistent = ($missingQualityResultCount -gt 0 -or $mismatchCount -gt 0 -or $readyWithoutQualityResult.Count -gt 0)
  $consistencyStatus = if ($inconsistent) {
    "INCONSISTENT"
  } elseif ($repairCount -gt 0) {
    "REPAIRED_WITH_CANONICAL_BACKFILL"
  } else {
    "PASS"
  }
  $promotionStatus = "BLOCKED_NO_READY_CANDIDATES"
  if ($candidateRecords.Count -lt 1) {
    $promotionStatus = "NO_CANDIDATES"
  } elseif ($consistencyStatus -eq "INCONSISTENT") {
    $promotionStatus = "BLOCKED_QUALITY_ARTIFACT_INCONSISTENCY"
  } elseif ($readyCandidates.Count -gt 0) {
    $promotionStatus = "WAITING_OWNER_REVIEW"
  }

  return [pscustomobject][ordered]@{
    status = "PASS"
    quality_artifact_consistency_status = $consistencyStatus
    candidate_count_total = $candidateRecords.Count
    candidate_count = $candidateRecords.Count
    quality_result_file_count = $qualityResultFileCount
    quality_decision_count = $qualityDecisionCount
    missing_quality_result_count = $missingQualityResultCount
    mismatch_detected = $mismatchCount -gt 0
    mismatch_count = $mismatchCount
    mismatched_fields = @($alignmentRecords | ForEach-Object { @($_.mismatched_fields) } | Select-Object -Unique)
    repair_count = $repairCount
    ready_candidate_count_after_quality = $readyCandidates.Count
    quality_ready_count = $readyCandidates.Count
    revision_required_count = $revisionRequiredCandidates.Count
    draft_candidate_count = $draftCandidates.Count
    quarantined_candidate_count = $quarantinedCandidates.Count
    blocked_candidate_count = $blockedCandidates.Count
    promotion_ready_candidate_ids = @($readyCandidates | ForEach-Object { [string]$_.candidate_id })
    revision_required_candidate_ids = @($revisionRequiredCandidates | ForEach-Object { [string]$_.candidate_id })
    quarantined_candidate_ids = @($quarantinedCandidates | ForEach-Object { [string]$_.candidate_id })
    blocked_candidate_ids = @($blockedCandidates | ForEach-Object { [string]$_.candidate_id })
    ready_candidate_without_quality_result_count = $readyWithoutQualityResult.Count
    owner_promotion_allowed = ($readyCandidates.Count -gt 0 -and $consistencyStatus -ne "INCONSISTENT")
    promotion_status = $promotionStatus
    last_quality_decision = if ($candidateRecords.Count -gt 0) { [string]$candidateRecords[-1].quality_status } else { "NONE" }
    last_revision_request = if ($candidateRecords.Count -gt 0) { [string]$candidateRecords[-1].revision_request_path } else { "NONE" }
    candidate_records = @($candidateRecords)
    quality_decisions = @($candidateRecords | ForEach-Object {
      [ordered]@{
        candidate_id = [string]$_.candidate_id
        quality_status = [string]$_.quality_status
        owner_promotion_allowed = [bool]$_.owner_promotion_allowed
        revision_required = [bool]$_.revision_required
        revision_request_path = [string]$_.revision_request_path
        quality_result_path = [string]$_.canonical_quality_result_path
        repair_source = [string]$_.repair_source
      }
    })
    alignment_records = @($alignmentRecords)
  }
}
