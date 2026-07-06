$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ReviewJsonPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_30000_DIVERSITY_AND_USE_REVIEW_V1.json"
$ReviewMdPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_30000_DIVERSITY_AND_USE_REVIEW_V1.md"
$ProofValidatorPath = "validators/validate_controlled_runtime_30000_diversity_and_use_proof_v1.ps1"

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

if ([string]::IsNullOrWhiteSpace([string]$review.status)) { Fail "STATUS_MISSING" }
if ([string]$review.status -ne "CONTROLLED_RUNTIME_30000_DIVERSITY_AND_USE_REVIEW_RECORDED") { Fail "STATUS_UNEXPECTED" }
if ([bool]$review.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([string]::IsNullOrWhiteSpace([string]$review.next_required)) { Fail "NEXT_REQUIRED_MISSING" }

$basisValues = @($review.basis | ForEach-Object { [string]$_ })
Require-Contains -Values $basisValues -Pattern "30000 stress proof" -Failure "BASIS_30000_STRESS_PROOF_MISSING"
Require-Contains -Values $basisValues -Pattern "diversity analyzer" -Failure "BASIS_DIVERSITY_ANALYZER_MISSING"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ProofValidatorPath
if ($LASTEXITCODE -ne 0) { Fail "DIVERSITY_AND_USE_PROOF_VALIDATOR_FAILED" }

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_30000_DIVERSITY_AND_USE_REVIEW_V1"
Write-Host "REVIEW_JSON=$ReviewJsonPath"
Write-Host "RUNTIME_READY=false"
exit 0
