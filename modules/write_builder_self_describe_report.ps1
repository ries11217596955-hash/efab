[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Read-JsonFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing required JSON file: $Path"
  }

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Object
  )

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Write-TextFile {
  param(
    [string]$Path,
    [string]$Text
  )

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $normalized = $Text -replace "`r`n", "`n"
  if (-not $normalized.EndsWith("`n")) {
    $normalized += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $normalized, [System.Text.UTF8Encoding]::new($false))
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

function Safe-Count {
  param([object]$Value)

  return @(As-Array $Value).Count
}

function Safe-Property {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
  if ($null -eq $property) {
    return $null
  }

  return $property.Value
}

function Select-Paths {
  param(
    [object[]]$Items,
    [int]$Limit = 25
  )

  return @(
    $Items |
      Select-Object -First $Limit |
      ForEach-Object {
        $path = Safe-Property -Object $_ -Name "path"
        $sourcePath = Safe-Property -Object $_ -Name "source_path"
        $id = Safe-Property -Object $_ -Name "id"
        if ($null -ne $path -and "$path" -ne "") {
          $path
        } elseif ($null -ne $sourcePath -and "$sourcePath" -ne "") {
          $sourcePath
        } elseif ($null -ne $id -and "$id" -ne "") {
          $id
        } else {
          "$_"
        }
      }
  )
}

function Format-ListText {
  param([object[]]$Values)

  $items = @($Values | Where-Object { $null -ne $_ -and "$_" -ne "" })
  if ((Safe-Count $items) -eq 0) {
    return "None recorded."
  }

  return ($items -join "; ")
}

$utcNow = Get-UtcStamp
$selfModelPath = Join-RepoPath "self_knowledge/BUILDER_SELF_MODEL.json"
$reportDirectory = Join-RepoPath "reports/self_knowledge"
if (-not (Test-Path -LiteralPath $reportDirectory)) {
  New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
}

$model = Read-JsonFile $selfModelPath

$existingSystems = @(
  As-Array $model.launch_surfaces |
    Where-Object { $_.status -eq "proven" } |
    ForEach-Object { "$($_.area): $($_.path)" }
)
$existingSystems += @(
  "Capabilities indexed: $($model.capability_manifest.counts.total)"
  "Modules indexed: $($model.module_inventory.counts.modules)"
  "Proof files indexed: $(Safe-Count $model.proof_index)"
  "Report files indexed: $(Safe-Count $model.report_index)"
)

$missingSystems = @(
  As-Array $model.missing_surfaces |
    Where-Object { $_.area -in @("Operation System", "Blueprint Compiler", "Produced Agents", "Generated Programs", "Launch Surfaces") } |
    ForEach-Object { "$($_.area): $($_.path)" }
)

$agentProducts = @(
  As-Array $model.produced_agents |
    Select-Object -First 25 |
    ForEach-Object { "$($_.agent_id) [$($_.status)] via $($_.source_path)" }
)

$supportingEvidence = @()
$supportingEvidence += Select-Paths -Items (As-Array $model.proof_index) -Limit 30
$supportingEvidence += Select-Paths -Items (As-Array $model.report_index) -Limit 30
$supportingEvidence = @($supportingEvidence | Sort-Object -Unique)

$answers = [ordered]@{
  who_is_builder = "Builder is the Agent Builder for this repository: it improves its own verified operating contour first, then produces other agents from formal specs."
  what_repo_is_this = "This is $($model.builder_identity.repo_name), identified by the required repo marker files and pack registry."
  current_capability = "$($model.current_state.current_capability)"
  queue_state = $(if ($model.queue_state.clean) { "Queue is clean: active_task_id is NONE." } else { "Queue is active: active_task_id is $($model.queue_state.active_task_id)." })
  major_systems_exist = $existingSystems
  major_systems_missing = $missingSystems
  agent_like_products_evidenced = $(if ((Safe-Count $agentProducts) -gt 0) { $agentProducts } else { @("No produced-agent files were evidenced in the scanned source surfaces.") })
  proofs_reports_supporting_claims = $(if ((Safe-Count $supportingEvidence) -gt 0) { $supportingEvidence } else { @("No proof or report files were indexed.") })
  what_should_be_built_next = "$($model.next_strongest_move.recommendation)"
  what_should_not_be_done_next = @(
    As-Array $model.cut_list |
      ForEach-Object { $_.item }
  )
}

$report = [ordered]@{
  schema_version = "AGENT_BUILDER_SELF_DESCRIBE_REPORT_V1"
  generated_at_utc = $utcNow
  collection_status = "collected"
  answers = $answers
  source_self_model = "self_knowledge/BUILDER_SELF_MODEL.json"
  evidence_policy = $model.evidence_policy
}

$jsonPath = Join-RepoPath "reports/self_knowledge/BUILDER_SELF_DESCRIBE_REPORT.json"
$markdownPath = Join-RepoPath "reports/self_knowledge/BUILDER_SELF_DESCRIBE_SUMMARY.md"

Write-JsonFile -Path $jsonPath -Object $report

$majorExistsMarkdown = ($answers.major_systems_exist | ForEach-Object { "- $_" }) -join [Environment]::NewLine
$majorMissingMarkdown = ($answers.major_systems_missing | ForEach-Object { "- $_" }) -join [Environment]::NewLine
$agentMarkdown = ($answers.agent_like_products_evidenced | ForEach-Object { "- $_" }) -join [Environment]::NewLine
$evidenceMarkdown = ($answers.proofs_reports_supporting_claims | Select-Object -First 40 | ForEach-Object { "- $_" }) -join [Environment]::NewLine
$cutMarkdown = ($answers.what_should_not_be_done_next | ForEach-Object { "- $_" }) -join [Environment]::NewLine

$markdown = @"
# Agent Builder Self-Describe Summary

Generated: $utcNow

## Who Is Builder?

$($answers.who_is_builder)

## What Repo Is This?

$($answers.what_repo_is_this)

## Current Capability

$($answers.current_capability)

## Queue State

$($answers.queue_state)

## Major Systems Exist

$majorExistsMarkdown

## Major Systems Missing

$majorMissingMarkdown

## Agents Or Agent-Like Products Evidenced

$agentMarkdown

## Proofs And Reports Supporting Claims

$evidenceMarkdown

## What Should Be Built Next

$($answers.what_should_be_built_next)

## What Should Not Be Done Next

$cutMarkdown
"@

Write-TextFile -Path $markdownPath -Text $markdown

Write-Host "SELF_DESCRIBE_REPORT=PASS"
Write-Host "OUTPUT=reports/self_knowledge/BUILDER_SELF_DESCRIBE_REPORT.json"
Write-Host "OUTPUT=reports/self_knowledge/BUILDER_SELF_DESCRIBE_SUMMARY.md"
