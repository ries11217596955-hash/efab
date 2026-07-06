param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$TaskKind = '',
  [string]$RequestedCapability = '',
  [string]$ContextHint = '',
  [string]$OutputPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$SelectorId = 'startup.selector.proof_energy.schema_validator.v1'
$TargetAtomId = 'law_kernel.matrix_cell.proof_energy.record_schema_validator.visibility.v1'

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
  param([string]$Path, [object]$Object)
  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 50) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-ArrayProperty {
  param($Object, [string]$Name)
  if ($null -eq $Object) { return @() }
  if ($Object -is [array]) { return @($Object) }
  if ($Object.PSObject.Properties.Name -contains $Name) { return @($Object.$Name) }
  return @()
}

function Test-SelectorTrigger {
  param(
    [string]$TaskKind,
    [string]$RequestedCapability,
    [string]$ContextHint
  )
  return (
    $TaskKind -like '*proof_energy_record_validation*' -and
    $RequestedCapability -like '*validate_law_kernel_matrix_cell_proof_energy_record*' -and
    $ContextHint -like '*law_kernel_matrix_cell*'
  )
}

$root = (Resolve-Path $RepoRoot).Path
$registryPath = Join-Path $root 'packs/registry.json'
$registry = Read-Json $registryPath
$registryEntries = Get-ArrayProperty -Object $registry -Name 'phase162_accepted_atom_references'
$matchedEntries = @($registryEntries | Where-Object { [string]$_.atom_id -eq $TargetAtomId })
$entry = if ($matchedEntries.Count -gt 0) { $matchedEntries[0] } else { $null }
$payload = if ($null -ne $entry -and $entry.PSObject.Properties.Name -contains 'payload') { $entry.payload } else { $null }

$schemaPath = if ($null -ne $payload -and $payload.PSObject.Properties.Name -contains 'schema_path') { [string]$payload.schema_path } else { '' }
$validatorPath = if ($null -ne $payload -and $payload.PSObject.Properties.Name -contains 'validator_path') { [string]$payload.validator_path } else { '' }
$schemaFullPath = if (-not [string]::IsNullOrWhiteSpace($schemaPath)) { Join-Path $root $schemaPath } else { '' }
$validatorFullPath = if (-not [string]::IsNullOrWhiteSpace($validatorPath)) { Join-Path $root $validatorPath } else { '' }

$triggerMatched = Test-SelectorTrigger -TaskKind $TaskKind -RequestedCapability $RequestedCapability -ContextHint $ContextHint
$atomFound = ($null -ne $entry)
$schemaExists = (-not [string]::IsNullOrWhiteSpace($schemaFullPath) -and (Test-Path -LiteralPath $schemaFullPath -PathType Leaf))
$validatorExists = (-not [string]::IsNullOrWhiteSpace($validatorFullPath) -and (Test-Path -LiteralPath $validatorFullPath -PathType Leaf))
$selectorMatched = ($triggerMatched -and $atomFound -and $schemaExists -and $validatorExists)

$missingReasons = @()
if (-not $triggerMatched) { $missingReasons += 'selector_trigger_not_matched' }
if (-not $atomFound) { $missingReasons += 'accepted_atom_not_found_in_registry' }
if (-not $schemaExists) { $missingReasons += 'schema_path_missing_or_absent' }
if (-not $validatorExists) { $missingReasons += 'validator_path_missing_or_absent' }

$selectionReason = if ($selectorMatched) {
  'Matched proof-energy record validation request to accepted local schema+validator atom in packs/registry.json.'
} else {
  'No runnable startup selector match: ' + ($missingReasons -join ',')
}

$result = [ordered]@{
  status = if ($selectorMatched) { 'SELECTOR_MATCH' } else { 'SELECTOR_NO_MATCH' }
  selector_id = $SelectorId
  selected_atom_id = if ($selectorMatched) { $TargetAtomId } else { '' }
  selected_schema_path = if ($selectorMatched) { $schemaPath } else { '' }
  selected_validator_path = if ($selectorMatched) { $validatorPath } else { '' }
  selection_reason = $selectionReason
  protected_mutation_done = $false
  codex_used_at_runtime = $false
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $OutputPath))
  }
  Write-Json -Path $outputFullPath -Object $result
}

$result | ConvertTo-Json -Depth 50
