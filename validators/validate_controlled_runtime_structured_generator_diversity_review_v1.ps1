$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ReviewJsonPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_STRUCTURED_GENERATOR_DIVERSITY_REVIEW_V1.json"
$ReviewMdPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_STRUCTURED_GENERATOR_DIVERSITY_REVIEW_V1.md"
$StructuredValidatorPath = "validators/validate_controlled_runtime_structured_generator_diversity_v1.ps1"

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
if (-not (Test-Path -LiteralPath $StructuredValidatorPath)) { Fail "STRUCTURED_VALIDATOR_MISSING" }

try {
  $review = Get-Content -LiteralPath $ReviewJsonPath -Raw | ConvertFrom-Json
} catch {
  Fail "REVIEW_JSON_PARSE_FAILED"
}

if ([string]$review.status -ne "STRUCTURED_GENERATOR_DIVERSITY_REPAIR_PASS") { Fail "STATUS_NOT_STRUCTURED_GENERATOR_DIVERSITY_REPAIR_PASS" }
if ([string]$review.promoted_from -ne "NORMALIZED_LOW_SYNTHETIC_GENERATOR") { Fail "PROMOTED_FROM_UNEXPECTED" }
if ([bool]$review.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([string]::IsNullOrWhiteSpace([string]$review.next_required)) { Fail "NEXT_REQUIRED_MISSING" }

$basisValues = @($review.basis | ForEach-Object { [string]$_ })
Require-Contains -Values $basisValues -Pattern "normalized low" -Failure "BASIS_PREVIOUS_LOW_DIVERSITY_MISSING"
Require-Contains -Values $basisValues -Pattern "StructuredV1 generator trial passed" -Failure "BASIS_STRUCTURED_V1_PASS_MISSING"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StructuredValidatorPath
if ($LASTEXITCODE -ne 0) { Fail "STRUCTURED_GENERATOR_VALIDATOR_FAILED" }

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_STRUCTURED_GENERATOR_DIVERSITY_REVIEW_V1"
Write-Host "REVIEW_JSON=$ReviewJsonPath"
Write-Host "RUNTIME_READY=false"
exit 0
