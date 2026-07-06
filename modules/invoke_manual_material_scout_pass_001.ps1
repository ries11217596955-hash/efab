function Read-JsonOptional {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  try { return Get-Content $Path -Raw | ConvertFrom-Json } catch { return $null }
}

function Write-JsonFile {
  param($Path, $Object, [int]$Depth = 40)
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Object | ConvertTo-Json -Depth $Depth | Set-Content -Path $Path -Encoding UTF8
}

function Invoke-ManualMaterialScoutPass001 {
  param(
    [string]$RepoRoot,
    [string]$RunId,
    $MaterialBootstrap,
    [string]$OutputRoot
  )

  Push-Location $RepoRoot

  try {
    if (-not (Test-Path $OutputRoot)) {
      New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }

    $Bootstrap = Read-JsonOptional "self_control/MATERIAL_ACQUISITION_BOOTSTRAP.json"
    $CatalogPath = "materials/MATERIAL_CATALOG.json"
    $Catalog = Read-JsonOptional $CatalogPath
    $P134 = Read-JsonOptional "proofs/self_development/PHASE134_BUILD_MATERIAL_ACQUISITION_BOOTSTRAP_V1.json"

    $status = "BLOCKED"
    $nextStep = "PHASE136_REVIEW_MANUAL_MATERIAL_SCOUT_PASS_001_INPUTS_V1"
    $reason = ""

    if (
      $MaterialBootstrap.status -eq "PASS" -and
      $Bootstrap.status -eq "PASS" -and
      $Bootstrap.default_trust -eq $false -and
      $Catalog.trusted_material_count -eq 0 -and
      $P134.status -eq "PASS"
    ) {
      $status = "PASS"
      $nextStep = "PHASE136_IMPORT_MANUAL_MATERIAL_SCOUT_PASS_TO_CATALOG_V1"
      $reason = "Manual scout pass recorded candidate/reference materials only. No external material was fetched, installed, wrapped, tested, or trusted."
    } else {
      $reason = "Material bootstrap, catalog, or PHASE134 proof is missing/unexpected."
    }

    $Candidates = @(
      [ordered]@{
        material_id = "candidate_pester_powershell_test_framework"
        name = "Pester"
        material_type = "LIBRARY"
        source = "https://github.com/pester/Pester"
        provenance = "Open-source PowerShell test and mock framework maintained in the pester GitHub organization."
        license_or_terms = "Apache-2.0 declared in repository license; owner/legal review still required before trusted use."
        risk_notes = "Would add a test framework dependency if adopted. Requires version pinning, PowerShell compatibility review, and quarantine smoke test."
        intended_use = "Future PowerShell module/runtime tests for Builder operations."
        initial_status = "CANDIDATE"
        owner_decision_required = $true
      },
      [ordered]@{
        material_id = "candidate_psscriptanalyzer_static_checker"
        name = "PSScriptAnalyzer"
        material_type = "LIBRARY"
        source = "https://github.com/PowerShell/PSScriptAnalyzer"
        provenance = "Microsoft PowerShell GitHub project for static analysis of PowerShell modules and scripts."
        license_or_terms = "MIT License declared in repository; owner/legal review still required before trusted use."
        risk_notes = "Would add static analysis rules and possible false positives. Requires pinned version, local smoke test, and rule scope decision."
        intended_use = "Future PowerShell quality gate for modules and orchestrator scripts."
        initial_status = "CANDIDATE"
        owner_decision_required = $true
      },
      [ordered]@{
        material_id = "candidate_syft_sbom_cli"
        name = "Syft"
        material_type = "CLI_TOOL"
        source = "https://github.com/anchore/syft"
        provenance = "Anchore open-source CLI tool and Go library for generating Software Bills of Materials."
        license_or_terms = "Apache-2.0 indicated by repository metadata; owner/legal review still required before trusted use."
        risk_notes = "CLI introduces binary/toolchain risk. Requires checksum/provenance review, pinned version, offline smoke, and no automatic install."
        intended_use = "Future SBOM generation operation for Builder repo and generated assets."
        initial_status = "CANDIDATE"
        owner_decision_required = $true
      },
      [ordered]@{
        material_id = "reference_json_schema_official"
        name = "JSON Schema official reference"
        material_type = "REFERENCE_ARCHITECTURE"
        source = "https://json-schema.org/"
        provenance = "Official JSON Schema website and documentation ecosystem."
        license_or_terms = "REFERENCE_ONLY; terms/license to be reviewed before copying any content or adopting tooling."
        risk_notes = "Useful as a schema reference, not executable material. Do not vendor text or tools without separate license review."
        intended_use = "Future schema design reference for material catalog, operation contracts, and proof/report validation."
        initial_status = "REFERENCE_ONLY"
        owner_decision_required = $true
      }
    )

    $ScoutPass = [ordered]@{
      status = $status
      scout_pass_id = "MANUAL_MATERIAL_SCOUT_PASS_001"
      created_by = "PHASE135_RUN_MANUAL_MATERIAL_SCOUT_PASS_001_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      mode = "MANUAL_SCOUT_PASS"
      external_fetch_performed_by_runtime = $false
      dependency_install_performed = $false
      trusted_material_count = 0
      candidate_material_count = 3
      reference_only_material_count = 1
      owner_decision_required_count = 4
      candidate_materials = $Candidates
      next_allowed_step = $nextStep
    }

    $ScoutPassPath = "materials/MANUAL_SCOUT_PASS_001.json"
    Write-JsonFile $ScoutPassPath $ScoutPass 40

    $UpdatedCatalog = [ordered]@{
      status = "MANUAL_SCOUT_PASS_001_RECORDED"
      catalog_id = "MATERIAL_CATALOG_V1"
      updated_by = "PHASE135_RUN_MANUAL_MATERIAL_SCOUT_PASS_001_V1"
      default_trust = $false
      trusted_material_count = 0
      candidate_material_count = 3
      reference_only_material_count = 1
      owner_decision_required_count = 4
      quarantine_required_before_use = $true
      material_statuses = @("DISCOVERED","CANDIDATE","QUARANTINED","WRAPPED","TESTED","TRUSTED","REJECTED","REFERENCE_ONLY","OWNER_APPROVAL_REQUIRED")
      materials = $Candidates
      next_allowed_step = $nextStep
    }

    Write-JsonFile $CatalogPath $UpdatedCatalog 40

    $Output = [ordered]@{
      status = $status
      engine_name = "MANUAL_MATERIAL_SCOUT_PASS_001_V1"
      run_id = $RunId
      scout_pass_recorded = ($status -eq "PASS")
      scout_pass_path = $ScoutPassPath
      material_catalog_path = $CatalogPath
      candidate_material_count = 3
      reference_only_material_count = 1
      trusted_material_count = 0
      external_fetch_performed_by_runtime = $false
      dependency_install_performed = $false
      proposed_next_step = $nextStep
      reason = $reason
      queue_mutated = $false
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $OutputPath = Join-Path $OutputRoot "MANUAL_MATERIAL_SCOUT_PASS_001_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 40
    $Output["output_path"] = $OutputPath

    return [pscustomobject]$Output
  } finally {
    Pop-Location
  }
}
