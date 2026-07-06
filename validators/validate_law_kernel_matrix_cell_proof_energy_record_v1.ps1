param(
    [string]$RepoRoot = "",
    [string]$SamplePath = "",
    [string]$ProofPath = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
$RepoRoot = (Resolve-Path $RepoRoot).Path

if (-not $OutputDir) {
    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $RepoRoot "reports\law_kernel_matrix_cell_proof_energy_validator_v1_$Stamp"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$SchemaPath = Join-Path $RepoRoot "contracts\self_development\law_kernel_matrix_cell_proof_energy_record_v1.schema.json"

if (-not $SamplePath -or -not $ProofPath) {
    $RecordDir = Get-ChildItem (Join-Path $RepoRoot "reports") -Directory -Filter "law_kernel_matrix_cell_proof_energy_record_v1_*" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $RecordDir) {
        throw "Record report directory not found."
    }

    if (-not $SamplePath) {
        $SamplePath = Join-Path $RecordDir.FullName "law_kernel_matrix_cell_proof_energy_record_v1.sample.json"
    }
    if (-not $ProofPath) {
        $ProofPath = Join-Path $RecordDir.FullName "LAW_KERNEL_MATRIX_CELL_PROOF_ENERGY_RECORD_V1_PROOF.json"
    }
}

$Checks = @()

function Add-Check {
    param(
        [string]$Name,
        [bool]$Pass,
        [string]$Detail
    )

    $Status = "FAIL"
    if ($Pass) { $Status = "PASS" }

    $script:Checks += [ordered]@{
        name = $Name
        status = $Status
        detail = $Detail
    }
}

function Has-Prop {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $false }
    return ($Obj.PSObject.Properties.Name -contains $Name)
}

$Schema = $null
$Sample = $null
$Proof = $null

try {
    $Schema = Get-Content $SchemaPath -Raw | ConvertFrom-Json
    Add-Check "schema_json_parse" $true $SchemaPath
} catch {
    Add-Check "schema_json_parse" $false $_.Exception.Message
}

try {
    $Sample = Get-Content $SamplePath -Raw | ConvertFrom-Json
    Add-Check "sample_json_parse" $true $SamplePath
} catch {
    Add-Check "sample_json_parse" $false $_.Exception.Message
}

try {
    $Proof = Get-Content $ProofPath -Raw | ConvertFrom-Json
    Add-Check "proof_json_parse" $true $ProofPath
} catch {
    Add-Check "proof_json_parse" $false $_.Exception.Message
}

$RequiredTop = @(
    "record_id",
    "schema_version",
    "created_at",
    "parent_task",
    "gap",
    "matrix_cell",
    "law_bindings",
    "proof_energy",
    "evidence",
    "decision",
    "return_to_parent_task"
)

foreach ($r in $RequiredTop) {
    Add-Check "sample_required_top_$r" (Has-Prop $Sample $r) "top-level required field"
}

Add-Check "schema_version_expected" ($Sample.schema_version -eq "law_kernel_matrix_cell_proof_energy_record.v1") "schema_version must match v1"

$GapTypes = @(
    "concept_gap",
    "procedure_gap",
    "requirement_gap",
    "organ_gap",
    "proof_gap",
    "source_gap",
    "safety_gap",
    "mode_gap"
)
Add-Check "gap_type_enum" ($GapTypes -contains $Sample.gap.gap_type) "gap_type must be known"

$Layers = @("atom", "molecule", "organ", "system", "head", "organism")
Add-Check "matrix_layer_enum" ($Layers -contains $Sample.matrix_cell.layer) "matrix_cell.layer must be known"

$CellStatuses = @(
    "candidate",
    "sandbox_pass",
    "validator_pass",
    "proof_pass",
    "validated_pending_acceptance",
    "accepted_local",
    "quarantined",
    "rollback_required"
)
Add-Check "matrix_status_enum" ($CellStatuses -contains $Sample.matrix_cell.status) "matrix_cell.status must be known"

$ProofEnergyFields = @(
    "memory_proof",
    "use_proof",
    "return_proof",
    "startup_visibility",
    "validation_command"
)

foreach ($p in $ProofEnergyFields) {
    $Exists = Has-Prop $Sample.proof_energy $p
    $NonEmpty = $false
    if ($Exists) {
        $NonEmpty = -not [string]::IsNullOrWhiteSpace([string]$Sample.proof_energy.$p)
    }
    Add-Check "proof_energy_$p" ($Exists -and $NonEmpty) "proof_energy field must exist and be non-empty"
}

$LawBindingCount = 0
if ($Sample.law_bindings) {
    $LawBindingCount = @($Sample.law_bindings).Count
}
Add-Check "law_bindings_non_empty" ($LawBindingCount -ge 1) "at least one law binding required"

$ProofStatuses = @("VALIDATED_PENDING_ACCEPTANCE", "VALIDATOR_PASS", "PROOF_PASS", "ACCEPTED_LOCAL")
Add-Check "proof_status_known" ($ProofStatuses -contains $Proof.status) "proof.status must be known"

$Failed = @($Checks | Where-Object { $_.status -eq "FAIL" })
$ValidatorStatus = "VALIDATOR_PASS"
if ($Failed.Count -gt 0) {
    $ValidatorStatus = "VALIDATOR_FAIL"
}

$Result = [ordered]@{
    validator_id = "validate_law_kernel_matrix_cell_proof_energy_record_v1"
    status = $ValidatorStatus
    created_at = (Get-Date).ToString("o")
    repo_root = $RepoRoot
    schema_path = $SchemaPath
    sample_path = $SamplePath
    proof_path = $ProofPath
    checks = $Checks
    failed_count = $Failed.Count
    codex_used = $false
    live_patch_done = $false
}

$ProofOut = Join-Path $OutputDir "VALIDATE_LAW_KERNEL_MATRIX_CELL_PROOF_ENERGY_RECORD_V1_PROOF.json"
$ReportOut = Join-Path $OutputDir "VALIDATE_LAW_KERNEL_MATRIX_CELL_PROOF_ENERGY_RECORD_V1_REPORT.md"

$Result | ConvertTo-Json -Depth 30 | Set-Content -Path $ProofOut -Encoding UTF8

$Report = @"
# VALIDATE_LAW_KERNEL_MATRIX_CELL_PROOF_ENERGY_RECORD_V1_REPORT

## Status

$ValidatorStatus

## Meaning

This validator binds the accepted local schema atom to a runnable structural proof.

## Inputs

- Schema: $SchemaPath
- Sample: $SamplePath
- Proof: $ProofPath

## Checks

Total checks: $($Checks.Count)
Failed checks: $($Failed.Count)

## Boundary

- Codex used: false
- Live patch done: false
"@

Set-Content -Path $ReportOut -Value $Report -Encoding UTF8

Write-Host "VALIDATOR_STATUS=$ValidatorStatus"
Write-Host "FAILED_COUNT=$($Failed.Count)"
Write-Host "PROOF_OUT=$ProofOut"
Write-Host "REPORT_OUT=$ReportOut"

if ($ValidatorStatus -ne "VALIDATOR_PASS") {
    throw "VALIDATOR_FAIL"
}
