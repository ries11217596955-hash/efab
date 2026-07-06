param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-JsonFile {
  param([string]$Path)
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-OptionalString {
  param(
    [object]$Object,
    [string]$PropertyName,
    [string]$DefaultValue = ""
  )

  if ($null -ne $Object -and $Object.PSObject.Properties.Name.Contains($PropertyName) -and $null -ne $Object.$PropertyName) {
    return [string]$Object.$PropertyName
  }

  return $DefaultValue
}

if (-not (Test-Path -LiteralPath $InputPath)) {
  throw "InputPath missing: $InputPath"
}

$inputObject = Read-JsonFile $InputPath
foreach ($field in @("task_id", "task_summary", "evidence_items")) {
  if (-not $inputObject.PSObject.Properties.Name.Contains($field)) {
    throw "Input JSON missing required field: $field"
  }
}

$evidenceItems = @($inputObject.evidence_items)
if ($evidenceItems.Count -eq 0) {
  throw "Input JSON evidence_items must contain at least one item."
}

$manifest = @()
$providedKeys = @()

foreach ($item in $evidenceItems) {
  foreach ($field in @("evidence_id", "evidence_type", "summary")) {
    if (-not $item.PSObject.Properties.Name.Contains($field)) {
      throw "Evidence item missing required field: $field"
    }
  }

  $evidenceId = Get-OptionalString -Object $item -PropertyName "evidence_id"
  $evidenceType = Get-OptionalString -Object $item -PropertyName "evidence_type"
  $label = Get-OptionalString -Object $item -PropertyName "label"
  $status = Get-OptionalString -Object $item -PropertyName "status" -DefaultValue "available"

  $providedKeys += $evidenceId
  $providedKeys += $evidenceType
  if (-not [string]::IsNullOrWhiteSpace($label)) {
    $providedKeys += $label
  }

  $manifest += [ordered]@{
    evidence_id = $evidenceId
    evidence_type = $evidenceType
    summary = Get-OptionalString -Object $item -PropertyName "summary"
    source_path = Get-OptionalString -Object $item -PropertyName "source_path"
    status = $status
  }
}

$requiredEvidence = @()
if ($inputObject.PSObject.Properties.Name.Contains("required_evidence")) {
  $requiredEvidence = @($inputObject.required_evidence)
}

$missingEvidence = @()
foreach ($required in $requiredEvidence) {
  $requiredText = [string]$required
  if ($providedKeys -notcontains $requiredText) {
    $missingEvidence += $requiredText
  }
}

$riskFlags = @()
if ($missingEvidence.Count -gt 0) {
  $riskFlags += "MISSING_EVIDENCE"
}

$nonAvailable = @($manifest | Where-Object { [string]$_.status -ne "available" })
if ($nonAvailable.Count -gt 0) {
  $riskFlags += "EVIDENCE_NOT_AVAILABLE"
}

if ($riskFlags.Count -eq 0) {
  $riskFlags += "NONE"
}

$nextAction = "Evidence package is ready for operator review."
if ($missingEvidence.Count -gt 0) {
  $nextAction = "Collect the missing evidence before closing the review."
}

$output = [ordered]@{
  evidence_manifest = $manifest
  missing_evidence = $missingEvidence
  risk_flags = $riskFlags
  next_operator_action = $nextAction
  validation_status = "PASS"
}

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
  New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

$output | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "EVIDENCE_PACKAGER_RUNTIME_STATUS=PASS"
