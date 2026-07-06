function Read-JsonOptional {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  try { return Get-Content $Path -Raw | ConvertFrom-Json } catch { return $null }
}

function Write-JsonFile {
  param($Path, $Object, [int]$Depth = 30)
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Object | ConvertTo-Json -Depth $Depth | Set-Content -Path $Path -Encoding UTF8
}

function Invoke-MaterialAcquisitionBootstrap {
  param(
    [string]$RepoRoot,
    [string]$RunId,
    $Entry,
    [string]$OutputRoot
  )

  Push-Location $RepoRoot

  try {
    if (-not (Test-Path $OutputRoot)) {
      New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }

    $SelfModel = Read-JsonOptional "self_model/BUILDER_SELF_MODEL.json"
    $Selector = Read-JsonOptional "self_control/SELF_BUILD_OPERATION_CAPABILITY_SELECTOR.json"
    $Contract = Read-JsonOptional "self_control/SELF_BUILD_OPERATION_CONTRACT.json"
    $P133 = Read-JsonOptional "proofs/self_development/PHASE133_BUILD_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_V1.json"

    $status = "BLOCKED"
    $reason = ""
    $nextStep = "PHASE135_REVIEW_MATERIAL_BOOTSTRAP_INPUTS_V1"

    if (
      $Entry.status -eq "PASS" -and
      $Entry.current_need -eq "NEED_MATERIAL_ACQUISITION_BOOTSTRAP" -and
      $SelfModel.status -eq "PASS" -and
      $Selector.status -eq "PASS" -and
      $Selector.selected_need_id -eq "NEED_MATERIAL_ACQUISITION_BOOTSTRAP" -and
      $Contract.status -eq "PASS" -and
      $P133.status -eq "PASS"
    ) {
      $status = "PASS"
      $nextStep = "PHASE135_RUN_MANUAL_MATERIAL_SCOUT_PASS_001_V1"
      $reason = "Material acquisition bootstrap created. No external materials are fetched, installed, or trusted. Next step is a manual scout pass that records candidates with provenance and risk."
    } else {
      $reason = "Entry, self-model, selector, contract, or PHASE133 proof is missing/unexpected."
    }

    $Bootstrap = [ordered]@{
      status = $status
      bootstrap_id = "MATERIAL_ACQUISITION_BOOTSTRAP_V1"
      created_by = "PHASE134_BUILD_MATERIAL_ACQUISITION_BOOTSTRAP_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      purpose = "Create the governed intake lane for external materials before catalog, quarantine, policy, wrapper, or trusted use."
      default_trust = $false
      external_fetch_performed = $false
      dependency_install_performed = $false
      allowed_material_types = @("CLI_TOOL","LIBRARY","TEMPLATE","WORKFLOW","DOCKER_IMAGE","POLICY","SCHEMA","EXAMPLE","REFERENCE_ARCHITECTURE")
      allowed_initial_statuses = @("DISCOVERED","CANDIDATE","REFERENCE_ONLY","OWNER_APPROVAL_REQUIRED")
      forbidden_initial_statuses = @("TRUSTED","TESTED","WRAPPED")
      required_fields_for_candidate = @("material_id","name","material_type","source","provenance","license_or_terms","risk_notes","intended_use","initial_status","owner_decision_required")
      next_manual_scout_pass = "PHASE135_RUN_MANUAL_MATERIAL_SCOUT_PASS_001_V1"
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $Catalog = [ordered]@{
      status = "READY_FOR_MANUAL_SCOUT_PASS"
      catalog_id = "MATERIAL_CATALOG_V1"
      created_by = "PHASE134_BUILD_MATERIAL_ACQUISITION_BOOTSTRAP_V1"
      default_trust = $false
      trusted_material_count = 0
      candidate_material_count = 0
      quarantine_required_before_use = $true
      material_statuses = @("DISCOVERED","CANDIDATE","QUARANTINED","WRAPPED","TESTED","TRUSTED","REJECTED","REFERENCE_ONLY","OWNER_APPROVAL_REQUIRED")
      materials = @()
      next_allowed_step = "PHASE135_RUN_MANUAL_MATERIAL_SCOUT_PASS_001_V1"
    }

    $Template = [ordered]@{
      template_id = "MANUAL_SCOUT_PASS_001_INPUT_TEMPLATE"
      status = "READY"
      instructions = "Owner or Assistant may record candidate materials here. This file is a template; it does not make any material trusted."
      candidate_materials = @(
        [ordered]@{
          material_id = "__REQUIRED__"
          name = "__REQUIRED__"
          material_type = "__CLI_TOOL_OR_LIBRARY_OR_TEMPLATE_OR_WORKFLOW_OR_DOCKER_IMAGE_OR_POLICY_OR_SCHEMA_OR_EXAMPLE_OR_REFERENCE_ARCHITECTURE__"
          source = "__URL_OR_LOCAL_REFERENCE__"
          provenance = "__WHO_CREATED_IT_AND_WHERE_IT_CAME_FROM__"
          license_or_terms = "__UNKNOWN_OR_DECLARED_LICENSE__"
          risk_notes = "__KNOWN_RISKS_OR_UNKNOWN__"
          intended_use = "__WHY_BUILDER_MIGHT_USE_IT__"
          initial_status = "CANDIDATE"
          owner_decision_required = $true
        }
      )
      next_allowed_step = "PHASE135_RUN_MANUAL_MATERIAL_SCOUT_PASS_001_V1"
    }

    $BootstrapPath = "self_control/MATERIAL_ACQUISITION_BOOTSTRAP.json"
    $CatalogPath = "materials/MATERIAL_CATALOG.json"
    $TemplatePath = "materials/MANUAL_SCOUT_PASS_001_INPUT_TEMPLATE.json"

    Write-JsonFile $BootstrapPath $Bootstrap 30
    Write-JsonFile $CatalogPath $Catalog 30
    Write-JsonFile $TemplatePath $Template 30

    $Output = [ordered]@{
      status = $status
      engine_name = "MATERIAL_ACQUISITION_BOOTSTRAP_BUILDER_V1"
      run_id = $RunId
      bootstrap_created = ($status -eq "PASS")
      bootstrap_path = $BootstrapPath
      material_catalog_path = $CatalogPath
      manual_scout_template_path = $TemplatePath
      external_fetch_performed = $false
      dependency_install_performed = $false
      trusted_material_count = 0
      proposed_next_step = $nextStep
      reason = $reason
      queue_mutated = $false
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $OutputPath = Join-Path $OutputRoot "MATERIAL_ACQUISITION_BOOTSTRAP_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 30
    $Output["output_path"] = $OutputPath

    return [pscustomobject]$Output
  } finally {
    Pop-Location
  }
}
