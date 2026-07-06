$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/USEFUL_KNOWLEDGE_LADDER_5000_PROOF_V1.json"
$RunnerPath = "tests/accepted_atom_retention/run_useful_knowledge_ladder_5000_proof_v1.ps1"
$GeneratorPath = "modules/invoke_useful_knowledge_ladder_candidate_generator_v1.ps1"
$Durable100ProofPath = "tests/accepted_atom_retention/USEFUL_BUILDER_ATOMS_DURABLE_RETRIEVAL_100_PROOF_V1.json"
$ReuseDecisionProofPath = "tests/accepted_atom_retention/USEFUL_BUILDER_ATOMS_REUSE_DECISION_PROOF_V1.json"
$AllowedDirtyPaths = @($GeneratorPath, $RunnerPath, $ProofPath, "validators/validate_useful_knowledge_ladder_5000_proof_v1.ps1")
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
$AllowedProofLabels = @("CODEX_DRAFT","PROVEN_LAB","NOT_PROVEN","BLOCKED_PREFLIGHT","OWNER_DECISION_REQUIRED","CONTEXT_MISMATCH","NOT_IMPLEMENTED")

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

function Assert-NonEmptyField {
    param($Object, [string]$Field, [string]$Code)
    if (-not ($Object.PSObject.Properties.Name -contains $Field)) { Fail $Code }
    if ([string]::IsNullOrWhiteSpace([string]$Object.PSObject.Properties[$Field].Value)) { Fail $Code }
}

function Test-PlaceholderOrCounterOnlyAtom {
    param($Atom)
    $joined = @(
        [string]$Atom.concept,
        [string]$Atom.trigger,
        [string]$Atom.rule,
        [string]$Atom.anti_pattern,
        [string]$Atom.decision_use,
        [string]$Atom.validator_hint
    ) -join " "
    if ($joined -match "(?i)\bplaceholder\b|\bcounter-only\b|\bdummy\b|\blorem\b|\btodo\b") { return $true }
    if (([string]$Atom.rule).Length -lt 80) { return $true }
    if (([string]$Atom.decision_use).Length -lt 80) { return $true }
    if (([string]$Atom.trigger).Length -lt 60) { return $true }
    return $false
}

foreach ($path in @($ProofPath,$RunnerPath,$GeneratorPath,$Durable100ProofPath,$ReuseDecisionProofPath)) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "MISSING_$path" }
}

$status = @(git status --short)
$unexpected = @($status | Where-Object {
    $path = Normalize-GitPath -Line ([string]$_)
    $AllowedDirtyPaths -notcontains $path
})
if ($unexpected.Count -ne 0) { Fail ("UNEXPECTED_GIT_STATUS=" + ($unexpected -join ";")) }

$generatorText = Get-Content -LiteralPath $GeneratorPath -Raw
if ($generatorText -match "\b5000\b") { Fail "N_SPECIFIC_LIMIT_IN_GENERATOR" }

$p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
$durable100 = Get-Content -LiteralPath $Durable100ProofPath -Raw | ConvertFrom-Json
$reuseDecision = Get-Content -LiteralPath $ReuseDecisionProofPath -Raw | ConvertFrom-Json

if ($p.schema -ne "useful_knowledge_ladder_5000_proof_v1") { Fail "SCHEMA" }
if ($p.status -ne "PASS") { Fail "STATUS" }
if ($p.final_status -ne "USEFUL_KNOWLEDGE_LADDER_5000_PROVEN") { Fail "FINAL_STATUS" }
if ([int]$p.target_accepted_count -ne 5000) { Fail "TARGET_ACCEPTED_COUNT" }
if ([int]$p.candidate_count -lt 5500) { Fail "CANDIDATE_COUNT" }
if ([int]$p.accepted_count -ne 5000) { Fail "ACCEPTED_COUNT" }
if ([int]$p.rejected_count -lt 300) { Fail "REJECTED_COUNT" }
if ([int]$p.duplicate_rejected_count -le 0) { Fail "DUPLICATE_REJECTED_COUNT" }
if ([int]$p.low_quality_rejected_count -le 0) { Fail "LOW_QUALITY_REJECTED_COUNT" }
if ([int]$p.conflict_or_unsafe_rejected_count -le 0) { Fail "CONFLICT_OR_UNSAFE_REJECTED_COUNT" }
if ([int]$p.unique_atom_id_count -ne 5000) { Fail "UNIQUE_ATOM_ID_COUNT" }
if ([int]$p.domain_count -ne 10) { Fail "DOMAIN_COUNT" }
if ([int]$p.ladder_level_count -ne 10) { Fail "LADDER_LEVEL_COUNT" }
if ([int]$p.durable_record_count -ne 5000) { Fail "DURABLE_RECORD_COUNT" }
if ([int]$p.compact_receipt_count -ne 5000) { Fail "COMPACT_RECEIPT_COUNT" }
if ($p.retrieval_status -ne "PASS") { Fail "RETRIEVAL_STATUS" }
if ($p.retrieval_by_atom_id_status -ne "PASS") { Fail "RETRIEVAL_BY_ATOM_ID_STATUS" }
if ($p.retrieval_by_domain_status -ne "PASS") { Fail "RETRIEVAL_BY_DOMAIN_STATUS" }
if ($p.retrieval_by_concept_status -ne "PASS") { Fail "RETRIEVAL_BY_CONCEPT_STATUS" }
if ($p.retrieval_by_tag_status -ne "PASS") { Fail "RETRIEVAL_BY_TAG_STATUS" }
if ($p.retrieval_by_ladder_level_status -ne "PASS") { Fail "RETRIEVAL_BY_LADDER_LEVEL_STATUS" }
if ($p.decision_reuse_sample_status -ne "PASS") { Fail "DECISION_REUSE_SAMPLE_STATUS" }
if ([int]$p.decision_scenario_count -lt 50) { Fail "DECISION_SCENARIO_COUNT" }
if ([int]$p.decision_changed_or_guarded_count -ne [int]$p.decision_scenario_count) { Fail "DECISION_CHANGED_OR_GUARDED_COUNT" }
if ($p.cleanup_survival_status -ne "PASS") { Fail "CLEANUP_SURVIVAL_STATUS" }
if ([bool]$p.runtime_bounded -ne $true) { Fail "RUNTIME_BOUNDED" }
if ([bool]$p.active_stubs_unchanged -ne $true) { Fail "ACTIVE_STUBS_UNCHANGED" }
if ([bool]$p.no_runtime_ready_overclaim -ne $true) { Fail "NO_RUNTIME_READY_OVERCLAIM" }
if ([bool]$p.runtime_ready -ne $false) { Fail "RUNTIME_READY" }
if ([bool]$p.n_specific_organ_limit_detected -ne $false) { Fail "N_SPECIFIC_ORGAN_LIMIT_DETECTED" }
if ([bool]$durable100.runtime_ready -ne $false) { Fail "DURABLE100_RUNTIME_READY" }
if ([bool]$reuseDecision.runtime_ready -ne $false) { Fail "REUSE_DECISION_RUNTIME_READY" }

$acceptedAtoms = @($p.accepted_atoms)
if ($acceptedAtoms.Count -ne 5000) { Fail "ACCEPTED_ATOMS_ARRAY_COUNT" }
$atomIds = @()
foreach ($atom in $acceptedAtoms) {
    foreach ($field in @("atom_id","domain","ladder_level","concept","trigger","rule","anti_pattern","decision_use","validator_hint","source_type")) {
        Assert-NonEmptyField -Object $atom -Field $field -Code "ACCEPTED_ATOM_FIELD_$field"
    }
    if (@($atom.reuse_tags).Count -lt 3) { Fail "ACCEPTED_ATOM_REUSE_TAGS" }
    if (Test-PlaceholderOrCounterOnlyAtom -Atom $atom) { Fail "PLACEHOLDER_OR_COUNTER_ONLY_ATOM_$($atom.atom_id)" }
    $atomIds += [string]$atom.atom_id
}
if (@($atomIds | Select-Object -Unique).Count -ne 5000) { Fail "ACCEPTED_ATOM_ID_UNIQUENESS" }

$domainGroups = @($acceptedAtoms | Group-Object domain)
$levelGroups = @($acceptedAtoms | Group-Object ladder_level)
if ($domainGroups.Count -ne 10) { Fail "ACCEPTED_DOMAIN_GROUP_COUNT" }
if ($levelGroups.Count -ne 10) { Fail "ACCEPTED_LADDER_LEVEL_GROUP_COUNT" }
foreach ($domain in $RequiredDomains) {
    $domainGroup = @($domainGroups | Where-Object { $_.Name -eq $domain })
    if ($domainGroup.Count -ne 1) { Fail "DOMAIN_MISSING_$domain" }
    if ([int]$domainGroup[0].Count -ne 500) { Fail "DOMAIN_ACCEPTED_COUNT_$domain" }
    if (-not ($p.per_domain_accepted_count.PSObject.Properties.Name -contains $domain)) { Fail "PER_DOMAIN_FIELD_$domain" }
    if ([int]$p.per_domain_accepted_count.PSObject.Properties[$domain].Value -ne 500) { Fail "PER_DOMAIN_COUNT_$domain" }
}
foreach ($level in 1..10) {
    $levelGroup = @($levelGroups | Where-Object { [int]$_.Name -eq $level })
    if ($levelGroup.Count -ne 1) { Fail "LADDER_LEVEL_MISSING_$level" }
    if ([int]$levelGroup[0].Count -ne 500) { Fail "LADDER_LEVEL_ACCEPTED_COUNT_$level" }
}

$durableRecords = @($p.durable_records)
$compactReceipts = @($p.compact_receipts)
if ($durableRecords.Count -ne 5000) { Fail "DURABLE_RECORD_ARRAY_COUNT" }
if ($compactReceipts.Count -ne 5000) { Fail "COMPACT_RECEIPT_ARRAY_COUNT" }
foreach ($receipt in $compactReceipts | Select-Object -First 50) {
    if ([string]$receipt.retained_trace -ne "compact_receipt_only") { Fail "COMPACT_RECEIPT_TRACE" }
    if ([string]::IsNullOrWhiteSpace([string]$receipt.atom_id)) { Fail "COMPACT_RECEIPT_ATOM_ID" }
}

foreach ($domainProof in @($p.retrieval_proof.by_domain)) {
    if ($domainProof.status -ne "PASS") { Fail "RETRIEVAL_DOMAIN_STATUS_$($domainProof.domain)" }
    if ([int]$domainProof.count -ne 500) { Fail "RETRIEVAL_DOMAIN_COUNT_$($domainProof.domain)" }
}
foreach ($levelProof in @($p.retrieval_proof.by_ladder_level)) {
    if ($levelProof.status -ne "PASS") { Fail "RETRIEVAL_LEVEL_STATUS_$($levelProof.ladder_level)" }
    if ([int]$levelProof.count -ne 500) { Fail "RETRIEVAL_LEVEL_COUNT_$($levelProof.ladder_level)" }
}
foreach ($tagProof in @($p.retrieval_proof.by_tag)) {
    if ($tagProof.status -ne "PASS") { Fail "RETRIEVAL_TAG_STATUS_$($tagProof.tag)" }
    if ([int]$tagProof.count -lt 5000) { Fail "RETRIEVAL_TAG_COUNT_$($tagProof.tag)" }
}

$scenarios = @($p.decision_scenarios)
if ($scenarios.Count -lt 50) { Fail "DECISION_SCENARIO_ARRAY_COUNT" }
$changedCount = 0
foreach ($scenario in $scenarios) {
    foreach ($field in @("scenario_id","input_case","naive_or_unsafe_decision","governed_decision","proof_label","allowed_next_action","blocked_action")) {
        Assert-NonEmptyField -Object $scenario -Field $field -Code "SCENARIO_FIELD_$field"
    }
    if (@($scenario.retrieved_atom_ids).Count -lt 5) { Fail "SCENARIO_RETRIEVED_ATOM_IDS_$($scenario.scenario_id)" }
    if (@($scenario.retrieved_domains).Count -lt 1) { Fail "SCENARIO_RETRIEVED_DOMAINS_$($scenario.scenario_id)" }
    if (@($scenario.applied_rules).Count -lt 5) { Fail "SCENARIO_APPLIED_RULES_$($scenario.scenario_id)" }
    if ([string]$scenario.naive_or_unsafe_decision -eq [string]$scenario.governed_decision) { Fail "SCENARIO_DECISION_NOT_CHANGED_$($scenario.scenario_id)" }
    if ([bool]$scenario.decision_changed_or_guarded -ne $true) { Fail "SCENARIO_DECISION_CHANGED_$($scenario.scenario_id)" }
    if ($AllowedProofLabels -notcontains [string]$scenario.proof_label) { Fail "SCENARIO_PROOF_LABEL_$($scenario.scenario_id)" }
    if ([string]$scenario.proof_label -eq "PROVEN_LIVE") { Fail "SCENARIO_PROVEN_LIVE_$($scenario.scenario_id)" }
    $changedCount++
}
if ($changedCount -ne [int]$p.decision_changed_or_guarded_count) { Fail "SCENARIO_CHANGED_COUNT" }

$protectedStatus = @(git status --short -- reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/accepted_change_memory_snapshot.json packs/registry.json)
if ($protectedStatus.Count -ne 0) { Fail "PROTECTED_ACTIVE_STUBS_CHANGED" }

Write-Host "VALIDATION_PASS=USEFUL_KNOWLEDGE_LADDER_5000_PROVEN"
Write-Host "CANDIDATE_COUNT=$($p.candidate_count)"
Write-Host "ACCEPTED_COUNT=$($p.accepted_count)"
Write-Host "REJECTED_COUNT=$($p.rejected_count)"
Write-Host "DURABLE_RECORD_COUNT=$($p.durable_record_count)"
Write-Host "COMPACT_RECEIPT_COUNT=$($p.compact_receipt_count)"
Write-Host "DOMAIN_COUNT=$($p.domain_count)"
Write-Host "LADDER_LEVEL_COUNT=$($p.ladder_level_count)"
Write-Host "DECISION_SCENARIO_COUNT=$($p.decision_scenario_count)"
Write-Host "RETRIEVAL_STATUS=$($p.retrieval_status)"
Write-Host "DECISION_REUSE_SAMPLE_STATUS=$($p.decision_reuse_sample_status)"
Write-Host "RUNTIME_READY=false"
exit 0
