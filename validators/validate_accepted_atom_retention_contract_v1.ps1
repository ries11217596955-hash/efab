$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$Required = @(
    "contracts/accepted_atom_retention_organ/ACCEPTED_ATOM_RETENTION_ORGAN_CONTRACT.md",
    "schemas/accepted_atom_retention/accepted_atom_receipt_v1.schema.json",
    "schemas/accepted_atom_retention/batch_manifest_v1.schema.json",
    "tests/accepted_atom_retention/fixture_accepted_atom_receipt_v1.json"
)

foreach ($p in $Required) {
    if (-not (Test-Path $p)) {
        Write-Host "FAIL=MISSING_$p"
        exit 1
    }
}

Get-Content "schemas/accepted_atom_retention/accepted_atom_receipt_v1.schema.json" -Raw | ConvertFrom-Json | Out-Null
Get-Content "schemas/accepted_atom_retention/batch_manifest_v1.schema.json" -Raw | ConvertFrom-Json | Out-Null
Get-Content "tests/accepted_atom_retention/fixture_accepted_atom_receipt_v1.json" -Raw | ConvertFrom-Json | Out-Null

$Contract = Get-Content "contracts/accepted_atom_retention_organ/ACCEPTED_ATOM_RETENTION_ORGAN_CONTRACT.md" -Raw

$Needles = @(
    "A successful atom is fuel, not archive.",
    "CompactAccepted",
    "QuarantineTrace",
    "Organ Passport",
    "Sanitizer Passport",
    "Proof Passport"
)

foreach ($n in $Needles) {
    if (-not $Contract.Contains($n)) {
        Write-Host "FAIL=CONTRACT_MISSING_$n"
        exit 1
    }
}

$Total = (Get-ChildItem $Repo -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
if ($Total -gt 20MB) {
    Write-Host "FAIL=THIN_REPO_SIZE_BUDGET_EXCEEDED bytes=$Total"
    exit 1
}

Write-Host "VALIDATION_PASS=ACCEPTED_ATOM_RETENTION_CONTRACT_V1"
Write-Host "RUNTIME_READY=false"
exit 0
