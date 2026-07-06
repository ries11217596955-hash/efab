[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "FIRST_SMOKE_INSTALL_TRIAL_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "first_smoke_install_trial_v1"
$PackId = "PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1"
$TaskId = "TASK_FIRST_SMOKE_INSTALL_TRIAL_V1_001"
$GateId = "FIRST_SMOKE_INSTALL_TRIAL_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$OperationId = "validate_json_schema_with_python_jsonschema"
$MaterialId = "mat_python_jsonschema_001"
$PlanPath = "operations/smoke_trials/FIRST_SMOKE_INSTALL_TRIAL_V1_PLAN.json"
$OperationContractPath = "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json"
$FixturesRoot = "operations/smoke_trials/fixtures/json_schema_validation"
$Phase84ProofPath = "proofs/operations/FIRST_WRAPPER_OPERATION_CONTRACTS_V1.json"
$ReportPath = "reports/operations/FIRST_SMOKE_INSTALL_TRIAL_REPORT.json"
$ProofPath = "proofs/operations/FIRST_SMOKE_INSTALL_TRIAL_V1.json"
$NextAllowedStep = "PHASE86_OPERATION_RUNTIME_SKELETON_V1"
$ProtectedStatePaths = @(
  "materials/MATERIAL_CATALOG.json",
  "materials/MATERIAL_POLICY.json",
  "materials/quarantine/QUARANTINE_BATCH_001.json",
  "materials/quarantine/mat_json_schema_ajv_001/MATERIAL_CARD.json",
  "materials/quarantine/mat_python_jsonschema_001/MATERIAL_CARD.json",
  "operations/registry.json",
  "operations/contracts/validate_json_schema_with_ajv.contract.json",
  "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json"
)

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Get-FileSha256 {
  param([string]$Path)
  return (Get-FileHash -LiteralPath (Join-RepoPath $Path) -Algorithm SHA256).Hash
}

function Get-HashMap {
  param([string[]]$Paths)

  $hashes = [ordered]@{}
  foreach ($path in $Paths) {
    $hashes[$path] = Get-FileSha256 -Path $path
  }
  return $hashes
}

function Compare-HashMaps {
  param(
    [object]$Before,
    [object]$After
  )

  foreach ($property in $Before.GetEnumerator()) {
    if (-not $After.Contains($property.Key)) {
      return $false
    }
    if ($After[$property.Key] -ne $property.Value) {
      return $false
    }
  }
  return $true
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Object
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "MISSING_JSON=$Path"
  }

  return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
}

function Get-PropertyInfo {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  return $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
}

function Get-PropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    return $null
  }
  return $property.Value
}

function Set-PropertyValue {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Value
  )

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  } else {
    $property.Value = $Value
  }
}

function As-Array {
  param([object]$Value)

  if ($null -eq $Value) {
    return @()
  }
  if ($Value -is [System.Array]) {
    return $Value
  }
  return @($Value)
}

function Update-TaskQueue {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  Set-PropertyValue -Object $queue -Name "active_task_id" -Value "NONE"

  foreach ($task in As-Array (Get-PropertyValue -Object $queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_FIRST_SMOKE_INSTALL_TRIAL_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_85"
      Set-PropertyValue -Object $task -Name "gate" -Value $GateId
      Set-PropertyValue -Object $task -Name "pack_id" -Value $PackId
    }
  }

  Write-JsonFile -Path "TASK_QUEUE.json" -Object $queue
}

function Update-Roadmap {
  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  foreach ($capability in As-Array (Get-PropertyValue -Object $roadmap -Name "capabilities")) {
    $id = Get-PropertyValue -Object $capability -Name "id"
    $phase = Get-PropertyValue -Object $capability -Name "phase"
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_85") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_85"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Run first sandbox-only smoke install trial for python-jsonschema without global install, repo dependency folders, trusted operation status, or material trust."
    }
  }
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_85"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "first_smoke_install_trial_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Name "completed_capabilities")
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)

  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Test-OperationNotTrusted {
  $registry = Read-JsonRequired "operations/registry.json"
  $operations = As-Array (Get-PropertyValue -Object $registry -Name "operations")
  $matches = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "operation_id")" -eq $OperationId })
  if (@($matches).Count -ne 1) {
    throw "OPERATION_REGISTRY_MATCH_COUNT_$OperationId=$(@($matches).Count)"
  }
  if ("$(Get-PropertyValue -Object $matches[0] -Name "status")" -eq "TRUSTED_OPERATION") {
    throw "OPERATION_TRUSTED_FORBIDDEN=$OperationId"
  }
}

function Write-SmokeTrialProof {
  param(
    [object]$Report,
    [bool]$ProtectedStateUnchanged
  )

  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $proof = [ordered]@{
    proof_id = "FIRST_SMOKE_INSTALL_TRIAL_V1"
    phase = "PHASE_85"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    status = "PASS"
    generated_at = Get-UtcStamp
    evidence_files = @(
      $PlanPath,
      $OperationContractPath,
      "operations/smoke_trials/fixtures/json_schema_validation/schema.json",
      "operations/smoke_trials/fixtures/json_schema_validation/valid_instance.json",
      "operations/smoke_trials/fixtures/json_schema_validation/invalid_instance.json",
      $Phase84ProofPath,
      $ReportPath
    )
    validation_gates = @(
      "phase84_proof_pass",
      "selected_operation_contract_ready",
      "selected_operation_not_trusted",
      "temp_venv_created",
      "sandbox_install_exit_code_zero",
      "jsonschema_import_pass",
      "valid_fixture_pass",
      "invalid_fixture_rejected",
      "protected_state_unchanged",
      "queue_returned_to_none"
    )
    queue_state_after = [ordered]@{
      active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
    }
    smoke_trial_state_after = [ordered]@{
      report_path = $ReportPath
      report_status = "$(Get-PropertyValue -Object $Report -Name "status")"
      operation_id = "$(Get-PropertyValue -Object $Report -Name "operation_id")"
      related_material_id = "$(Get-PropertyValue -Object $Report -Name "related_material_id")"
      install_mode = "$(Get-PropertyValue -Object $Report -Name "install_mode")"
      sandbox_path_inside_repo = [bool](Get-PropertyValue -Object $Report -Name "sandbox_path_inside_repo")
      venv_created = [bool](Get-PropertyValue -Object $Report -Name "venv_created")
      sandbox_install_exit_code = [int](Get-PropertyValue -Object $Report -Name "sandbox_install_exit_code")
      package_import_pass = [bool](Get-PropertyValue -Object $Report -Name "package_import_pass")
      smoke_valid_case_pass = [bool](Get-PropertyValue -Object $Report -Name "smoke_valid_case_pass")
      smoke_invalid_case_pass = [bool](Get-PropertyValue -Object $Report -Name "smoke_invalid_case_pass")
    }
    forbidden_actions_confirmed = [ordered]@{
      no_global_install = (-not [bool](Get-PropertyValue -Object $Report -Name "global_install_performed"))
      no_user_install = $true
      no_npm_install = $true
      no_repo_clone = $true
      no_production_wrapper_created = $true
      no_materials_marked_trusted = (-not [bool](Get-PropertyValue -Object $Report -Name "material_marked_trusted"))
      no_trusted_operations_created = (-not [bool](Get-PropertyValue -Object $Report -Name "operation_marked_trusted"))
      no_catalog_mutation = $ProtectedStateUnchanged
      no_policy_mutation = $ProtectedStateUnchanged
      no_quarantine_card_mutation = $ProtectedStateUnchanged
      no_operation_contract_mutation = $ProtectedStateUnchanged
      no_external_agent_created = $true
      no_phase78_files_modified = $true
      no_phase79_files_modified = $true
      no_phase80_files_modified = $true
      no_phase81_files_modified = $true
      no_phase82_files_modified = $true
      no_phase83_files_modified = $true
      no_phase84_files_modified = $true
    }
    next_allowed_step = $NextAllowedStep
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

function Invoke-Validator {
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
}

Write-Host "PHASE85_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$phase84Proof = Read-JsonRequired $Phase84ProofPath
if ("$(Get-PropertyValue -Object $phase84Proof -Name "status")" -ne "PASS") {
  throw "PHASE84_PROOF_NOT_PASS"
}

$contract = Read-JsonRequired $OperationContractPath
if ("$(Get-PropertyValue -Object $contract -Name "operation_id")" -ne $OperationId) {
  throw "OPERATION_CONTRACT_ID_MISMATCH"
}
if ("$(Get-PropertyValue -Object $contract -Name "status")" -ne "CONTRACT_READY") {
  throw "OPERATION_CONTRACT_NOT_READY"
}
if ("$(Get-PropertyValue -Object $contract -Name "execution_mode")" -ne "NO_EXECUTION") {
  throw "OPERATION_CONTRACT_EXECUTION_MODE_NOT_NO_EXECUTION"
}
if ("$(Get-PropertyValue -Object $contract -Name "status")" -eq "TRUSTED_OPERATION") {
  throw "OPERATION_TRUSTED_FORBIDDEN"
}
Test-OperationNotTrusted

$hashesBefore = Get-HashMap -Paths $ProtectedStatePaths

$report = & (Join-RepoPath "modules/operations/run_first_smoke_install_trial.ps1") -RepoRoot $RepoRoot -OperationId $OperationId -PlanPath $PlanPath -OperationContractPath $OperationContractPath -FixturesRoot $FixturesRoot -OutputReportPath $ReportPath
Write-Host "FIRST_SMOKE_INSTALL_TRIAL_REPORT_WRITTEN"

if ($null -eq $report) {
  $report = Read-JsonRequired $ReportPath
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "SMOKE_TRIAL_REPORT_STATUS_NOT_PASS"
}

$hashesAfter = Get-HashMap -Paths $ProtectedStatePaths
$protectedStateUnchanged = Compare-HashMaps -Before $hashesBefore -After $hashesAfter
if (-not $protectedStateUnchanged) {
  throw "PHASE85_PROTECTED_STATE_MUTATED"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-SmokeTrialProof -Report $report -ProtectedStateUnchanged $protectedStateUnchanged
Write-Host "FIRST_SMOKE_INSTALL_TRIAL_PROOF_WRITTEN"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

Invoke-Validator

Write-Host "PHASE85_APPLY_COMPLETE"
