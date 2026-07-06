param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputPath = 'reports/self_development/protected_state_update_candidates/PHASE161G1_CONSUMER_COMPATIBILITY_MATRIX.json'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$targets = @(
  [pscustomobject]@{ file = 'GENESIS_STATE.json'; tokens = @('GENESIS_STATE.json','GENESIS_STATE') },
  [pscustomobject]@{ file = 'CAPABILITY_ROADMAP.json'; tokens = @('CAPABILITY_ROADMAP.json','CAPABILITY_ROADMAP') },
  [pscustomobject]@{ file = 'TASK_QUEUE.json'; tokens = @('TASK_QUEUE.json','TASK_QUEUE') },
  [pscustomobject]@{ file = 'packs/registry.json'; tokens = @('packs/registry.json','packs\registry.json') },
  [pscustomobject]@{ file = 'orchestrator/run.ps1'; tokens = @('orchestrator/run.ps1','orchestrator\run.ps1') }
)

$extensions = @('.ps1','.psm1','.json','.md','.yml','.yaml','.txt')
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
  $_.Extension -in $extensions -and
  $_.FullName -notmatch '[\\/]\.git[\\/]' -and
  $_.FullName -notmatch '[\\/]runtime_sessions[\\/]'
})

$items = New-Object System.Collections.Generic.List[object]
foreach ($file in $files) {
  $relative = ([System.IO.Path]::GetRelativePath($root, $file.FullName) -replace '\\','/')
  $text = $null
  try { $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop } catch { continue }
  if ([string]::IsNullOrEmpty($text)) { continue }

  foreach ($target in $targets) {
    $matchedToken = $null
    foreach ($token in $target.tokens) {
      if ($text.IndexOf($token, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $matchedToken = $token
        break
      }
    }
    if (-not $matchedToken) { continue }

    $lines = @($text -split "`r?`n")
    $matchIndex = -1
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
      if ($lines[$lineIndex] -match [regex]::Escape($matchedToken)) {
        $matchIndex = $lineIndex
        break
      }
    }
    $snippet = $(if ($matchIndex -ge 0) { $lines[$matchIndex] } else { $matchedToken })
    $snippet = ($snippet.Trim() -replace '\s+',' ')
    if ($snippet.Length -gt 240) { $snippet = $snippet.Substring(0,240) }

    $isExecutable = $file.Extension -in @('.ps1','.psm1')
    $isHistorical = $relative -like 'packs/*' -or $relative -like 'self_build_programs/generated/*'
    $isReportReference = $relative -like 'reports/*' -or $relative -like 'proofs/*' -or $relative -like 'docs/*' -or $file.Extension -eq '.md'
    $parsesJson = $text -match 'ConvertFrom-Json'
    $contextStart = [Math]::Max(0, $matchIndex - 8)
    $contextEnd = [Math]::Min($lines.Count - 1, $matchIndex + 8)
    $contextText = $(if ($matchIndex -ge 0) { ($lines[$contextStart..$contextEnd] -join "`n") } else { $snippet })
    $writesTarget = $contextText -match '(Set-Content|Out-File|Copy-Item|Move-Item)'
    $strictSignal = $contextText -match '(PSObject\.Properties|Properties)\.Count|additionalProperties.{0,20}false|Compare-Object.{0,160}(PSObject\.Properties|top.level|keys)|exact.{0,40}(field|property|key).{0,20}count'

    $accessPattern = if ($writesTarget) {
      'WRITE_REFERENCE'
    } elseif ($isExecutable -and $parsesJson) {
      'PARSE_JSON_NAMED_PROPERTY_CONSUMER'
    } elseif ($isExecutable) {
      'EXECUTABLE_REFERENCE'
    } elseif ($isReportReference) {
      'REPORT_OR_DOCUMENT_REFERENCE'
    } else {
      'DATA_OR_CONFIGURATION_REFERENCE'
    }

    $strictRisk = if ($strictSignal) { 'true' } elseif ($isExecutable -and $parsesJson) { 'false' } else { 'unknown' }
    $extraSafe = if ($strictSignal) { 'false' } elseif ($isExecutable -and $parsesJson) { 'true' } else { 'unknown' }
    $riskReason = if ($strictSignal) {
      'Consumer contains an exact-property/count/schema strictness signal and requires separate review.'
    } elseif ($isExecutable -and $parsesJson) {
      'Consumer parses JSON into an object and no exact top-level property-count or additional-property rejection signal was found.'
    } elseif ($isHistorical) {
      'Historical/generated implementation reference; not treated as a current consumer, but retained as unknown compatibility evidence.'
    } elseif ($isReportReference) {
      'Reference-only artifact; it does not establish runtime consumer compatibility.'
    } else {
      'Reference found without enough evidence to prove whether extra top-level fields are accepted.'
    }

    $items.Add([pscustomobject][ordered]@{
      consumer_path = $relative
      target_file = $target.file
      access_pattern = $accessPattern
      consumer_scope = $(if ($isHistorical) { 'HISTORICAL_OR_GENERATED' } elseif ($isReportReference) { 'REFERENCE_ONLY' } elseif ($isExecutable) { 'CURRENT_EXECUTABLE_CANDIDATE' } else { 'DATA_REFERENCE' })
      strict_schema_risk = $strictRisk
      top_level_extra_fields_safe = $extraSafe
      risk_reason = $riskReason
      evidence_snippet_or_pattern = $snippet
    })
  }
}

$array = @($items.ToArray() | Sort-Object target_file, consumer_path -Unique)
$summary = foreach ($target in $targets.file) {
  $targetItems = @($array | Where-Object { $_.target_file -eq $target })
  [pscustomobject]@{
    target_file = $target
    consumer_reference_count = $targetItems.Count
    current_executable_count = @($targetItems | Where-Object { $_.consumer_scope -eq 'CURRENT_EXECUTABLE_CANDIDATE' }).Count
    strict_risk_true_count = @($targetItems | Where-Object { $_.strict_schema_risk -eq 'true' }).Count
    strict_risk_unknown_count = @($targetItems | Where-Object { $_.strict_schema_risk -eq 'unknown' }).Count
    extra_fields_safe_true_count = @($targetItems | Where-Object { $_.top_level_extra_fields_safe -eq 'true' }).Count
  }
}

$result = [pscustomobject][ordered]@{
  matrix_id = 'PHASE161G1_PROTECTED_STATE_CONSUMER_COMPATIBILITY_MATRIX_V1'
  search_scope = 'Repository text files excluding .git and runtime_sessions'
  interpretation = 'Current executable consumers are separated from historical/generated and reference-only matches. Unknowns are retained explicitly.'
  summary = @($summary)
  consumers = $array
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}

$fullOutput = Join-Path $root $OutputPath
$dir = Split-Path -Parent $fullOutput
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fullOutput -Encoding UTF8
$result
