[CmdletBinding()]
param(
  [string]$RequestPath = "operations/runtime/requests/FIRST_OPERATION_RUNTIME_DRY_RUN_REQUEST.json",
  [string]$OperationRegistryPath = "operations/registry.json",
  [string]$ContractsRoot = "operations/contracts",
  [string]$SmokeProofPath = "proofs/operations/FIRST_SMOKE_INSTALL_TRIAL_V1.json",
  [string]$OutputReportPath = "reports/operations/OPERATION_RUNTIME_SKELETON_REPORT.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE_86"
$CapabilityId = "operation_runtime_skeleton_v1"
$RequiredMode = "DRY_RUN_PLAN_ONLY"
$RequiredContractStatus = "CONTRACT_READY"
$CompatibleSmokeNextSteps = @(
  "PHASE86_OPERATION_RUNTIME_SKELETON_V1",
  "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"
)
$NextAllowedStep = "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"
$ProtectedStatePaths = @(
  "materials/MATERIAL_CATALOG.json",
  "materials/MATERIAL_POLICY.json",
  "materials/quarantine/QUARANTINE_BATCH_001.json",
  "materials/quarantine/mat_json_schema_ajv_001/MATERIAL_CARD.json",
  "materials/quarantine/mat_python_jsonschema_001/MATERIAL_CARD.json",
  "operations/registry.json",
  "operations/contracts/validate_json_schema_with_ajv.contract.json",
  "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json",
  "reports/operations/FIRST_SMOKE_INSTALL_TRIAL_REPORT.json",
  "proofs/operations/FIRST_SMOKE_INSTALL_TRIAL_V1.json"
)

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "MISSING_JSON=$Path"
  }

  return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
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

function Get-FileSha256 {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    return ""
  }
  return (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
}

function Get-ProtectedStateHashes {
  $hashes = [ordered]@{}
  foreach ($path in $ProtectedStatePaths) {
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

function Resolve-ContractPath {
  param(
    [object]$Registry,
    [string]$OperationId
  )

  $operations = As-Array (Get-PropertyValue -Object $Registry -Name "operations")
  $matches = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "operation_id")" -eq $OperationId })
  if (@($matches).Count -ne 1) {
    throw "OPERATION_REGISTRY_MATCH_COUNT_$OperationId=$(@($matches).Count)"
  }

  $operation = $matches[0]
  if ("$(Get-PropertyValue -Object $operation -Name "status")" -eq "TRUSTED_OPERATION") {
    throw "TRUSTED_OPERATION_FORBIDDEN=$OperationId"
  }

  $contractPath = "$(Get-PropertyValue -Object $operation -Name "contract_path")"
  if ([string]::IsNullOrWhiteSpace($contractPath)) {
    $contractPath = (Join-Path $ContractsRoot "$OperationId.contract.json").Replace("\", "/")
  }

  return [pscustomobject]@{
    operation = $operation
    contract_path = $contractPath
  }
}

function New-InitialReport {
  param(
    [object]$Request,
    [object]$ProtectedHashesBefore
  )

  return [ordered]@{
    report_id = "OPERATION_RUNTIME_SKELETON_REPORT"
    phase = $Phase
    capability_id = $CapabilityId
    status = "FAIL"
    generated_at = Get-UtcStamp
    request_path = $RequestPath
    operation_id = "$(Get-PropertyValue -Object $Request -Name "operation_id")"
    operation_registry_path = $OperationRegistryPath
    operation_contract_path = ""
    operation_contract_status = ""
    smoke_proof_path = $SmokeProofPath
    smoke_proof_status = ""
    runtime_mode = "$(Get-PropertyValue -Object $Request -Name "requested_mode")"
    dry_run_plan_created = $false
    dry_run_plan = [ordered]@{}
    execution_performed = $false
    install_performed = $false
    external_fetch_performed = $false
    trusted_operation_count = 0
    operation_marked_trusted = $false
    material_marked_trusted = $false
    allowed_reads = @()
    allowed_writes = @()
    forbidden_actions = @(As-Array (Get-PropertyValue -Object $Request -Name "forbidden_actions"))
    validation_gates = @()
    protected_state_hashes_before = $ProtectedHashesBefore
    protected_state_hashes_after = [ordered]@{}
    protected_state_unchanged = $false
    next_allowed_step = $NextAllowedStep
    cut_list = @(
      "Do not execute operation tools.",
      "Do not install packages.",
      "Do not create sandboxes or runtime environments.",
      "Do not fetch external repositories.",
      "Do not create production wrappers.",
      "Do not mark operations or materials trusted.",
      "Do not mutate registry, contracts, catalog, policy, quarantine cards, or smoke evidence."
    )
  }
}

Write-Host "OPERATION_RUNTIME_SKELETON_START"

$protectedHashesBefore = Get-ProtectedStateHashes
$request = $null
$report = $null

try {
  foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
    }
  }

  $request = Read-JsonRequired $RequestPath
  $requestId = "$(Get-PropertyValue -Object $request -Name "request_id")"
  $operationId = "$(Get-PropertyValue -Object $request -Name "operation_id")"
  $requestedMode = "$(Get-PropertyValue -Object $request -Name "requested_mode")"
  Write-Host "OPERATION_REQUEST_ID=$requestId"
  Write-Host "OPERATION_ID=$operationId"

  $report = New-InitialReport -Request $request -ProtectedHashesBefore $protectedHashesBefore

  if ($requestId -ne "FIRST_OPERATION_RUNTIME_DRY_RUN_REQUEST") {
    throw "REQUEST_ID_MISMATCH=$requestId"
  }
  if ($requestedMode -ne $RequiredMode) {
    throw "REQUESTED_MODE_NOT_SUPPORTED=$requestedMode"
  }
  if ("$(Get-PropertyValue -Object $request -Name "required_contract_status")" -ne $RequiredContractStatus) {
    throw "REQUEST_REQUIRED_CONTRACT_STATUS_MISMATCH"
  }

  $requiredSmokeProof = "$(Get-PropertyValue -Object $request -Name "required_smoke_proof")"
  if (-not [string]::IsNullOrWhiteSpace($requiredSmokeProof) -and $requiredSmokeProof -ne $SmokeProofPath) {
    throw "REQUEST_SMOKE_PROOF_PATH_MISMATCH=$requiredSmokeProof"
  }

  $registry = Read-JsonRequired $OperationRegistryPath
  $operations = As-Array (Get-PropertyValue -Object $registry -Name "operations")
  $trustedOperationCount = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "TRUSTED_OPERATION" }).Count
  $report["trusted_operation_count"] = $trustedOperationCount
  if ($trustedOperationCount -ne 0) {
    throw "TRUSTED_OPERATION_COUNT=$trustedOperationCount"
  }

  $resolved = Resolve-ContractPath -Registry $registry -OperationId $operationId
  $contractPath = $resolved.contract_path
  $contract = Read-JsonRequired $contractPath
  $contractStatus = "$(Get-PropertyValue -Object $contract -Name "status")"
  $report["operation_contract_path"] = $contractPath
  $report["operation_contract_status"] = $contractStatus
  Write-Host "OPERATION_CONTRACT_STATUS=$contractStatus"
  if ($contractStatus -ne $RequiredContractStatus) {
    throw "OPERATION_CONTRACT_STATUS_NOT_READY=$contractStatus"
  }
  if ("$(Get-PropertyValue -Object $contract -Name "operation_id")" -ne $operationId) {
    throw "OPERATION_CONTRACT_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $contract -Name "status")" -eq "TRUSTED_OPERATION") {
    throw "CONTRACT_TRUSTED_OPERATION_FORBIDDEN"
  }

  $smokeProof = Read-JsonRequired $SmokeProofPath
  $smokeProofStatus = "$(Get-PropertyValue -Object $smokeProof -Name "status")"
  $smokeNextStep = "$(Get-PropertyValue -Object $smokeProof -Name "next_allowed_step")"
  $report["smoke_proof_status"] = $smokeProofStatus
  Write-Host "SMOKE_PROOF_STATUS=$smokeProofStatus"
  if ($smokeProofStatus -ne "PASS") {
    throw "SMOKE_PROOF_STATUS_NOT_PASS=$smokeProofStatus"
  }
  if ($CompatibleSmokeNextSteps -notcontains $smokeNextStep) {
    throw "SMOKE_PROOF_NEXT_STEP_NOT_COMPATIBLE=$smokeNextStep"
  }

  $allowedReads = As-Array (Get-PropertyValue -Object $contract -Name "allowed_reads")
  $allowedWrites = As-Array (Get-PropertyValue -Object $contract -Name "allowed_writes")
  $forbiddenActions = As-Array (Get-PropertyValue -Object $request -Name "forbidden_actions")

  $dryRunPlan = [ordered]@{
    plan_id = "FIRST_OPERATION_RUNTIME_DRY_RUN_PLAN"
    operation_id = $operationId
    runtime_mode = $RequiredMode
    contract_path = $contractPath
    smoke_proof_path = $SmokeProofPath
    input_refs = Get-PropertyValue -Object $request -Name "input_refs"
    output_refs = Get-PropertyValue -Object $request -Name "output_refs"
    sandbox_policy = "$(Get-PropertyValue -Object $request -Name "sandbox_policy")"
    allowed_reads = @($allowedReads)
    allowed_writes = @($allowedWrites)
    forbidden_actions = @($forbiddenActions)
    execution_steps = @(
      "validate_request",
      "validate_operation_registry_entry",
      "validate_operation_contract",
      "validate_smoke_proof",
      "prepare_future_sandbox_execution_plan",
      "write_runtime_report",
      "record_runtime_proof"
    )
    blocked_in_phase86 = @(
      "tool_execution",
      "package_install",
      "environment_creation",
      "external_fetch",
      "production_wrapper_creation",
      "trust_promotion"
    )
  }

  $report["dry_run_plan"] = $dryRunPlan
  $report["dry_run_plan_created"] = $true
  $report["allowed_reads"] = @($allowedReads)
  $report["allowed_writes"] = @($allowedWrites)
  $report["forbidden_actions"] = @($forbiddenActions)
  $report["validation_gates"] = @(
    "request_parse_pass",
    "runtime_mode_dry_run_only",
    "registry_operation_found",
    "operation_not_trusted",
    "contract_ready",
    "smoke_proof_pass",
    "dry_run_plan_created",
    "execution_performed_false",
    "install_performed_false",
    "external_fetch_performed_false"
  )

  Write-Host "RUNTIME_MODE=$RequiredMode"
  Write-Host "DRY_RUN_PLAN_CREATED=TRUE"
  Write-Host "EXECUTION_PERFORMED=FALSE"
  Write-Host "INSTALL_PERFORMED=FALSE"
  Write-Host "EXTERNAL_FETCH_PERFORMED=FALSE"

  $protectedHashesAfter = Get-ProtectedStateHashes
  $report["protected_state_hashes_after"] = $protectedHashesAfter
  $report["protected_state_unchanged"] = Compare-HashMaps -Before $protectedHashesBefore -After $protectedHashesAfter
  if (-not [bool]$report["protected_state_unchanged"]) {
    throw "PROTECTED_STATE_MUTATED"
  }

  $report["status"] = "PASS"
  Write-JsonFile -Path $OutputReportPath -Object $report
  Write-Host "OPERATION_RUNTIME_REPORT_WRITTEN=$OutputReportPath"
  Write-Host "OPERATION_RUNTIME_SKELETON_COMPLETE"

  return [pscustomobject]$report
} catch {
  $failureMessage = $_.Exception.Message
  if ($null -eq $report) {
    if ($null -eq $request) {
      $request = [pscustomobject]@{
        request_id = ""
        operation_id = ""
        requested_mode = ""
        forbidden_actions = @()
      }
    }
    $report = New-InitialReport -Request $request -ProtectedHashesBefore $protectedHashesBefore
  }
  $report["status"] = "FAIL"
  $report["failure"] = $failureMessage
  $protectedHashesAfter = Get-ProtectedStateHashes
  $report["protected_state_hashes_after"] = $protectedHashesAfter
  $report["protected_state_unchanged"] = Compare-HashMaps -Before $protectedHashesBefore -After $protectedHashesAfter
  Write-JsonFile -Path $OutputReportPath -Object $report
  Write-Host "FAIL=$failureMessage"
  Write-Host "OPERATION_RUNTIME_REPORT_WRITTEN=$OutputReportPath"
  throw
}
