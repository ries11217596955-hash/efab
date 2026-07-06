$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ReviewJsonPath = "contracts/controlled_runtime/PROMOTION_REVIEW_CONTROLLED_RUNTIME_V1.json"
$ReviewMdPath = "contracts/controlled_runtime/PROMOTION_REVIEW_CONTROLLED_RUNTIME_V1.md"
$RuntimeValidator = "validators/validate_ephemeral_candidate_to_atom_runtime_1000_trial_v1.ps1"

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath $ReviewJsonPath)) { Fail "PROMOTION_REVIEW_JSON_MISSING" }
if (-not (Test-Path -LiteralPath $ReviewMdPath)) { Fail "PROMOTION_REVIEW_MD_MISSING" }
if (-not (Test-Path -LiteralPath $RuntimeValidator)) { Fail "RUNTIME_1000_VALIDATOR_MISSING" }

$runtimeValidation = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RuntimeValidator
if ($LASTEXITCODE -ne 0) {
  Write-Host ($runtimeValidation -join "`n")
  Fail "RUNTIME_1000_VALIDATOR_FAILED"
}

$review = Get-Content -LiteralPath $ReviewJsonPath -Raw | ConvertFrom-Json

if ([string]$review.status -ne "CONTROLLED_RUNTIME_CANDIDATE") { Fail "STATUS_NOT_CONTROLLED_RUNTIME_CANDIDATE" }
if ([string]$review.promoted_from -ne "ACCEPTED_LOCAL") { Fail "PROMOTED_FROM_NOT_ACCEPTED_LOCAL" }
if ([bool]$review.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }

$basisJson = $review.basis | ConvertTo-Json -Depth 20
if ($basisJson -notmatch "EPHEMERAL_CANDIDATE_TO_ATOM_BATCH_100_TRIAL_V1\.json") { Fail "BASIS_BATCH_100_MISSING" }
if ($basisJson -notmatch "EPHEMERAL_CANDIDATE_TO_ATOM_RUNTIME_1000_TRIAL_V1\.json") { Fail "BASIS_RUNTIME_1000_MISSING" }
if ($basisJson -notmatch "AGENTS\.md") { Fail "BASIS_AGENTS_MAP_MISSING" }

$invariants = @($review.invariants | ForEach-Object { [string]$_ })
if (@($invariants | Where-Object { $_ -match "candidate_material.*pruned|successful_candidate_material_must_be_pruned" }).Count -lt 1) {
  Fail "INVARIANT_CANDIDATE_MATERIAL_PRUNE_MISSING"
}
if (@($invariants | Where-Object { $_ -match "work_current.*pruned|work_current_must_be_pruned_after_success" }).Count -lt 1) {
  Fail "INVARIANT_WORK_PRUNE_MISSING"
}
if (@($invariants | Where-Object { $_ -match "failed.*quarantine.*preserved|failed_or_quarantine_traces_must_be_preserved" }).Count -lt 1) {
  Fail "INVARIANT_FAILED_TRACE_PRESERVATION_MISSING"
}

if ([string]::IsNullOrWhiteSpace([string]$review.next_required)) { Fail "NEXT_REQUIRED_MISSING" }
if ([string]$review.next_required -ne "CONTROLLED_RUNTIME_WIRING_OR_STOP_GOVERNED_CONTINUOUS_TRIAL") {
  Fail "NEXT_REQUIRED_UNEXPECTED"
}

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_PROMOTION_REVIEW_V1"
Write-Host "RUNTIME_1000_VALIDATOR=PASS"
Write-Host "RUNTIME_READY=false"
exit 0
