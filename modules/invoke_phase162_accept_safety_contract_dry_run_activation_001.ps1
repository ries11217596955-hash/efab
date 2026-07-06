param(
  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,

  [Parameter(Mandatory=$true)]
  [string]$ControllerRoot,

  [Parameter(Mandatory=$true)]
  [string]$SafetyRoot,

  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
  param([string]$Path, [object]$Object)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth 70 | Set-Content -Path $Path -Encoding UTF8
}

function Get-PathFingerprint {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return [ordered]@{
      exists = $false
      length = 0
      sha256 = "ABSENT"
    }
  }

  $item = Get-Item -LiteralPath $Path
  if ($item.PSIsContainer) {
    return [ordered]@{
      exists = $true
      length = -1
      sha256 = "DIRECTORY"
    }
  }

  return [ordered]@{
    exists = $true
    length = $item.Length
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
  }
}

function Test-UnderRoot {
  param([string]$Path, [string]$Root)

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $fullRoot = [System.IO.Path]::GetFullPath($Root)
  return $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

$RepoRootFull = [System.IO.Path]::GetFullPath($RepoRoot)

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_ACCEPT_SAFETY_DRY_RUN_ACTIVATION_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$OutputRootFull = [System.IO.Path]::GetFullPath($OutputRoot)

$controller = Read-Json (Join-Path $ControllerRoot "controller_with_next_cycle_trial_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_with_next_cycle_trial_validation.json")
$request = Read-Json (Join-Path $ControllerRoot "accept_safety_contract_dry_run_activation_request.json")

$safety = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_result.json")
$contract = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_scaffold.json")
$safetyValidation = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_validation.json")

$inputReady = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.next_machine_action -eq "ACTIVATE_AND_TEST_ACCEPT_SAFETY_CONTRACTS_IN_DRY_RUN") -and
  ([string]$request.status -eq "READY_TO_BUILD") -and
  ([string]$safetyValidation.status -eq "PASS") -and
  ([bool]$safety.accept_safety_contracts_present -eq $true) -and
  ([string]$contract.contract_mode -eq "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES")
)

$protected = @($contract.protected_paths | ForEach-Object { [string]$_ })
$beforeFingerprints = [ordered]@{}
foreach ($rel in $protected) {
  $full = Join-Path $RepoRootFull $rel
  $beforeFingerprints[$rel] = Get-PathFingerprint -Path $full
}

$dryRunWriteRoot = Join-Path $OutputRootFull "dry_run_write_area"
New-Item -ItemType Directory -Force -Path $dryRunWriteRoot | Out-Null

$allowedProbePath = Join-Path $dryRunWriteRoot "accept_write_probe.json"
$rollbackProbePath = Join-Path $dryRunWriteRoot "rollback_probe.json"

$allowedWritePermitted = Test-UnderRoot -Path $allowedProbePath -Root $OutputRootFull
$protectedDenials = @()

foreach ($rel in $protected) {
  $full = Join-Path $RepoRootFull $rel
  $allowed = Test-UnderRoot -Path $full -Root $OutputRootFull
  $protectedDenials += [ordered]@{
    path = $rel
    write_permitted_by_dry_run_contract = [bool]$allowed
    expected = "DENY"
    pass = (-not [bool]$allowed)
  }
}

$probePayload = [ordered]@{
  schema = "PHASE162_DRY_RUN_ACCEPT_WRITE_PROBE_V1"
  created_at = (Get-Date -Format o)
  mode = "DRY_RUN_ONLY"
  message = "This file is allowed because it is under the dry-run output root."
}

if ($allowedWritePermitted) {
  Write-Json -Path $allowedProbePath -Object $probePayload
}

$rollbackPayload = [ordered]@{
  schema = "PHASE162_DRY_RUN_ROLLBACK_PROBE_V1"
  created_at = (Get-Date -Format o)
  mode = "CREATE_THEN_DELETE"
}

Write-Json -Path $rollbackProbePath -Object $rollbackPayload
$rollbackCreated = Test-Path -LiteralPath $rollbackProbePath
Remove-Item -LiteralPath $rollbackProbePath -Force
$rollbackDeleted = -not (Test-Path -LiteralPath $rollbackProbePath)

$afterFingerprints = [ordered]@{}
foreach ($rel in $protected) {
  $full = Join-Path $RepoRootFull $rel
  $afterFingerprints[$rel] = Get-PathFingerprint -Path $full
}

$protectedUnchanged = $true
foreach ($rel in $protected) {
  $before = $beforeFingerprints[$rel]
  $after = $afterFingerprints[$rel]

  if (
    ([bool]$before.exists -ne [bool]$after.exists) -or
    ([int64]$before.length -ne [int64]$after.length) -or
    ([string]$before.sha256 -ne [string]$after.sha256)
  ) {
    $protectedUnchanged = $false
  }
}

$allProtectedDenied = (@($protectedDenials | Where-Object { -not [bool]$_.pass }).Count -eq 0)

$dryRunPassed = (
  $inputReady -and
  $allowedWritePermitted -and
  (Test-Path -LiteralPath $allowedProbePath) -and
  $rollbackCreated -and
  $rollbackDeleted -and
  $protectedUnchanged -and
  $allProtectedDenied
)

$result = [ordered]@{
  schema = "PHASE162_ACCEPT_SAFETY_CONTRACT_DRY_RUN_ACTIVATION_RESULT_V1"
  status = if ($dryRunPassed) { "PASS" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  controller_root = $ControllerRoot
  safety_root = $SafetyRoot
  output_root = $OutputRoot
  contract_mode = "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES"
  accept_safety_contract_dry_run_activated = [bool]$dryRunPassed
  safety_validated_for_accept = [bool]$dryRunPassed
  rollback_tested = [bool]($rollbackCreated -and $rollbackDeleted)
  protected_paths_unchanged = [bool]$protectedUnchanged
  protected_writes_denied = [bool]$allProtectedDenied
  allowed_write_probe_created = [bool](Test-Path -LiteralPath $allowedProbePath)
  owner_review_granted = $false
  accept_ready = $false
  expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action_after_controller_consumes_this = "REQUEST_OWNER_REVIEW_FOR_CONTROLLED_ACCEPT"
  protected_denials = $protectedDenials
  before_fingerprints = $beforeFingerprints
  after_fingerprints = $afterFingerprints
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "accept_safety_contract_dry_run_activation_result.json") -Object $result

@"
# PHASE162 Accept Safety Contract Dry-Run Activation Report

## Result

- status: $($result.status)
- accept_safety_contract_dry_run_activated: $($result.accept_safety_contract_dry_run_activated)
- safety_validated_for_accept: $($result.safety_validated_for_accept)
- rollback_tested: $($result.rollback_tested)
- protected_paths_unchanged: $($result.protected_paths_unchanged)
- protected_writes_denied: $($result.protected_writes_denied)
- owner_review_granted: false
- accept_ready: false
- expected_machine_decision: ACCEPT_BLOCKED_AUTONOMOUS_CYCLE
- next_machine_action_after_controller_consumes_this: REQUEST_OWNER_REVIEW_FOR_CONTROLLED_ACCEPT
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The admission cycle tested the future accept safety boundary in dry-run mode.

Allowed dry-run write was created under the output root. Rollback probe was created and deleted. Protected paths were fingerprinted before and after and remained unchanged.

## Boundary

No accepted core write happened. This is still not absorb.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_ACCEPT_SAFETY_DRY_RUN_ACTIVATION_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  accept_safety_contract_dry_run_activated = [bool]$result.accept_safety_contract_dry_run_activated
  safety_validated_for_accept = [bool]$result.safety_validated_for_accept
  rollback_tested = [bool]$result.rollback_tested
  protected_paths_unchanged = [bool]$result.protected_paths_unchanged
  protected_writes_denied = [bool]$result.protected_writes_denied
  owner_review_granted = $false
  accept_ready = $false
  next_machine_action_after_controller_consumes_this = [string]$result.next_machine_action_after_controller_consumes_this
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
