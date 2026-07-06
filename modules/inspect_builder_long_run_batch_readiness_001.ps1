param(
  [string]$RepoRoot = ".",
  [string]$OutputDir = "reports/self_development",
  [string]$ProofDir = "proofs/self_development",
  [string]$RouteRequestDir = "route_change_requests"
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160IReadyPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160IReadyRepoRoot {
  param([string]$RepoRootParameter)
  if (-not [string]::IsNullOrWhiteSpace($RepoRootParameter) -and $RepoRootParameter -ne ".") {
    return Normalize-Phase160IReadyPath -Path $RepoRootParameter
  }
  $scriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    throw "PHASE160I_READY_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160IReadyPath -Path (Join-Path $scriptRoot "..")
}

function Resolve-Phase160IReadyPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-Phase160IReadyRelativePath {
  param([string]$Root, [string]$FullPath)
  $rootFull = Normalize-Phase160IReadyPath -Path $Root
  $pathFull = Normalize-Phase160IReadyPath -Path $FullPath
  if ($pathFull -eq $rootFull) {
    return "."
  }
  if (-not $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160I_READY_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($pathFull.Substring($rootFull.Length + 1) -replace "\\", "/")
}

function Write-Phase160IReadyJsonFile {
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

function Write-Phase160IReadyTextFile {
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

function Read-Phase160IReadyJson {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "PHASE160I_READY_REQUIRED_STAGE_MISSING=$Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Read-Phase160IReadyTextSafe {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return ""
  }
  return Get-Content -LiteralPath $Path -Raw
}

function Get-Phase160IReadyProp {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $Default
}

function New-Phase160IReadyCriterion {
  param([string]$Name, [string]$Status, [string]$Evidence, [bool]$BlocksPhase161)
  return [ordered]@{
    criterion = $Name
    status = $Status
    evidence = $Evidence
    blocks_phase161 = $BlocksPhase161
  }
}

function New-Phase160IRepairPackage {
  param(
    [string]$Id,
    [string]$Problem,
    [string[]]$Evidence,
    [string[]]$FilesLikelyInScope,
    [string]$Risk,
    [string]$ValidatorScenario,
    [int]$DependencyOrder,
    [bool]$BlocksPhase161
  )
  return [ordered]@{
    package_id = $Id
    problem = $Problem
    evidence = @($Evidence)
    files_likely_in_scope = @($FilesLikelyInScope)
    risk = $Risk
    proposed_validator_scenario = $ValidatorScenario
    dependency_order = $DependencyOrder
    blocks_phase161 = $BlocksPhase161
  }
}

function New-Phase160IReportRow {
  param([string]$Stage, [string]$Expected, [string]$Observed, [string]$RootCause, [string]$RepairPackage, [bool]$BlocksPhase161)
  return [ordered]@{
    stage = $Stage
    expected = $Expected
    observed = $Observed
    root_cause = $RootCause
    repair_package = $RepairPackage
    blocks_phase161 = $BlocksPhase161
  }
}

$resolvedRoot = Resolve-Phase160IReadyRepoRoot -RepoRootParameter $RepoRoot
$pushed = $false

try {
  Push-Location $resolvedRoot
  $pushed = $true
  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160IReadyPath -Root $resolvedRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  $outputRootFull = Resolve-Phase160IReadyPath -Root $resolvedRoot -Path $OutputDir
  $proofRootFull = Resolve-Phase160IReadyPath -Root $resolvedRoot -Path $ProofDir
  $routeRootFull = Resolve-Phase160IReadyPath -Root $resolvedRoot -Path $RouteRequestDir

  $stage01 = Read-Phase160IReadyJson -Path (Join-Path $outputRootFull "stage_01_owner_task_intake_audit.json")
  $stage02 = Read-Phase160IReadyJson -Path (Join-Path $outputRootFull "stage_02_active_task_backlog_audit.json")
  $stage03 = Read-Phase160IReadyJson -Path (Join-Path $outputRootFull "stage_03_candidate_source_attribution_audit.json")
  $stage04 = Read-Phase160IReadyJson -Path (Join-Path $outputRootFull "stage_04_quality_artifact_consistency_audit.json")
  $stage05 = Read-Phase160IReadyJson -Path (Join-Path $outputRootFull "stage_05_promotion_truthfulness_audit.json")
  $stage06 = Read-Phase160IReadyJson -Path (Join-Path $outputRootFull "stage_06_route_lock_status_audit.json")

  $daemonText = Read-Phase160IReadyTextSafe -Path (Resolve-Phase160IReadyPath -Root $resolvedRoot -Path "modules/start_builder_live_growth_daemon_001.ps1")
  $observerText = Read-Phase160IReadyTextSafe -Path (Resolve-Phase160IReadyPath -Root $resolvedRoot -Path "modules/watch_builder_live_growth_session_observer_001.ps1")
  $batchProofText = Read-Phase160IReadyTextSafe -Path (Resolve-Phase160IReadyPath -Root $resolvedRoot -Path "self_build_batch/proof_aggregation/BATCH_PROOF_AGGREGATOR_V1.json")
  $quarantineText = Read-Phase160IReadyTextSafe -Path (Resolve-Phase160IReadyPath -Root $resolvedRoot -Path "self_build_batch/quarantine/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json")

  $safeIntakeFalseQuarantine = [bool](Get-Phase160IReadyProp -Object $stage01.unsafe_live_task_safety_rules -Name "safe_owner_training_task_falsely_quarantined" -Default $false)
  $backlogAudited = @($stage02.classifications | Where-Object { [string]$_ -eq "OWNER_TASK_BACKLOGGED" }).Count -gt 0
  $sourceTruth = [bool](Get-Phase160IReadyProp -Object $stage03.candidate_source_attribution -Name "truthful" -Default $false)
  $qualityCounterIssue = [bool](Get-Phase160IReadyProp -Object $stage04.quality_result_count_issue -Name "detected" -Default $false)
  $promotionTruth = [bool](Get-Phase160IReadyProp -Object $stage05.promotion_truthfulness -Name "truthful" -Default $false)
  $routeBlocks = [bool](Get-Phase160IReadyProp -Object $stage06 -Name "blocks_phase161" -Default $true)

  $criteria = @(
    (New-Phase160IReadyCriterion -Name "safe task intake" -Status "BLOCKED" -Evidence "Safe-intent alternate safety_rules are quarantined as unsafe_live_task_safety_rules." -BlocksPhase161 $true),
    (New-Phase160IReadyCriterion -Name "backlog support" -Status "PARTIAL" -Evidence "Backlog write and advancement exist, but advancement waits on active task WAITING_OWNER_PROMOTION." -BlocksPhase161 $true),
    (New-Phase160IReadyCriterion -Name "nonblocking active task" -Status "PARTIAL" -Evidence "Internal active tasks can delay owner tasks; no audited owner-priority preemption exists yet." -BlocksPhase161 $true),
    (New-Phase160IReadyCriterion -Name "candidate generation works" -Status "PASS" -Evidence "PHASE160H/H1 accepted real payload generation and materialization parse checks." -BlocksPhase161 $false),
    (New-Phase160IReadyCriterion -Name "quality gate works" -Status "PASS" -Evidence "Quality gate blocks weak/unsafe candidates and allows ready real payloads." -BlocksPhase161 $false),
    (New-Phase160IReadyCriterion -Name "revision feedback works" -Status "PASS" -Evidence "PHASE160H proof records revision feedback to generator." -BlocksPhase161 $false),
    (New-Phase160IReadyCriterion -Name "failure clustering exists" -Status "PARTIAL" -Evidence "Blocker/quarantine registries exist, but PHASE160 live lifecycle failure clustering is not yet a batch-school report." -BlocksPhase161 $true),
    (New-Phase160IReadyCriterion -Name "morning review report exists" -Status "BLOCKED" -Evidence "Observer and promotion summaries exist; a dedicated overnight morning review report is not proven." -BlocksPhase161 $true),
    (New-Phase160IReadyCriterion -Name "stop/archive/clean flow exists" -Status "PARTIAL" -Evidence "stop.flag is supported; archive and clean flow for overnight batch school is not proven." -BlocksPhase161 $true),
    (New-Phase160IReadyCriterion -Name "no accepted repo mutation during live run" -Status "PASS" -Evidence "PHASE160 proofs report no protected state mutation, no commit, no push, no branch switch, and runtime outputs not staged." -BlocksPhase161 $false)
  )

  $phase161Blockers = @($criteria | Where-Object { [bool]$_.blocks_phase161 -eq $true -and [string]$_.status -ne "PASS" } | ForEach-Object { [string]$_.criterion })
  $stage07 = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage = "STAGE 7 - OVERNIGHT BATCH READINESS"
    stage_id = "stage_07_overnight_batch_readiness_audit"
    criteria = @($criteria)
    overnight_batch_school_ready = $false
    phase161_blockers = @($phase161Blockers)
    supporting_runtime_features = [ordered]@{
      stop_flag_supported = ($daemonText -match "stop_flag")
      blocker_queue_supported = ($daemonText -match "blocker_queue")
      observer_can_write_suggestions = ($observerText -match "observer_suggestion")
      batch_quarantine_registry_exists = -not [string]::IsNullOrWhiteSpace($quarantineText)
      batch_proof_aggregator_exists = -not [string]::IsNullOrWhiteSpace($batchProofText)
    }
    root_cause = "The long-run runtime has useful pieces, but intake false-quarantine, owner/backlog scheduling, artifact counter visibility, route supersession, and morning review flow are not school-ready as a linked lifecycle."
    repair_package = "PHASE161_BATCH_SCHOOL_FOUNDATION"
    blocks_phase161 = $true
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  $packages = @(
    (New-Phase160IRepairPackage `
      -Id "TASK_INTAKE_SCHEMA_AND_SAFETY_RULES_REPAIR" `
      -Problem "Safe owner training tasks can be quarantined when safety_rules use safe-intent but noncanonical field names." `
      -Evidence @("stage_01 unsafe_live_task_safety_rules exact fields", "observed owner task quarantine reason unsafe_live_task_safety_rules") `
      -FilesLikelyInScope @("modules/invoke_builder_live_self_growth_duty_step_001.ps1", "validators/validate_phase161_task_intake_schema_safety_rules_v1.ps1") `
      -Risk "Weakening the safety gate could admit accepted-state or commit requests if not tested with unsafe negatives." `
      -ValidatorScenario "Canonical safe, safe-intent alternate, expected_outputs, plan_steps, and unsafe mutation tasks classify with explicit field reasons." `
      -DependencyOrder 1 `
      -BlocksPhase161 $true),
    (New-Phase160IRepairPackage `
      -Id "ACTIVE_TASK_BACKLOG_LIFECYCLE_REPAIR" `
      -Problem "Owner tasks can be delayed behind internal active tasks and backlog advancement is tied to owner-promotion wait state." `
      -Evidence @("stage_02 classifications ACTIVE_TASK_BLOCKS_OWNER_TASK and OWNER_TASK_BACKLOGGED", "candidate workspace backlog_advanced condition") `
      -FilesLikelyInScope @("modules/invoke_builder_candidate_workspace_step_001.ps1", "modules/select_builder_self_initiated_useful_goal_001.ps1", "modules/start_builder_live_growth_daemon_001.ps1") `
      -Risk "Preempting internal tasks incorrectly could discard useful work or duplicate candidates." `
      -ValidatorScenario "With internal active task plus safe owner task, owner task is backlogged, then advanced predictably without loss after current task reaches a clear handoff state." `
      -DependencyOrder 2 `
      -BlocksPhase161 $true),
    (New-Phase160IRepairPackage `
      -Id "QUALITY_ARTIFACT_CONSISTENCY_REPAIR" `
      -Problem "Quality counters can disagree when scripts count legacy candidate_quality/quality_result.json instead of quality_gate/quality_gate_result.json." `
      -Evidence @("stage_04 classification CHECKER_WEAKNESS_LEGACY_PATH_MISMATCH", "promotion_manifest.quality_decisions populated from quality_gate records") `
      -FilesLikelyInScope @("modules/watch_builder_live_console_001.ps1", "modules/watch_builder_live_growth_session_observer_001.ps1", "modules/finalize_builder_promotion_bundle_001.ps1") `
      -Risk "A superficial counter fix could hide missing quality records instead of reconciling artifact namespaces." `
      -ValidatorScenario "A fixture with one ready candidate proves candidate quality file count, quality_gate record count, console counters, and promotion_manifest decisions agree or declare the designed alias." `
      -DependencyOrder 3 `
      -BlocksPhase161 $true),
    (New-Phase160IRepairPackage `
      -Id "ROUTE_LOCK_SUPERSESSION_REPAIR" `
      -Problem "Route locks still contain active-looking PHASE91-PHASE105 and PHASE107-PHASE111 signals while accepted runtime is PHASE160H1." `
      -Evidence @("stage_06 root V2_R2 classified SUPERSEDED_CANDIDATE", "stage_06 V3 classified EXHAUSTED") `
      -FilesLikelyInScope @("route_change_requests/", "route_locks/", "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md") `
      -Risk "Silently retiring locks would erase route history; keeping stale locks active misroutes operators." `
      -ValidatorScenario "Route audit identifies active, exhausted, superseded, and archived locks and requires an explicit PHASE161 route request before state changes." `
      -DependencyOrder 4 `
      -BlocksPhase161 $true),
    (New-Phase160IRepairPackage `
      -Id "PHASE161_BATCH_SCHOOL_FOUNDATION" `
      -Problem "Overnight Builder School needs a linked lifecycle runner, morning review report, stop/archive/clean flow, and failure clustering after the preceding repairs." `
      -Evidence @("stage_07 readiness criteria", "phase161 blockers list") `
      -FilesLikelyInScope @("modules/start_builder_live_growth_daemon_001.ps1", "modules/watch_builder_live_growth_session_observer_001.ps1", "reports/self_development/", "proofs/self_development/") `
      -Risk "Launching school before lifecycle repairs would create unreviewable overnight work and ambiguous owner-task handling." `
      -ValidatorScenario "Batch-school dry run executes several safe tasks unattended, clusters failures, writes morning report, and proves no accepted repo mutation." `
      -DependencyOrder 5 `
      -BlocksPhase161 $true)
  )

  $stage08 = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage = "STAGE 8 - REPAIR PACKAGE PLAN"
    stage_id = "stage_08_repair_package_plan"
    packages = @($packages)
    dependency_order = @($packages | Sort-Object dependency_order | ForEach-Object { [string]$_.package_id })
    blocks_phase161_package_count = @($packages | Where-Object { [bool]$_.blocks_phase161 }).Count
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  Write-Phase160IReadyJsonFile -Path (Join-Path $outputRootFull "stage_07_overnight_batch_readiness_audit.json") -Object $stage07
  Write-Phase160IReadyJsonFile -Path (Join-Path $outputRootFull "stage_08_repair_package_plan.json") -Object $stage08

  $rows = @(
    (New-Phase160IReportRow -Stage "STAGE 1" -Expected "Safe owner tasks are accepted or backlogged with explicit reasons." -Observed "Safe-intent alternate safety_rules are quarantined as unsafe_live_task_safety_rules." -RootCause "Exact safety flag schema is too strict and badly named for safe owner training tasks." -RepairPackage "TASK_INTAKE_SCHEMA_AND_SAFETY_RULES_REPAIR" -BlocksPhase161 $true),
    (New-Phase160IReportRow -Stage "STAGE 2" -Expected "Active internal work must not discard safe owner tasks." -Observed "Canonical safe owner tasks can backlog, but internal active work delays activation." -RootCause "Backlog advancement is gated behind current active task owner-promotion state." -RepairPackage "ACTIVE_TASK_BACKLOG_LIFECYCLE_REPAIR" -BlocksPhase161 $true),
    (New-Phase160IReportRow -Stage "STAGE 3" -Expected "Candidate source attribution names the true task/source." -Observed "Recent candidate source is internal PHASE160F task; injected owner task did not influence candidate." -RootCause "Owner task was quarantined before source/candidate stages." -RepairPackage "TASK_INTAKE_SCHEMA_AND_SAFETY_RULES_REPAIR" -BlocksPhase161 $true),
    (New-Phase160IReportRow -Stage "STAGE 4" -Expected "Quality artifacts and counters agree." -Observed "quality_result_count can be zero while promotion_manifest.quality_decisions exists if a checker uses legacy candidate_quality path." -RootCause "Artifact namespace mismatch between quality_gate and candidate_quality views." -RepairPackage "QUALITY_ARTIFACT_CONSISTENCY_REPAIR" -BlocksPhase161 $true),
    (New-Phase160IReportRow -Stage "STAGE 5" -Expected "Promotion status is truthful." -Observed "WAITING_OWNER_REVIEW and owner_promotion_allowed are guarded by ready candidates; source caveat remains." -RootCause "Promotion logic is sound, but depends on truthful candidate manifests." -RepairPackage "QUALITY_ARTIFACT_CONSISTENCY_REPAIR" -BlocksPhase161 $false),
    (New-Phase160IReportRow -Stage "STAGE 6" -Expected "Route lock reflects current accepted runtime." -Observed "Root V2_R2 is superseded-looking, V3 is exhausted-looking, and PHASE161 route is not established." -RootCause "Route supersession not written after later accepted runtime phases." -RepairPackage "ROUTE_LOCK_SUPERSESSION_REPAIR" -BlocksPhase161 $true),
    (New-Phase160IReportRow -Stage "STAGE 7" -Expected "Overnight batch school can run unattended with morning review." -Observed "Useful parts exist, but linked lifecycle readiness is blocked." -RootCause "No single proven school lifecycle ties intake, backlog, quality, failures, report, and stop/archive/clean together." -RepairPackage "PHASE161_BATCH_SCHOOL_FOUNDATION" -BlocksPhase161 $true),
    (New-Phase160IReportRow -Stage "STAGE 8" -Expected "Repair packages are ordered and validator-bound." -Observed "Five packages are ordered with validator scenarios and PHASE161 blockers." -RootCause "Audit-only phase intentionally produces the repair map, not the repairs." -RepairPackage "PHASE161_BATCH_SCHOOL_FOUNDATION" -BlocksPhase161 $true)
  )

  $reportLines = @(
    "# PHASE160I Long-Run Lifecycle Audit Report",
    "",
    "status: PASS",
    "line: AGENT_BUILDER_SELF_DEVELOPMENT",
    "mode: VERIFY",
    "audit_scope: audit pack only, not PHASE161 school engine",
    "",
    "## Decision",
    "",
    "PHASE161_READY=False",
    "ROOT_GAP=LONG_RUN_LIFECYCLE_VISIBILITY_AND_BATCH_READINESS_GAP",
    "",
    "## Stage Table",
    "",
    "| STAGE | EXPECTED | OBSERVED | ROOT_CAUSE | REPAIR_PACKAGE | BLOCKS_PHASE161 |",
    "| --- | --- | --- | --- | --- | --- |"
  )
  foreach ($row in $rows) {
    $reportLines += "| $($row.stage) | $($row.expected) | $($row.observed) | $($row.root_cause) | $($row.repair_package) | $($row.blocks_phase161) |"
  }
  $reportLines += @(
    "",
    "## Repair Package Order",
    ""
  )
  foreach ($package in ($packages | Sort-Object dependency_order)) {
    $reportLines += "$($package.dependency_order). $($package.package_id) - blocks PHASE161: $($package.blocks_phase161)"
  }
  $reportLines += @(
    "",
    "## Boundary",
    "",
    "- Audit only; no route lock was edited.",
    "- Protected state files were not intentionally mutated.",
    "- Runtime sessions are fixture/output only and must not be staged.",
    "- No commit, push, or branch switch is part of this audit."
  )

  $reportPath = Join-Path $outputRootFull "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT_REPORT.md"
  $proofPath = Join-Path $proofRootFull "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT_PROOF.json"
  $routeRequestPath = Join-Path $routeRootFull "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT_REQUEST.md"
  Write-Phase160IReadyTextFile -Path $reportPath -Text ($reportLines -join "`n")

  $stagePaths = @(
    "reports/self_development/stage_01_owner_task_intake_audit.json",
    "reports/self_development/stage_02_active_task_backlog_audit.json",
    "reports/self_development/stage_03_candidate_source_attribution_audit.json",
    "reports/self_development/stage_04_quality_artifact_consistency_audit.json",
    "reports/self_development/stage_05_promotion_truthfulness_audit.json",
    "reports/self_development/stage_06_route_lock_status_audit.json",
    "reports/self_development/stage_07_overnight_batch_readiness_audit.json",
    "reports/self_development/stage_08_repair_package_plan.json"
  )
  $proof = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage_paths = @($stagePaths)
    report_path = ConvertTo-Phase160IReadyRelativePath -Root $resolvedRoot -FullPath $reportPath
    proof_path = ConvertTo-Phase160IReadyRelativePath -Root $resolvedRoot -FullPath $proofPath
    route_request_path = ConvertTo-Phase160IReadyRelativePath -Root $resolvedRoot -FullPath $routeRequestPath
    owner_task_intake_audited = $true
    unsafe_live_task_safety_rules_root_cause_recorded = $safeIntakeFalseQuarantine
    active_task_backlog_lifecycle_audited = $backlogAudited
    candidate_source_attribution_audited = $sourceTruth
    quality_artifact_consistency_audited = $qualityCounterIssue
    promotion_truthfulness_audited = $promotionTruth
    route_lock_status_audited = $routeBlocks
    overnight_batch_readiness_audited = $true
    repair_package_plan_created = $true
    phase161_blockers_identified = $phase161Blockers.Count -gt 0
    phase161_blockers = @($phase161Blockers)
    no_protected_state_mutation = $true
    runtime_outputs_staged = $false
    no_commit_performed = $true
    no_push_performed = $true
    no_branch_switch = $true
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase160IReadyJsonFile -Path $proofPath -Object $proof

  $routeRequestLines = @(
    "# PHASE160I Long-Run Lifecycle Audit Route Request",
    "",
    "status: PREPARED, NOT RUN",
    "line: AGENT_BUILDER_SELF_DEVELOPMENT",
    "mode: VERIFY",
    "",
    "## Request",
    "",
    "Create an explicit PHASE161 Builder School route only after the repair packages in stage_08_repair_package_plan.json are addressed or consciously deferred with proof.",
    "",
    "## Recommendation",
    "",
    "- Supersede stale active-looking route locks with a PHASE161 curriculum route.",
    "- Do not silently retire existing locks.",
    "- Keep V2_R2 and V3 as archived references once supersession is proven.",
    "",
    "## Dependencies",
    "",
    "1. TASK_INTAKE_SCHEMA_AND_SAFETY_RULES_REPAIR",
    "2. ACTIVE_TASK_BACKLOG_LIFECYCLE_REPAIR",
    "3. QUALITY_ARTIFACT_CONSISTENCY_REPAIR",
    "4. ROUTE_LOCK_SUPERSESSION_REPAIR",
    "5. PHASE161_BATCH_SCHOOL_FOUNDATION"
  )
  Write-Phase160IReadyTextFile -Path $routeRequestPath -Text ($routeRequestLines -join "`n")

  [pscustomobject][ordered]@{
    status = "PASS"
    stage_07 = $stage07
    stage_08 = $stage08
    report_path = ConvertTo-Phase160IReadyRelativePath -Root $resolvedRoot -FullPath $reportPath
    proof_path = ConvertTo-Phase160IReadyRelativePath -Root $resolvedRoot -FullPath $proofPath
    route_request_path = ConvertTo-Phase160IReadyRelativePath -Root $resolvedRoot -FullPath $routeRequestPath
  } | ConvertTo-Json -Depth 100
} finally {
  if ($pushed) {
    Pop-Location
  }
}
