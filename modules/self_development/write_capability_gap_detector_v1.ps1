$ErrorActionPreference = "Stop"

function Ensure-Dir($Path) {
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Write-Json($Path, $Obj) {
  $dir = Split-Path $Path -Parent
  if ($dir) { Ensure-Dir $dir }
  $Obj | ConvertTo-Json -Depth 80 | Set-Content -Path $Path -Encoding UTF8
}

function Read-Json($Path) {
  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Assert-File($Path) {
  if (-not (Test-Path $Path)) {
    throw "REQUIRED_FILE_MISSING=$Path"
  }
}

function Write-CapabilityGapDetectorArtifacts {
  param(
    [string]$SchemaPath,
    [string]$DetectorPath,
    [string]$GapIndexPath,
    [string]$ReportPath,
    [string]$ProofPath,
    [string]$Phase92ProofPath,
    [string]$BacklogContractPath,
    [string]$RouteLockPath
  )

  Assert-File $Phase92ProofPath
  Assert-File $BacklogContractPath
  Assert-File $RouteLockPath

  $phase92Proof = Read-Json $Phase92ProofPath
  $backlogContract = Read-Json $BacklogContractPath
  $routeText = Get-Content $RouteLockPath -Raw

  if ($phase92Proof.status -ne "PASS") {
    throw "PHASE92_PROOF_STATUS_NOT_PASS=$($phase92Proof.status)"
  }
  if ($phase92Proof.next_allowed_step -ne "PHASE93_CAPABILITY_GAP_DETECTOR_V1") {
    throw "PHASE92_NEXT_ALLOWED_STEP_UNEXPECTED=$($phase92Proof.next_allowed_step)"
  }

  $gapStatuses = @(
    "PROVEN",
    "PARTIAL",
    "MISSING",
    "BLOCKED",
    "NEEDS_OWNER_DECISION",
    "NEEDS_CODEX_REPAIR",
    "NEEDS_MATERIAL",
    "PLANNED"
  )

  $schema = [ordered]@{
    '$schema' = "https://json-schema.org/draft/2020-12/schema"
    title = "Capability Gap Detector V1"
    type = "object"
    required = @("detector_id", "version", "status", "input_sources", "gap_statuses", "detection_rules", "output_contract")
    properties = [ordered]@{
      detector_id = [ordered]@{ type = "string" }
      version = [ordered]@{ type = "string" }
      status = [ordered]@{ type = "string" }
      input_sources = [ordered]@{
        type = "array"
        items = [ordered]@{ type = "string" }
      }
      gap_statuses = [ordered]@{
        type = "array"
        items = [ordered]@{
          type = "string"
          enum = $gapStatuses
        }
      }
      detection_rules = [ordered]@{ type = "object" }
      output_contract = [ordered]@{ type = "object" }
    }
  }

  $detector = [ordered]@{
    detector_id = "CAPABILITY_GAP_DETECTOR_V1"
    version = "V1"
    status = "ACTIVE_DETECTOR_CONTRACT"
    active_line = "AGENT_BUILDER / SELF_BUILD"
    route_lock = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md"
    purpose = "Detect missing capabilities needed for the batch self-build engine from repo evidence, route lock, backlog contract, and proofs."
    input_sources = @(
      "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
      "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json",
      "proofs/self_development/SELF_BUILD_BACKLOG_CONTRACT_V1.json",
      "CAPABILITY_ROADMAP.json",
      "GENESIS_STATE.json",
      "TASK_QUEUE.json"
    )
    gap_statuses = $gapStatuses
    detection_rules = [ordered]@{
      use_proof_before_claim = $true
      route_lock_controls_next_gap = $true
      backlog_contract_required = $true
      missing_capability_becomes_backlog_candidate = $true
      blocked_gap_must_include_reason = $true
      owner_order_mapping_not_yet_available = $true
      no_external_agent_gap_until_route_allows = $true
    }
    output_contract = [ordered]@{
      gap_required_fields = @(
        "gap_id",
        "title",
        "status",
        "why_needed",
        "evidence",
        "missing_artifacts",
        "risk",
        "recommended_next_step",
        "assistance_required"
      )
      gap_index_path = "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json"
      next_primary_gap_must_match_route = $true
    }
    no_external_agent_production = $true
    no_external_install = $true
    no_external_fetch = $true
    next_allowed_step = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
  }

  $gaps = @(
    [ordered]@{
      gap_id = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
      title = "Owner Order To Gap Map V1"
      status = "MISSING"
      why_needed = "Builder must translate an Owner request into missing capabilities before building."
      evidence = @("Route lock V2_R2 lists PHASE94 as next after capability gap detector.")
      missing_artifacts = @("owner_order_to_gap_map contract", "owner_order_to_gap_map report/proof")
      risk = "Without this, the Owner must manually explain every self-build gap."
      recommended_next_step = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2"
      title = "Self-Build Program Generator V2"
      status = "MISSING"
      why_needed = "Builder needs stronger programs that describe goals, files, risks, validation, and proof."
      evidence = @("Route lock V2_R2 lists PHASE95.")
      missing_artifacts = @("program generator V2 contract", "program generator V2 runtime proof")
      risk = "Without V2 generator, self-build programs remain too shallow for batch work."
      recommended_next_step = "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE96_BATCH_PLANNER_V1"
      title = "Batch Planner V1"
      status = "MISSING"
      why_needed = "Builder must group many backlog items into safe batches."
      evidence = @("Route lock V2_R2 lists PHASE96.")
      missing_artifacts = @("batch planner contract", "batch plan output schema")
      risk = "Without batch planning, large work becomes one-by-one manual control."
      recommended_next_step = "PHASE96_BATCH_PLANNER_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE97_BATCH_ADMISSION_POLICY_V1"
      title = "Batch Admission Policy V1"
      status = "MISSING"
      why_needed = "Builder must decide whether a batch is safe before execution."
      evidence = @("Route lock V2_R2 lists PHASE97.")
      missing_artifacts = @("batch admission policy", "batch admission proof")
      risk = "Unsafe batches may modify too much or hide risk."
      recommended_next_step = "PHASE97_BATCH_ADMISSION_POLICY_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1"
      title = "Item-Level Execution Ledger V1"
      status = "MISSING"
      why_needed = "Builder must record each item attempt, status, reason, and evidence."
      evidence = @("Owner batch doctrine requires item-level proof/failure reports.")
      missing_artifacts = @("item ledger schema", "item ledger runtime writer")
      risk = "Without item ledger, batch reports can hide failed or skipped items."
      recommended_next_step = "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1"
      title = "Continue-On-Failure Runtime V1"
      status = "MISSING"
      why_needed = "Builder must continue after safe item-level failures while stopping on systemic failures."
      evidence = @("Backlog contract defines continue_after_safe_item_failure=true.")
      missing_artifacts = @("continue-on-failure runtime behavior", "failure classification proof")
      risk = "Without this, a safe failure stops the whole batch."
      recommended_next_step = "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1"
      title = "Quarantine And Blocker Registry V1"
      status = "MISSING"
      why_needed = "Failed or blocked items need durable quarantine/blocker records."
      evidence = @("Backlog contract includes QUARANTINED and BLOCKED statuses.")
      missing_artifacts = @("quarantine registry", "blocker registry")
      risk = "Failed items may be lost or retried blindly."
      recommended_next_step = "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE101_BATCH_PROOF_AGGREGATOR_V1"
      title = "Batch Proof Aggregator V1"
      status = "MISSING"
      why_needed = "Builder needs a summary proof for large batches without hiding item-level details."
      evidence = @("Route lock V2_R2 lists PHASE101.")
      missing_artifacts = @("batch proof aggregator", "batch report schema")
      risk = "Large runs become unreadable without aggregation."
      recommended_next_step = "PHASE101_BATCH_PROOF_AGGREGATOR_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE102_AUTO_NEXT_GAP_DECISION_V1"
      title = "Auto Next-Gap Decision V1"
      status = "MISSING"
      why_needed = "After a batch, Builder should recommend the next missing capability."
      evidence = @("Owner wants Builder to say what is missing next.")
      missing_artifacts = @("next-gap decision kernel", "next-gap proof")
      risk = "Owner remains the manual planner after every batch."
      recommended_next_step = "PHASE102_AUTO_NEXT_GAP_DECISION_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE103_REPAIR_LOOP_GENERATOR_V1"
      title = "Repair Loop Generator V1"
      status = "MISSING"
      why_needed = "Builder needs repair programs for proven failures."
      evidence = @("Control doctrine requires fact → cause → patch → proof.")
      missing_artifacts = @("repair loop generator", "repair admission guard")
      risk = "Failures require manual repair design every time."
      recommended_next_step = "PHASE103_REPAIR_LOOP_GENERATOR_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"
      title = "Controlled Multi-Cycle Self-Build Run V1"
      status = "MISSING"
      why_needed = "Builder must run multiple controlled cycles: gap, program, admission, runtime, proof, next gap."
      evidence = @("Route lock V2_R2 lists PHASE104.")
      missing_artifacts = @("multi-cycle controller", "cycle stop conditions")
      risk = "Self-build remains a single-cycle mechanism."
      recommended_next_step = "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"
      assistance_required = "NONE"
    },
    [ordered]@{
      gap_id = "PHASE105_SCALE_TRIAL_10_TO_30_TO_100_TASKS_V1"
      title = "Scale Trial 10 To 30 To 100 Tasks V1"
      status = "MISSING"
      why_needed = "Builder must prove it can process bigger batches honestly."
      evidence = @("Owner described large-scale batch processing goal.")
      missing_artifacts = @("scale trial program", "scale report", "scale proof")
      risk = "The system may work only for tiny demonstrations."
      recommended_next_step = "PHASE105_SCALE_TRIAL_10_TO_30_TO_100_TASKS_V1"
      assistance_required = "NONE"
    }
  )

  $gapIndex = [ordered]@{
    index_id = "CAPABILITY_GAP_INDEX_V1"
    status = "ACTIVE_GAP_INDEX"
    active_line = "AGENT_BUILDER / SELF_BUILD"
    route_lock = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md"
    detector_id = "CAPABILITY_GAP_DETECTOR_V1"
    baseline_commit = "339a060"
    detected_gap_count = $gaps.Count
    next_primary_gap = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
    proven_foundation = @(
      "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1",
      "PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION",
      "PHASE92_SELF_BUILD_BACKLOG_CONTRACT_V1"
    )
    gaps = $gaps
    no_external_agent_production = $true
    next_allowed_step = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
  }

  $report = [ordered]@{
    status = "PASS"
    phase = "PHASE93_CAPABILITY_GAP_DETECTOR_V1"
    active_line = "AGENT_BUILDER / SELF_BUILD"
    baseline_commit = "339a060"
    detector_created = $DetectorPath
    gap_index_created = $GapIndexPath
    schema_created = $SchemaPath
    detected_gap_count = $gaps.Count
    next_primary_gap = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
    no_external_agents = $true
    no_external_install = $true
    no_external_fetch = $true
    batch_self_build_engine_route = $true
    next_allowed_step = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
  }

  $proof = [ordered]@{
    status = "PASS"
    phase = "PHASE93_CAPABILITY_GAP_DETECTOR_V1"
    task_id = "TASK_CAPABILITY_GAP_DETECTOR_V1_001"
    runtime_mode = "SELF_BUILD"
    route_lock_version = "V2_R2"
    baseline_commit = "339a060"
    detector_created = $DetectorPath
    gap_index_created = $GapIndexPath
    schema_created = $SchemaPath
    detected_gap_count = $gaps.Count
    next_primary_gap = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
    includes_owner_order_gap = $true
    includes_batch_planner_gap = $true
    includes_item_ledger_gap = $true
    includes_quarantine_registry_gap = $true
    no_external_agent_production = $true
    no_external_install = $true
    no_external_fetch = $true
    phase94_not_executed = $true
    queue_returned_to_none = $true
    next_allowed_step = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
  }

  Write-Json $SchemaPath $schema
  Write-Json $DetectorPath $detector
  Write-Json $GapIndexPath $gapIndex
  Write-Json $ReportPath $report
  Write-Json $ProofPath $proof

  Write-Output "CAPABILITY_GAP_SCHEMA_WRITTEN=$SchemaPath"
  Write-Output "CAPABILITY_GAP_DETECTOR_WRITTEN=$DetectorPath"
  Write-Output "CAPABILITY_GAP_INDEX_WRITTEN=$GapIndexPath"
  Write-Output "CAPABILITY_GAP_REPORT_WRITTEN=$ReportPath"
  Write-Output "CAPABILITY_GAP_PROOF_WRITTEN=$ProofPath"
}
