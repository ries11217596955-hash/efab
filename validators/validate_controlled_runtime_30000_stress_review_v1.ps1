$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ReviewJsonPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_30000_STRESS_REVIEW_V1.json"
$ReviewMdPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_30000_STRESS_REVIEW_V1.md"
$ProofValidatorPath = "validators/validate_controlled_runtime_30000_stress_proof_v1.ps1"

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
if (-not (Test-Path -LiteralPath $ProofValidatorPath)) { Fail "PROOF_VALIDATOR_MISSING" }

try {
  $review = Get-Content -LiteralPath $ReviewJsonPath -Raw | ConvertFrom-Json
} catch {
  Fail "REVIEW_JSON_PARSE_FAILED"
}

if ([string]$review.status -ne "CONTROLLED_RUNTIME_30000_STRESS_REVIEW_PASS") { Fail "STATUS_NOT_STRESS_REVIEW_PASS" }
if ([string]$review.promoted_from -ne "CONTROLLED_RUNTIME_ENTRYPOINT_ACCEPTED_LOCAL") { Fail "PROMOTED_FROM_UNEXPECTED" }
if ([bool]$review.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([string]::IsNullOrWhiteSpace([string]$review.next_required)) { Fail "NEXT_REQUIRED_MISSING" }

$basisValues = @($review.basis | ForEach-Object { [string]$_ })
Require-Contains -Values $basisValues -Pattern "memory delta isolation" -Failure "BASIS_MEMORY_DELTA_ISOLATION_MISSING"
Require-Contains -Values $basisValues -Pattern "30000 detached run" -Failure "BASIS_30000_DETACHED_RUN_MISSING"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ProofValidatorPath
if ($LASTEXITCODE -ne 0) { Fail "STRESS_PROOF_VALIDATOR_FAILED" }

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_30000_STRESS_REVIEW_V1"
Write-Host "REVIEW_JSON=$ReviewJsonPath"
Write-Host "RUNTIME_READY=false"
exit 0
