[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$PackId = "PHASE86_OPERATION_RUNTIME_SKELETON_V1"
$TaskId = "TASK_OPERATION_RUNTIME_SKELETON_V1_001"
$OperationId = "validate_json_schema_with_python_jsonschema"
$MaterialId = "mat_python_jsonschema_001"
$RequestPath = "operations/runtime/requests/FIRST_OPERATION_RUNTIME_DRY_RUN_REQUEST.json"
$OperationRequestSchemaPath = "contracts/operations/operation_request.schema.json"
$RuntimeReportSchemaPath = "contracts/operations/operation_runtime_report.schema.json"
$OperationRegistryPath = "operations/registry.json"
$OperationContractPath = "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json"
$SmokeReportPath = "reports/operations/FIRST_SMOKE_INSTALL_TRIAL_REPORT.json"
$SmokeProofPath = "proofs/operations/FIRST_SMOKE_INSTALL_TRIAL_V1.json"
$ReportPath = "reports/operations/OPERATION_RUNTIME_SKELETON_REPORT.json"
$ProofPath = "proofs/operations/OPERATION_RUNTIME_SKELETON_V1.json"
$NextAllowedStep = "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"

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
    "operations/registry.json",
    "operations/contracts/validate_json_schema_with_ajv.contract.json",
    "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json",
    "reports/operations/FIRST_SMOKE_INSTALL_TRIAL_REPORT.json",
    "proofs/operations/FIRST_SMOKE_INSTALL_TRIAL_V1.json",
    "materials/MATERIAL_CATALOG.json",
    "materials/MATERIAL_POLICY.json",
    "materials/quarantine",
    "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1",
    "packs/PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1",
    "packs/PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1",
    "packs/PHASE81_MATERIAL_ADMISSION_POLICY_V1",
    "packs/PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1",
    "packs/PHASE83_OPERATION_CONTRACT_SKELETON_V1",
    "packs/PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1",
    "packs/PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1",
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

function Assert-SelectedOperationContract {
  param([object]$Contract)

  if ($null -eq $Contract) {
    return
  }

  if ("$(Get-PropertyValue -Object $Contract -Name "operation_id")" -ne $OperationId) {
    Add-Failure "CONTRACT_OPERATION_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $Contract -Name "related_material_id")" -ne $MaterialId) {
    Add-Failure "CONTRACT_RELATED_MATERIAL_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $Contract -Name "status")" -ne "CONTRACT_READY") {
    Add-Failure "CONTRACT_STATUS_NOT_READY"
  }
  if ("$(Get-PropertyValue -Object $Contract -Name "status")" -eq "TRUSTED_OPERATION") {
    Add-Failure "CONTRACT_TRUSTED_OPERATION_FORBIDDEN"
  }
}

function Assert-OperationNotTrusted {
  $operationRegistry = Read-JsonFile $OperationRegistryPath
  if ($null -eq $operationRegistry) {
    return
  }

  $operations = As-Array (Get-PropertyValue -Object $operationRegistry -Name "operations")
  $matches = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "operation_id")" -eq $OperationId })
  if (@($matches).Count -ne 1) {
    Add-Failure "OPERATION_REGISTRY_MATCH_COUNT_$OperationId=$(@($matches).Count)"
    return
  }
  if ("$(Get-PropertyValue -Object $matches[0] -Name "status")" -eq "TRUSTED_OPERATION") {
    Add-Failure "OPERATION_STATUS_TRUSTED_FORBIDDEN"
  }
}

function Assert-MaterialNotTrusted {
  $catalog = Read-JsonFile "materials/MATERIAL_CATALOG.json"
  if ($null -eq $catalog) {
    return
  }

  $entries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
  $matches = @($entries | Where-Object { "$(Get-PropertyValue -Object $_ -Name "material_id")" -eq $MaterialId })
  if (@($matches).Count -ne 1) {
    Add-Failure "MATERIAL_CATALOG_MATCH_COUNT_$MaterialId=$(@($matches).Count)"
    return
  }

  $entry = $matches[0]
  foreach ($field in @("status", "trust_status")) {
    if ("$(Get-PropertyValue -Object $entry -Name $field)" -eq "TRUSTED") {
      Add-Failure "MATERIAL_TRUSTED_FORBIDDEN=$field"
    }
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
  "modules/operations/invoke_operation_runtime.ps1",
  "packs/PHASE86_OPERATION_RUNTIME_SKELETON_V1/APPLY.ps1",
  "packs/PHASE86_OPERATION_RUNTIME_SKELETON_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass -Path $script
}

Read-JsonFile $OperationRequestSchemaPath | Out-Null
Read-JsonFile $RuntimeReportSchemaPath | Out-Null
$request = Read-JsonFile $RequestPath
if ($null -ne $request) {
  if ("$(Get-PropertyValue -Object $request -Name "request_id")" -ne "FIRST_OPERATION_RUNTIME_DRY_RUN_REQUEST") {
    Add-Failure "REQUEST_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $request -Name "operation_id")" -ne $OperationId) {
    Add-Failure "REQUEST_OPERATION_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $request -Name "requested_mode")" -ne "DRY_RUN_PLAN_ONLY") {
    Add-Failure "REQUEST_MODE_NOT_DRY_RUN"
  }
}

if (-not (Test-Path -LiteralPath (Join-RepoPath "operations/runtime/README.md"))) {
  Add-Failure "MISSING_RUNTIME_README"
}

$contract = Read-JsonFile $OperationContractPath
Assert-SelectedOperationContract -Contract $contract
Assert-OperationNotTrusted
Assert-MaterialNotTrusted

$smokeProof = Read-JsonFile $SmokeProofPath
if ($null -ne $smokeProof) {
  $proofStatus = Get-PropertyValue -Object $smokeProof -Name "status"
  if ("$proofStatus" -ne "PASS") {
    Add-Failure "PHASE85_PROOF_STATUS_NOT_PASS=$proofStatus"
  }
}

Read-JsonFile $SmokeReportPath | Out-Null
Read-JsonFile "packs/PHASE86_OPERATION_RUNTIME_SKELETON_V1/PACK.json" | Out-Null
Read-JsonFile "tasks/TASK_OPERATION_RUNTIME_SKELETON_V1_001.json" | Out-Null

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
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

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

  if ($null -ne $report) {
    if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
      Add-Failure "REPORT_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $report -Name "runtime_mode")" -ne "DRY_RUN_PLAN_ONLY") {
      Add-Failure "REPORT_RUNTIME_MODE_MISMATCH"
    }
    if (-not [bool](Get-PropertyValue -Object $report -Name "dry_run_plan_created")) {
      Add-Failure "REPORT_DRY_RUN_PLAN_CREATED_FALSE"
    }
    foreach ($field in @("execution_performed", "install_performed", "external_fetch_performed", "operation_marked_trusted", "material_marked_trusted")) {
      if ([bool](Get-PropertyValue -Object $report -Name $field)) {
        Add-Failure "REPORT_FIELD_TRUE=$field"
      }
    }
    if (-not [bool](Get-PropertyValue -Object $report -Name "protected_state_unchanged")) {
      Add-Failure "REPORT_PROTECTED_STATE_UNCHANGED_FALSE"
    }
  }

  if ($null -ne $proof) {
    if ("$(Get-PropertyValue -Object $proof -Name "status")" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS"
    }
    $nextAllowed = Get-PropertyValue -Object $proof -Name "next_allowed_step"
    if ("$nextAllowed" -ne $NextAllowedStep) {
      Add-Failure "PROOF_NEXT_ALLOWED_STEP_MISMATCH=$nextAllowed"
    }
    $forbidden = Get-PropertyValue -Object $proof -Name "forbidden_actions_confirmed"
    foreach ($field in @("no_tool_execution", "no_install_performed", "no_external_fetch_performed", "no_venv_created", "no_production_wrapper_created", "no_materials_marked_trusted", "no_trusted_operations_created", "no_catalog_mutation", "no_policy_mutation", "no_quarantine_card_mutation", "no_operation_contract_mutation", "no_operation_registry_mutation", "no_external_agent_created", "no_phase78_files_modified", "no_phase79_files_modified", "no_phase80_files_modified", "no_phase81_files_modified", "no_phase82_files_modified", "no_phase83_files_modified", "no_phase84_files_modified", "no_phase85_files_modified")) {
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
  throw "PHASE86_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
