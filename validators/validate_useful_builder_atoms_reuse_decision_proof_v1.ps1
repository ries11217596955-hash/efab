$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/USEFUL_BUILDER_ATOMS_REUSE_DECISION_PROOF_V1.json"
$RunnerPath = "tests/accepted_atom_retention/run_useful_builder_atoms_reuse_decision_proof_v1.ps1"
$SourceProofPath = "tests/accepted_atom_retention/USEFUL_BUILDER_ATOMS_DURABLE_RETRIEVAL_100_PROOF_V1.json"
$MatrixPath = "tests/accepted_atom_retention/RETENTION_PROOF_PATH_MATRIX_V1.json"
$ValidatorPath = "validators/validate_useful_builder_atoms_reuse_decision_proof_v1.ps1"
$AllowedDirtyPaths = @(
    $RunnerPath,
    $ProofPath,
    $ValidatorPath
)
$AllowedProofLabels = @(
    "CODEX_DRAFT",
    "PROVEN_LAB",
    "PROVEN_LIVE",
    "NOT_PROVEN",
    "BLOCKED_PREFLIGHT",
    "OWNER_DECISION_REQUIRED",
    "CONTEXT_MISMATCH",
    "NOT_IMPLEMENTED"
)
$RequiredThemes = @(
    "Codex draft without terminal proof",
    "PREFLIGHT violation",
    "GitHub main vs thin-control mismatch",
    "lab proof vs runtime_ready",
    "failed legacy 1000 path",
    "old 5k/30k used as current proof",
    "wrong X/context mismatch",
    "silent terminal output",
    "Git pack lock",
    "commit+push single-block mistake",
    "receipts treated as semantic memory",
    "durable store under cleanup-pruned root",
    "active stubs promoted silently",
    "Codex as brain",
    "Bridge/tool as policy brain",
    "missing validator for organ",
    "300k before reuse proof",
    "duplicate runtime/hidden mutation",
    "raw archive as active settings",
    "owner asks shortcut skipping proof"
)
$RequiredDomains = @(
    "evidence_and_acceptance",
    "live_lab_boundary",
    "codex_boundary",
    "retention_and_memory",
    "organ_construction",
    "path_selection",
    "input_x_restore",
    "runtime_safety",
    "settings_governance",
    "owner_guidance"
)

function Fail {
    param([string]$Code)
    Write-Host "FAIL=$Code"
    exit 1
}

function Normalize-GitPath {
    param([string]$Line)
    if ($Line.Length -lt 4) { return $Line.Trim() }
    return ($Line.Substring(3).Trim() -replace "\\","/")
}

foreach ($path in @($ProofPath,$RunnerPath,$SourceProofPath,$MatrixPath)) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "MISSING_$path" }
}

$status = @(git status --short)
$unexpected = @($status | Where-Object {
    $path = Normalize-GitPath -Line ([string]$_)
    $AllowedDirtyPaths -notcontains $path
})
if ($unexpected.Count -ne 0) { Fail ("UNEXPECTED_GIT_STATUS=" + ($unexpected -join ";")) }

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
$sourceProof = Get-Content -LiteralPath $SourceProofPath -Raw | ConvertFrom-Json
$matrix = Get-Content -LiteralPath $MatrixPath -Raw | ConvertFrom-Json

if ($p.schema -ne "useful_builder_atoms_reuse_decision_proof_v1") { Fail "SCHEMA" }
if ($p.status -ne "PASS") { Fail "STATUS" }
if ($p.final_status -ne "USEFUL_BUILDER_ATOMS_REUSE_DECISION_PROVEN") { Fail "FINAL_STATUS" }
if ([bool]$p.runtime_ready -ne $false) { Fail "RUNTIME_READY_OVERCLAIM" }
if ([bool]$p.no_runtime_ready_overclaim -ne $true) { Fail "NO_RUNTIME_READY_OVERCLAIM" }
if ([int]$p.proven_live_claim_count -ne 0) { Fail "PROVEN_LIVE_CLAIM_COUNT" }
if (@($p.proven_live_claims).Count -ne 0) { Fail "PROVEN_LIVE_CLAIMS_NOT_EMPTY" }
if ([bool]$p.active_stubs_unchanged -ne $true) { Fail "ACTIVE_STUBS_UNCHANGED" }
if ([bool]$p.module_files_changed -ne $false) { Fail "MODULE_FILES_CHANGED" }
if ([bool]$p.protected_files_changed -ne $false) { Fail "PROTECTED_FILES_CHANGED" }

if ($p.source_proof_path -ne $SourceProofPath) { Fail "SOURCE_PROOF_PATH" }
if ($sourceProof.schema -ne "useful_builder_atoms_durable_retrieval_100_proof_v1") { Fail "SOURCE_SCHEMA" }
if ($sourceProof.status -ne "PASS") { Fail "SOURCE_STATUS" }
if ($sourceProof.final_status -ne "USEFUL_BUILDER_ATOMS_DURABLE_RETRIEVAL_100_PROVEN") { Fail "SOURCE_FINAL_STATUS" }
if ([int]$sourceProof.total_atom_count -ne 100) { Fail "SOURCE_TOTAL_ATOM_COUNT" }
if ([int]$sourceProof.unique_atom_id_count -ne 100) { Fail "SOURCE_UNIQUE_ATOM_ID_COUNT" }
if ([int]$sourceProof.domain_count -lt 10) { Fail "SOURCE_DOMAIN_COUNT" }
if ([bool]$sourceProof.runtime_ready -ne $false) { Fail "SOURCE_RUNTIME_READY" }
if ($matrix.schema -ne "retention_proof_path_matrix_v1") { Fail "MATRIX_SCHEMA" }
if ([bool]$matrix.runtime_ready -ne $false) { Fail "MATRIX_RUNTIME_READY" }
if ($matrix.canonical_lane -ne "small_scale_durable_compact_store_integration_proof") { Fail "MATRIX_CANONICAL_LANE" }

$scenarios = @($p.scenarios)
if ([int]$p.scenario_count -ne 20) { Fail "SCENARIO_COUNT_FIELD" }
if ($scenarios.Count -ne 20) { Fail "SCENARIO_COUNT" }

$themes = @($scenarios | ForEach-Object { [string]$_.theme })
foreach ($theme in $RequiredThemes) {
    if ($themes -notcontains $theme) { Fail "MISSING_THEME_$theme" }
}
if (@($themes | Select-Object -Unique).Count -ne 20) { Fail "DUPLICATE_THEME" }

$passScenarios = @($scenarios | Where-Object { $_.scenario_status -eq "PASS" })
if ([int]$p.pass_scenario_count -ne 20) { Fail "PASS_SCENARIO_COUNT_FIELD" }
if ($passScenarios.Count -ne 20) { Fail "PASS_SCENARIO_COUNT" }

$calculatedAtomIds = @()
$calculatedDomains = @()
$decisionChangedOrGuardedCount = 0
foreach ($scenario in $scenarios) {
    if ([string]::IsNullOrWhiteSpace([string]$scenario.scenario_id)) { Fail "SCENARIO_ID_EMPTY" }
    if ([string]$scenario.scenario_status -ne "PASS") { Fail "SCENARIO_STATUS_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.input_case)) { Fail "INPUT_CASE_EMPTY_$($scenario.scenario_id)" }
    if ($null -eq $scenario.retrieval_query) { Fail "RETRIEVAL_QUERY_EMPTY_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.retrieval_mode)) { Fail "RETRIEVAL_MODE_EMPTY_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.scenario_proof_id)) { Fail "SCENARIO_PROOF_ID_EMPTY_$($scenario.scenario_id)" }
    if ([string]$scenario.scenario_proof_id -ne "USEFUL_BUILDER_ATOMS_REUSE_DECISION_$($scenario.scenario_id)") { Fail "SCENARIO_PROOF_ID_VALUE_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.proof_label)) { Fail "PROOF_LABEL_EMPTY_$($scenario.scenario_id)" }
    if ($AllowedProofLabels -notcontains [string]$scenario.proof_label) { Fail "PROOF_LABEL_NOT_ALLOWED_$($scenario.scenario_id)" }
    if ([string]$scenario.proof_label -eq "PROVEN_LIVE") { Fail "PROOF_LABEL_PROVEN_LIVE_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.naive_or_unsafe_decision)) { Fail "NAIVE_DECISION_EMPTY_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.governed_decision)) { Fail "GOVERNED_DECISION_EMPTY_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.expected_decision)) { Fail "EXPECTED_DECISION_EMPTY_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.allowed_next_action)) { Fail "ALLOWED_NEXT_ACTION_EMPTY_$($scenario.scenario_id)" }
    if ([string]::IsNullOrWhiteSpace([string]$scenario.blocked_action)) { Fail "BLOCKED_ACTION_EMPTY_$($scenario.scenario_id)" }
    if ([string]$scenario.naive_or_unsafe_decision -eq [string]$scenario.governed_decision) { Fail "DECISION_NOT_CHANGED_$($scenario.scenario_id)" }
    if ([string]$scenario.expected_decision -ne [string]$scenario.governed_decision) { Fail "EXPECTED_DECISION_MISMATCH_$($scenario.scenario_id)" }
    if ([bool]$scenario.decision_changed_or_guarded -ne $true) { Fail "DECISION_CHANGED_OR_GUARDED_$($scenario.scenario_id)" }
    $decisionChangedOrGuardedCount++

    $scenarioAtomIds = @($scenario.retrieved_atom_ids | ForEach-Object { [string]$_ })
    $scenarioDomains = @($scenario.retrieved_domains | ForEach-Object { [string]$_ })
    $scenarioConcepts = @($scenario.retrieved_concepts | ForEach-Object { [string]$_ })
    $applied = @($scenario.applied_rules)
    if ($scenarioAtomIds.Count -lt 2) { Fail "RETRIEVED_ATOM_IDS_COUNT_$($scenario.scenario_id)" }
    if ($scenarioDomains.Count -lt 1) { Fail "RETRIEVED_DOMAINS_COUNT_$($scenario.scenario_id)" }
    if ($scenarioConcepts.Count -lt 1) { Fail "RETRIEVED_CONCEPTS_COUNT_$($scenario.scenario_id)" }
    if ($applied.Count -lt 2) { Fail "APPLIED_RULE_COUNT_$($scenario.scenario_id)" }
    if (@($scenarioAtomIds | Select-Object -Unique).Count -ne $scenarioAtomIds.Count) { Fail "DUPLICATE_RETRIEVED_ATOM_$($scenario.scenario_id)" }
    foreach ($atomId in $scenarioAtomIds) {
        if ([string]::IsNullOrWhiteSpace($atomId)) { Fail "ATOM_ID_EMPTY_$($scenario.scenario_id)" }
        if (-not $atomId.StartsWith("builder.")) { Fail "ATOM_ID_PREFIX_$($scenario.scenario_id)" }
        $calculatedAtomIds += $atomId
    }
    foreach ($domain in $scenarioDomains) {
        if ([string]::IsNullOrWhiteSpace($domain)) { Fail "ATOM_DOMAIN_EMPTY_$($scenario.scenario_id)" }
        $calculatedDomains += $domain
    }
    foreach ($rule in $applied) {
        if ($scenarioAtomIds -notcontains [string]$rule.atom_id) { Fail "APPLIED_RULE_NOT_RETRIEVED_$($scenario.scenario_id)" }
        if ([string]::IsNullOrWhiteSpace([string]$rule.rule_application)) { Fail "RULE_APPLICATION_EMPTY_$($scenario.scenario_id)" }
    }
    if ([bool]$scenario.proof.retrieval_pass -ne $true) { Fail "SCENARIO_RETRIEVAL_PASS_$($scenario.scenario_id)" }
    if ([bool]$scenario.proof.decision_application_pass -ne $true) { Fail "SCENARIO_DECISION_APPLICATION_PASS_$($scenario.scenario_id)" }
    if ([int]$scenario.proof.retrieved_atom_count -lt 2) { Fail "SCENARIO_PROOF_RETRIEVED_COUNT_$($scenario.scenario_id)" }
    if ([int]$scenario.proof.applied_rule_count -lt 2) { Fail "SCENARIO_PROOF_APPLIED_COUNT_$($scenario.scenario_id)" }
}

$uniqueAtomIds = @($calculatedAtomIds | Select-Object -Unique)
$uniqueDomains = @($calculatedDomains | Select-Object -Unique)
if ([int]$p.unique_atom_id_used_count -ne $uniqueAtomIds.Count) { Fail "UNIQUE_ATOM_ID_USED_COUNT_FIELD" }
if ($uniqueAtomIds.Count -lt 10) { Fail "UNIQUE_ATOM_ID_USED_COUNT_MIN" }
if ([int]$p.domain_used_count -ne $uniqueDomains.Count) { Fail "DOMAIN_USED_COUNT_FIELD" }
if ($uniqueDomains.Count -lt 10) { Fail "DOMAIN_USED_COUNT_MIN" }
foreach ($domain in $RequiredDomains) {
    if ($uniqueDomains -notcontains $domain) { Fail "REQUIRED_DOMAIN_MISSING_$domain" }
}
if ([int]$p.decision_changed_or_guarded_count -ne 20) { Fail "DECISION_CHANGED_OR_GUARDED_COUNT_FIELD" }
if ($decisionChangedOrGuardedCount -ne 20) { Fail "DECISION_CHANGED_OR_GUARDED_COUNT" }
if ($p.retrieval_status -ne "PASS") { Fail "RETRIEVAL_STATUS" }
if ($p.decision_application_status -ne "PASS") { Fail "DECISION_APPLICATION_STATUS" }

$protectedStatus = @(git status --short -- reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/accepted_change_memory_snapshot.json packs/registry.json)
if ($protectedStatus.Count -ne 0) { Fail "ACTIVE_STUBS_MUTATED" }

Write-Host "VALIDATION_PASS=USEFUL_BUILDER_ATOMS_REUSE_DECISION_PROVEN"
Write-Host "SCENARIO_COUNT=$($p.scenario_count)"
Write-Host "PASS_SCENARIO_COUNT=$($p.pass_scenario_count)"
Write-Host "UNIQUE_ATOM_ID_USED_COUNT=$($p.unique_atom_id_used_count)"
Write-Host "DOMAIN_USED_COUNT=$($p.domain_used_count)"
Write-Host "DECISION_CHANGED_OR_GUARDED_COUNT=$($p.decision_changed_or_guarded_count)"
Write-Host "RETRIEVAL_STATUS=$($p.retrieval_status)"
Write-Host "DECISION_APPLICATION_STATUS=$($p.decision_application_status)"
Write-Host "PROVEN_LIVE_CLAIM_COUNT=$($p.proven_live_claim_count)"
Write-Host "RUNTIME_READY=false"
exit 0
