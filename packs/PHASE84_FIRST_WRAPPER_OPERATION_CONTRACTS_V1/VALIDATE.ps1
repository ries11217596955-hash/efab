[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$PackId = "PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1"
$TaskId = "TASK_FIRST_WRAPPER_OPERATION_CONTRACTS_V1_001"
$RegistryPath = "operations/registry.json"
$QuarantineBatchPath = "materials/quarantine/QUARANTINE_BATCH_001.json"
$OperationSkeletonProofPath = "proofs/operations/OPERATION_CONTRACT_SKELETON_V1.json"
$ReportPath = "reports/operations/FIRST_WRAPPER_OPERATION_CONTRACTS_REPORT.json"
$ProofPath = "proofs/operations/FIRST_WRAPPER_OPERATION_CONTRACTS_V1.json"
$NextAllowedStep = "PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1"
$ContractPaths = @(
  "operations/contracts/validate_json_schema_with_ajv.contract.json",
  "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json"
)
$QuarantineCardPaths = @(
  "materials/quarantine/mat_json_schema_ajv_001/MATERIAL_CARD.json",
  "materials/quarantine/mat_python_jsonschema_001/MATERIAL_CARD.json"
)
$ExpectedOperationIds = @(
  "validate_json_schema_with_ajv",
  "validate_json_schema_with_python_jsonschema"
)
$ExpectedContractSpecs = @{
  "validate_json_schema_with_ajv" = @{
    operation_name = "Validate JSON Schema with Ajv"
    operation_type = "VALIDATE_JSON_SCHEMA"
    phase_created = "PHASE_84"
    related_material_id = "mat_json_schema_ajv_001"
    related_quarantine_card_path = "materials/quarantine/mat_json_schema_ajv_001/MATERIAL_CARD.json"
    risk_level = "LOW"
    owner_approval_required = $false
  }
  "validate_json_schema_with_python_jsonschema" = @{
    operation_name = "Validate JSON Schema with python-jsonschema"
    operation_type = "VALIDATE_JSON_SCHEMA"
    phase_created = "PHASE_84"
    related_material_id = "mat_python_jsonschema_001"
    related_quarantine_card_path = "materials/quarantine/mat_python_jsonschema_001/MATERIAL_CARD.json"
    risk_level = "LOW"
    owner_approval_required = $false
  }
}

$script:Failures = @()

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Add-Failure {
  param([string]$Message)
  $script:Failures += $Message
}

function Read-JsonFile {
  param([string]$RelativePath)

  $path = Join-RepoPath $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    Add-Failure "MISSING_JSON=$RelativePath"
    return $null
  }

  try {
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
  } catch {
    Add-Failure "INVALID_JSON=$RelativePath :: $($_.Exception.Message)"
    return $null
  }
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

function Assert-ParserPass {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    Add-Failure "MISSING_SCRIPT=$Path"
    return
  }

  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$tokens, [ref]$errors) | Out-Null
  if (@($errors).Count -gt 0) {
    Add-Failure "POWERSHELL_PARSE_FAIL=$Path"
  }
}

function Assert-ProtectedClean {
  $protectedPaths = @(
    "orchestrator/run.ps1",
    "contracts/operations/operation_contract.schema.json",
    "contracts/operations/operation_registry.schema.json",
    "materials/MATERIAL_CATALOG.json",
    "materials/MATERIAL_POLICY.json",
    "materials/quarantine",
    "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1",
    "packs/PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1",
    "packs/PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1",
    "packs/PHASE81_MATERIAL_ADMISSION_POLICY_V1",
    "packs/PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1",
    "packs/PHASE83_OPERATION_CONTRACT_SKELETON_V1",
    "generated_agents",
    "applied_agents",
    ".github/workflows"
  )

  foreach ($path in $protectedPaths) {
    $status = @(git -C $RepoRoot status --short -- $path)
    if (@($status).Count -gt 0) {
      Add-Failure "PROTECTED_PATH_MODIFIED=$path :: $($status -join '; ')"
    }
  }
}

function Find-TaskEntry {
  param([object]$Queue)

  foreach ($task in As-Array (Get-PropertyValue -Object $Queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      return $task
    }
  }
  return $null
}

function Get-MatchingRegistryPacks {
  param([object]$Registry)

  return @(
    As-Array (Get-PropertyValue -Object $Registry -Name "packs") |
      Where-Object { "$(Get-PropertyValue -Object $_ -Name "task_id")" -eq $TaskId }
  )
}

function Get-OperationSummaries {
  param([object]$OperationRegistry)
  return @(As-Array (Get-PropertyValue -Object $OperationRegistry -Name "operations"))
}

function Get-TrustedOperationCount {
  param([object[]]$Operations)
  return @($Operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "TRUSTED_OPERATION" }).Count
}

function Resolve-ValidationStage {
  param([string]$RequestedStage)

  if ($RequestedStage -ne "Auto") {
    return $RequestedStage
  }

  $queue = Read-JsonFile "TASK_QUEUE.json"
  $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
  if ("$activeTaskId" -eq $TaskId) {
    return "Seed"
  }
  if ("$activeTaskId" -eq "NONE") {
    return "Completed"
  }
  return "Seed"
}

function Assert-ContractReady {
  param(
    [object]$Contract,
    [string]$Path
  )

  $requiredFields = @(
    "operation_id",
    "operation_name",
    "operation_type",
    "status",
    "phase_created",
    "related_material_id",
    "related_quarantine_card_path",
    "purpose",
    "input_contract",
    "output_contract",
    "allowed_reads",
    "allowed_writes",
    "forbidden_actions",
    "execution_mode",
    "risk_level",
    "smoke_test_plan",
    "proof_requirements",
    "rollback_notes",
    "owner_approval_required",
    "created_at",
    "next_allowed_step"
  )

  foreach ($field in $requiredFields) {
    if ($null -eq (Get-PropertyInfo -Object $Contract -Name $field)) {
      Add-Failure "CONTRACT_MISSING_FIELD=$Path::$field"
    }
  }

  $operationId = "$(Get-PropertyValue -Object $Contract -Name "operation_id")"
  if ($ExpectedOperationIds -notcontains $operationId) {
    Add-Failure "UNEXPECTED_OPERATION_ID=$operationId"
  } elseif ($ExpectedContractSpecs.ContainsKey($operationId)) {
    $spec = $ExpectedContractSpecs[$operationId]
    foreach ($key in $spec.Keys) {
      $actual = Get-PropertyValue -Object $Contract -Name $key
      $expected = $spec[$key]
      if ($expected -is [bool]) {
        if ([bool]$actual -ne $expected) {
          Add-Failure "CONTRACT_VALUE_MISMATCH=$operationId::$key"
        }
      } elseif ("$actual" -ne "$expected") {
        Add-Failure "CONTRACT_VALUE_MISMATCH=$operationId::$key"
      }
    }
  }
  if ("$(Get-PropertyValue -Object $Contract -Name "status")" -ne "CONTRACT_READY") {
    Add-Failure "CONTRACT_STATUS_NOT_READY=$operationId"
  }
  if ("$(Get-PropertyValue -Object $Contract -Name "execution_mode")" -ne "NO_EXECUTION") {
    Add-Failure "CONTRACT_EXECUTION_MODE_NOT_NO_EXECUTION=$operationId"
  }
  if ("$(Get-PropertyValue -Object $Contract -Name "status")" -eq "TRUSTED_OPERATION") {
    Add-Failure "CONTRACT_TRUSTED_OPERATION_FORBIDDEN=$operationId"
  }
  if ("$(Get-PropertyValue -Object $Contract -Name "next_allowed_step")" -ne $NextAllowedStep) {
    Add-Failure "CONTRACT_NEXT_ALLOWED_STEP_MISMATCH=$operationId"
  }
}

$requestedStage = $Stage
$Stage = Resolve-ValidationStage -RequestedStage $requestedStage

Write-Host "VALIDATION_STAGE=$Stage"
if ($requestedStage -eq "Auto") {
  Write-Host "VALIDATION_STAGE_AUTO_RESOLVED=$Stage"
}

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    Add-Failure "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

Assert-ProtectedClean

foreach ($script in @(
  "modules/operations/register_operation_contracts.ps1",
  "packs/PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1/APPLY.ps1",
  "packs/PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass -Path $script
}

Read-JsonFile "packs/PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1/PACK.json" | Out-Null
Read-JsonFile "tasks/TASK_FIRST_WRAPPER_OPERATION_CONTRACTS_V1_001.json" | Out-Null

$skeletonProof = Read-JsonFile $OperationSkeletonProofPath
if ($null -ne $skeletonProof) {
  $proofStatus = Get-PropertyValue -Object $skeletonProof -Name "status"
  if ("$proofStatus" -ne "PASS") {
    Add-Failure "PHASE83_PROOF_STATUS_NOT_PASS=$proofStatus"
  }
}

$quarantineBatch = Read-JsonFile $QuarantineBatchPath
if ($null -ne $quarantineBatch) {
  $selected = As-Array (Get-PropertyValue -Object $quarantineBatch -Name "selected_material_ids")
  if (@($selected).Count -ne 2) {
    Add-Failure "QUARANTINE_BATCH_SELECTED_COUNT=$(@($selected).Count)"
  }
  foreach ($materialId in @("mat_json_schema_ajv_001", "mat_python_jsonschema_001")) {
    if ($selected -notcontains $materialId) {
      Add-Failure "QUARANTINE_BATCH_SELECTED_MISSING=$materialId"
    }
  }
}

foreach ($cardPath in $QuarantineCardPaths) {
  Read-JsonFile $cardPath | Out-Null
}

$operationRegistry = Read-JsonFile $RegistryPath
if ($null -ne $operationRegistry) {
  $registryStatus = "$(Get-PropertyValue -Object $operationRegistry -Name "status")"
  if ($Stage -eq "Seed" -and $registryStatus -notin @("SKELETON_READY", "CONTRACTS_REGISTERED")) {
    Add-Failure "SEED_OPERATION_REGISTRY_STATUS_INVALID=$registryStatus"
  }
  $operations = Get-OperationSummaries -OperationRegistry $operationRegistry
  $trustedOperationCount = Get-TrustedOperationCount -Operations $operations
  if ($trustedOperationCount -ne 0) {
    Add-Failure "TRUSTED_OPERATION_COUNT=$trustedOperationCount"
  }
  if ([bool](Get-PropertyValue -Object $operationRegistry -Name "execution_performed")) {
    Add-Failure "OPERATION_EXECUTION_PERFORMED_TRUE"
  }
}

foreach ($contractPath in $ContractPaths) {
  if (Test-Path -LiteralPath (Join-RepoPath $contractPath)) {
    $contract = Read-JsonFile $contractPath
    if ($null -ne $contract) {
      Assert-ContractReady -Contract $contract -Path $contractPath
    }
  } elseif ($Stage -eq "Completed") {
    Add-Failure "MISSING_OPERATION_CONTRACT=$contractPath"
  }
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$taskEntry = Find-TaskEntry -Queue $queue
if ($null -eq $taskEntry) {
  Add-Failure "TASK_NOT_FOUND=$TaskId"
}

$packRegistry = Read-JsonFile "packs/registry.json"
$matchingPacks = Get-MatchingRegistryPacks -Registry $packRegistry
if (@($matchingPacks).Count -ne 1) {
  Add-Failure "REGISTRY_MATCH_COUNT=$(@($matchingPacks).Count)"
} else {
  $packId = Get-PropertyValue -Object $matchingPacks[0] -Name "pack_id"
  if ("$packId" -ne $PackId) {
    Add-Failure "REGISTRY_PACK_ID_MISMATCH=$packId"
  }
}

if ($Stage -eq "Seed") {
  $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
  if ("$activeTaskId" -ne $TaskId) {
    Add-Failure "SEED_ACTIVE_TASK_MISMATCH=$activeTaskId"
  }
  if ($null -ne $taskEntry) {
    $status = Get-PropertyValue -Object $taskEntry -Name "status"
    if ("$status" -notin @("PENDING", "READY", "ACTIVE")) {
      Add-Failure "SEED_TASK_STATUS_INVALID=$status"
    }
  }
}

if ($Stage -eq "Completed") {
  $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
  if ("$activeTaskId" -ne "NONE") {
    Add-Failure "ACTIVE_TASK_NOT_CLOSED=$activeTaskId"
  }
  if ($null -ne $taskEntry) {
    $status = Get-PropertyValue -Object $taskEntry -Name "status"
    if ("$status" -ne "COMPLETED") {
      Add-Failure "TASK_STATUS_NOT_COMPLETED=$status"
    }
  }

  if ($null -ne $operationRegistry) {
    $registryStatus = Get-PropertyValue -Object $operationRegistry -Name "status"
    if ("$registryStatus" -ne "CONTRACTS_REGISTERED") {
      Add-Failure "OPERATION_REGISTRY_STATUS=$registryStatus"
    }
    $operations = Get-OperationSummaries -OperationRegistry $operationRegistry
    if (@($operations).Count -ne 2) {
      Add-Failure "OPERATION_REGISTRY_OPERATION_COUNT=$(@($operations).Count)"
    }
    foreach ($operationId in $ExpectedOperationIds) {
      $summary = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "operation_id")" -eq $operationId })
      if (@($summary).Count -ne 1) {
        Add-Failure "OPERATION_SUMMARY_MATCH_COUNT_$operationId=$(@($summary).Count)"
      } else {
        $summaryStatus = Get-PropertyValue -Object $summary[0] -Name "status"
        if ("$summaryStatus" -ne "CONTRACT_READY") {
          Add-Failure "OPERATION_SUMMARY_STATUS_NOT_READY=$operationId"
        }
      }
    }
  }

  $report = Read-JsonFile $ReportPath
  if ($null -ne $report) {
    $reportStatus = Get-PropertyValue -Object $report -Name "status"
    if ("$reportStatus" -ne "PASS") {
      Add-Failure "REPORT_STATUS_NOT_PASS=$reportStatus"
    }
    if ([bool](Get-PropertyValue -Object $report -Name "execution_performed")) {
      Add-Failure "REPORT_EXECUTION_PERFORMED_TRUE"
    }
    if ([bool](Get-PropertyValue -Object $report -Name "install_performed")) {
      Add-Failure "REPORT_INSTALL_PERFORMED_TRUE"
    }
    if ([bool](Get-PropertyValue -Object $report -Name "external_fetch_performed")) {
      Add-Failure "REPORT_EXTERNAL_FETCH_PERFORMED_TRUE"
    }
  }

  $proof = Read-JsonFile $ProofPath
  if ($null -ne $proof) {
    $proofStatus = Get-PropertyValue -Object $proof -Name "status"
    if ("$proofStatus" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS=$proofStatus"
    }
    $nextAllowed = Get-PropertyValue -Object $proof -Name "next_allowed_step"
    if ("$nextAllowed" -ne $NextAllowedStep) {
      Add-Failure "PROOF_NEXT_ALLOWED_STEP_MISMATCH=$nextAllowed"
    }
    $forbidden = Get-PropertyValue -Object $proof -Name "forbidden_actions_confirmed"
    foreach ($field in @("no_external_tools_installed", "no_external_repos_fetched", "no_tool_execution", "no_smoke_tests_run", "no_wrapper_implementation_created", "no_materials_marked_trusted", "no_trusted_operations_created", "no_catalog_mutation", "no_policy_mutation", "no_quarantine_batch_mutation", "no_quarantine_card_mutation", "no_external_agent_created", "no_phase78_files_modified", "no_phase79_files_modified", "no_phase80_files_modified", "no_phase81_files_modified", "no_phase82_files_modified", "no_phase83_files_modified")) {
      if (-not [bool](Get-PropertyValue -Object $forbidden -Name $field)) {
        Add-Failure "FORBIDDEN_ACTION_CONFIRMATION_FALSE=$field"
      }
    }
  }
}

if (@($script:Failures).Count -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE84_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
