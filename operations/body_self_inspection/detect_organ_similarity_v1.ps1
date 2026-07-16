param(
    [string]$RepoRoot,
    [string]$RuntimeRoot,
    [string]$CandidatePath,
    [string]$BodyMapPath,
    [string]$CapabilityMapPath
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

if (-not $CandidatePath -or $CandidatePath.Trim() -eq "") {
    $CandidatePath = Join-Path $RuntimeRoot "organ_candidates.json"
}
if (-not $BodyMapPath -or $BodyMapPath.Trim() -eq "") {
    $BodyMapPath = Join-Path $RuntimeRoot "body_map_read.json"
}
if (-not $CapabilityMapPath -or $CapabilityMapPath.Trim() -eq "") {
    $CapabilityMapPath = Join-Path $RuntimeRoot "capability_map_read.json"
}

function New-BodyInspectionBoundary {
    return @{
        repo_mutated = $false
        active_memory_mutated = $false
        accepted_core_mutated = $false
        body_map_mutated = $false
        capability_map_mutated = $false
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

    $json = ($Data | ConvertTo-Json -Depth 80) -replace "`r`n", "`n"
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

function Get-NormalizedId {
    param([string]$Text)

    if (-not $Text) {
        return "unknown"
    }
    $value = $Text.ToLowerInvariant()
    $value = $value -replace "\\", "/"
    $value = $value -replace "\.[a-z0-9]+$", ""
    $value = $value -replace "[^a-z0-9]+", "_"
    $value = $value.Trim("_")
    while ($value.Contains("__")) {
        $value = $value.Replace("__", "_")
    }
    if (-not $value) {
        return "unknown"
    }
    return $value
}

function Add-UniqueString {
    param(
        [ref]$List,
        [string]$Value
    )

    if (-not $Value -or $Value.Trim() -eq "") {
        return
    }

    $text = $Value.Trim()
    foreach ($existing in @($List.Value)) {
        if ([string]$existing -eq $text) {
            return
        }
    }
    $List.Value += $text
}

function Get-Tokens {
    param([string]$Text)

    $tokens = @()
    $normalized = Get-NormalizedId -Text $Text
    foreach ($token in @($normalized -split "_")) {
        if ($token.Length -ge 4 -and @("body", "self", "slice", "proof", "validate", "candidate", "organ", "runtime", "tool") -notcontains $token) {
            Add-UniqueString -List ([ref]$tokens) -Value $token
        }
    }
    return $tokens
}

function Get-SharedTokens {
    param(
        [array]$A,
        [array]$B
    )

    $shared = @()
    foreach ($token in @($A)) {
        if (@($B) -contains $token) {
            Add-UniqueString -List ([ref]$shared) -Value $token
        }
    }
    return $shared
}

function New-SubjectFromCandidate {
    param($Candidate)

    return @{
        subject_id = [string]$Candidate.candidate_id
        subject_type = "REPO_ORGAN_CANDIDATE"
        name = [string]$Candidate.name_guess
        capability = [string]$Candidate.capability_guess
        family_root = [string]$Candidate.family_root
        primary_path = [string]$Candidate.primary_path
        candidate_type = [string]$Candidate.candidate_type
        has_contract_ref = [bool]$Candidate.has_contract_ref
        has_passport_ref = [bool]$Candidate.has_passport_ref
        has_validator_ref = [bool]$Candidate.has_validator_ref
        has_proof_ref = [bool]$Candidate.has_proof_ref
        has_invocation_ref = [bool]$Candidate.has_invocation_ref
        evidence_refs = @($Candidate.evidence_refs)
    }
}

function New-SubjectFromDeclaredOrgan {
    param($Organ)

    return @{
        subject_id = "declared_organ_" + (Get-NormalizedId -Text ([string]$Organ.declared_organ_id))
        subject_type = "MAP_DECLARED_ORGAN"
        name = [string]$Organ.name
        capability = (@($Organ.capabilities) -join " ")
        family_root = [string]$Organ.declared_organ_id
        primary_path = [string]$Organ.source_map_ref
        candidate_type = "MAP_DECLARED_ORGAN"
        has_contract_ref = (@($Organ.contract_refs).Count -gt 0)
        has_passport_ref = (@($Organ.passport_refs).Count -gt 0)
        has_validator_ref = (@($Organ.validator_refs).Count -gt 0)
        has_proof_ref = (@($Organ.proof_refs).Count -gt 0)
        has_invocation_ref = (@($Organ.invocation_paths).Count -gt 0)
        evidence_refs = @($Organ.source_map_ref)
    }
}

function New-SubjectFromDeclaredCapability {
    param($Capability)

    return @{
        subject_id = "declared_capability_" + (Get-NormalizedId -Text ([string]$Capability.capability_id))
        subject_type = "MAP_DECLARED_CAPABILITY"
        name = [string]$Capability.name
        capability = [string]$Capability.capability_id
        family_root = [string]$Capability.capability_id
        primary_path = [string]$Capability.source_map_ref
        candidate_type = "MAP_DECLARED_CAPABILITY"
        has_contract_ref = $false
        has_passport_ref = $false
        has_validator_ref = (@($Capability.validator_refs).Count -gt 0)
        has_proof_ref = (@($Capability.proof_refs).Count -gt 0)
        has_invocation_ref = (@($Capability.invocation_refs).Count -gt 0)
        evidence_refs = @($Capability.source_map_ref)
    }
}

function Compare-Subjects {
    param(
        $A,
        $B
    )

    $features = @()
    $conflicts = @()
    $score = 0.0

    if ([string]$A.family_root -ne "" -and [string]$A.family_root -eq [string]$B.family_root) {
        $features += "SAME_FAMILY_ROOT"
        $score += 0.55
    }

    $aName = Get-NormalizedId -Text ([string]$A.name)
    $bName = Get-NormalizedId -Text ([string]$B.name)
    if ($aName -ne "unknown" -and $aName -eq $bName) {
        $features += "SAME_NORMALIZED_NAME_STEM"
        $score += 0.20
    }

    $sharedTokens = @(Get-SharedTokens -A (Get-Tokens -Text (([string]$A.name) + " " + ([string]$A.capability))) -B (Get-Tokens -Text (([string]$B.name) + " " + ([string]$B.capability))))
    if ($sharedTokens.Count -ge 2) {
        $features += ("SHARED_CAPABILITY_WORDS:" + ($sharedTokens -join ","))
        $score += [Math]::Min(0.20, 0.05 * $sharedTokens.Count)
    }

    if ($A.has_contract_ref -and $B.has_contract_ref) {
        $features += "BOTH_CONTRACT_BACKED"
        $score += 0.05
    }
    if ($A.has_passport_ref -and $B.has_passport_ref) {
        $features += "BOTH_PASSPORT_REFERENCED"
        $score += 0.05
    }
    if ($A.has_validator_ref -and $B.has_validator_ref) {
        $features += "BOTH_VALIDATOR_BACKED"
        $score += 0.05
    }
    if ($A.has_proof_ref -and $B.has_proof_ref) {
        $features += "BOTH_PROOF_REFERENCED"
        $score += 0.05
    }
    if ($A.has_invocation_ref -and $B.has_invocation_ref) {
        $features += "BOTH_INVOCATION_REFERENCED"
        $score += 0.05
    }

    if ([string]$A.candidate_type -ne [string]$B.candidate_type) {
        $conflicts += ("DIFFERENT_SURFACE_TYPES:" + [string]$A.candidate_type + "/" + [string]$B.candidate_type)
    }

    if ($score -gt 1.0) {
        $score = 1.0
    }

    return @{
        score = [Math]::Round($score, 3)
        matching_features = @($features)
        conflicting_features = @($conflicts)
    }
}

function Get-SimilarityStatus {
    param(
        $A,
        $B,
        $Comparison
    )

    $features = @($Comparison.matching_features)
    $score = [double]$Comparison.score

    if ($features -contains "SAME_FAMILY_ROOT") {
        return "SAME_FAMILY"
    }
    if ($A.subject_type -like "MAP_DECLARED_*" -and $B.subject_type -like "MAP_DECLARED_*" -and $score -ge 0.45) {
        return "CONFLICTING_ORGAN"
    }
    if ($score -ge 0.70 -and $features.Count -gt 1 -and -not ($features.Count -eq 1 -and $features[0] -eq "SAME_NORMALIZED_NAME_STEM")) {
        return "POSSIBLE_DUPLICATE"
    }
    if ($score -ge 0.35 -and $features.Count -gt 0) {
        return "FUNCTIONAL_OVERLAP"
    }
    return "UNKNOWN_SIMILARITY"
}

function New-SimilarityRecord {
    param(
        [string]$Id,
        $A,
        $B,
        [string]$Status,
        [double]$Score,
        [array]$MatchingFeatures,
        [array]$ConflictingFeatures,
        [array]$EvidenceRefs,
        [string]$Risk,
        [string]$RecommendedLogicAction
    )

    return @{
        similarity_id = $Id
        subject_a = $A
        subject_b = $B
        cluster_id = "cluster_" + (Get-NormalizedId -Text ([string]$A.family_root + "_" + [string]$B.family_root))
        similarity_status = $Status
        similarity_score = $Score
        matching_features = @($MatchingFeatures)
        conflicting_features = @($ConflictingFeatures)
        evidence_refs = @($EvidenceRefs)
        risk = $Risk
        recommended_logic_action = $RecommendedLogicAction
        forbidden_now = @(
            "promote either candidate",
            "delete duplicate",
            "merge files",
            "rewrite map",
            "claim replacement"
        )
    }
}

if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
}

$candidateIndex = Read-JsonFile -Path $CandidatePath
$bodyMap = Read-JsonFile -Path $BodyMapPath
$capabilityMap = Read-JsonFile -Path $CapabilityMapPath
$generatedAt = (Get-Date).ToUniversalTime().ToString("o")

$repoSubjects = @()
foreach ($candidate in @($candidateIndex.candidates)) {
    $repoSubjects += (New-SubjectFromCandidate -Candidate $candidate)
}

$declaredOrganSubjects = @()
$declaredCapabilitySubjects = @()
foreach ($source in @($bodyMap, $capabilityMap)) {
    foreach ($organ in @($source.declared_organs)) {
        $declaredOrganSubjects += (New-SubjectFromDeclaredOrgan -Organ $organ)
    }
    foreach ($capability in @($source.declared_capabilities)) {
        $declaredCapabilitySubjects += (New-SubjectFromDeclaredCapability -Capability $capability)
    }
}

$records = @()
$subjectsWithMatch = @{}
$recordLimit = 800
$pairOrdinal = 0

 $repoCompareSubjects = @($repoSubjects | Select-Object -First 160)
for ($i = 0; $i -lt $repoCompareSubjects.Count; $i++) {
        for ($j = $i + 1; $j -lt $repoCompareSubjects.Count; $j++) {
        if ($records.Count -ge $recordLimit) {
            break
        }
        $comparison = Compare-Subjects -A $repoCompareSubjects[$i] -B $repoCompareSubjects[$j]
        if ([double]$comparison.score -lt 0.35) {
            continue
        }
        $status = Get-SimilarityStatus -A $repoCompareSubjects[$i] -B $repoCompareSubjects[$j] -Comparison $comparison
        $pairOrdinal++
        $evidenceRefs = @($repoCompareSubjects[$i].evidence_refs + $repoCompareSubjects[$j].evidence_refs)
        $records += (New-SimilarityRecord -Id ("similarity_repo_repo_" + $pairOrdinal) -A $repoCompareSubjects[$i] -B $repoCompareSubjects[$j] -Status $status -Score $comparison.score -MatchingFeatures $comparison.matching_features -ConflictingFeatures $comparison.conflicting_features -EvidenceRefs $evidenceRefs -Risk "SIMILARITY_HEURISTIC_NOT_PROOF" -RecommendedLogicAction $(if ($status -eq "SAME_FAMILY") { "compare_validators" } else { "compare_contracts" }))
        $subjectsWithMatch[$repoCompareSubjects[$i].subject_id] = $true
        $subjectsWithMatch[$repoCompareSubjects[$j].subject_id] = $true
    }
}

foreach ($candidateSubject in @($repoSubjects | Select-Object -First 120)) {
    foreach ($declaredSubject in @($declaredOrganSubjects | Select-Object -First 60)) {
        if ($records.Count -ge $recordLimit) {
            break
        }
        $comparison = Compare-Subjects -A $candidateSubject -B $declaredSubject
        if ([double]$comparison.score -lt 0.25) {
            continue
        }
        $pairOrdinal++
        $status = Get-SimilarityStatus -A $candidateSubject -B $declaredSubject -Comparison $comparison
        $records += (New-SimilarityRecord -Id ("similarity_repo_map_organ_" + $pairOrdinal) -A $candidateSubject -B $declaredSubject -Status $status -Score $comparison.score -MatchingFeatures $comparison.matching_features -ConflictingFeatures $comparison.conflicting_features -EvidenceRefs @($candidateSubject.evidence_refs + $declaredSubject.evidence_refs) -Risk "MAP_SUPPORTED_SIMILARITY_NOT_PROOF" -RecommendedLogicAction "compare_contracts")
        $subjectsWithMatch[$candidateSubject.subject_id] = $true
    }
}

foreach ($candidateSubject in @($repoSubjects | Select-Object -First 120)) {
    foreach ($declaredCapabilitySubject in @($declaredCapabilitySubjects | Select-Object -First 60)) {
        if ($records.Count -ge $recordLimit) {
            break
        }
        $comparison = Compare-Subjects -A $candidateSubject -B $declaredCapabilitySubject
        if ([double]$comparison.score -lt 0.25) {
            continue
        }
        $pairOrdinal++
        $records += (New-SimilarityRecord -Id ("similarity_repo_map_capability_" + $pairOrdinal) -A $candidateSubject -B $declaredCapabilitySubject -Status "FUNCTIONAL_OVERLAP" -Score $comparison.score -MatchingFeatures $comparison.matching_features -ConflictingFeatures $comparison.conflicting_features -EvidenceRefs @($candidateSubject.evidence_refs + $declaredCapabilitySubject.evidence_refs) -Risk "CAPABILITY_DECLARATION_OVERLAP_HEURISTIC" -RecommendedLogicAction "compare_validators")
        $subjectsWithMatch[$candidateSubject.subject_id] = $true
    }
}

for ($i = 0; $i -lt $declaredOrganSubjects.Count; $i++) {
    for ($j = $i + 1; $j -lt $declaredOrganSubjects.Count; $j++) {
        if ($records.Count -ge $recordLimit) {
            break
        }
        $comparison = Compare-Subjects -A $declaredOrganSubjects[$i] -B $declaredOrganSubjects[$j]
        if ([double]$comparison.score -lt 0.35) {
            continue
        }
        $pairOrdinal++
        $records += (New-SimilarityRecord -Id ("similarity_map_map_" + $pairOrdinal) -A $declaredOrganSubjects[$i] -B $declaredOrganSubjects[$j] -Status (Get-SimilarityStatus -A $declaredOrganSubjects[$i] -B $declaredOrganSubjects[$j] -Comparison $comparison) -Score $comparison.score -MatchingFeatures $comparison.matching_features -ConflictingFeatures $comparison.conflicting_features -EvidenceRefs @($declaredOrganSubjects[$i].evidence_refs + $declaredOrganSubjects[$j].evidence_refs) -Risk "MAP_DECLARATION_CONFLICT_HEURISTIC" -RecommendedLogicAction "compare_contracts")
    }
}

foreach ($subject in @($repoSubjects)) {
    if ($subjectsWithMatch.ContainsKey($subject.subject_id)) {
        continue
    }
    $pairOrdinal++
    $records += (New-SimilarityRecord -Id ("similarity_unique_" + $pairOrdinal) -A $subject -B @{ subject_id = "NO_CLOSE_MATCH"; subject_type = "NO_CLOSE_MATCH"; name = "NO_CLOSE_MATCH"; capability = ""; family_root = ""; primary_path = ""; candidate_type = ""; evidence_refs = @() } -Status "UNIQUE_ORGAN_CANDIDATE" -Score 0.0 -MatchingFeatures @() -ConflictingFeatures @("no close match above heuristic threshold") -EvidenceRefs @($subject.evidence_refs) -Risk "UNIQUE_IS_HEURISTIC_NOT_PROMOTION" -RecommendedLogicAction "mark_unique_candidate")
}

$statusCounts = @{}
foreach ($record in @($records)) {
    $status = [string]$record.similarity_status
    if (-not $statusCounts.ContainsKey($status)) {
        $statusCounts[$status] = 0
    }
    $statusCounts[$status] = $statusCounts[$status] + 1
}

$output = @{
    schema = "organ_similarity_index_v1"
    status = "PASS_ORGAN_SIMILARITY_DETECTION_V1"
    generated_at = $generatedAt
    source_refs = @{
        organ_candidates = $CandidatePath
        body_map_read = $BodyMapPath
        capability_map_read = $CapabilityMapPath
    }
    similarity_records = @($records)
    aggregates = @{
        similarity_record_count = @($records).Count
        repo_candidate_subject_count = @($repoSubjects).Count
        declared_organ_subject_count = @($declaredOrganSubjects).Count
        declared_capability_subject_count = @($declaredCapabilitySubjects).Count
        status_counts = $statusCounts
        record_limit = $recordLimit
        repo_compare_subject_limit = 160
        map_compare_subject_limit = 60
    }
    scoring_boundary = @{
        similarity_score = "heuristic_not_proof"
        duplicate_boundary = "duplicate is not proven solely by filename"
        forbidden = @("automatic deletion", "automatic merge", "map rewrite", "organ promotion")
    }
    stale_after = "24h"
    boundary = New-BodyInspectionBoundary
    errors = @()
}

$outputPath = Join-Path $RuntimeRoot "organ_similarity_index.json"
Write-JsonFile -Path $outputPath -Data $output
Write-Output $outputPath
