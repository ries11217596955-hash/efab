$ErrorActionPreference = 'Stop'

$ManifestPath = 'operations/autonomous_inner_motor/innate_reflex_kernel_v1.json'
$BuilderPath = 'operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1'
$BodyOrganKnowledgePath = 'operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json'
$RunnerPath = 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$CanonicalLauncherPath = 'operations/autonomous_inner_motor/start_agent_life_v1.ps1'
$BodyInspectionEntrypoint = 'operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1'
$TempOutputPath = '.runtime/self_development/innate_reflex_kernel_v1_test/innate_reflex_kernel.json'
$ProofPath = 'tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json'

$RequiredReflexIds = @(
  'body_audit_reflex',
  'organ_audit_reflex',
  'full_body_map_audit_reflex',
  'repo_reality_reflex',
  'process_scan_reflex',
  'runtime_pressure_reflex',
  'preflight_reflex',
  'validator_run_reflex',
  'proof_pack_reflex',
  'rollback_reflex',
  'quarantine_reflex',
  'stop_or_freeze_reflex',
  'memory_queue_reflex',
  'active_memory_read_reflex',
  'memory_digest_reflex',
  'handoff_write_reflex',
  'self_notebook_update_reflex',
  'directory_create_reflex',
  'file_normalize_reflex',
  'archive_backup_reflex',
  'artifact_convert_reflex',
  'codex_consult_reflex',
  'codex_task_authoring_reflex',
  'web_source_search_reflex',
  'source_ingestion_reflex'
)

$BoundaryFalseFlags = @(
  'body_inspection_invoked',
  'active_memory_mutated',
  'live_process_touched',
  'repair_executed',
  'legacy_launch_used',
  'runner_integrated'
)

$errors = @()

function Add-Err([string]$Message) {
  $script:errors += $Message
}

function Read-JsonForValidation([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Add-Err "missing_json:$Path"
    return $null
  }

  try {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    Add-Err "json_parse_failed:${Path}:$($_.Exception.Message)"
    return $null
  }
}

function Write-CleanJson([string]$Path, $Obj, [int]$Depth = 100) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  $json = ($Obj | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $full = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($full, $json.TrimEnd() + "`n", $utf8NoBom)
}

function Has-Property($Obj, [string]$Name) {
  return $null -ne $Obj -and $null -ne ($Obj.PSObject.Properties[$Name])
}

function Assert-Equal($Actual, $Expected, [string]$Name) {
  if ($Actual -ne $Expected) {
    Add-Err "$Name expected=[$Expected] actual=[$Actual]"
  }
}

function Assert-TrueValue($Actual, [string]$Name) {
  if ([bool]$Actual -ne $true) {
    Add-Err "$Name expected=true actual=[$Actual]"
  }
}

function Assert-FalseValue($Actual, [string]$Name) {
  if ($null -eq $Actual -or [bool]$Actual -ne $false) {
    Add-Err "$Name expected=false actual=[$Actual]"
  }
}

function Check-GitPathUnmodified([string]$Path, [string]$Name) {
  $status = & git status --short --untracked-files=all -- $Path 2>&1
  if ($LASTEXITCODE -ne 0) {
    Add-Err "$Name git_status_failed:$status"
    return
  }
  if (-not [string]::IsNullOrWhiteSpace(($status | Out-String).Trim())) {
    Add-Err "$Name modified_or_untracked:$($status -join ' ')"
  }
}

function Check-CommonReflexFields($Reflex, [string]$ReflexId) {
  $fields = @(
    'reflex_id',
    'built_in',
    'callable',
    'status',
    'input_contract',
    'output_contract',
    'allowed_surfaces',
    'forbidden_surfaces',
    'validator',
    'proof_expectation',
    'boundary',
    'maturity'
  )

  foreach ($field in $fields) {
    if (-not (Has-Property $Reflex $field)) {
      Add-Err "reflex_field_missing:${ReflexId}:$field"
    }
  }

  if (-not (Has-Property $Reflex 'entrypoint') -and -not (Has-Property $Reflex 'planned_entrypoint')) {
    Add-Err "reflex_entrypoint_field_missing:$ReflexId"
  }
}

$manifest = Read-JsonForValidation $ManifestPath
$bodyOrgan = Read-JsonForValidation $BodyOrganKnowledgePath

if (-not (Test-Path -LiteralPath $BuilderPath -PathType Leaf)) {
  Add-Err "missing_builder:$BuilderPath"
}

if ($null -ne $manifest) {
  Assert-Equal ([string]$manifest.kernel_id) 'INNATE_REFLEX_KERNEL_V1' 'manifest.kernel_id'
  $reflexes = @($manifest.reflexes)
  Assert-Equal @($reflexes).Count 25 'manifest.reflex_count'

  $byId = @{}
  foreach ($reflex in $reflexes) {
    $reflexId = [string]$reflex.reflex_id
    if ([string]::IsNullOrWhiteSpace($reflexId)) {
      Add-Err 'reflex_id_missing'
      continue
    }
    if ($byId.ContainsKey($reflexId)) {
      Add-Err "duplicate_reflex_id:$reflexId"
      continue
    }

    $byId[$reflexId] = $reflex
    Check-CommonReflexFields $reflex $reflexId
    Assert-TrueValue $reflex.built_in "$reflexId.built_in"

    if ($reflexId -ne 'body_audit_reflex') {
      Assert-FalseValue $reflex.callable "$reflexId.callable"
      Assert-Equal ([string]$reflex.status) 'RESERVED_NOT_BUILT' "$reflexId.status"
      Assert-Equal ([string]$reflex.maturity) 'RESERVED_SLOT' "$reflexId.maturity"
    }
  }

  foreach ($requiredId in $RequiredReflexIds) {
    if (-not $byId.ContainsKey($requiredId)) {
      Add-Err "required_reflex_missing:$requiredId"
    }
  }

  if ($byId.ContainsKey('body_audit_reflex')) {
    $body = $byId['body_audit_reflex']
    Assert-TrueValue $body.built_in 'body_audit_reflex.built_in'
    Assert-FalseValue $body.callable 'body_audit_reflex.callable'
    Assert-Equal ([string]$body.status) 'AVAILABLE_NOT_WIRED' 'body_audit_reflex.status'
    Assert-Equal ([string]$body.organ_id) 'BODY_SELF_INSPECTION_CIRCUIT_V1' 'body_audit_reflex.organ_id'
    Assert-Equal ([string]$body.organ_status) 'KNOWN_ORGAN_AVAILABLE_NOT_WIRED' 'body_audit_reflex.organ_status'
    Assert-Equal ([string]$body.entrypoint) $BodyInspectionEntrypoint 'body_audit_reflex.entrypoint'
    Assert-TrueValue $body.can_hear_body 'body_audit_reflex.can_hear_body'
    Assert-FalseValue $body.body_inspection_invoked 'body_audit_reflex.body_inspection_invoked'
    Assert-FalseValue $body.invoked_this_cycle 'body_audit_reflex.invoked_this_cycle'
  }
}

if ($null -ne $bodyOrgan) {
  Assert-Equal ([string]$bodyOrgan.organ_id) 'BODY_SELF_INSPECTION_CIRCUIT_V1' 'body_organ.organ_id'
  Assert-Equal ([string]$bodyOrgan.status) 'KNOWN_ORGAN_AVAILABLE_NOT_WIRED' 'body_organ.status'
}

$runtimeKernel = $null
if (Test-Path -LiteralPath $BuilderPath -PathType Leaf) {
  try {
    $runtimeKernel = & $BuilderPath -OutputPath $TempOutputPath
    if (-not (Test-Path -LiteralPath $TempOutputPath -PathType Leaf)) {
      Add-Err "temp_output_missing:$TempOutputPath"
    }
  } catch {
    Add-Err "builder_execution_failed:$($_.Exception.Message)"
  }
}

$runtimeOutput = Read-JsonForValidation $TempOutputPath
if ($null -ne $runtimeOutput) {
  Assert-Equal ([string]$runtimeOutput.status) 'PASS_INNATE_REFLEX_KERNEL_V1_BUILT' 'runtime.status'
  Assert-Equal ([int]$runtimeOutput.reflex_count) 25 'runtime.reflex_count'
  Assert-Equal ([int]$runtimeOutput.available_not_wired_count) 1 'runtime.available_not_wired_count'
  Assert-Equal ([int]$runtimeOutput.reserved_count) 24 'runtime.reserved_count'
  Assert-Equal ([int]$runtimeOutput.callable_count) 0 'runtime.callable_count'

  foreach ($flag in $BoundaryFalseFlags) {
    if (-not (Has-Property $runtimeOutput.boundary $flag)) {
      Add-Err "runtime.boundary_missing:$flag"
    } else {
      Assert-FalseValue $runtimeOutput.boundary.$flag "runtime.boundary.$flag"
    }
  }

  Assert-FalseValue $runtimeOutput.body_audit_reflex.body_inspection_invoked 'runtime.body_audit_reflex.body_inspection_invoked'
  Assert-FalseValue $runtimeOutput.body_audit_reflex.invoked_this_cycle 'runtime.body_audit_reflex.invoked_this_cycle'
  Assert-FalseValue $runtimeOutput.body_audit_reflex.callable 'runtime.body_audit_reflex.callable'
}

if ($null -eq $runtimeKernel) {
  Add-Err 'runtime_safe_object_not_returned'
}

Check-GitPathUnmodified $RunnerPath 'runner'
Check-GitPathUnmodified $CanonicalLauncherPath 'canonical_launcher'
Check-GitPathUnmodified $BodyInspectionEntrypoint 'body_inspection_entrypoint'
Check-GitPathUnmodified '.runtime/active_compact_semantic_memory_v1' 'active_memory'

$status = if ($errors.Count -eq 0) { 'PASS_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A' } else { 'FAIL_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A' }

$proof = [ordered]@{
  schema = 'callable_innate_reflex_kernel_v1_slice_a_proof'
  status = $status
  checked_at = (Get-Date).ToUniversalTime().ToString('o')
  manifest_path = $ManifestPath
  builder_path = $BuilderPath
  body_organ_knowledge_path = $BodyOrganKnowledgePath
  runtime_output_path = $TempOutputPath
  required_reflex_count = $RequiredReflexIds.Count
  manifest_reflex_count = if ($null -ne $manifest) { @($manifest.reflexes).Count } else { 0 }
  runtime_reflex_count = if ($null -ne $runtimeOutput) { [int]$runtimeOutput.reflex_count } else { 0 }
  available_not_wired_count = if ($null -ne $runtimeOutput) { [int]$runtimeOutput.available_not_wired_count } else { 0 }
  reserved_count = if ($null -ne $runtimeOutput) { [int]$runtimeOutput.reserved_count } else { 0 }
  callable_count = if ($null -ne $runtimeOutput) { [int]$runtimeOutput.callable_count } else { 0 }
  boundary = [ordered]@{
    runner_modified = $false
    canonical_launcher_modified = $false
    body_inspection_invoked = $false
    active_memory_mutated = $false
    legacy_launch_used = $false
    runner_integrated = $false
    validator_only_temp_output = $TempOutputPath
  }
  errors = @($errors)
}

Write-CleanJson -Path $ProofPath -Obj $proof -Depth 100

Write-Host "STATUS=$status"
Write-Host "PROOF=$ProofPath"

if ($errors.Count -gt 0) {
  foreach ($err in $errors) {
    Write-Host "ERROR=$err"
  }
  exit 1
}
