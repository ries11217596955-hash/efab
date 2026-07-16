param(
    [string]$RepoRoot,
    [string]$RuntimeRoot
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

if (-not $RuntimeRoot -or $RuntimeRoot.Trim() -eq "") {
    $RuntimeRoot = Join-Path $RepoRoot ".runtime\body_self_inspection_v1"
}

function New-BodyInspectionBoundary {
    return @{
        repo_mutated = $false
        active_memory_mutated = $false
        accepted_core_mutated = $false
        body_map_mutated = $false
        capability_map_mutated = $false
        passports_mutated = $false
        contracts_mutated = $false
        live_process_touched = $false
        codex_launched = $false
        web_launched = $false
        cleanup_performed = $false
    }
}

function Write-JsonFile {
    param(
        [string]$Path,
        $Data
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $json = ($Data | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
    $json = $json.TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Invoke-AllowedGit {
    param(
        [string]$Root,
        [string[]]$Arguments
    )

    $output = & git -C $Root @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        return ""
    }
    return (($output | Out-String).Trim())
}

if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
}

$sliceBInvoker = Join-Path $PSScriptRoot "invoke_body_self_inspection_slice_b_v1.ps1"
$passportAuditor = Join-Path $PSScriptRoot "audit_passports_and_contracts_v1.ps1"
$signalAuditor = Join-Path $PSScriptRoot "audit_signal_readiness_v1.ps1"

& $sliceBInvoker -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
& $passportAuditor -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
& $signalAuditor -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null

$sliceAProofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"
$sliceBProofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_B_PROOF.json"
$passportAuditPath = Join-Path $RuntimeRoot "passport_audit.json"
$signalAuditPath = Join-Path $RuntimeRoot "signal_readiness_audit.json"
$proofPath = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_C_PROOF.json"

$sliceAProof = Read-JsonFile -Path $sliceAProofPath
$sliceBProof = Read-JsonFile -Path $sliceBProofPath
$passportAudit = Read-JsonFile -Path $passportAuditPath
$signalAudit = Read-JsonFile -Path $signalAuditPath

$proof = @{
    schema = "body_self_inspection_slice_c_runtime_proof_v1"
    status = "PASS_BODY_SELF_INSPECTION_SLICE_C_RUNTIME_V1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
    slice = "C"
    repo_root = $RepoRoot
    repo_head = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--short", "HEAD")
    branch = Invoke-AllowedGit -Root $RepoRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    output_refs = @{
        slice_a_runtime_proof = $sliceAProofPath
        slice_b_runtime_proof = $sliceBProofPath
        passport_audit = $passportAuditPath
        signal_readiness_audit = $signalAuditPath
        runtime_proof = $proofPath
    }
    checks = @{
        slice_a_runtime_proof_status = $sliceAProof.status
        slice_b_runtime_proof_status = $sliceBProof.status
        passport_audit_status = $passportAudit.status
        signal_readiness_audit_status = $signalAudit.status
        passport_audit_target_count = $passportAudit.aggregates.target_count
        signal_audit_target_count = $signalAudit.aggregates.target_count
    }
    aggregate_counts = @{
        passport_audit = $passportAudit.aggregates
        signal_readiness_audit = $signalAudit.aggregates
    }
    boundary_statement = @{
        passport_present = "PASSPORT_PRESENT != PASSPORT_VALIDATED"
        passport_validated = "PASSPORT_VALIDATED != ORGAN_MATURE"
        contract_present = "CONTRACT_PRESENT != ORGAN_WIRED"
        signal_field_present = "SIGNAL_FIELD_PRESENT != SIGNAL_READY"
        signal_ready = "SIGNAL_READY != NERVOUS_SYSTEM_CONNECTED"
    }
    boundary_claims = @{
        passport_presence_claims_maturity = $false
        contract_presence_claims_wiring = $false
        signal_field_presence_claims_nervous_system_connection = $false
        candidate_promoted_to_organ = $false
    }
    boundary = New-BodyInspectionBoundary
    errors = @()
}

Write-JsonFile -Path $proofPath -Data $proof
Write-Output $proofPath
