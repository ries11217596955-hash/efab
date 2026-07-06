param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CandidateRoot = 'reports/self_development/protected_state_update_candidates'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$candidateFull = Join-Path $root $CandidateRoot
$outputPath = Join-Path $candidateFull 'PHASE161F_DRY_RUN_APPLY_RESULT.json'
$jsonCandidates = @(
  'GENESIS_STATE_update_candidate.json',
  'CAPABILITY_ROADMAP_update_candidate.json',
  'TASK_QUEUE_update_candidate.json',
  'packs_registry_update_candidate.json'
)

$protected = @('TASK_QUEUE.json','GENESIS_STATE.json','CAPABILITY_ROADMAP.json','packs/registry.json','orchestrator/run.ps1')
$beforeHashes = @{}
foreach ($path in $protected) {
  $beforeHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash
}

$parsedCount = 0
$validCount = 0
$errors = New-Object System.Collections.Generic.List[string]
$simulated = New-Object System.Collections.Generic.List[object]

foreach ($name in $jsonCandidates) {
  $candidatePath = Join-Path $candidateFull $name
  try {
    $candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
    $parsedCount++
    $targetPath = Join-Path $root $candidate.target_file
    $target = Get-Content -LiteralPath $targetPath -Raw | ConvertFrom-Json
    $clone = $target | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $simulatedApplied = $candidate.proposed_update_type -ne 'NO_CHANGE_RECOMMENDED'
    if ($simulatedApplied) {
      $envelope = [pscustomobject][ordered]@{
        promotion_id = 'PHASE161F_PROTECTED_SELF_MODEL_PROMOTION_CANDIDATE_V1'
        proposed_update_type = $candidate.proposed_update_type
        proposed_fields_or_sections = $candidate.proposed_fields_or_sections
        simulated_only = $true
      }
      if ($clone.PSObject.Properties.Name -contains '_phase161f_simulated_candidate') {
        $clone._phase161f_simulated_candidate = $envelope
      } else {
        $clone | Add-Member -NotePropertyName '_phase161f_simulated_candidate' -NotePropertyValue $envelope
      }
    }
    $cloneJson = $clone | ConvertTo-Json -Depth 100
    $cloneJson | ConvertFrom-Json | Out-Null
    $validCount++
    $simulated.Add([pscustomobject]@{
      target_file = $candidate.target_file
      proposed_update_type = $candidate.proposed_update_type
      simulated_apply_performed = $simulatedApplied
      simulated_json_parse = 'PASS'
      original_file_written = $false
    })
  } catch {
    $errors.Add(('{0}: {1}' -f $name, $_.Exception.Message))
  }
}

$afterHashes = @{}
foreach ($path in $protected) {
  $afterHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash
  if ($beforeHashes[$path] -ne $afterHashes[$path]) {
    $errors.Add("Protected target changed during dry-run: $path")
  }
}

$errorArray = $errors.ToArray()
$simulatedArray = $simulated.ToArray()
$protectedChangeErrors = @($errorArray | Where-Object { $_ -like 'Protected target changed*' })

$result = [pscustomobject][ordered]@{
  dry_run_status = $(if ($errors.Count -eq 0 -and $parsedCount -eq $jsonCandidates.Count -and $validCount -eq $jsonCandidates.Count) { 'PASS' } else { 'FAIL' })
  protected_files_modified_directly = $protectedChangeErrors.Count -gt 0
  candidates_parsed = $parsedCount
  candidates_valid_json = $validCount
  simulated_targets = $simulatedArray
  validation_errors = $errorArray
  rollback_possible = $true
  owner_approval_required = $true
  original_hashes_preserved = $protectedChangeErrors.Count -eq 0
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outputPath -Encoding UTF8
$result
