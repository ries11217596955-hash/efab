function Read-Phase161B1RouterJsonSafe {
  param([string]$Path)
  try {
    if (-not (Test-Path -LiteralPath $Path)) {
      return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-Phase161B1OwnerInboxRouterState {
  param(
    [string]$SessionRootFull
  )
  $routerRoot = Join-Path $SessionRootFull "owner_inbox_router"
  $recordsRoot = Join-Path $routerRoot "route_records"
  $records = @()
  if (Test-Path -LiteralPath $recordsRoot) {
    foreach ($file in @(Get-ChildItem -LiteralPath $recordsRoot -File -Filter "*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc, Name)) {
      $record = Read-Phase161B1RouterJsonSafe -Path $file.FullName
      if ($null -ne $record) {
        $records += $record
      }
    }
  }
  $last = if ($records.Count -gt 0) { $records[-1] } else { $null }
  $acceptedCurricula = @($records | Where-Object { [string]$_.route_decision -eq "ROUTE_CURRICULUM_PACK" -and [bool]$_.accepted_by_router })
  return [pscustomobject][ordered]@{
    owner_inbox_router_enabled = $true
    last_owner_inbox_message_type = if ($null -ne $last) { [string]$last.message_type } else { "NONE" }
    last_owner_inbox_route_decision = if ($null -ne $last) { [string]$last.route_decision } else { "NONE" }
    last_owner_inbox_quarantine_reason = if ($null -ne $last) { [string]$last.quarantine_reason } else { "NONE" }
    curriculum_pack_routed_count = @($records | Where-Object { [string]$_.route_decision -eq "ROUTE_CURRICULUM_PACK" -and [bool]$_.accepted_by_router }).Count
    owner_task_routed_count = @($records | Where-Object { [string]$_.route_decision -eq "ROUTE_OWNER_TASK" -and [bool]$_.accepted_by_router }).Count
    instruction_routed_count = @($records | Where-Object { [string]$_.route_decision -eq "ROUTE_INSTRUCTION" -and [bool]$_.accepted_by_router }).Count
    control_message_routed_count = @($records | Where-Object { [string]$_.route_decision -in @("ROUTE_CONTROL_STOP", "ROUTE_CONTROL_PAUSE") -and [bool]$_.accepted_by_router }).Count
    unknown_message_quarantine_count = @($records | Where-Object { [string]$_.route_decision -eq "QUARANTINE_UNKNOWN_MESSAGE_TYPE" }).Count
    active_curriculum_id = if ($acceptedCurricula.Count -gt 0) { [string]$acceptedCurricula[-1].curriculum_id } else { "NONE" }
    last_instruction_message_id = if (@($records | Where-Object { [string]$_.route_decision -eq "ROUTE_INSTRUCTION" }).Count -gt 0) { [string]@($records | Where-Object { [string]$_.route_decision -eq "ROUTE_INSTRUCTION" })[-1].message_id } else { "NONE" }
  }
}
