function Write-Phase161B1RouterJsonFile {
  param([string]$Path, [object]$Object, [int]$Depth = 100)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-Phase161B1UniqueFilePath {
  param([string]$Directory, [string]$Name)
  New-Item -ItemType Directory -Force -Path $Directory | Out-Null
  $target = Join-Path $Directory $Name
  $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
  $extension = [System.IO.Path]::GetExtension($Name)
  $index = 1
  while (Test-Path -LiteralPath $target) {
    $target = Join-Path $Directory ("{0}_{1:d4}{2}" -f $base, $index, $extension)
    $index += 1
  }
  return $target
}

function Move-Phase161B1RouterFileUnique {
  param([string]$SourcePath, [string]$DestinationDirectory, [string]$Prefix = "")
  New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
  $name = [System.IO.Path]::GetFileName($SourcePath)
  if (-not [string]::IsNullOrWhiteSpace($Prefix)) {
    $name = "$Prefix$name"
  }
  $target = Get-Phase161B1UniqueFilePath -Directory $DestinationDirectory -Name $name
  Move-Item -LiteralPath $SourcePath -Destination $target
  return $target
}

function Invoke-Phase161B1OwnerInboxMessageQuarantine {
  param(
    [string]$SessionRootFull,
    [object]$RouteRecord,
    [string]$RawFileFullPath,
    [string]$Reason
  )
  $teacherQuarantine = Join-Path $SessionRootFull "teacher_quarantine"
  New-Item -ItemType Directory -Force -Path $teacherQuarantine | Out-Null
  $safeId = ([string]$RouteRecord.message_id) -replace '[^A-Za-z0-9_.-]', '_'
  $quarantinePath = Get-Phase161B1UniqueFilePath -Directory $teacherQuarantine -Name ("quarantine_router_{0}.json" -f $safeId)
  $RouteRecord.quarantine_reason = $Reason
  $RouteRecord.quarantine_required = $true
  Write-Phase161B1RouterJsonFile -Path $quarantinePath -Object ([ordered]@{
    status = if ([string]$RouteRecord.route_decision -eq "REJECT_MALFORMED_MESSAGE") { "REJECTED" } else { "QUARANTINED" }
    router_record = $RouteRecord
    reason = $Reason
    accepted_repo_mutation_allowed = $false
    protected_state_mutation_allowed = $false
    repo_commit_performed = $false
    repo_push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $false
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  })
  $movedRaw = $null
  if (-not [string]::IsNullOrWhiteSpace($RawFileFullPath) -and (Test-Path -LiteralPath $RawFileFullPath)) {
    $movedRaw = Move-Phase161B1RouterFileUnique -SourcePath $RawFileFullPath -DestinationDirectory $teacherQuarantine -Prefix "raw_router_"
  }
  return [pscustomobject][ordered]@{
    quarantine_path = $quarantinePath
    moved_raw_path = $movedRaw
  }
}
