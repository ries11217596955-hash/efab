param(
  [string]$ManifestPath = 'operations/autonomous_inner_motor/innate_reflex_kernel_v1.json',
  [string]$BodyOrganKnowledgePath = 'operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json',
  [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

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

function Read-JsonRequired([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "JSON_REQUIRED_MISSING:$Path"
  }

  try {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    throw "JSON_PARSE_FAILED:${Path}:$($_.Exception.Message)"
  }
}

function Convert-PropertiesToOrdered($Value) {
  $item = [ordered]@{}
  foreach ($prop in $Value.PSObject.Properties) {
    $item[$prop.Name] = $prop.Value
  }
  return $item
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

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) {
    throw $Message
  }
}

function Assert-FalseValue($Value, [string]$Message) {
  if ($null -eq $Value -or [bool]$Value -ne $false) {
    throw $Message
  }
}

function Assert-RequiredFields($Reflex, [string[]]$Fields) {
  foreach ($field in $Fields) {
    Assert-True ($Reflex.Contains($field)) "REFLEX_FIELD_MISSING:$($Reflex['reflex_id']):$field"
  }
}

$manifest = Read-JsonRequired $ManifestPath
$bodyOrgan = Read-JsonRequired $BodyOrganKnowledgePath

Assert-True ([string]$manifest.kernel_id -eq 'INNATE_REFLEX_KERNEL_V1') "KERNEL_ID_MISMATCH:$($manifest.kernel_id)"
Assert-True ([string]$bodyOrgan.organ_id -eq 'BODY_SELF_INSPECTION_CIRCUIT_V1') "BODY_ORGAN_ID_MISMATCH:$($bodyOrgan.organ_id)"
Assert-True ([string]$bodyOrgan.status -eq 'KNOWN_ORGAN_AVAILABLE_NOT_WIRED') "BODY_ORGAN_STATUS_MISMATCH:$($bodyOrgan.status)"

$sourceReflexes = @($manifest.reflexes)
Assert-True (@($sourceReflexes).Count -ge $RequiredReflexIds.Count) "REFLEX_COUNT_TOO_SMALL:$(@($sourceReflexes).Count)"

$reflexById = @{}
$runtimeReflexes = @()
$bodyAuditReflex = $null

foreach ($reflex in $sourceReflexes) {
  $item = Convert-PropertiesToOrdered $reflex
  $reflexId = [string]$item['reflex_id']
  Assert-True (-not [string]::IsNullOrWhiteSpace($reflexId)) 'REFLEX_ID_MISSING'
  Assert-True (-not $reflexById.ContainsKey($reflexId)) "DUPLICATE_REFLEX_ID:$reflexId"

  Assert-RequiredFields $item @(
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

  Assert-True ([bool]$item['built_in'] -eq $true) "REFLEX_NOT_BUILT_IN:$reflexId"

  if ($reflexId -eq 'body_audit_reflex') {
    Assert-True ([string]$item['status'] -eq 'AVAILABLE_NOT_WIRED') "BODY_AUDIT_STATUS_MISMATCH:$($item['status'])"
    Assert-FalseValue $item['callable'] "BODY_AUDIT_CALLABLE_NOT_FALSE"
    Assert-True ([string]$item['organ_id'] -eq 'BODY_SELF_INSPECTION_CIRCUIT_V1') "BODY_AUDIT_ORGAN_MISMATCH:$($item['organ_id'])"
    Assert-True ([string]$item['organ_status'] -eq 'KNOWN_ORGAN_AVAILABLE_NOT_WIRED') "BODY_AUDIT_ORGAN_STATUS_MISMATCH:$($item['organ_status'])"
    Assert-True ([string]$item['entrypoint'] -eq [string]$bodyOrgan.invocation_entrypoint) "BODY_AUDIT_ENTRYPOINT_MISMATCH:$($item['entrypoint'])"
    Assert-True ([bool]$item['can_hear_body'] -eq $true) 'BODY_AUDIT_CAN_HEAR_BODY_NOT_TRUE'
    Assert-FalseValue $item['body_inspection_invoked'] 'BODY_AUDIT_BODY_INSPECTION_INVOKED_NOT_FALSE'
    Assert-FalseValue $item['invoked_this_cycle'] 'BODY_AUDIT_INVOKED_THIS_CYCLE_NOT_FALSE'

    $item['built_in'] = $true
    $item['callable'] = $false
    $item['status'] = 'AVAILABLE_NOT_WIRED'
    $item['organ_status'] = [string]$bodyOrgan.status
    $item['can_hear_body'] = $true
    $item['body_inspection_invoked'] = $false
    $item['invoked_this_cycle'] = $false
    $item['boundary'] = [ordered]@{
      observe_only_future_use = $true
      body_inspection_invoked = $false
      active_memory_mutated = $false
      live_process_touched = $false
      repair_executed = $false
      legacy_launch_used = $false
      runner_integrated = $false
    }
    $bodyAuditReflex = $item
  } else {
    Assert-True ($item.Contains('planned_entrypoint') -or $item.Contains('entrypoint')) "REFLEX_ENTRYPOINT_FIELD_MISSING:$reflexId"
    Assert-FalseValue $item['callable'] "RESERVED_REFLEX_CALLABLE_NOT_FALSE:$reflexId"
    Assert-True ([string]$item['status'] -eq 'RESERVED_NOT_BUILT') "RESERVED_REFLEX_STATUS_WRONG:${reflexId}:$($item['status'])"
    Assert-True ([string]$item['maturity'] -eq 'RESERVED_SLOT') "RESERVED_REFLEX_MATURITY_WRONG:${reflexId}:$($item['maturity'])"

    $item['built_in'] = $true
    $item['callable'] = $false
    $item['status'] = 'RESERVED_NOT_BUILT'
    $item['maturity'] = 'RESERVED_SLOT'
  }

  $reflexById[$reflexId] = $item
  $runtimeReflexes += $item
}

foreach ($requiredId in $RequiredReflexIds) {
  Assert-True ($reflexById.ContainsKey($requiredId)) "REQUIRED_REFLEX_MISSING:$requiredId"
}

Assert-True ($null -ne $bodyAuditReflex) 'BODY_AUDIT_REFLEX_MISSING'

$availableNotWired = @($runtimeReflexes | Where-Object { [string]$_['status'] -eq 'AVAILABLE_NOT_WIRED' })
$reserved = @($runtimeReflexes | Where-Object { [string]$_['status'] -eq 'RESERVED_NOT_BUILT' })
$callable = @($runtimeReflexes | Where-Object { [bool]$_['callable'] -eq $true })

$boundary = [ordered]@{}
foreach ($flag in $BoundaryFalseFlags) {
  $boundary[$flag] = $false
}
$boundary['direct_active_memory_write'] = $false
$boundary['canonical_launcher_changed'] = $false

$kernel = [ordered]@{
  schema = 'innate_reflex_kernel_runtime_v1'
  status = 'PASS_INNATE_REFLEX_KERNEL_V1_BUILT'
  kernel_id = 'INNATE_REFLEX_KERNEL_V1'
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
  source_manifest_path = $ManifestPath
  body_organ_knowledge_path = $BodyOrganKnowledgePath
  body_organ_status = [string]$bodyOrgan.status
  body_organ_canonical_life_status = [string]$bodyOrgan.canonical_life_status
  reflex_count = @($runtimeReflexes).Count
  required_reflex_count = $RequiredReflexIds.Count
  available_not_wired_count = @($availableNotWired).Count
  reserved_count = @($reserved).Count
  callable_count = @($callable).Count
  available_reflexes = @()
  available_not_wired_reflexes = @($availableNotWired | ForEach-Object { [string]$_['reflex_id'] })
  reserved_reflexes = @($reserved | ForEach-Object { [string]$_['reflex_id'] })
  body_audit_reflex = $bodyAuditReflex
  reflexes = @($runtimeReflexes)
  boundary = $boundary
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  Write-CleanJson -Path $OutputPath -Obj $kernel -Depth 100
}

$kernel
