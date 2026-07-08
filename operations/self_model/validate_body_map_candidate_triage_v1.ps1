$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$proofPath='tests/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1_PROOF.json'
$mapPath='reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
foreach($p in @($reportPath,$proofPath,$mapPath)){Assert (Test-Path $p) ("MISSING:{0}" -f $p)}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$m=Get-Content $mapPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_BODY_MAP_CANDIDATE_TRIAGE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_BODY_MAP_CANDIDATE_TRIAGE_V1') 'PROOF_STATUS_BAD'
$sourceCandidates=@($m.primary_evidence_candidates)
$items=@($r.items)
Assert ($sourceCandidates.Count -gt 0) 'SOURCE_CANDIDATES_MISSING'
Assert ($items.Count -eq $sourceCandidates.Count) ("TRIAGE_COUNT_MISMATCH:{0}:{1}" -f $items.Count,$sourceCandidates.Count)
Assert (@($items.candidate_id|Sort-Object -Unique).Count -eq $items.Count) 'DUPLICATE_TRIAGE_IDS'
$sourceIds=@($sourceCandidates|ForEach-Object{$_.id})
foreach($it in $items){
  Assert ($sourceIds -contains $it.candidate_id) ("TRIAGED_UNKNOWN_ID:{0}" -f $it.candidate_id)
  Assert (-not [string]::IsNullOrWhiteSpace([string]$it.triage_class)) ("CLASS_MISSING:{0}" -f $it.candidate_id)
  Assert (-not [string]::IsNullOrWhiteSpace([string]$it.next_action)) ("NEXT_ACTION_MISSING:{0}" -f $it.candidate_id)
  Assert (-not [string]::IsNullOrWhiteSpace([string]$it.passport_readiness)) ("PASSPORT_READINESS_MISSING:{0}" -f $it.candidate_id)
}
Assert (@($items|Where-Object{$_.triage_class -eq 'REAL_ORGAN_CANDIDATE'}).Count -gt 0) 'NO_REAL_ORGAN_CANDIDATES'
$classCounts=@($r.triage_counts.class_counts)
Assert ($classCounts.Count -gt 1) 'CLASS_COUNTS_EMPTY_OR_BLANK'
foreach($cc in $classCounts){Assert (-not [string]::IsNullOrWhiteSpace([string]$cc.triage_class)) 'CLASS_COUNT_BLANK_NAME'; Assert ([int]$cc.count -gt 0) 'CLASS_COUNT_ZERO'}
Assert ($r.boundaries.no_organ_promotion_performed -eq $true) 'ORGAN_PROMOTION_BOUNDARY_BAD'
Assert ($r.boundaries.no_passport_generation_performed -eq $true) 'PASSPORT_GENERATION_BOUNDARY_BAD'
Assert ($r.boundaries.triage_is_classification_not_acceptance -eq $true) 'TRIAGE_ACCEPTANCE_BOUNDARY_BAD'
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Assert ($p.all_candidates_classified -eq $true) 'PROOF_ALL_CLASSIFIED_FALSE'
Assert ($p.unique_candidate_ids -eq $true) 'PROOF_UNIQUE_IDS_FALSE'
Write-Host 'VALIDATION_PASS=PASS_BODY_MAP_CANDIDATE_TRIAGE_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)

