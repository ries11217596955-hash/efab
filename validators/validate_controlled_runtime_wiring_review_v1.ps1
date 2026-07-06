$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ReviewJsonPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_WIRING_REVIEW_V1.json"
$ReviewMdPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_WIRING_REVIEW_V1.md"
$EntrypointPath = "modules/run_ephemeral_candidate_controlled_runtime_v1.ps1"
$WiringValidatorPath = "validators/validate_controlled_ephemeral_runtime_wiring_trial_v1.ps1"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

function Require-Contains {
  param(
    [string[]]$Values,
    [string]$Pattern,
    [string]$Failure
  )

  $joined = ($Values -join "`n")
  if ($joined -notmatch [regex]::Escape($Pattern)) {
    Fail $Failure
  }
}

if (-not (Test-Path -LiteralPath $ReviewJsonPath)) { Fail "REVIEW_JSON_MISSING" }
if (-not (Test-Path -LiteralPath $ReviewMdPath)) { Fail "REVIEW_MD_MISSING" }
if (-not (Test-Path -LiteralPath $EntrypointPath)) { Fail "ENTRYPOINT_MISSING" }
if (-not (Test-Path -LiteralPath $WiringValidatorPath)) { Fail "WIRING_VALIDATOR_MISSING" }

try {
  $review = Get-Content -LiteralPath $ReviewJsonPath -Raw | ConvertFrom-Json
} catch {
  Fail "REVIEW_JSON_PARSE_FAILED"
}

if ([string]$review.status -ne "CONTROLLED_RUNTIME_ENTRYPOINT_ACCEPTED_LOCAL") {
  Fail "STATUS_NOT_CONTROLLED_RUNTIME_ENTRYPOINT_ACCEPTED_LOCAL"
}
if ([string]$review.promoted_from -ne "CONTROLLED_RUNTIME_CANDIDATE") {
  Fail "PROMOTED_FROM_NOT_CONTROLLED_RUNTIME_CANDIDATE"
}
if ([bool]$review.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([string]$review.entrypoint -ne $EntrypointPath) { Fail "ENTRYPOINT_PATH_UNEXPECTED" }
if ([string]::IsNullOrWhiteSpace([string]$review.next_required)) { Fail "NEXT_REQUIRED_MISSING" }

$basisValues = @()
$review.basis.PSObject.Properties | ForEach-Object { $basisValues += [string]$_.Value }
Require-Contains -Values $basisValues -Pattern "CONTROLLED_EPHEMERAL_RUNTIME_WIRING_TRIAL_V1.json" -Failure "BASIS_WIRING_TRIAL_PROOF_MISSING"
Require-Contains -Values $basisValues -Pattern "validate_ephemeral_candidate_to_atom_runtime_1000_trial_v1.ps1" -Failure "BASIS_RUNTIME_1000_VALIDATOR_MISSING"

$invariants = @($review.invariants | ForEach-Object { [string]$_ })
Require-Contains -Values $invariants -Pattern "MaxCycles" -Failure "INVARIANT_MAXCYCLES_MISSING"
Require-Contains -Values $invariants -Pattern "StopFile" -Failure "INVARIANT_STOPFILE_MISSING"
Require-Contains -Values $invariants -Pattern "heartbeat" -Failure "INVARIANT_HEARTBEAT_MISSING"
Require-Contains -Values $invariants -Pattern "no_unbounded_loops" -Failure "INVARIANT_NO_UNBOUNDED_LOOPS_MISSING"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $WiringValidatorPath
if ($LASTEXITCODE -ne 0) { Fail "CONTROLLED_RUNTIME_WIRING_VALIDATOR_FAILED" }

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_WIRING_REVIEW_V1"
Write-Host "REVIEW_JSON=$ReviewJsonPath"
Write-Host "ENTRYPOINT=$EntrypointPath"
Write-Host "RUNTIME_READY=false"
exit 0
