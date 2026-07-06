param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Read-Phase165SC1Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "MISSING_FILE=$Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-Phase165SC1Count {
  param($Root, [string]$Property, [string]$AtomId)
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) {
    return 0
  }
  return @($Root.$Property | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

$root = (Resolve-Path $RepoRoot).Path
$proof = Read-Phase165SC1Json (Join-Path $root 'proofs/self_development/PHASE165S_C1_CONNECT_SCHOOL_RESULT_TO_AGENT_SELF_DEVELOPMENT_LOOP_ONE_CONCEPT_PROOF_V1.json')
$memory = Read-Phase165SC1Json (Join-Path $root 'reports/self_development/accepted_change_memory_snapshot.json')
$selfMap = Read-Phase165SC1Json (Join-Path $root 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json')
$registry = Read-Phase165SC1Json (Join-Path $root 'packs/registry.json')
$atomId = 'decision_rule.map_signal_not_command.v1'

$memoryCount = Get-Phase165SC1Count -Root $memory -Property 'phase162_accepted_atom_memory_records' -AtomId $atomId
$selfMapCount = Get-Phase165SC1Count -Root $selfMap -Property 'phase162_absorbed_atom_capability_notes' -AtomId $atomId
$registryCount = Get-Phase165SC1Count -Root $registry -Property 'phase162_accepted_atom_references' -AtomId $atomId
$protectedDirty = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1 route_locks)

$checks = [ordered]@{
  blocked_status_honest = ([string]$proof.status -eq 'BLOCKED_PROTECTED_APPLY_REQUIRED')
  source_lesson_reconstructed = ([bool]$proof.source_lesson_reconstructed -eq $true)
  candidate_id_correct = ([string]$proof.atom_candidate.atom_id -eq $atomId)
  candidate_not_claimed_accepted = ([bool]$proof.accepted_atom_claimed -eq $false)
  existing_acceptance_path_found = ([bool]$proof.existing_universal_acceptance_path_found -eq $true)
  protected_registry_dependency_identified = ([string]$proof.protected_apply_dependency.forbidden_target -eq 'packs/registry.json')
  existing_executor_requires_registry = (@($proof.protected_apply_dependency.target_files | Where-Object { $_ -eq 'packs/registry.json' }).Count -eq 1)
  memory_proof_not_claimed = ([bool]$proof.memory_proof.passed -eq $false)
  use_proof_not_claimed = ([bool]$proof.use_proof.passed -eq $false)
  behavior_delta_not_claimed = ([bool]$proof.behavior_delta.passed -eq $false)
  persistence_not_claimed = ([bool]$proof.persistence.passed -eq $false)
  visibility_not_claimed = ([bool]$proof.startup_or_next_cycle_visibility.passed -eq $false)
  pass_marker_disallowed = ([bool]$proof.pass_marker_allowed -eq $false)
  atom_absent_from_memory = ($memoryCount -eq 0)
  atom_absent_from_self_map = ($selfMapCount -eq 0)
  atom_absent_from_registry = ($registryCount -eq 0)
  no_parallel_registry_created = ([bool]$proof.no_parallel_atom_registry_created -eq $true)
  exact_apply_plan_present = (@($proof.exact_candidate_apply_plan).Count -ge 7)
  protected_state_clean = ($protectedDirty.Count -eq 0)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { [string]$_.Key })
if ($failed.Count -gt 0) {
  Write-Host 'PHASE165S_C1_LESSON_TO_ATOM_BRIDGE_VALIDATE_RESULT=FAIL'
  Write-Host "FAIL_REASON=$($failed -join ';')"
  exit 1
}

# PASS is intentionally forbidden until the accepted atom and all six proof gates exist.
Write-Host 'PHASE165S_C1_LESSON_TO_ATOM_BRIDGE_VALIDATE_RESULT=BLOCKED_PROTECTED_APPLY_REQUIRED'
Write-Host 'BLOCKED_STATE_VALIDATED=True'
Write-Host "ATOM_ID=$atomId"
Write-Host "MEMORY_COUNT=$memoryCount"
Write-Host "SELF_MAP_COUNT=$selfMapCount"
Write-Host "REGISTRY_COUNT=$registryCount"
Write-Host 'PROTECTED_STATE_DIRTY_CHECK='
Write-Host 'PASS_MARKER_EMITTED=False'
exit 0
