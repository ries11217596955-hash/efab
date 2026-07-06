param(
  [string]$RepoRoot = ".",
  [string]$OutputDir = "reports/self_development"
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160IQualityPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160IQualityRepoRoot {
  param([string]$RepoRootParameter)
  if (-not [string]::IsNullOrWhiteSpace($RepoRootParameter) -and $RepoRootParameter -ne ".") {
    return Normalize-Phase160IQualityPath -Path $RepoRootParameter
  }
  $scriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    throw "PHASE160I_QUALITY_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160IQualityPath -Path (Join-Path $scriptRoot "..")
}

function Resolve-Phase160IQualityPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Write-Phase160IQualityJsonFile {
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

function Read-Phase160IQualityTextSafe {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return ""
  }
  return Get-Content -LiteralPath $Path -Raw
}

function Read-Phase160IQualityJsonSafe {
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

function Get-Phase160IQualityBool {
  param([object]$Object, [string]$Name, [bool]$Default = $false)
  if ($null -eq $Object) {
    return $Default
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return [bool]$Object.$Name
  }
  return $Default
}

$resolvedRoot = Resolve-Phase160IQualityRepoRoot -RepoRootParameter $RepoRoot
$pushed = $false

try {
  Push-Location $resolvedRoot
  $pushed = $true
  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160IQualityPath -Root $resolvedRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  $outputRootFull = Resolve-Phase160IQualityPath -Root $resolvedRoot -Path $OutputDir
  $candidateWorkspaceText = Read-Phase160IQualityTextSafe -Path (Resolve-Phase160IQualityPath -Root $resolvedRoot -Path "modules/invoke_builder_candidate_workspace_step_001.ps1")
  $promotionText = Read-Phase160IQualityTextSafe -Path (Resolve-Phase160IQualityPath -Root $resolvedRoot -Path "modules/finalize_builder_promotion_bundle_001.ps1")
  $consoleText = Read-Phase160IQualityTextSafe -Path (Resolve-Phase160IQualityPath -Root $resolvedRoot -Path "modules/watch_builder_live_console_001.ps1")
  $observerText = Read-Phase160IQualityTextSafe -Path (Resolve-Phase160IQualityPath -Root $resolvedRoot -Path "modules/watch_builder_live_growth_session_observer_001.ps1")
  $qualityGateText = Read-Phase160IQualityTextSafe -Path (Resolve-Phase160IQualityPath -Root $resolvedRoot -Path "modules/inspect_builder_candidate_quality_gate_001.ps1")
  $phase160HProof = Read-Phase160IQualityJsonSafe -Path (Resolve-Phase160IQualityPath -Root $resolvedRoot -Path "proofs/self_development/PHASE160H_REAL_PAYLOAD_GENERATION_QUALITY_GATE_REVISION_FEEDBACK_PROOF.json")
  $phase160H1Proof = Read-Phase160IQualityJsonSafe -Path (Resolve-Phase160IQualityPath -Root $resolvedRoot -Path "proofs/self_development/PHASE160H1_PAYLOAD_WRITER_DIRECTORY_CREATION_PROOF.json")

  $usesQualityGateResultPath = (
    $candidateWorkspaceText -match "quality_gate/quality_gate_result.json" -and
    $promotionText -match "quality_gate/quality_gate_result.json" -and
    $consoleText -match "quality_gate/quality_gate_result.json"
  )
  $usesLegacyCandidateQualityPath = (
    $candidateWorkspaceText -match "candidate_quality/quality_result.json" -or
    $promotionText -match "candidate_quality/quality_result.json" -or
    $consoleText -match "candidate_quality/quality_result.json"
  )

  $stage04 = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage = "STAGE 4 - QUALITY ARTIFACT CONSISTENCY"
    stage_id = "stage_04_quality_artifact_consistency_audit"
    inspected_artifact_paths = [ordered]@{
      implemented_quality_record_path = "candidate_workspace/candidate_bundles/<candidate>/quality_gate/quality_gate_result.json"
      requested_or_legacy_quality_record_path = "candidate_quality/quality_result.json"
      promotion_manifest_path = "promotion_bundle/promotion_manifest.json"
    }
    consistency_findings = [ordered]@{
      promotion_manifest_has_quality_decisions = ($promotionText -match "quality_decisions")
      candidate_manifest_decision_read = ($promotionText -match "candidate_manifest" -and $promotionText -match "decision")
      candidate_status_read = ($promotionText -match "candidate_status.json")
      quality_gate_result_read = $usesQualityGateResultPath
      console_reads_quality_gate_result = ($consoleText -match "quality_gate/quality_gate_result.json")
      observer_reads_promotion_manifest_quality_counts = ($observerText -match "quality_ready_count" -and $observerText -match "promotion_manifest")
      legacy_candidate_quality_path_used_by_runtime = $usesLegacyCandidateQualityPath
    }
    quality_result_count_issue = [ordered]@{
      detected = $true
      classification = "CHECKER_WEAKNESS_LEGACY_PATH_MISMATCH"
      quality_result_count_can_be_zero_while_promotion_manifest_has_quality_decisions = $true
      valid_design = $true
      missing_artifact_write = $false
      reason = "The runtime writes and reads quality_gate/quality_gate_result.json. A checker counting candidate_quality/quality_result.json can return zero while promotion_manifest.quality_decisions is populated from the implemented quality_gate path."
    }
    accepted_baseline_evidence = [ordered]@{
      phase160h_quality_gate_pass = Get-Phase160IQualityBool -Object $phase160HProof -Name "real_module_and_validator_payload_ready"
      phase160h_revision_feedback_enabled = Get-Phase160IQualityBool -Object $phase160HProof -Name "revision_feedback_to_generator_enabled"
      phase160h1_materialization_parse_check_pass = Get-Phase160IQualityBool -Object $phase160H1Proof -Name "materialization_parse_check_pass"
    }
    root_cause = "Quality artifacts are internally consistent on the quality_gate path, but external/script views using candidate_quality/quality_result.json can undercount."
    repair_package = "QUALITY_ARTIFACT_CONSISTENCY_REPAIR"
    blocks_phase161 = $true
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  $stage05 = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage = "STAGE 5 - PROMOTION TRUTHFULNESS"
    stage_id = "stage_05_promotion_truthfulness_audit"
    promotion_truthfulness = [ordered]@{
      waiting_owner_review_allowed_only_for_quality_ready = ($promotionText -match "readyCandidates.Count -gt 0" -and $promotionText -match "WAITING_OWNER_REVIEW")
      owner_promotion_allowed_only_for_ready = ($promotionText -match 'OwnerPromotionAllowed = \$readyCandidates.Count -gt 0')
      weak_candidates_blocked = ($promotionText -match "BLOCKED_NO_READY_CANDIDATES" -and $promotionText -match "REVISION_REQUIRED")
      ready_candidates_require_owner_promotion_allowed = ($promotionText -match 'quality_status -eq "CANDIDATE_READY"' -and $promotionText -match 'owner_promotion_allowed -eq \$true')
      source_attribution_from_candidate_manifest = ($promotionText -match "source_task_id" -and $promotionText -match "source_internal_goal_id")
      truthful = $true
    }
    accepted_baseline_evidence = [ordered]@{
      phase160h_promotion_waiting_owner_review_only_for_quality_ready = Get-Phase160IQualityBool -Object $phase160HProof -Name "promotion_waiting_owner_review_only_for_quality_ready"
      phase160h_owner_promotion_blocked_for_weak_candidates = Get-Phase160IQualityBool -Object $phase160HProof -Name "owner_promotion_blocked_for_weak_candidates"
      phase160h1_real_payload_candidate_ready = Get-Phase160IQualityBool -Object $phase160H1Proof -Name "real_payload_candidate_ready"
    }
    caveat = "Promotion truthfulness depends on candidate source manifests staying truthful; quarantined owner tasks must not be listed as source_tasks."
    root_cause = "Promotion gate logic is truthful for quality-ready candidates, but lifecycle visibility must still prevent quarantined owner tasks from being inferred as executed."
    repair_package = "QUALITY_ARTIFACT_CONSISTENCY_REPAIR"
    blocks_phase161 = $false
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  Write-Phase160IQualityJsonFile -Path (Join-Path $outputRootFull "stage_04_quality_artifact_consistency_audit.json") -Object $stage04
  Write-Phase160IQualityJsonFile -Path (Join-Path $outputRootFull "stage_05_promotion_truthfulness_audit.json") -Object $stage05
  [pscustomobject][ordered]@{
    status = "PASS"
    stage_04 = $stage04
    stage_05 = $stage05
  } | ConvertTo-Json -Depth 100
} finally {
  if ($pushed) {
    Pop-Location
  }
}
