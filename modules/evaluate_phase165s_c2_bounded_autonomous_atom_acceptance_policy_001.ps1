param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [Parameter(Mandatory=$true)]
  [string]$CandidatePath,
  [string]$OutputPath = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Read-J {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-J {
  param([string]$Path,[object]$Object)
  $Parent = Split-Path -Parent $Path
  if ($Parent) { New-Item -ItemType Directory -Force -Path $Parent | Out-Null }
  $Object | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Get-P {
  param($Obj,[string]$Name,$Default = $null)
  if ($null -eq $Obj) { return $Default }
  if ($Obj.PSObject.Properties.Name -contains $Name) { return $Obj.$Name }
  return $Default
}

function Count-Atom {
  param($Root,[string]$Property,[string]$AtomId)
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) { return 0 }
  return @($Root.$Property | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

$root = (Resolve-Path $RepoRoot).Path
$candidate = Read-J $CandidatePath

$atomIds = @()
if ($candidate.PSObject.Properties.Name -contains "atom_ids") { $atomIds = @($candidate.atom_ids | ForEach-Object { [string]$_ }) }
elseif ($candidate.PSObject.Properties.Name -contains "atom_id") { $atomIds = @([string]$candidate.atom_id) }

$batchSize = [int](Get-P $candidate "batch_size" $atomIds.Count)
$sourceRoute = [string](Get-P $candidate "source_route" "")
$sourceAuthority = [string](Get-P $candidate "source_authority" "")
$targetFiles = @((Get-P $candidate "target_files" @()) | ForEach-Object { [string]$_ })
$protectedFiles = @((Get-P $candidate "protected_files_to_mutate" @()) | ForEach-Object { [string]$_ })
$riskFlags = @((Get-P $candidate "risk_flags" @()) | ForEach-Object { [string]$_ })
$proofGates = Get-P $candidate "proof_gates" $null

$allowedTargets = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)

$forbiddenProtected = @(
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json",
  "TASK_QUEUE.json",
  "orchestrator/run.ps1",
  "route_locks"
)

$memory = Read-J (Join-Path $root "reports/self_development/accepted_change_memory_snapshot.json")
$selfMap = Read-J (Join-Path $root "reports/self_development/SELF_MODEL_ACTIVE_MAP.json")
$registry = Read-J (Join-Path $root "packs/registry.json")

$duplicateAtoms = @()
foreach ($a in $atomIds) {
  $m = Count-Atom $memory "phase162_accepted_atom_memory_records" $a
  $s = Count-Atom $selfMap "phase162_absorbed_atom_capability_notes" $a
  $r = Count-Atom $registry "phase162_accepted_atom_references" $a
  if (($m + $s + $r) -gt 0) { $duplicateAtoms += $a }
}

$reasons = @()

if ($atomIds.Count -ne 1) { $reasons += "atom_id_count_not_one" }
if ($batchSize -ne 1) { $reasons += "batch_size_not_one" }
if ([string]::IsNullOrWhiteSpace($atomIds[0])) { $reasons += "atom_id_empty" }

if ($sourceRoute -notin @("OWNER_INBOX_CURRICULUM","APPROVED_CURRICULUM","OWNER_APPROVED_CURRICULUM")) {
  $reasons += "source_route_not_approved"
}

if ($sourceAuthority -notin @("OWNER_APPROVED","COMMITTED_CURRICULUM","APPROVED_SOURCE_CATALOG")) {
  $reasons += "source_authority_not_approved"
}

$badTargets = @($targetFiles | Where-Object { $_ -notin $allowedTargets })
$missingTargets = @($allowedTargets | Where-Object { $_ -notin $targetFiles })
if ($badTargets.Count -gt 0) { $reasons += "target_files_outside_accept_atom_surfaces" }
if ($missingTargets.Count -gt 0) { $reasons += "required_accept_atom_surface_missing" }

$badProtected = @($protectedFiles | Where-Object { $_ -ne "packs/registry.json" })
if ($badProtected.Count -gt 0) { $reasons += "protected_write_outside_registry" }

foreach ($p in $forbiddenProtected) {
  if (@($protectedFiles | Where-Object { $_ -like "*$p*" }).Count -gt 0) {
    $reasons += "forbidden_protected_target=$p"
  }
}

$gateNames = @(
  "memory_proof_status",
  "use_proof_status",
  "behavior_delta_status",
  "persistence_status",
  "startup_visibility_status"
)

foreach ($g in $gateNames) {
  if ([string](Get-P $proofGates $g "") -ne "PASS") {
    $reasons += "proof_gate_not_pass=$g"
  }
}

if ([bool](Get-P $candidate "rollback_plan_available" $false) -ne $true) { $reasons += "rollback_plan_missing" }
if ([bool](Get-P $candidate "exactly_one_atom_scope" $false) -ne $true) { $reasons += "exactly_one_atom_scope_false" }
if ([bool](Get-P $candidate "mass_acceptance_forbidden" $false) -ne $true) { $reasons += "mass_acceptance_not_forbidden" }
if ($riskFlags.Count -gt 0) { $reasons += "risk_flags_present" }
if ($duplicateAtoms.Count -gt 0) { $reasons += "duplicate_atom_found" }

$allowed = ($reasons.Count -eq 0)

$result = [ordered]@{
  schema = "PHASE165S_C2_BOUNDED_AUTONOMOUS_ATOM_ACCEPTANCE_POLICY_EVALUATION_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  candidate_path = $CandidatePath
  autonomous_accept_allowed = [bool]$allowed
  decision_code = if ($allowed) { "ALLOW_AUTONOMOUS_ONE_ATOM_ACCEPTANCE" } else { "DENY_REQUIRE_OWNER_OR_REPAIR" }
  atom_ids = $atomIds
  batch_size = $batchSize
  source_route = $sourceRoute
  source_authority = $sourceAuthority
  allowed_target_files = $allowedTargets
  target_files = $targetFiles
  protected_files_to_mutate = $protectedFiles
  duplicate_atoms = $duplicateAtoms
  denial_reasons = $reasons
  owner_prompt_required = (-not $allowed)
  protected_write_scope = "packs/registry.json only, and only through existing PHASE162 accepted-core executor"
  next_machine_action = if ($allowed) { "RUN_EXISTING_PHASE162_ACCEPT_PIPELINE_WITHOUT_OWNER_INTERRUPT" } else { "STOP_FOR_OWNER_OR_REPAIR" }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $root "reports/self_development/PHASE165S_C2_BOUNDED_AUTONOMOUS_POLICY_GATE_RESULT.json"
}

Write-J $OutputPath $result
[pscustomobject]$result
