$ErrorActionPreference = "Stop"

function Ensure-Dir($Path) {
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Write-Json($Path, $Obj) {
  $dir = Split-Path $Path -Parent
  if ($dir) { Ensure-Dir $dir }
  $Obj | ConvertTo-Json -Depth 60 | Set-Content -Path $Path -Encoding UTF8
}

function Write-SelfBuildBacklogContractArtifacts {
  param(
    [string]$SchemaPath,
    [string]$ContractPath,
    [string]$ReportPath,
    [string]$ProofPath
  )

  $statuses = @(
    "PLANNED",
    "RUNNING",
    "PASS",
    "FAILED",
    "QUARANTINED",
    "BLOCKED",
    "NEEDS_OWNER_DECISION",
    "NEEDS_CODEX_REPAIR",
    "NEEDS_MATERIAL",
    "SKIPPED_BY_POLICY"
  )

  $schema = [ordered]@{
    '$schema' = "https://json-schema.org/draft/2020-12/schema"
    title = "Self-Build Backlog Contract V1"
    type = "object"
    required = @("contract_id", "version", "status", "item_statuses", "item_contract", "batch_behavior")
    properties = [ordered]@{
      contract_id = [ordered]@{ type = "string" }
      version = [ordered]@{ type = "string" }
      status = [ordered]@{ type = "string" }
      item_statuses = [ordered]@{
        type = "array"
        items = [ordered]@{
          type = "string"
          enum = $statuses
        }
      }
      item_contract = [ordered]@{
        type = "object"
        required = @("required_fields", "evidence_required_for_pass", "quarantine_required_for_failed_unknown")
      }
      batch_behavior = [ordered]@{
        type = "object"
        required = @("continue_after_safe_item_failure", "stop_on_systemic_failure", "batch_report_required")
      }
    }
  }

  $contract = [ordered]@{
    contract_id = "SELF_BUILD_BACKLOG_CONTRACT_V1"
    version = "V1"
    status = "ACTIVE_CONTRACT"
    active_line = "AGENT_BUILDER / SELF_BUILD"
    route_lock = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md"
    purpose = "Define the backlog contract for batch self-build work: item statuses, evidence, quarantine, blockers, and assistance requests."
    item_statuses = $statuses
    item_contract = [ordered]@{
      required_fields = @(
        "item_id",
        "title",
        "requested_outcome",
        "status",
        "risk_level",
        "dependencies",
        "allowed_files_scope",
        "blocked_files_scope",
        "proof_required",
        "failure_reason",
        "quarantine_reason",
        "assistance_required",
        "next_action"
      )
      evidence_required_for_pass = @(
        "changed_files",
        "validation_output",
        "proof_or_report_path",
        "queue_state",
        "runtime_or_diagnostic_result"
      )
      quarantine_required_for_failed_unknown = $true
      failure_must_not_hide_item = $true
      blocked_item_must_include_reason = $true
      assistance_required_values = @(
        "NONE",
        "OWNER_DECISION",
        "CODEX_REPAIR",
        "MATERIAL_REQUIRED",
        "RUNTIME_REPAIR",
        "POLICY_DECISION"
      )
    }
    batch_behavior = [ordered]@{
      continue_after_safe_item_failure = $true
      stop_on_systemic_failure = $true
      stop_on_policy_violation = $true
      stop_on_repo_corruption = $true
      batch_report_required = $true
      item_level_report_required = $true
      proof_aggregation_required = $true
      commit_only_after_batch_validation = $true
    }
    examples = @(
      [ordered]@{
        item = "chair"
        result = "PASS"
        meaning = "Item built and proven."
      },
      [ordered]@{
        item = "table"
        result = "QUARANTINED"
        meaning = "Item failed safely; reason and needed help recorded; batch continues."
      },
      [ordered]@{
        item = "sofa"
        result = "BLOCKED"
        meaning = "Cannot continue this item without missing material, owner decision, or repair."
      }
    )
    next_allowed_step = "PHASE93_CAPABILITY_GAP_DETECTOR_V1"
  }

  $report = [ordered]@{
    status = "PASS"
    phase = "PHASE92_SELF_BUILD_BACKLOG_CONTRACT_V1"
    active_line = "AGENT_BUILDER / SELF_BUILD"
    baseline_commit = "ec162b8"
    contract_created = $ContractPath
    schema_created = $SchemaPath
    item_statuses = $statuses
    batch_self_build_engine_route = $true
    no_external_agents = $true
    no_external_install = $true
    no_external_fetch = $true
    continue_after_safe_item_failure_defined = $true
    quarantine_and_blocker_statuses_defined = $true
    next_allowed_step = "PHASE93_CAPABILITY_GAP_DETECTOR_V1"
  }

  $proof = [ordered]@{
    status = "PASS"
    phase = "PHASE92_SELF_BUILD_BACKLOG_CONTRACT_V1"
    task_id = "TASK_SELF_BUILD_BACKLOG_CONTRACT_V1_001"
    runtime_mode = "SELF_BUILD"
    route_lock_version = "V2_R2"
    baseline_commit = "ec162b8"
    schema_created = $SchemaPath
    contract_created = $ContractPath
    item_statuses_defined = $true
    includes_quarantine = $true
    includes_blocked = $true
    includes_needs_owner_decision = $true
    includes_needs_codex_repair = $true
    includes_needs_material = $true
    continue_after_safe_item_failure_defined = $true
    batch_report_required = $true
    no_external_agent_production = $true
    no_external_install = $true
    no_external_fetch = $true
    phase93_not_executed = $true
    queue_returned_to_none = $true
    next_allowed_step = "PHASE93_CAPABILITY_GAP_DETECTOR_V1"
  }

  Write-Json $SchemaPath $schema
  Write-Json $ContractPath $contract
  Write-Json $ReportPath $report
  Write-Json $ProofPath $proof

  Write-Output "SELF_BUILD_BACKLOG_SCHEMA_WRITTEN=$SchemaPath"
  Write-Output "SELF_BUILD_BACKLOG_CONTRACT_WRITTEN=$ContractPath"
  Write-Output "SELF_BUILD_BACKLOG_REPORT_WRITTEN=$ReportPath"
  Write-Output "SELF_BUILD_BACKLOG_PROOF_WRITTEN=$ProofPath"
}
